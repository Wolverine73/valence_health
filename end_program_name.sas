
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  end_program_name.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  
|                        
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro end_program_name(programstepid=);

   %end_log_printto;   
   %scanlog(infile=&program_log.); 
   %set_error_fl;  
   %on_error(
     action=ABORT, 
     em_to=&primary_programmer_email,
     em_subject=CLINICAL INTEGRATION: CI Process Step &program_name_step. FAILURE,
     em_msg=%str(This message is to inform the CI user that the requested steps for last night did not process successfully due to a processing issue.  Please examine the log within the %upcase(&clientname.) log directory to discover the reason.));
   %put NOTE: End Step &program_name_step.;
   
%mend end_program_name;