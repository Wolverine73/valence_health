
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  end_log_printto.sas
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

%macro end_log_printto;
	proc printto log=log;
	run;
%mend end_log_printto;