
/*HEADER------------------------------------------------------------------------
|
| program:  edw_guideline_master_incremental_prospective.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Call the specific client's guideline program to run prospective guideines from the EDW
|
| logic:   Use the client_id to determine which shell to run 
|              
| input:    client_id   - the client id from vmine (e.g., 4=NSAP) 
|		
| output:   Guideline SAS datasets
|
+--------------------------------------------------------------------------------
| history:  
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
| 13JAN2012 - Robyn Stellman  - Clinical Integration  1.1.01
|             Implement into Production
| 11APR2012 - EM No longer resolving guidelibname, this macro is not used anywhere
| 03MAY2012 - KN libname rename to accommodate hardware issues 
| 07MAY2012 - EM redirecting cistage libname to the initial location 
| 08MAY2012 - LS modify to only run incremental prospective - split guideline master into 3.
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
%bpm_environment;

%let client = &client_short_name.; 

*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to start.    
+------------------------------------------------------------------------SASDOC*; 
%bpm_process_control(timevar=START);



*SASDOC--------------------------------------------------------------------------
| Retrieve the client guideline shell parameters
|
+------------------------------------------------------------------------SASDOC*; 
/*EM 04/02/2012 - Not resolving in BPM environment, so need to resolve it here*/
%let fg_guide =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=fg_Guidelines;"); 
libname fg_guide oledb init_string=&fg_guide.   preserve_tab_names=yes readbuff=10000;

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


%put NOTE: edw_directory = &edw_directory. ;

%let client_key = &client_id.;

%set_error_flag;
%on_error(ACTION=ABORT);


/* SASDOC--------------------------------------------------------------------------*
| Run Prospective Pieces:
| Create libnames first
| Run Registry & Care Elements
|+------------------------------------------------------------------------SASDOC*; */
libname control "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\control";
libname valence "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\valence\control";

%macro reg_lib;
%mvarexist(SAS_MODE); 
	%if &mvarexist. %then %do;
		%if %upcase(&sas_mode)=TEST %then %do;  	
 			libname registry "M:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\Registry\Testing";
			libname cistage "M:\sastemp\CIStaging\GD TESTING"; 	
 		%end;
 	
 		%else %do;
			libname registry "m:\CI\sasdata\ValenceBaseMeasures\Guideline Development\%sysfunc(strip(&client.))\registry";
			libname cistage "M:\SASTEMP\CIStaging\&client";                                   
		%end;
	%end;
%mend;
%reg_lib;

     
/** RUN THE PROSPECTIVE PIECES  **/

/* Incremental Run: use setup2 */
%include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Prospective Logic\Release 1.0 Prospective Front End Setup2_v3.sas"; 

*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to complete.        
+------------------------------------------------------------------------SASDOC*;
%bpm_process_control(timevar=COMPLETE);
