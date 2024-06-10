
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  start_program_name.sas
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


%macro start_program_name(programstepid=);

	data name;
	 set job_4_today (where=(stepid=&programstepid.));
	 call symput('programname',trim(log_name));
	run;

	%let program_name=&programname.;
	/**%let program_name_step=%substr(%scan(&program_name.,2,"_"),5,1);**/
	%let program_name_step=&programstepid.;
	%let program_log=%str(&saslogs.\&program_name._&logdate..log);

	%put NOTE: Begin Step &program_name_step.;
	%start_log_printto(logfile=&program_log.);

	%if &program_name_step. = 2 %then %do; 
	%end;
	%else %do;
	  %insert_ci_history(cihiststepid=&program_name_step.);
	%end;

%mend start_program_name;
