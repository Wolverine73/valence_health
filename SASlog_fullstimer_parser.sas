/* User Macro Variables 
	LOG_Filepath - Enter file path of the SAS log, where SAS job has options fullstimer turned on.
	Result_folder (optional) - Enter the folder location where you want the parser result to be saved. The resulting html output
								will have the format of (Filename)_log_parser.html. If not specified, result will be saved in
								the same folder as the original LOG file.

   To invoke the macro, you can write macro in the following 2 ways: 

		%saslog_fullstimer_parser(log_filepath=M:\dw\Programs\Auto\Log Sasbi\PFKJanuaryvquestlog.log,result_folder=C:\Users\gliu\Documents\);

		%saslog_fullstimer_parser(log_filepath=M:\dw\Programs\Auto\Log Sasbi\PFKJanuaryvquestlog.log);
*/

%macro saslog_fullstimer_parser(log_filepath=,result_folder=);

/* Program begins */
%let result_folder=&result_folder.;
data _null_;
	if upcase(scan("&log_filepath.",-1,'./\')) not in ('LOG','TXT','PRN') then log_filename=scan("&log_filepath.",-1,'./\');
	else log_filename=scan("&log_filepath.",-2,'./\');
	call symput('log_filename',trim(left(log_filename)));

	if "&result_folder."="" then call symput('result_folder',substr("&log_filepath.",1,length("&log_filepath.")-length(scan("&log_filepath.",-1,'/\'))));
	else if substr("&result_folder.",length("&result_folder."),1) not in ('/','\') then call symput('result_folder',"&result_folder."||'\');
run;

data input_logfile;
	infile "&log_filepath." dsd lrecl=100 truncover;
	input original_logtext $75.;
	logtext=upcase(original_logtext);
	loglinenum=_n_;
	if logtext ne '';
run;

data input_logfile(drop=lag1logtext fullstimer_ind);
	set input_logfile;
	lag1logtext=lag1(logtext);
	if _n_=1 then do;
		job_step=1;
		fullstimer_ind=0;
	end;
	if scan(logtext,1,' ') in ('MEMORY','TIMESTAMP') or 
		scan(logtext,1,' ')='OS' and scan(logtext,2,' ')='MEMORY' or 
		scan(logtext,1,' ') in ('USER','SYSTEM') and scan(logtext,2,' ')='CPU' and scan(logtext,3,' ')='TIME' or
		scan(logtext,1,' ')='REAL' and scan(logtext,2,' ')='TIME' then fullstimer_ind+1;
	if scan(lag1logtext,1,' ')='TIMESTAMP' and fullstimer_ind gt 3 then do;
		step_asc=0;
		job_step+1;
		fullstimer_ind=0;
	end;
	step_asc+1;
proc sort data=input_logfile; by descending loglinenum;
data input_logfile(drop=lag1progstep) job_step(keep=job_step);
	set input_logfile;
	by descending loglinenum;
	lag1progstep=lag1(job_step);
	if lag1progstep ne job_step then do;
		step_desc=0;
	end;
	step_desc+1;

	retain fullstimer_section;
	if step_desc=1 then do; 
		fullstimer_section=1;
		if scan(logtext,1,' ')='TIMESTAMP' then output job_step;
	end;
	else if fullstimer_section=1 and scan(logtext,1,' ')='NOTE:' then do;
		firstnote=1;
		fullstimer_section=0;
	end;
	output input_logfile;
run;

proc sql;
	create view view_logfile as
	select	a.*
	from	input_logfile a, job_step b
	where	a.job_step=b.job_step;
quit;

data job_task(keep=job_step step_asc original_logtext loglinenum)
	 job_memory(keep=job_step job_memory)
	 job_os_memory(keep=job_step job_os_memory)
	 job_realtime(keep=job_step job_realtime)
	 job_user_cputime(keep=job_step job_user_cputime)
	 job_system_cputime(keep=job_step job_system_cputime)
	;
	set view_logfile;
	if scan(logtext,2,' ') in: ('+*','*','+/*','/*') then delete;
	else if scan(logtext,2,' ')='+' and scan(logtext,3,' ') in: ('*','/*') then delete;
	else if logtext=:'NOTE: %INCLUDE' then delete;
	else if scan(logtext,1,' +') in ('DATA','PROC','%INCLUDE') or 
			scan(logtext,1,' +') not in ('DATA','PROC','%INCLUDE') and scan(logtext,2,' +') in ('DATA','PROC','%INCLUDE') or
			firstnote then output job_task;
	else if fullstimer_section then do;
		if scan(logtext,1,' ')='OS' and scan(logtext,2,' ')='MEMORY' then do; job_os_memory=scan(logtext,3,' '); output job_os_memory; end;
		else if scan(logtext,1,' ')='MEMORY' then do; job_memory=scan(logtext,2,' '); output job_memory; end;
		else if scan(logtext,1,' ')='SYSTEM' and scan(logtext,2,' ')='CPU' and scan(logtext,3,' ')='TIME' then do; job_system_cputime=scan(logtext,4,' '); output job_system_cputime; end;
		else if scan(logtext,1,' ')='USER' and scan(logtext,2,' ')='CPU' and scan(logtext,3,' ')='TIME' then do; job_user_cputime=scan(logtext,4,' '); output job_user_cputime; end;
		else if scan(logtext,1,' ')='REAL' and scan(logtext,2,' ')='TIME' then do; job_realtime=scan(logtext,3,' '); output job_realtime; end;
	end;
run;

%macro slfp_format_memory(m_name);
  data &m_name.;
	set &m_name.(rename=(&m_name.=org&m_name.));
	format &m_name. comma13.;
	if substr(upcase(org&m_name.),length(org&m_name.),1)='K' then &m_name.=substr(org&m_name.,1,length(org&m_name.)-1);
	else &m_name.=substr(org&m_name.,1,length(org&m_name.)-1)/1000;
  run;
%mend slfp_format_memory;
%slfp_format_memory(job_memory);
%slfp_format_memory(job_os_memory);

%macro slfp_format_time(m_name);
  data &m_name.;
	set &m_name.(rename=(&m_name.=org&m_name.));
	format &m_name. 8.2;
	if index(org&m_name.,':')=0 and index(org&m_name.,'.') then &m_name.=org&m_name./60;
	else if scan(org&m_name.,3,':') ne '' then &m_name.=scan(org&m_name.,1,':')*60 + scan(org&m_name.,2,':') + scan(org&m_name.,3,':')/60;
	else if scan(org&m_name.,2,':') ne '' then &m_name.=scan(org&m_name.,1,':') + scan(org&m_name.,2,':')/60;
  run;
%mend slfp_format_time;
%slfp_format_time(job_realtime);
%slfp_format_time(job_user_cputime);
%slfp_format_time(job_system_cputime);

proc sql;
	create table slfp_summary(drop=step_asc) as
	select	"&log_filename." as logfilename label='Log Filename',
			s.job_step label='Job Step #', t.loglinenum label='Log Line #', t.step_asc, t.original_logtext label='Log Text', 
			r.job_realtime label='Real Time (in minutes)', u.job_user_cputime label='User CPU Time (in minutes)', y.job_system_cputime label='System CPU Time (in minutes)',
			m.job_memory label='Memory (in Kb)', o.job_os_memory label='OS Memory (in Kb)'
	from	job_step s, job_task t, job_memory m, job_os_memory o, job_realtime r, job_user_cputime u, job_system_cputime y
	where	s.job_step=t.job_step and s.job_step=m.job_step and s.job_step=o.job_step
	and		s.job_step=r.job_step and s.job_step=u.job_step and s.job_step=y.job_step
	group by logfilename, s.job_step
	having	min(step_asc)=step_asc
	order by logfilename, job_realtime desc;
quit;

ods listing close;
ods html body="&result_folder.&log_filename._log_parser.html" style=minimal;

proc print data=slfp_summary noobs label;
	title "SAS Log Parser for &log_filepath.";
run; title;

ods html close;
ods listing;

proc sql;
	drop view view_logfile;
	drop table input_logfile, job_step, job_task, job_memory, job_os_memory, job_realtime, job_user_cputime, job_system_cputime, slfp_summary;
quit;

%mend saslog_fullstimer_parser;
