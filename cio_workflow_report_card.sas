
/*HEADER------------------------------------------------------------------------
|
| program:  cio_workflow_report_card.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create cio report card on a workflow 
|
| logic:     
|
| input:         
|                         
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 14AUG2012 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
|
+-----------------------------------------------------------------------HEADER*/


%macro cio_workflow_report_card(workflow=0, clientid=0);

	%*SASDOC----------------------------------------------------------------------
	| Define SAS macros for program    
	| 
	+----------------------------------------------------------------------SASDOC*;
	%let sysparm=%str(sas_prgm_id=0 practice_id=0 client_id=0  sas_mode=prod report=\\sas2\ci\programs\Development\Reports);  
	%bpm_environment; 
	options nomlogic mprint nosymbolgen;
	libname report "&report";
	%if &clientid = 0 %then %let wflow_exec_id=&workflow.;
	%else  %let wflow_exec_id=&clientid.;
	
	proc datasets library=report nolist;
	delete report_1_&wflow_exec_id (memtype = data) ;
	delete report_2_&wflow_exec_id (memtype = data) ;
	delete report_3_&wflow_exec_id (memtype = data) ;
	delete report_4_&wflow_exec_id (memtype = data) ;
	delete report_5_&wflow_exec_id (memtype = data) ;
	delete report_6_&wflow_exec_id (memtype = data) ;
	delete report_7_&wflow_exec_id (memtype = data) ;
	delete report_8_&wflow_exec_id (memtype = data) ;
	delete report_9_&wflow_exec_id (memtype = data) ;
	run; 
	quit;

	proc datasets lib=work kill nolist ;
	run;
	quit;


	%*SASDOC----------------------------------------------------------------------
	| Report 1 - BPM Metadata Information    
	| 
	+----------------------------------------------------------------------SASDOC*;
	%macro report_1_sk_process_control;
	
		%global practice_id2 sk_count;

		%if &clientid = 0 %then %let wflow_exec_id=&workflow.;
		%else  %let wflow_exec_id=&clientid.;

		proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table report_1_&wflow_exec_id. as select * from connection to oledb
		(	
			select b.ext_program_name, c.status_desc, 
				case when server_process_id = -99 then 'retry workflow - disconnection issue from skelta and sas'
       				else '' end resolution, 
       				a.*
			from  [BPMMetaData].[dbo].[SK_PROCESS_CONTROL] as a left join
			      [BPMMetaData].[dbo].[SK_EXT_PROGRAM]     as b  on    a.[SK_EXT_PRGM_ID]=b.[SK_EXT_PRGM_ID] left join
			      [BPMMetaData].[dbo].[SK_PROCESS_STATUS]  as c  on    a.[SK_STATUS_ID]=c.[SK_STATUS_ID]  
			where %if &clientid = 0 %then %do;
			        [WFLOW_EXEC_ID] = &wflow_exec_id.
			      %end;
			      %else %do;
				[client_id] = &clientid.
			        and START_TIME > CURRENT_TIMESTAMP-1					        
			      %end;
		);
		quit; 
		
		%let sk_count=0;
		
		proc sql noprint;
		select count(*) into: sk_count separated by ''
		from report_1_&wflow_exec_id. ;
		quit;
		
		%put NOTE: sk_count = &sk_count. ;

		%if &clientid = 0 %then %do;
		proc sort data = report_1_&wflow_exec_id.;
		by ext_program_name descending start_time  ;
		run;

		proc sort data = report_1_&wflow_exec_id. nodupkey;
		by ext_program_name  ;
		run;
		%end;
		%else %do;
		%end;

		proc sort data = report_1_&wflow_exec_id. ;
		by WFLOW_EXEC_ID SK_PRCS_CTRL_ID  ;
		run;

		proc sql noprint;
		select distinct(DATA_SOURCE_ID) into: practice_id separated by ','
		from report_1_&wflow_exec_id.
        where DATA_SOURCE_ID > 0;
		quit;

		proc sql noprint;
		select distinct(DATA_SOURCE_ID) into: practice_id2 separated by ' '
		from report_1_&wflow_exec_id.
        where DATA_SOURCE_ID > 0;
		quit;

		proc sql noprint;
		select distinct(CLIENT_ID) into: client_id separated by ','
		from report_1_&wflow_exec_id.
        where client_id > 0;
		quit;

		proc sql noprint;
		select distinct(wflow_exec_id) into: workflow separated by ','
		from report_1_&wflow_exec_id.
        where wflow_exec_id > 0;
		quit;
		

		proc sql noprint;
		connect to oledb(init_string=&ids.);
		create table report1_information as select * from connection to oledb
		(
			select distinct  c.clientname, b.*, datasourceid as data_source_id
			from [integrationdatasource].[dbo].[datasource]    as a left join
			[integrationdatasource].[dbo].[dataformat] as b on a.dataformatid=b.dataformatid left join
			[integrationdatasource].[dbo].client as c on a.clientid=c.clientid   
		);
		quit;
		
		proc sort data = report_1_&wflow_exec_id. ;
		by data_source_id  ;
		run;
		
		proc sort data = report1_information ;
		by data_source_id  ;
		run;

		data report.report_1_&wflow_exec_id.;
		format report $50. ;
		merge report_1_&wflow_exec_id. (in=a)
		    report1_information (in=b);
		by data_source_id;
		if a;
		sortvar=substr(ext_program_name,1,15);
		report='report_1_sk_process_control';
		run;
		
		proc sort data = report.report_1_&wflow_exec_id. ;
		by wflow_exec_id sk_prcs_ctrl_id  ;
		run;

		%put NOTE: practice_id = &practice_id. ;
		%put NOTE: practice_id2 = &practice_id2. ;
		%put NOTE: client_id = &client_id. ;
		%put NOTE: wflow_exec_id = &wflow_exec_id. ;
		%put NOTE: workflow = &workflow. ;

	%mend report_1_sk_process_control;


	%*SASDOC----------------------------------------------------------------------
	| Report 2 - EDW Load Counts   
	| 
	+----------------------------------------------------------------------SASDOC*;
	%macro report_2_edw_header_detail_cnts;

		proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table report_2_&wflow_exec_id. as select * from connection to oledb
		(	
		select ed.DATA_SOURCE_ID, pra.PRACTICE_NAME, pro.PROVIDER_KEY, pro.PROVIDER_NAME, DATEPART(YYYY, ed.SERVICE_DATE) Service_Date_Year, DATEPART(MM, ed.SERVICE_DATE) Service_Date_Month, 
		       count(distinct (case eh.CLAIM_SOURCE when 1 then eh.ENCOUNTER_KEY else null end) ) vMine_hdr,          count(case eh.CLAIM_SOURCE when 1 then eh.ENCOUNTER_KEY else null end) vMine_dtl,
		       count(distinct (case eh.CLAIM_SOURCE when 2 then eh.ENCOUNTER_KEY else null end) ) PGF_hdr,            count(case eh.CLAIM_SOURCE when 2 then eh.ENCOUNTER_KEY else null end) PGF_dtl,
		       count(distinct (case eh.CLAIM_SOURCE when 11 then eh.ENCOUNTER_KEY else null end) ) PGF_Uploader_hdr,  count(case eh.CLAIM_SOURCE when 11 then eh.ENCOUNTER_KEY else null end) PGF_Uploader_dtl,
		       count(distinct (case eh.CLAIM_SOURCE when 8 then eh.ENCOUNTER_KEY else null end) ) SelfPay_Prof_hdr,   count(case eh.CLAIM_SOURCE when 8 then eh.ENCOUNTER_KEY else null end) SelfPay_Prof_dtl,
		       count(distinct (case eh.CLAIM_SOURCE when 12 then eh.ENCOUNTER_KEY else null end) ) "837P_hdr",        count(case eh.CLAIM_SOURCE when 12 then eh.ENCOUNTER_KEY else null end) "837P_dtl",
		       count(distinct (case eh.CLAIM_SOURCE when 7 then eh.ENCOUNTER_KEY else null end) ) HCF_hdr,            count(case eh.CLAIM_SOURCE when 7 then eh.ENCOUNTER_KEY else null end) HCF_dtl,
		       count(distinct (case eh.CLAIM_SOURCE when 14 then eh.ENCOUNTER_KEY else null end) ) SelfPay_Inst_hdr,  count(case eh.CLAIM_SOURCE when 14 then eh.ENCOUNTER_KEY else null end) SelfPay_Inst_dtl,
		       count(distinct (case eh.CLAIM_SOURCE when 3 then eh.ENCOUNTER_KEY else null end) ) "837I_hdr",         count(case eh.CLAIM_SOURCE when 3 then eh.ENCOUNTER_KEY else null end) "837I_dtl",
		       count(distinct (case eh.CLAIM_SOURCE when 13 then eh.ENCOUNTER_KEY else null end) ) User_Comments_hdr, count(case eh.CLAIM_SOURCE when 13 then eh.ENCOUNTER_KEY else null end) User_Comments_dtl
		from dbo.ENCOUNTER_HEADER eh (nolock)
		   inner join dbo.ENCOUNTER_DETAIL ed (nolock) on eh.ENCOUNTER_KEY = ed.ENCOUNTER_KEY
		   left join dbo.provider pro (nolock) on eh.PROVIDER_KEY = pro.PROVIDER_KEY 
		   left join dbo.PRACTICE pra (nolock) on eh.PRACTICE_KEY = pra.PRACTICE_KEY 
		where eh.CLIENT_KEY in ( &client_id.)
		  and ed.DATA_SOURCE_ID in ( &practice_id.)
		  and eh.wflow_exec_id in ( &workflow.) 
		group by ed.DATA_SOURCE_ID, pra.PRACTICE_NAME, pro.PROVIDER_KEY, pro.PROVIDER_NAME, DATEPART(YYYY, ed.SERVICE_DATE), DATEPART(MM, ed.SERVICE_DATE)
		order by 1, 2, 3, 4, 5, 6
		);
		quit; 

		data report.report_2_&wflow_exec_id.;
		format report $50. ;
		set report_2_&wflow_exec_id. ;
		report='report_2_edw_header_detail_counts';  
		run;

	%mend report_2_edw_header_detail_cnts;


	%*SASDOC----------------------------------------------------------------------
	| Report 3 - EDW No Load Counts   
	| 
	+----------------------------------------------------------------------SASDOC*;
	%macro report_3_noload_counts;
		proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table report_3_&wflow_exec_id. as select * from connection to oledb
		(	
			select filename, practice_key, npi, provname, count(*) as cnt
			from  [CIHold].[dbo].[NL_HOLD_ENCOUNTER_HEADER_DETAIL]
			where client_key in ( &client_id.)  
			  and practice_id in ( &practice_id.)
			  and wflow_exec_id in ( &workflow.) 
			group by filename, practice_key, npi, provname
		);
		quit; 

		data report.report_3_&wflow_exec_id.;
		format report $50. ;
		set report_3_&wflow_exec_id. (obs=10000);
		report='report_3_noload_counts';  
		run;
	%mend report_3_noload_counts;

	%*SASDOC----------------------------------------------------------------------
	| Report 4 - Log Search  
	| 
	+----------------------------------------------------------------------SASDOC*;
	%macro report_4_workflow_logs;

		proc sql noprint;
		select SASLogFileLocation into: SASLogFileLocation separated by ''
		from ids.client
		where clientid=&client_id.;
		quit;

		%put NOTE: SASLogFileLocation = &SASLogFileLocation. ;

		filename indata1 pipe "dir /a &SASLogFileLocation.\*_&client_id..log";  	

		data directory_list  ;
	        format date time size $20. date2 mmddyy10. ; 
			infile indata1 truncover;
			input directory_list $200.;  
			if index(directory_list,'.log') > 0;
			date=scan(directory_list,1,' ');
			date2=input(date,mmddyy10.);
			time=scan(directory_list,2,' ');
			ampm=scan(directory_list,3,' ');
			time=trim(time)||' '||trim(ampm);
			size=scan(directory_list,4,' '); 
			log=scan(directory_list,5,' ');
			wflow_exec_id=reverse(scan(reverse(log),2,'_'))*1;
			sortvar=substr(log,1,15);
			%if &clientid = 0 %then %do;  
				logindex="&workflow._&client_id..log";
				if index(log,logindex) > 0;
			%end;
			%else %do; 
				if wflow_exec_id in (&workflow.);			
			%end;
			drop directory_list ampm; 
		run;

		proc sort data = directory_list;
		by descending log ;
		run;

		proc sort data = directory_list ;**nodupkey;
		by wflow_exec_id sortvar ;
		run;

		data _null_;
		  set directory_list  end=eof;
		    i+1;
		    ii=left(put(i,4.));
		    call symput('log_filename'||ii,trim(log));
			call symput('log_date'||ii,trim(date));
			call symput('log_time'||ii,trim(time));
			call symput('log_wf'||ii,trim(wflow_exec_id));
		    if eof then call symput('logname_total',ii);
		run;

		%do log = 1 %to &logname_total. ;

			data input_logfile&log.;
				infile "&SASLogFileLocation.\&&log_filename&log" dsd lrecl=136 truncover;
				input original_logtext $136.;
				logtext=upcase(original_logtext);
				loglinenum=_n_;
				if logtext ne '';
			run;

			data input_errors&log. (keep=logfilename logdate logtime loglinenum original_logtext error_rank wflow_exec_id);
				format logfilename logdate logtime $50.;
				label logfilename='Log Filename' loglinenum='Log Line #' original_logtext='Log Text';
				set input_logfile&log.;
				logfilename="&&log_filename&log";
				logdate="&&log_date&log";
				logtime="&&log_time&log";
				wflow_exec_id=&&log_wf&log;
				outind=0;
				if logtext=:'WARNING' then do;
					error_rank=5;
					if index(logtext,'CREATE TABLE STATEMENT RECURSIVELY REFERENCES THE TARGET') then ;
					else if index(logtext,'LIMIT SET BY ERRORS= OPTION REACHED') then;
					else outind=1;
					if index(logtext,'INCOMPLETE') then error_rank=error_rank-1;
					if index(logtext,'STOPPED') then error_rank=error_rank-1;
					if index(logtext,'NOT RESOLVED') then error_rank=error_rank-1;
				end;
				else if logtext=:'ERROR' then do;
					error_rank=1;
					outind=1;
				end;
				else if index(logtext,'REPEATS ') then do;
					error_rank=3;
					outind=1;
				end;
				else if index(logtext,'UNINITIALIZED') then do;
					error_rank=9;
					outind=1;
				end;

				if outind;
			run;

		%end;

		data report_4_&wflow_exec_id.;
		set %do log = 1 %to &logname_total. ;
		      input_errors&log.
		    %end;;
		if error_rank = 1;
		sortvar=substr(logfilename,1,15);
		run;

		proc sort data = report_4_&wflow_exec_id.;
		  by wflow_exec_id sortvar ;
		run;

		proc sort data = report.report_1_&wflow_exec_id.;
		  by wflow_exec_id sortvar ;
		run;

		data report_4_&wflow_exec_id.;
		merge report.report_1_&wflow_exec_id. (in=a)
		      report_4_&wflow_exec_id. (in=b);
		by wflow_exec_id sortvar;
		if a;
		run;

		proc sort data = report_4_&wflow_exec_id.;
		  by SK_PRCS_CTRL_ID ;
		run;

		data report.report_4_&wflow_exec_id.;
		format report $50. ;
		set report_4_&wflow_exec_id. ;
		report='report_4_workflow_logs';  
		run;

	%mend report_4_workflow_logs;
	

	%*SASDOC----------------------------------------------------------------------
	| Report 5 - Process Queue and File Notification Summary  
	| 
	+----------------------------------------------------------------------SASDOC*;
	%macro report_5_process_queue_summary; 

		proc sql noprint;
		connect to oledb(init_string=&ids.);
		create table report_5a_&wflow_exec_id. as select * from connection to oledb
		(	
			select a.clientid, c.clientname, b.dataformatgroupdesc, a.dataformatgroupid, d.processqueuestatusdesc, count(*) as cnt
			from [integrationdatasource].[dbo].[processqueue]    as a left join
			[integrationdatasource].[dbo].[dataformatgroup] as b on a.dataformatgroupid=b.dataformatgroupid left join
			[integrationdatasource].[dbo].client as c on a.clientid=c.clientid left join
			[integrationdatasource].[dbo].processqueuestatus as d on a.processqueuestatusid=d.processqueuestatusid 
			where a.processqueuestatusid  in (1,2) 
			  and a.clientid = &client_id.
			group by a.clientid, c.clientname, b.dataformatgroupdesc, a.dataformatgroupid, d.processqueuestatusdesc
		);
		quit; 

		
		proc sql noprint;
		connect to oledb(init_string=&ids.);
		create table report_5b_&wflow_exec_id. as select  * from connection to oledb
		(	
			select a.clientid, c.clientname, b.dataformatgroupdesc, a.*, d.processqueuestatusdesc
			from [integrationdatasource].[dbo].[processqueue]    as a left join
			[integrationdatasource].[dbo].[dataformatgroup] as b on a.dataformatgroupid=b.dataformatgroupid left join
			[integrationdatasource].[dbo].client as c on a.clientid=c.clientid left join
			[integrationdatasource].[dbo].processqueuestatus as d on a.processqueuestatusid=d.processqueuestatusid 
			where datasourceid in ( &practice_id)
			and timestamp > CURRENT_TIMESTAMP-30
			order by processqueueid desc
		);
		quit;

		%put NOTE: practice_id = &practice_id2. ;
		%let list1=%str(&practice_id2);

		%let z=0;

		%do %while (%scan(&list1, &z+1) ne );

		%let z=%eval(&z+1);
		%let datasourceid=%scan(&list1,&z);

				data sqlparam;
				  format sqlparam $10. ;
				  sqlparam=left(trim("&datasourceid."));
				  sqlparam="'"||left(trim(sqlparam))||"%'";
				  call symput('sqlparam',sqlparam);
				run;

				proc sql noprint;
				connect to oledb(init_string=&ids.);
				create table temp_5c as select  * from connection to oledb
				(	
					select b.*, a.*
					from [integrationdatasource].[dbo].[FileNotificationsCrosswalk] a left join   
		                	     [integrationdatasource].[dbo].[FileNotifications] b
		            		on a.filename=b.filename 
					where newfilename like &sqlparam.
					order by [LastActivityDateTime] desc
				);
				quit; 

				%if &z = 1 %then %do;
					data report_5c_&wflow_exec_id. ;
					set temp_5c (obs=20);
					run;
				%end;
				%else %do;
					data report_5c_&wflow_exec_id. ;
					set report_5c_&wflow_exec_id. temp_5c (obs=20);
					run;
				%end;

		%end;	
				

		data report.report_5_&wflow_exec_id. ;
		format report $50. ;
		 set report_5a_&wflow_exec_id. (in=a)
		     report_5b_&wflow_exec_id. (in=b)
		     report_5c_&wflow_exec_id. (in=c);
		 if a then report='report_5_processqueue_summary'; 
		 if b then report='report_5_processqueue_history'; 
		 if c then report='report_5_file_notification_history';
		run;

	%mend report_5_process_queue_summary;


	%macro report_final_all;


		filename indata1 pipe "dir /a &report.";  	

		data dataset_list  ;
	        format date time size $20. ; 
			infile indata1 truncover;
			input directory_list $200.;  
			if index(directory_list,'.sas7bdat') > 0;
			date=scan(directory_list,1,' ');
			time=scan(directory_list,2,' ');
			ampm=scan(directory_list,3,' ');
			time=trim(time)||' '||trim(ampm);
			size=scan(directory_list,4,' '); 
			dataset=scan(directory_list,5,' ');
			dataset='report.'||scan(dataset,1,'.');
			drop directory_list ampm; 
		run;

		/**--------------------------------------------------------
		proc sql;
		create table work_libname as
		select distinct(memname) as memname
		from dictionary.columns
		where upcase(libname)='WORK';
		quit;
		--------------------------------------------------------**/

		data _null_;
		w = getoption('work'); 
		call symput('work',trim(w)); 
		run;

		%put NOTE: work = &work. ;
		%put NOTE: report = &report. ;

		data dataset_list2;
		set dataset_list;
		report_id=scan(dataset,2,'_')*1;
		wflow_exec_id=scan(dataset,3,'_')*1;
		if upcase(substr(dataset,1,14))='REPORT.REPORT_' and report_id > 0 and wflow_exec_id = &wflow_exec_id. ;
		run;

		proc sql noprint;
		select trim(dataset) into: dataset separated by ' '
		from dataset_list2;
		quit;

		%put NOTE: dataset = &dataset. ;

		data report_0_all; 
		set &dataset. ; 
		run;

		data x;
		report_date=put(year(today()),z4.)||put(month(today()),z2.)||put(day(today()),z2.);
		call symput('report_date',compress(report_date)); ;
		run;

		%put NOTE: report_date = &report_date. ;

		filename _temp_ "\\sas2\ci\programs\Development\Reports\Report_0_client_&client_id._wf&wflow_exec_id._&report_date..xls";
		ods noresults;
		ods listing close;
		ods html file=_temp_ rs=none style=minimal; 
		proc print data=Work.'Report_0_all'N label noobs;
		run;
		ods html close;
		ods results;
		ods listing;
		filename _temp_;
		dm "winexecfile ""\\sas2\ci\programs\Development\Reports\Report_0_client_&client_id._wf&wflow_exec_id._&report_date..xls"" ";


	%mend report_final_all;


	%report_1_sk_process_control;
	
	%if &sk_count. ne 0 %then %do ;
	
		%report_2_edw_header_detail_cnts;
		%report_3_noload_counts;
		%report_4_workflow_logs;
		%report_5_process_queue_summary;

		%report_final_all;
	
	%end;

%mend cio_workflow_report_card;