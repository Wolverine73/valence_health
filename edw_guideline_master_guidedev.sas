
/*HEADER------------------------------------------------------------------------
|
| program:  edw_guideline_master_guidedev.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Call the specific client's guideline program to run guideines from the EDW
|
| logic:   Use the client_id to determine which shell to run 
|              
| input:    client_id   - the client id from vmine (e.g., 4=NSAP) 
|                        
| output:   Guideline SAS datasets
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 13JAN2012 - Robyn Stellman  - Clinical Integration  1.1.01
|             Implement into Production
|             
| 11APR2012 - EM No longer resolving guidelibname, this macro is not used anywhere
|
| 03MAY2012  - KN libname rename to accommodate hardware issues 
| 07MAY2012  - EM redirecting cistage libname to the initial location 
| 26JUL2012 - LS modify Skelta to poingtto GuideDev Team's Development/Testing Folders
| 01AUG2012 - EM removed the delete_g0 macro in the %Guidelines_Configuration_Shell 
|				  because it no longer exists
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
options mprint mlogic symbolgen msglevel=i error=2 ls=100 ps=60;

option spool;


/** This line is a proposed solution to the core-dump type of crash **/
/** it may need to be increased to 512k    RDS 10FEB2012            **/
Options MEXECSIZE=512k mcompilenote=ALL;



*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*; 
/*%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=68 client_id=4  sas_mode=test );*/
/*%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=68 client_id=6  sas_mode=prod );*/
%bpm_environment;


*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to start.    
+------------------------------------------------------------------------SASDOC*; 
%bpm_process_control(timevar=START);

%let run_key = 1;
%let payer_key = 4;
%let client_key =  15;

libname output1 "M:\CI\sasdata\HEDIS\client_&client_key\payer_&payer_key\output1";

/** will need to get this from the client table based on client_key for production **/
%let dmart=DM_TCHP;


%let data_mart =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=&dmart.;");

libname dmart  oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;
              Initial Catalog=&dmart.;" preserve_tab_names=yes insertbuff=10000 readbuff=10000 insert_sql=yes;

%macro hedis_load;

data tables;
	  set sashelp.vtable;
	run;

	data temp1 temp2;
	  set tables;
	  if upcase(libname)='OUTPUT1' and nvar > 3 and memname not in ('HEDIS_ATTRIB_LOAD','HEDIS_LOAD','HEDIS_DATES_ALL') 
        then output temp1;
	  if upcase(libname)='OUTPUT1' and nvar = 3 then output temp2;
	run;

	data _null_;
	  set temp1  end=eof;
	  i+1;
	  ii=left(put(i,4.));
	  call symput('table'||ii,memname);
	  if eof then call symput('table_total',ii);
	run;	


	*SASDOC--------------------------------------------------------------------------
	| Measure Output 
	------------------------------------------------------------------------SASDOC*;  
	data hedisout1 (compress=binary);
	  length meas $15. drill_1 $4. guideline_key $20.;
	  format meas $15. drill_1 $4. guideline_key $20.;
	  set %do g=1 %to &table_total. ;
	        output1.&&table&g
	      %end;;
    client_key = &client_key.;
	run;

	data _null_;
	  set temp2  end=eof;
	  where memname ne 'HEDIS_DATES_ALL';
	  i+1;
	  ii=left(put(i,4.));
	  call symput('table'||ii,memname);
	  if eof then call symput('table_total',ii);
	run;	


	*SASDOC--------------------------------------------------------------------------
	| Attribution Output 
	------------------------------------------------------------------------SASDOC*;  
	data hedis_attrib (compress=binary);
	  length pcpid $10. guideline_key $20.;
	  format pcpid $10. guideline_key $20. memid 16.;
	  set %do h=1 %to &table_total. ;
	        output1.&&table&h
	      %end;;

	run;



data hedis_load;
   format memberid $16. created_on datetime. guideline_name measure_name $50.;
   set hedisout1;
   memberid=memid;
   run_key=&run_key.;			
   
   created_on=datetime();
   created_by='BPM-SAS';

   guideline_name='';
   measure_name=''; 

   rename memberid=member_key
   		 guideline_key=guideline_external_id
		 meas=measure_id
		 payer=payer_category
		 epop=is_eligible
		 excl=is_exclusion
		 num=is_compliant
		 ;
    
run;
   
/** Delete records from last run - do not truncate in order to keep the table key consistent **/
/** and avoide duplicate primary keys                                                        **/


proc sql;
				connect to oledb(init_string=&data_mart.);
				
					execute (
					TRUNCATE TABLE dbo.DMPAT_HEDIS_OUTPUT1_STAGE
				)
				by oledb;
   quit;

    proc append base=dmart.DMPAT_HEDIS_OUTPUT1_STAGE(dbsastype=(member_key='char(16)') IGNORE_READ_ONLY_COLUMNS=YES) 
               data=hedis_load force;
   run;

   
data hedis_attrib_load;
   format member_key $16. created_on datetime. pcpid $10.;
   set hedis_attrib;
   member_key=memid;
   run_key=&run_key.;	
   client_key=&client_key.;
   
   created_on=datetime();
   created_by='BPM-SAS';

