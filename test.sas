
/*HEADER------------------------------------------------------------------------
|
| program:  edw_main_extract.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create driver program to handle vmine and non-vmine data  
|
| logic:    
|              
|
| input:    Macro parameters and /or SQL server practices
|           sas_prgm_id - the sas program id (e.g., 27)
|           system_id   - the pm system id from vmine (e.g., 1=Medisoft) 
|           practice_id - opitional field but the practice id from vmine (e.g., 256) 
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|           filename - files to be processed (e.g., 710-20110825T09400000.txt)
|                        
| output:   
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/


*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 

%bpm_environment; 

*SASDOC--------------------------------------------------------------------------
| Macro -  edw_main_extract
|
| Determine if vmine or non-vmine and execute the routine
------------------------------------------------------------------------SASDOC*;
%macro edw_main_extract;

	%data_source_information;

	%put NOTE: edw_directory = &edw_directory. ;
	
	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=START);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);	

%mend edw_main_extract;

%edw_main_extract;


