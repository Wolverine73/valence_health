
/*HEADER------------------------------------------------------------------------
|
| program:  edw_consolidate_guildeines.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Finalize the guidelines process (run the outlier report, load the data marts)
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



*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*; 

/*%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=74 client_id=6  sas_mode=prod );*/
%bpm_environment;


*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to start.    
+------------------------------------------------------------------------SASDOC*; 
%bpm_process_control(timevar=START);


libname cistage "M:\sastemp\CIStaging\DEV TESTING";

 
*SASDOC--------------------------------------------------------------------------
| Run the outlier reports
|
+------------------------------------------------------------------------SASDOC*;  
 %edw_outlier_report;

*SASDOC--------------------------------------------------------------------------
| Insert the data into the data marts
| 1. Refresh the guidelines and guideline_submeasures tables in CIEDW
| 2. Load the DMPAT_GUIDELINE_SNAPSHOT table in the appropriate data mart
| 3. Load the DMPVR_GUIDELINES table in the appropriate data mart
|
+------------------------------------------------------------------------SASDOC*; 

/*%include "M:\CI\programs\EDW\edw_insert_guidelines.sas"; */

%set_error_flag;
%on_error(ACTION=ABORT);

*SASDOC--------------------------------------------------------------------------
| Update the sasbiweb.CI_CLIENT_PARAMETERS table with the run date and the most
|  recent claim date
|
+------------------------------------------------------------------------SASDOC*; 

libname sasbi oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;
              Initial Catalog=SASBIWEB;" preserve_tab_names=yes insertbuff=10000 readbuff=10000; 
              
/*
proc sql noprint;
  create table maxdt as
  select max(datepart(svcdt2)) as mxdt format date9.
  from ciedw.vguidelineinput
  where client_key=&client_id.
  ;
quit;  

*/

data _null_;
  format mxdt date9.;
/*  set maxdt;
  max_clm_dt= put(mxdt,date9.); */
  rundt=put(today(),mmddyy10.);  
/*  call symput('max_claim_date',max_clm_dt); */
  call symput('rundt',rundt);
run;

/*%put &max_claim_date.; */
%put &rundt.;

/*
proc sql;
  update sasbi.CI_CLIENT_PARAMETERS
  set parameter_value = &max_claim_date.     
  where client_key=&client_id.
  and parameter_key=34;
quit;
*/

/*
proc sql;
  update sasbi.CI_CLIENT_PARAMETERS
  set parameter_value = &rundt.
  where client_key=&client_id.
  and parameter_key=35;
quit;
*/

*SASDOC--------------------------------------------------------------------------
| Drop the member temp table created earlier in the process
|
+------------------------------------------------------------------------SASDOC*;

/*proc sql;*/
/*	connect to oledb(init_string=&sqlci.);*/
/*	execute ( */
/*	  drop table [cihold].[dbo].[saswrk_gline_member_&wflow_exec_id.]  */
/*		              ) */
/*	    by oledb; */
/*quit;*/


%set_error_flag;
%on_error(ACTION=ABORT);


*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to complete.        
+------------------------------------------------------------------------SASDOC*;
%bpm_process_control(timevar=COMPLETE);
