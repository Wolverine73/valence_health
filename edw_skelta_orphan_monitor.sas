/**----------------------------------------------------------**/
/** http://technet.microsoft.com/en-us/library/bb491010.aspx **/
/** http://technet.microsoft.com/en-us/library/bb491009.aspx **/
/** similar to unix ps -ef | grep sas                        **/ 
/**----------------------------------------------------------**/

options sasautos = ("\\sas2\ci\programs\standardmacros" "\\sas2\ci\programs\clientmacros" sasautos);
options sastrace=',,,d';

%let sysparm=%str(client_id=6 sas_mode=prod); 
%bpm_environment;

%macro edw_skelta_orphan_monitor;

	%let wflow_exec_id = 0;
	%let server_process_id = 0;


	data _null_;
	   call symput('tasklist',"tasklist /v /fo csv");  
	run;  

	filename indata pipe "&tasklist.";  

	data processes ;  
	length imagename pid2 sessionname session memusage status username cputime windowtitle $100. ;
	infile indata truncover  delimiter="," dsd;
	input  imagename pid2 sessionname session memusage status username cputime windowtitle ; 
	server_process_id=pid2*1; 
	if index(imagename,'sas') > 0 ;
	run;

	data processes2;
	set processes;
	**if index(username,'skeltaadmin') > 0;
	run; 

	proc sort data = processes;
	by server_process_id;
	run;

	proc sql noprint;
	create table sk_process_control as
	select *
	from vbpm.sk_process_control
	where start_time > today() - 10
	  and end_time=. 
	  and server_process_id ne -99
	order by  sk_prcs_ctrl_id descending;
	quit;

	proc sql noprint;
	select server_process_id into: server_process_id separated by ','
	from sk_process_control;
	quit;

	%put NOTE: server_process_id = &server_process_id. ;

	proc sort data = sk_process_control;
	by server_process_id;
	run;

	proc sort data = processes2;
	by server_process_id;
	run;

	data update_processes;
	 merge processes2 (in=a)
	       sk_process_control (in=b);
	by server_process_id;
	if b and not a ;
	run;

	proc sql noprint;
	select wflow_exec_id into: wflow_exec_id separated by ','
	from update_processes ;
	quit;

	%put NOTE: wflow_exec_id = &wflow_exec_id. ;

	%**let wflow_exec_id=61518;
	%let src_record_cnt=0;
	%let tgt_record_cnt=0;

	data _null_; 
	  ts=input("&date."||put(time(),time16.6),datetime22.3);
	  update_time="'"||left(trim(put(ts,datetime22.3)))||"'dt"; 
	  call symput('update_time',left(trim(update_time))); 
	run;  

	%if &wflow_exec_id. ne 0 %then %do;
			
		proc sql noprint;
		update vbpm.sk_process_control a
		set sk_status_id = 3, src_record_cnt = &src_record_cnt.,  tgt_record_cnt = &tgt_record_cnt., end_time = &update_time.
		where a.wflow_exec_id in (&wflow_exec_id.)
		and end_time = .;
		quit;

		%macro send_email_alert;
			filename mail_out email to=("bstropich@valencehealth.com" "msanguansuk@valencehealth.com" "smore@valencehealth.com") subject="CIO Work Flow - Orphan Process";

			data _null_;
			file mail_out lrecl=32767;  
			put "work flow ID = &wflow_exec_id."; 
			run;
		%mend send_email_alert;
	%send_email_alert;
	
	%end;

%mend edw_skelta_orphan_monitor; 
%edw_skelta_orphan_monitor;