
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
%let sysparm=%str(sk_prcs_ctrl_id=87 wflow_exec_id=5180 sas_prgm_id=1 client_id=4 system_id=3  practice_id=263 pgf_practice= sas_mode=TEST); 
%bpm_environment;


proc sql;
connect to oledb(init_string=&sqlci.);
create table edw_report as select * from connection to oledb
(	

	with sp as
		(
		select 
			 sp.[wflow_exec_id]
			,max(sp.[practice_key]) as practice_key 
		from [ciedw].[dbo].[encounter_header] as sp
		group by sp.[wflow_exec_id]
		)

	select top 1000 
	       a.[wflow_exec_id]
	      ,a.[sk_ext_prgm_id]
		  ,[client_id]
	      ,[ext_program_name]
		  ,p.[practice_key]
		  ,p.[practice_name] 
		  ,pm.[practice_mgt_name]
	      ,[start_time]
	      ,[end_time]
		  ,' ' as duration_time
	      ,[src_record_cnt]
	      ,[tgt_record_cnt]
		  ,' ' as percent_loaded_edw
		  ,' ' as percent_loaded_hold
	      ,[ext_output_log]
	  from [bpmmetadata].[dbo].[sk_process_control] a,
	       [bpmmetadata].[dbo].[sk_ext_program]     b,
		   sp	                                    sp,
	       [ciedw].[dbo].[practice]                 p,
		   [ciedw].[dbo].[practice_mgt_system]      pm
	  where a.sk_ext_prgm_id=b.sk_ext_prgm_id
	    and a.wflow_exec_id > 5185
		and a.client_id=4
		and a.wflow_exec_id=sp.wflow_exec_id
		and sp.practice_key=p.practice_key
		and p.practice_mgt_key=pm.practice_mgt_key
	  order by wflow_exec_id, start_time
);
quit; 



proc sql;
connect to oledb(init_string=&sqlci.);
create table edw_report2 as select * from connection to oledb
(	

	with sp as
		(
		select 
			 sp.[wflow_exec_id]
			,max(sp.[practice_key]) as practice_key 
		from [ciedw].[dbo].[encounter_header] as sp
		group by sp.[wflow_exec_id]
		)

	select top 1000
           a.[wflow_exec_id]
		  ,p.[practice_key]
		  ,p.[practice_name] 
		  ,pm.[practice_mgt_name]
	      ,a.[validation_type_id]
	      ,c.[vld_subject]
	      ,b.[vld_typ_desc]
	      ,count(*) as count
	  from [bpmmetadata].[dbo].[validation_detail]  a,
	       [bpmmetadata].[dbo].[validation_type]    b,
	       [bpmmetadata].[dbo].[validation_subject] c,
		   sp	                                    sp,
	       [ciedw].[dbo].[practice]                 p,
		   [ciedw].[dbo].[practice_mgt_system]      pm

	  where a.wflow_exec_id > 5185
	    and a.[validation_type_id]= b.[validation_type_id]
	    and b.[vld_subject]=c.validation_subject_id
		and a.[validation_type_id] in (19,20,21,28,29,30,31,32,33,34,35,36,37)
		and a.wflow_exec_id=sp.wflow_exec_id
		and sp.practice_key=p.practice_key
		and p.practice_mgt_key=pm.practice_mgt_key
	  group by a.wflow_exec_id, p.practice_key, p.practice_name, pm.practice_mgt_name,
               a.validation_type_id, c.vld_subject, b.vld_typ_desc
	  order by a.wflow_exec_id
                
);
quit; 



proc sql;
connect to oledb(init_string=&sqlci.);
create table edw_report3 as select * from connection to oledb
(	

	with sp as
		(
		select 
			 sp.[wflow_exec_id]
			,max(sp.[practice_key]) as practice_key 
		from [ciedw].[dbo].[encounter_header] as sp
		group by sp.[wflow_exec_id]
		)

	select top 100000
           a.[wflow_exec_id]
		  ,a.entity_id, a.old_val, a.new_val
		  ,p.[practice_key]
		  ,p.[practice_name] 
		  ,pm.[practice_mgt_name]
	      ,a.[validation_type_id]
	      ,c.[vld_subject]
	      ,b.[vld_typ_desc] 
	  from [bpmmetadata].[dbo].[validation_detail]  a,
	       [bpmmetadata].[dbo].[validation_type]    b,
	       [bpmmetadata].[dbo].[validation_subject] c,
		   sp	                                    sp,
	       [ciedw].[dbo].[practice]                 p,
		   [ciedw].[dbo].[practice_mgt_system]      pm

	  where a.wflow_exec_id > 5185
	    and a.[validation_type_id]= b.[validation_type_id]
	    and b.[vld_subject]=c.validation_subject_id
		and a.[validation_type_id] in (32)
		and a.wflow_exec_id=sp.wflow_exec_id
		and sp.practice_key=p.practice_key
		and p.practice_mgt_key=pm.practice_mgt_key
	  order by a.wflow_exec_id
                
);
quit; 

data icd9;
infile 'P:\ValenceHealth\CI\ICD9\11ICDV1FFW.txt' missover dsd pad lrecl=200;
input new $1-2 proccd $3-9 proccd_desc $10-150;
proccd=left(proccd);
run;

data x;
 set icd9;
 where proccd='V81.2';
run;

proc sort data = icd9;
by proccd;
run;

proc sql noprint;
create table y as 
select old_val, count(*) as cnt
from edw_report3
group by old_val;
quit;

data edw_report3b;
 merge edw_report3b (in=a)
       icd9         (in=b rename=(proccd=old_val));
 by old_val ;
 if a and b;
run;

proc sort data = edw_report3b nodupkey;
 by old_val;
run;

proc sql;
connect to oledb(init_string=&sqlci.);
create table edw_report4 as select * from connection to oledb
(	

	with sp as
		(
		select 
			 sp.[wflow_exec_id]
			,max(sp.[practice_key]) as practice_key 
		from [ciedw].[dbo].[encounter_header] as sp
		group by sp.[wflow_exec_id]
		)

	select top 100000
           a.[wflow_exec_id]
		  ,a.entity_id, a.old_val, a.new_val
		  ,p.[practice_key]
		  ,p.[practice_name] 
		  ,pm.[practice_mgt_name]
	      ,a.[validation_type_id]
	      ,c.[vld_subject]
	      ,b.[vld_typ_desc] 
	  from [bpmmetadata].[dbo].[validation_detail]  a,
	       [bpmmetadata].[dbo].[validation_type]    b,
	       [bpmmetadata].[dbo].[validation_subject] c,
		   sp	                                    sp,
	       [ciedw].[dbo].[practice]                 p,
		   [ciedw].[dbo].[practice_mgt_system]      pm

	  where a.wflow_exec_id > 5185
	    and a.[validation_type_id]= b.[validation_type_id]
	    and b.[vld_subject]=c.validation_subject_id
		and a.[validation_type_id] in (31)
		and a.wflow_exec_id=sp.wflow_exec_id
		and sp.practice_key=p.practice_key
		and p.practice_mgt_key=pm.practice_mgt_key
	  order by a.wflow_exec_id
                
);
quit; 

data _1426170;
 set cihold.NL_HOLD_ENCOUNTER_HEADER_DETAIL;
 where encounter_key=1426170 and wflow_exec_id=5194;
run;
