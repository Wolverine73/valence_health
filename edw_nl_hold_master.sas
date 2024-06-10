
/*HEADER------------------------------------------------------------------------
|
| program:  edw_nl_hold_master.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Master Program to kick off NL HOLD programs
|
| logic:    
|
| input:    Macro parameters and /or SQL server practices
|           sk_prcs_ctrl_id - bpm process identifier
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|                        
| output:   
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 26MAY2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/


%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment;

%macro edw_nl_hold_master;
	%if %index(%str(&sqlci.),%str(Data Source=SQLCIDEV)) ne 0 %then %do;
		%let sas_prgm_id=19; %inc 'M:\ci\programs\Development\EDW\edw_claims_reprocess_nl_hold.sas';
	%end;
	%else %if %index(%str(&sqlci.),%str(Data Source=SQL-CI)) ne 0 %then %do;
		%let sas_prgm_id=19; %inc 'M:\ci\programs\EDW\edw_claims_reprocess_nl_hold.sas';
	%end;
%mend edw_nl_hold_master;
%edw_nl_hold_master;
