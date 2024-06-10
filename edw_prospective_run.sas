
/*HEADER------------------------------------------------------------------------
|
| program:  edw_prospective_Run.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Run the prospective pieces for the guidelines from the EDW
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

/*%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=70 client_id=6  sas_mode=prod );*/
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
libname control "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\control";
libname valence "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\valence\control";
libname release "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\Registry\Development";
libname cistage "M:\sastemp\CIStaging\DEV TESTING";

/*
%macro reg_lib;

%mvarexist(SAS_MODE); 
   %if &mvarexist. %then %do;
 	%if %upcase(&sas_mode)=TEST %then %do; 
 	
 libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\Registry\Development";
 	
 	%end;
 	
 	%else %do;

libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\Registry\Development";
                                  
	%end;
	%end;
%mend;
%reg_lib;
*/


libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\Registry\Development";

/* WORKFLOW #1: RUN THE PROSPECTIVE PIECES */
%*let include = %str(M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Testing\Split Workflow Prospective Pieces\Release 1.0 Prospective Logic.sas);  
%*include "&include.";

data trash2;
  set ciedw.member;
  where client_key=15;
run;


%let err_fl=1;
%set_error_flag;
%on_error(ACTION=ABORT);





*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to complete.        
+------------------------------------------------------------------------SASDOC*;
%bpm_process_control(timevar=COMPLETE);
