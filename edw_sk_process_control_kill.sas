
/*HEADER------------------------------------------------------------------------
|
| program:  edw_sk_process_control_kill.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Reprocess claims from NL HOLD ENCOUNTER HEADER DETAIL table
|
| logic:    
|
| input:    Macro parameters and /or SQL server practices
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|	    sas_prgm_id - needs value of 19 since other programs reference
|                         the value (e.g., steps 1-5)
|                        
| output:   Staging dataset for all clients/practices needing reprocessing
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JUL2012 - B Stropich  - Clinical Integration  1.0.01
|             Original
|
+-----------------------------------------------------------------------HEADER*/


*SASDOC-----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos); 


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment;


%macro edw_sk_process_control_kill;


	%bpm_process_control(timevar=START);
	
	%let practice_id_target=99;
	
		
		*SASDOC-----------------------------------------------------------
		| Table Driven Solution
		|
		+---------------------------------------------------------SASDOC*;
		%if &practice_id_target eq 99 %then %do;
		
		  data sk_process_control_kill;
		  set vbpm.sk_process_control_kill  ;
		  where processed=0;
		  run;
		  
		  %let cnt_process_id=0;
		
		  proc sql noprint;
		    select count(*) into: cnt_process_id separated by ''
		    from sk_process_control_kill ;
		  quit;
		  
		  %put NOTE: cnt_process_id = &cnt_process_id. ;	
		  
		  %if &cnt_process_id. ne 0 %then %do;	  
		  
		    /** select only 1 since there could be multiple data sources within the table that need reprocessing **/
		    data sk_process_control_kill;
		    set sk_process_control_kill (obs=1); 
		    run;	
		    
		    proc sql noprint;
		    select sk_process_control_kill_key into: sk_process_control_kill_key separated by ''
		    from sk_process_control_kill ;
		    quit;
		  
		    %put NOTE: sk_process_control_kill_key = &sk_process_control_kill_key. ;	
		    
		    proc sql noprint;
		      select process_id into: process_id_target separated by ''
		      from sk_process_control_kill ;
		    quit;
		    
		    proc sql noprint;
		      update vbpm.sk_process_control_kill
		      set processed = 1
		      where sk_process_control_kill_key = &sk_process_control_kill_key. ;
		    quit;
		  
		  %end;
		  %else %do;
		  
		    /** default to 1 if the process was kicked off for table driven solution 99999 **/
		    %let process_id_target=1;
		  	
		  %end;
		  
		  %put NOTE: process_id_target = &process_id_target. ;
		  
		%end;
		
		options noxwait;
		
		data _null_;
		   call symput('tasklist',"tasklist /v /fo csv");  
		run;  

		filename indata pipe "&tasklist.";  

		data processes1 ;  
		length imagename pid2 sessionname session memusage status username cputime windowtitle $100. ;
		infile indata truncover  delimiter="," dsd;
		input  imagename pid2 sessionname session memusage status username cputime windowtitle ; 
		server_process_id=pid2*1; 
		if index(imagename,'sas') > 0 ;
		run;

		data _null_;
		set processes1;
		**if index(username,'skeltaadmin') > 0;
		put _all_ ;
		run; 
		
		%put NOTE: sysjobid = &sysjobid. ;		

		data _null_;
		  x "taskkill /f /pid &process_id_target."; 
		run;
	
		data processes2 ;  
		length imagename pid2 sessionname session memusage status username cputime windowtitle $100. ;
		infile indata truncover  delimiter="," dsd;
		input  imagename pid2 sessionname session memusage status username cputime windowtitle ; 
		server_process_id=pid2*1; 
		if index(imagename,'sas') > 0 ;
		run;

		data _null_;
		set processes2;
		**if index(username,'skeltaadmin') > 0;
		put _all_ ;
		run; 
			
	
	%bpm_process_control(timevar=COMPLETE);	
	
	%macro send_email_alert;
		filename mail_out email to=("bstropich@valencehealth.com") subject="Sk Process Control Kill - Complete";

		data _null_;
		file mail_out lrecl=32767; 		
		run;
	%mend send_email_alert;
	%send_email_alert;	
	

%mend edw_sk_process_control_kill;

%edw_sk_process_control_kill;
