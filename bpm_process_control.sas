


/*HEADER------------------------------------------------------------------------
|
| program:  bpm_process_control.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:   
|
| logic:     
|           
|
| input:               
|
| output:    
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
| 
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%macro bpm_process_control(timevar=,sk_status_id=4);

	%local update_time;
                              
	%let timevar=%upcase(&timevar);
	
	%put NOTE: --------------------------------------------------------------------- ;
	%put NOTE: bpm_process_control - timevar = &timevar.                             ;
	%put NOTE:                                                                       ;
	%put NOTE: SK STATUS ID:                                                         ;
	%put NOTE:   1=executing                                                         ;
	%put NOTE:   2=success                                                           ;
	%put NOTE:   3=failure                                                           ;
	%put NOTE:   4=failure on claim validation                                       ;
	%put NOTE: --------------------------------------------------------------------- ;

	%if &timevar. = START %then %do;
	
		data _null_; 
		  ts=input("&date."||put(time(),time16.6),datetime22.3);
		  update_time="'"||left(trim(PUT(ts,DATETIME22.3)))||"'dt"; 
		  call symput('update_time',left(trim(update_time))); 
		run; 
		
		proc sql noprint;
		  update vbpm.sk_process_control a
		  set start_time = &update_time., 
		      sk_status_id = 1, 
		      server_process_id = &sysjobid., 
		      end_time = .,  
		      src_record_cnt = ., 
		      tgt_record_cnt = .
		  where a.wflow_exec_id=&wflow_exec_id.
		    and a.client_id=&client_id.
                    and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
		quit;

	   %mvarexist(filename); 
	   %if &mvarexist. %then %do;	
	   
		proc sql noprint;
		  update vbpm.sk_process_control a
		  set file_name = "&filename."
		  where a.wflow_exec_id=&wflow_exec_id.
		    and a.client_id=&client_id.
                    and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
		quit;
		
	   %end;	

	   %mvarexist(practice_id); 
	   %if &mvarexist. %then %do;
		proc sql noprint;
		  update vbpm.sk_process_control a
		  set data_source_id = &practice_id.
		  where a.wflow_exec_id=&wflow_exec_id.
		    and a.client_id=&client_id.
                    and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
		quit;
		
	   %end;				
		
		%put NOTE: BPM process control - initialize work flow exec ID. ;
		
	%end;
	%else %if &timevar. = COMPLETE %then %do;

		data _null_; 
		  ts=input("&date."||put(time(),time16.6),datetime22.3);
		  update_time="'"||left(trim(PUT(ts,DATETIME22.3)))||"'dt"; 
		  call symput('update_time',left(trim(update_time))); 
		run;  
		
		proc sql noprint;
		  update vbpm.sk_process_control a
		  set sk_status_id = 2,  
		      src_record_cnt = &src_record_cnt., 
		      tgt_record_cnt = &tgt_record_cnt., 
		      end_time = &update_time.
		  where a.wflow_exec_id=&wflow_exec_id.
		    and a.client_id=&client_id.
                    and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
		quit;
		
		%put NOTE: BPM process control - updated status and end timestamp. ;
		
	%end;
	%else %if &timevar. = DQSUCCESS or &timevar. = DQFAIL %then %do;

		data _null_; 
		  ts=input("&date."||put(time(),time16.6),datetime22.3);
		  update_time="'"||left(trim(PUT(ts,DATETIME22.3)))||"'dt"; 
		  call symput('update_time',left(trim(update_time))); 
		run;  

		/**---------------------------------------------------------------------------------------------
		   DQFAIL = 4 allows skelta to pause the workflow and alerts the client team 
		   DQFAIL = 2 prevents skelta to pause when onboarding                                
		---------------------------------------------------------------------------------------------**/		
		proc sql noprint;
		  update vbpm.sk_process_control a
		  %if &timevar. = DQFAIL and &client_id. ne 3 %then %do;
		  	set sk_status_id = 4
		  %end;
		  %else %do;
		    set sk_status_id = 2
		  %end; ,
		    src_record_cnt = &src_record_cnt., 
		    tgt_record_cnt = &tgt_record_cnt., 
		    ext_output_log = "&xl.", 
		    end_time = &update_time.
		  where a.wflow_exec_id=&wflow_exec_id.
		    and a.client_id=&client_id.
                    and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
		quit;
		
		%put NOTE: BPM process control - updated status and end timestamp. ;
		
	%end; 
	%else %if &timevar. = ABORT or &timevar. = ABORT RETURN %then %do;

		data _null_; 
		  ts=input("&date."||put(time(),time16.6),datetime22.3);
		  update_time="'"||left(trim(PUT(ts,DATETIME22.3)))||"'dt"; 
		  call symput('update_time',left(trim(update_time))); 
		run;  
		
		proc sql noprint;
		  update vbpm.sk_process_control a 
		  set sk_status_id = &sk_status_id., 
              	      end_time = &update_time.
		  where a.wflow_exec_id=&wflow_exec_id.
		    and a.client_id=&client_id.
                    and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
		quit;
		
		%if %sysfunc(exist(cihold.saswrk_header_detail_&wflow_exec_id.)) %then %do;
		    proc sql;
		      connect to oledb(init_string=&cihold.);
		      execute ( 
				drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
			      ) 
		      by oledb; 
		    quit;
		%end;
		
		%put NOTE: BPM process control - updated status and end timestamp. ;
		
	%end;
	%else %do;
	  %put WARNING: ----------------------------------------------------------------------------- ;
	  %put WARNING: Need additional logic to account for bpm_process_control - timevar: &timevar. ;
	  %put WARNING: ----------------------------------------------------------------------------- ;
	%end;
	


%mend bpm_process_control;