run;
   
/*
    proc append base=dmart.DMPAT_HEDIS_ATTRIB_STAGE(dbsastype=(member_key='char(16)') IGNORE_READ_ONLY_COLUMNS=YES) 
               data=hedis_attrib_load force;
   run;
*/

proc sort data=output1.hedis_dates_all;by guideline_key;run;

/** Load the HEDIS date value table to SQL **/
proc transpose data = output1.hedis_dates_all
    out = hedis_dates (drop=_name_ _label_) ;
	by guideline_key;
	id name;
	var value;
run;

data hedis_dates;
  set hedis_dates;
  client_key=&client_key.;
  run_key=&run_key.;
run;

/*
    proc append base=dmart.DMPAT_HEDIS_DATES IGNORE_READ_ONLY_COLUMNS=YES) 
               data=hedis_dates force;
   run;
*/


%mend;
%hedis_load;



%let err_fl=1;
%set_error_flag;
%on_error(ACTION=ABORT);


%bpm_process_control(timevar=COMPLETE);




*SASDOC--------------------------------------------------------------------------
| Retrieve the client guideline shell parameters
|
+------------------------------------------------------------------------SASDOC*; 
/*
proc sql;
  create table active_clientmacroparameters as 
  select *
  from fg_guide.active_clientmacroparameters
  where clientid = &client_id.;
quit;
*/

/*
data _null_;
  set active_clientmacroparameters  ;
  call symput(client_var,trim(left(paramvalue))); 
  put @1 _n_  @10 client_var  @40 paramvalue;
run;
*/


/*%put NOTE: edw_directory = &edw_directory. ;*/

%let client_key = &client_id.;

%set_error_flag;
%on_error(ACTION=ABORT);


/**SASDOC--------------------------------------------------------------------------*/
/*| run care elements and registry*/
/*|*/
/*+------------------------------------------------------------------------SASDOC*; */
/*libname control "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\control";*/
/*libname valence "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\valence\control";*/

/*libname release "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry";*/
/*libname release "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\CCCPP\Registry\prod";*/

/*libname cistage "M:\SASTEMP\CIStaging\&client";*/
/*libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\CCCPP\Registry\prod";*/
                                  

/*libname control "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\control";*/
/*libname valence "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\valence\control";*/
/*libname release "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\guideline testing";*/
/*libname cistage "M:\SASTEMP\CIStaging\CCCPP"; */
/*libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\guideline testing";*/
 	
/**RUN THE PROSPECTIVE PIECES - comment out when running guidelines **/
/* Full Run: use setup1  - using Member table */
/*%include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Prospective Logic\Release 1.0 Prospective Front End Setup1_v2.sas";*/


/* Full TEST Run: use setup1  - using Member table */
/*%include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Development\Release 1.0 Prospective Front End HM Setup Test.sas";*/

/* Incremental Run: use setup2 */
/*%include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Prospective Logic\Release 1.0 Prospective Front End Setup2_v2.sas";*/

/*Full Run with HM  */  
/*%include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Prospective Logic\Release 1.0 Prospective Front End Setup1_v3.sas"; */


/* Comment these out when running guidelines: */
%let err_fl=1;
%set_error_flag;
%on_error(ACTION=ABORT);


/**SASDOC--------------------------------------------------------------------------*/
/*| Only run guidelines on the assigned guideline day*/
/*|*/
/*+------------------------------------------------------------------------SASDOC*; */


%macro run_guidelines;

proc sql noprint;
  select paramvalue into: run_day
  from fg_guide.active_clientmacroparameters
  where clientid=&client_id.
  and client_var='run_day'
  ;
quit;

%put NOTE: Guideline Run Day is &run_day.;

/*  COMMENTED OUT FOR TESTING - RESTORE WHEN GOING LIVE */

/*data _null_;*/
/*  run_day = day(today());*/
/*  call symputx('day_run',run_day);*/
/*run;*/


%let day_run = 15;

%if &run_day. = &day_run. %then %do; 


%put *********************************************;
%put NOTE: ***************************************;
%put NOTE: Today is a guideline run day &day_run.;
%put NOTE: ***************************************;
%put *********************************************;
/* Create directory if it does not exist for a client.  This happens when new client starts CIO Release 1.0 Process */
%let current1 = M:\CI\sasdata\guidelines\client_&client_id.\current;
%let prior1 = M:\CI\sasdata\guidelines\client_&client_id.\prior;
%let out_det = M:\CI\sasdata\guidelines\client_&client_id.;

%put &current1;
%put &prior1;

x if not exist &current1. mkdir &current1.;
x if not exist &prior1. mkdir &prior1.;

libname current1 "M:\CI\sasdata\guidelines\client_&client_id.\current";
libname prior1 "M:\CI\sasdata\guidelines\client_&client_id.\prior";
libname out_det "M:\CI\sasdata\guidelines\client_&client_id.";
/*libname release "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry";*/
libname release "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\CCCPP\Registry\prod";


