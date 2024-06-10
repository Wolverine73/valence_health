
/*HEADER------------------------------------------------------------------------
|
| program:  cio_workflow_process_queue.sas
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


%macro cio_workflow_process_queue(workflow=0, clientid=0);

	%*SASDOC----------------------------------------------------------------------
	| Define SAS macros for program    
	| 
	+----------------------------------------------------------------------SASDOC*;
	%let sysparm=%str(sas_prgm_id=0 practice_id=0 client_id=0  sas_mode=prod report=\\sas2\ci\programs\Development\Reports);  
	%bpm_environment; 
	options nomlogic mprint nosymbolgen;
	libname report "&report";
	%let wflow_exec_id=0;
	%global report_date practice_id2 sk_count;;

	data x;
	report_date=put(year(today()),z4.)||put(month(today()),z2.)||put(day(today()),z2.);
	call symput('report_date',compress(report_date)); ;
	run;

	%put NOTE: report_date = &report_date. ;
	
	%*SASDOC----------------------------------------------------------------------
	| Report 1 - BPM Metadata Information    
	| 
	+----------------------------------------------------------------------SASDOC*;
	%macro report_1_workflows;
	

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
			where START_TIME > CURRENT_TIMESTAMP-1 
		);
		quit; 
		
		%let sk_count=0;
		
		proc sql noprint;
		select count(*) into: sk_count separated by ''
		from report_1_&wflow_exec_id. ;
		quit;
		
		%put NOTE: sk_count = &sk_count. ;

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
			select distinct  c.clientname, b.dataformatid, b.dataformatdescription, b.sasfilelayout, 
			b.ciofilelayout, a.datasourceid as data_source_id, a.name as data_source_name
			from [integrationdatasource].[dbo].[datasource]    as a left join
			[integrationdatasource].[dbo].[dataformat] as b on a.dataformatid=b.dataformatid left join
			[integrationdatasource].[dbo].client as c on a.clientid=c.clientid   
		);
		quit;
		
		proc sql noprint;
		connect to oledb(init_string=&vbpm.);
		create table report0_issue_workflows as select * from connection to oledb
		(
			select 'report_1_workflows_issue' as report,  a.data_source_id, b.ext_program_name, a.*
			  from [bpmmetadata].[dbo].[sk_process_control] a left join  [bpmmetadata].[dbo].sk_ext_program b
			  on a.sk_ext_prgm_id=b.sk_ext_prgm_id
			  where  (START_TIME > GETDATE()-30 and END_TIME is null)
			  or SERVER_PROCESS_ID=-99
			  order by sk_prcs_ctrl_id desc
		);
		quit;
				
		proc sort data = report_1_&wflow_exec_id. ;
		by data_source_id  ;
		run;
		
		proc sort data = report1_information ;
		by data_source_id  ;
		run;

		data report.report_0_workflows_&report_date.;
		format report $50. ;
		merge report_1_&wflow_exec_id. (in=a)
		    report1_information (in=b);
		by data_source_id;
		if a;
		sortvar=substr(ext_program_name,1,15);
		report='report_1_workflows_last_24_hours';
		run;
		
		data report.report_0_workflows_&report_date. ;
		set report.report_0_workflows_&report_date. report0_issue_workflows ;
		run;
		
		proc sort data = report.report_0_workflows_&report_date.;
		by report client_id wflow_exec_id sk_prcs_ctrl_id  ;
		run;

		%put NOTE: practice_id = &practice_id. ;
		%put NOTE: practice_id2 = &practice_id2. ;
		%put NOTE: client_id = &client_id. ;
		%put NOTE: wflow_exec_id = &wflow_exec_id. ;
		%put NOTE: workflow = &workflow. ;

	%mend report_1_workflows;

	%*SASDOC----------------------------------------------------------------------
	| Report 5 - Process Queue and File Notification Summary  
	| 
	+----------------------------------------------------------------------SASDOC*;
	%macro report_1_process_queue_summary; 
	


		proc sql noprint;
		connect to oledb(init_string=&ids.);
		create table report_1a as select * from connection to oledb
		(	
			select a.clientid, c.clientname, b.dataformatgroupdesc, a.dataformatgroupid, d.processqueuestatusdesc, count(*) as cnt
			from [integrationdatasource].[dbo].[processqueue]    as a left join
			[integrationdatasource].[dbo].[dataformatgroup] as b on a.dataformatgroupid=b.dataformatgroupid left join
			[integrationdatasource].[dbo].client as c on a.clientid=c.clientid left join
			[integrationdatasource].[dbo].processqueuestatus as d on a.processqueuestatusid=d.processqueuestatusid 
			where a.processqueuestatusid  in (1,2)  
			group by a.clientid, c.clientname, b.dataformatgroupdesc, a.dataformatgroupid, d.processqueuestatusdesc
			order by processqueuestatusdesc desc, clientid
		);
		quit; 
		
		proc sql noprint;
		connect to oledb(init_string=&ids.);
		create table report_1b as select * from connection to oledb
		(	
			select a.clientid, c.clientname, b.dataformatgroupdesc, a.dataformatgroupid, d.processqueuestatusdesc, a.*
			from [integrationdatasource].[dbo].[processqueue]    as a left join
			[integrationdatasource].[dbo].[dataformatgroup] as b on a.dataformatgroupid=b.dataformatgroupid left join
			[integrationdatasource].[dbo].client as c on a.clientid=c.clientid left join
			[integrationdatasource].[dbo].processqueuestatus as d on a.processqueuestatusid=d.processqueuestatusid 
			where a.processqueuestatusid  in (1,2) 
              		  and a.clientid in (5,6,8,13) 
			order by processqueuestatusdesc desc, a.clientid, a.datasourceid
		);
		quit; 
		
		proc sql noprint;
		connect to oledb(init_string=&ids.);
		create table report_1c as select  * from connection to oledb
		(	
			select a.clientid, c.clientname, b.dataformatgroupdesc, a.*, d.processqueuestatusdesc
			from [integrationdatasource].[dbo].[processqueue]    as a left join
			[integrationdatasource].[dbo].[dataformatgroup] as b on a.dataformatgroupid=b.dataformatgroupid left join
			[integrationdatasource].[dbo].client as c on a.clientid=c.clientid left join
			[integrationdatasource].[dbo].processqueuestatus as d on a.processqueuestatusid=d.processqueuestatusid 
			where WFLOW_EXEC_ID in ( &workflow.) 
		);
		quit;
				

		data report.report_0_process_queue_&report_date. ;
		format report $50. ;
		 set report_1a (in=a)
		     report_1b (in=b)
		     report_1c (in=c);
		 if a then report='report_1_processqueue_summary'; 
		 if b then report='report_1_processqueue_detail'; 
		 if c then report='report_1_processqueue_workflow';
		run;

	%mend report_1_process_queue_summary;


	%macro report_final_all;

		data x;
		report_date=put(year(today()),z4.)||put(month(today()),z2.)||put(day(today()),z2.);
		call symput('report_date',compress(report_date)); ;
		run;

		%put NOTE: report_date = &report_date. ;

		data Report_0_all;
		set report.report_0_process_queue_&report_date. 
		    report.report_0_workflows_&report_date.;
		run;

		filename _temp_ "\\sas2\ci\programs\Development\Reports\Report_0_process_queue_&report_date..xls";
		ods noresults;
		ods listing close;
		ods html file=_temp_ rs=none style=minimal; 
		proc print data=Work.'Report_0_all'N label noobs;
		run;
		ods html close;
		ods results;
		ods listing;
		filename _temp_;
		dm "winexecfile ""\\sas2\ci\programs\Development\Reports\Report_0_process_queue_&report_date..xls"" ";


	%mend report_final_all;


	%report_1_workflows;
	%report_1_process_queue_summary
	%report_final_all;
	
%mend cio_workflow_process_queue;