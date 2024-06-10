
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  start_log_printto.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Capture the log file for clinical integration.
|
| LOGIC:    
|
| INPUT:          
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 14APR2009 - Clinical Integration  1.0.01
|                 
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro start_log_printto(logfile=);
	proc printto log   = "&logfile." new;
	run;
%mend start_log_printto;