%let current1 = M:\CI\sasdata\guidelines\client_&client_id.\current;
%let prior1 = M:\CI\sasdata\guidelines\client_&client_id.\prior;
%let out_det = M:\CI\sasdata\guidelines\client_&client_id.;

/**SASDOC--------------------------------------------------------------------------*/
/*| call guideline configuration program and run guidelines*/
/*|*/
/*+------------------------------------------------------------------------SASDOC*; */
/**/
/** Calculate the current period end date from the run date **/
%let apst = %str(%');
data _null_;
	  k = intnx('month',today(),-&lag_number.,'same');
	  mon1 = month(k);
	  year1 = year(k);
	  gl_enddt = "&apst."||put(mdy(cats(mon1),'01',cats(year1)),date9.)||"&apst."||"d";
	  call symput('gl_enddt',gl_enddt);   /** current end date **/
	run;

%put &gl_enddt.;

/* When running a subset of guidelines, enter them in as: run_these = "310.1.1.0.3" "310.5.1.0.3", */
/*%guidelines_configuration_shell(client_data=&client_name.,*/
/*								run_type=Production , */
/*								program_type=Retrospective , */
/*								client_parameters=&client_name. ,*/
/*								gl_enddt=&gl_enddt. ,*/
/*                                run_g0= N, */
/*								copy_g0= Y,*/
/*                                runprior= Y, */
/*								runCurrent=N,*/
/*								run_all= N,*/
/*								run_these=  "310.7.1.0.3" "400.2.1.0.3",*/
/*								run_except= ,*/
/*								legacy=N ); */
/**/
/**/
/*%set_error_flag;*/
/*%on_error(ACTION=ABORT);*/


*SASDOC--------------------------------------------------------------------------
| Create submeasures details and other final datasets for loading
|   1. Submeasures_detail
|   2. Submeasures_current
|   3. Submeasures_prior
|   4. Portal Dates
|
+------------------------------------------------------------------------SASDOC*; 
%let apst = %str(%');
data _null_;
	  k = intnx("month",today(),-&lag_number.,"same");
	  mon1 = month(k);
	  year1 = year(k);
	  gl_enddt = "&apst."||put(mdy(cats(mon1),'01',cats(year1)),date9.)||"&apst."||"d";
	  call symput("gl_enddt",gl_enddt);   /** current end date **/
	run;

%put &gl_enddt.;


%portal_dates(period=prior);
%set_error_flag;
%on_error(ACTION=ABORT);

%portal_dates(period=current);
%set_error_flag;
%on_error(ACTION=ABORT);


libname out_det "M:\CI\sasdata\guidelines\client_&client_id.";

proc sql noprint;
  select count(*) into: tgt_record_cnt
    from out_det.submeasures_detail 
  ;
quit;


%put G0 Record count is &src_record_cnt.;  
%put Submeasures_Detail Record count is &tgt_record_cnt.;

proc sql noprint;
  update vbpm.sk_process_control a
  set src_record_cnt = &src_record_cnt.
  where a.wflow_exec_id=&wflow_exec_id.
  and a.client_id=&client_id.
  and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
quit;

proc sql noprint;
  update vbpm.sk_process_control a
  set tgt_record_cnt = &tgt_record_cnt.
  where a.wflow_exec_id=&wflow_exec_id.
  and a.client_id=&client_id.
  and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
quit;

*SASDOC--------------------------------------------------------------------------
| Insert the data into the data marts
| 1. Refresh the guidelines and guideline_submeasures tables in CIEDW
| 2. Load the DMPAT_GUIDELINE_SNAPSHOT table in the appropriate data mart
| 3. Load the DMPVR_GUIDELINES table in the appropriate data mart
|
+------------------------------------------------------------------------SASDOC*; 

/* Deleted insert guidelines for adhoc runs */

*SASDOC--------------------------------------------------------------------------
| Update the sasbiweb.CI_CLIENT_PARAMETERS table with the run date and the most
|  recent claim date
|
+------------------------------------------------------------------------SASDOC*; 

libname sasbi oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;
              Initial Catalog=SASBIWEB;" preserve_tab_names=yes insertbuff=10000 readbuff=10000; 
              


%let apst = %str(%');
data _null_;

 
 rundt="&apst."||put(today(),mmddyy10.)||"&apst.";  
 

  call symput('rundt',rundt);
run;

%put &rundt.;


/*proc sql;*/
/*  update sasbi.CI_CLIENT_PARAMETERS*/
/*  set parameter_value = &rundt.*/
/*  where client_key=&client_id.*/
/*  and parameter_key=35;*/
/*quit;*/


%end;

%else %do;
%put *********************************************;
%put NOTE: ***************************************;
%put NOTE: Today is NOT a guideline run day       ;
%put NOTE: Guidelines are run on the &run_day     ;
%put NOTE: ***************************************;
%put *********************************************;

%end;


%let err_fl=1;
%set_error_flag;
%on_error(ACTION=ABORT);


%mend;
/*%run_guidelines;*/



*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to complete.        
+------------------------------------------------------------------------SASDOC*;
%bpm_process_control(timevar=COMPLETE);