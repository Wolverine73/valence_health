
/*HEADER------------------------------------------------------------------------
|
| program:  edw_prior_run.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Run the prior period for the guidelines
|
| logic:    
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
| 16FEB2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
+-----------------------------------------------------------------------HEADER*/

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

/*%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=73 client_id=6  sas_mode=prod );*/
%bpm_environment;


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

%let client_key = &client_id.;

%set_error_flag;
%on_error(ACTION=ABORT);

/**/
/**/
/**SASDOC--------------------------------------------------------------------------*/
/*| run care elements and registry*/
/*|*/
/*+------------------------------------------------------------------------SASDOC*; */
/**/

/*
libname control "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\control";
libname valence "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\valence\control";
libname release "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry";
libname cistage "M:\SASTEMP\CIStaging\&client";
*/
/*
%macro reg_lib;

%mvarexist(SAS_MODE); 
   %if &mvarexist. %then %do;
 	%if %upcase(&sas_mode)=TEST %then %do; 
 	
 libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\Registry\Development";
 	
 	%end;
 	
 	%else %do;

libname registry "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry";
                                  
	%end;
	%end;
%mend;
*/
/*%reg_lib; */

libname control "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\control";
libname valence "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\valence\control";
libname release "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry\Development";
libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\Registry\Development";
libname cistage "M:\SASTEMP\CIStaging\DEV TESTING";



/* WORKFLOW #3: Run the Guidelines */
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
/*
data _null_;
  run_day = day(today());
  call symputx('day_run',run_day);
run;

*/
%let day_run = 15;

%if &run_day. = &day_run. %then %do; 


%put *********************************************;
%put NOTE: ***************************************;
%put NOTE: Today is a guideline run day &day_run.;
%put NOTE: ***************************************;
%put *********************************************;

/*
libname current1 "M:\CI\sasdata\guidelines\client_&client_id.\current";
libname prior1 "M:\CI\sasdata\guidelines\client_&client_id.\prior";
libname out_det "M:\CI\sasdata\guidelines\client_&client_id.";
libname release "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry";


%let current1 = M:\CI\sasdata\guidelines\client_&client_id.\current;
%let prior1 = M:\CI\sasdata\guidelines\client_&client_id.\prior;
%let out_det = M:\CI\sasdata\guidelines\client_&client_id.;
*/

libname current1 "M:\CI\sasdata\guidelines\client_&client_id.\Development\current";
libname prior1 "M:\CI\sasdata\guidelines\client_&client_id.\Development\prior";
libname out_det "M:\CI\sasdata\guidelines\client_&client_id.\Development";
libname release "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry\Development";


%let current1 = M:\CI\sasdata\guidelines\client_&client_id.\Development\current;
%let prior1 = M:\CI\sasdata\guidelines\client_&client_id.\Development\prior;
%let out_det = M:\CI\sasdata\guidelines\client_&client_id.\Development;

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


%Guidelines_Configuration_Shell_test(		client_data=&client_name.,
										run_type=Production,
										program_type=Retrospective,
										client_parameters=&client_name.,
										gl_enddt=&gl_enddt.,
										run_g0=Y,
										delete_g0=Y,
										runprior=Y,
										runCurrent=N,
										Run_all=Y,
										Run_these= ,
										Run_except= ,
										legacy=N
									  );


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

%end;

%else %do;
%put *********************************************;
%put NOTE: ***************************************;
%put NOTE: Today is NOT a guideline run day       ;
%put NOTE: Guidelines are run on the &run_day     ;
%put NOTE: ***************************************;
%put *********************************************;

%end;


/*%let err_fl=1; */
%set_error_flag;
%on_error(ACTION=ABORT);


%mend;
%run_guidelines;



*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to complete.        
+------------------------------------------------------------------------SASDOC*;
%bpm_process_control(timevar=COMPLETE);
