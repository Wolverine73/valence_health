
/*HEADER------------------------------------------------------------------------
|
| program:  edw_guideline_master.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Call the specific client's guideline program to run guideines from the EDW
|
| logic:   Use the client_id to determine which shell to run 
|              
|
| input:    client_id   - the client id from vmine (e.g., 4=NSAP) 
|		
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
options mprint mlogic symbolgen msglevel=i error=2 ls=100 ps=60;
option spool;


*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*; 
/*%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=68 client_id=4  sas_mode=test );*/
/*%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=68 client_id=6  sas_mode=test );*/
%bpm_environment;


/*******************************************************************************************************************/
/*** testing cccpp - hard coded values to overwrite nsap values ****************************************************/
/*******************************************************************************************************************/

libname ciedw oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;
              Initial Catalog=CIEDW_BL_TEST;" preserve_tab_names=yes insertbuff=10000 readbuff=10000; 
              
/*******************************************************************************************************************/

*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to start.    
+------------------------------------------------------------------------SASDOC*; 
%bpm_process_control(timevar=START);



*SASDOC--------------------------------------------------------------------------
| Retrieve the client guideline shell parameters
|
+------------------------------------------------------------------------SASDOC*; 
proc sql;
  create table active_clientmacroparameters as 
  select *
  from fg_guide.active_clientmacroparameters
  where clientid = &client_id.;
quit;

data _null_;
  set active_clientmacroparameters  ;
  call symput(client_var,trim(left(paramvalue))); 
  put @1 _n_  @10 client_var  @40 paramvalue;
run;

%let guidelibname = &guideline_libname.;

%put NOTE: edw_directory = &edw_directory. ;

%set_error_flag;
%on_error(ACTION=ABORT);




*SASDOC--------------------------------------------------------------------------
| run care elements and registry
|
+------------------------------------------------------------------------SASDOC*; 

/**COMMENTED OUT FOR TESTING - DON'T WANT TO OVERWRITE THESE BY ACCIDENT **/
%*include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Prospective Logic\Release 1.0 Prospective Front End Setup.sas";

%*set_error_flag;
%*on_error(ACTION=ABORT);

*SASDOC--------------------------------------------------------------------------
| Only run guidelines on the assigned guideline day
|
+------------------------------------------------------------------------SASDOC*; 


%macro run_guidelines;

proc sql noprint;
  select paramvalue into: run_day
  from fg_guide.active_clientmacroparameters
  where clientid=&client_id.
  and client_var='run_day'
  ;
quit;

%*let run_day = 4;

%put NOTE: Guideline Run Day is &run_day.;

data _null_;
  run_day = day(today());
  call symputx('day_run',run_day);
run;

%if &run_day. = &day_run. %then %do; 


%put *********************************************;
%put NOTE: ***************************************;
%put NOTE: Today is a guideline run day &day_run.;
%put NOTE: ***************************************;
%put *********************************************;

libname current1 "M:\CI\sasdata\guidelines\%qcmpres(&client_name.)\current";
libname prior1 "M:\CI\sasdata\guidelines\%qcmpres(&client_name.)\prior";
libname out_det "M:\CI\sasdata\guidelines\%qcmpres(&client_name.)";
libname release "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\CCCPP\Registry";

%let current1 = M:\CI\sasdata\guidelines\%qcmpres(&client_name.)\current;
%let prior1 = M:\CI\sasdata\guidelines\%qcmpres(&client_name.)\prior;
%let out_det = "M:\CI\sasdata\guidelines\%qcmpres(&client_name.)";

*SASDOC--------------------------------------------------------------------------
| call guideline configuration program and run guidelines
|
+------------------------------------------------------------------------SASDOC*; 

/** Calculate the current period end date from the run date **/
%let apst = %str(%');
data _null_;
	  mon1 = month(today()) - (&lag_number.);
	  year1 = year(today());
	  gl_enddt = "&apst."||put(mdy(cats(mon1),'01',cats(year1)),date9.)||"&apst."||"d";
	  call symput('gl_enddt',gl_enddt);   /** current end date **/
	run;

%put &gl_enddt.;

/*** FOR TESTING ONLY ***/
/*libname cistage "M:\SASTEMP\CIStaging\%qcmpres(&client_name.)"; */

/*data g0_edw; */
/*  set cistage.g0_edw;  */
/*  where member_key ne -99; */
/*  drop memberid; */
/*run; */

/*data g0_edw;  */
/*  format memberid 16.; */
/*  set g0_edw; */
/*  memberid=member_key; */
/*run; */
/*options obs=10000000; */
/** END OF TESTING ADDITION **/

%guidelines_configuration_shell(client_data=&client_name. ,run_type=Production , program_type=Retrospective , client_parameters=&client_name. ,gl_enddt=&gl_enddt. ,run_g0=N ,
                                  runprior=Y ,run_all=Y ,run_these= ,run_except= ,legacy=N );

%set_error_flag;
%on_error(ACTION=ABORT);


*SASDOC--------------------------------------------------------------------------
| Create submeasures details and other final datasets for loading
|   1. Submeasures_detail
|   2. Submeasures_current
|   3. Submeasures_prior
|   4. Portal Dates
|
+------------------------------------------------------------------------SASDOC*; 



%portal_dates(period=prior);
%set_error_flag;
%on_error(ACTION=ABORT);

%portal_dates(period=current);
%set_error_flag;
%on_error(ACTION=ABORT);

proc sql noprint;
  select count(*) from g0_edw into: src_record_cnt
  where client_key=&client_id.
  ;
quit;

proc sql noprint;
  select count(*) from out_det.submeasures_detail into: tgt_record_cnt
  ;
quit;

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

%*include "M:\CI\programs\EDW\insert_guidelines.sas";
%*set_error_flag;
%*on_error(ACTION=ABORT);

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
%run_guidelines;



*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to complete.        
+------------------------------------------------------------------------SASDOC*;
%bpm_process_control(timevar=COMPLETE);
