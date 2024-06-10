

options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

%let sysparm=%str(sk_prcs_ctrl_id=1191 wflow_exec_id=9688 sas_prgm_id=12 client_id=4 system_id=1 practice_id=31 group_id=31 pgf_practice=31 sas_mode=prod); 

%bpm_environment;

			    proc sql;
			      connect to oledb(init_string=&cihold.);
			      execute ( 
			                drop table [cihold].[dbo].[saswrk_temp ]  
			              ) 
			      by oledb; 
			    quit;


		    proc sql;
		      connect to oledb(init_string=&sqlci.);
		      execute ( create table [cihold].[dbo].[saswrk_temp ] 
					 ( sk_prcs_ctrl_id int, sk_ext_prgm_id int, wflow_exec_id int, start_time datetime, end_time datetime)
		             ) 
		      by oledb; 
		    quit;

    proc sql;
	connect to oledb(init_string=&sqlci.);
	create table a as select * from connection to oledb
	(	 
		select  sk_prcs_ctrl_id, sk_ext_prgm_id, wflow_exec_id,  end_time as start_time, end_time
		from [bpmmetadata].[dbo].[sk_process_control] 
		where sk_ext_prgm_id in (19,25,20,22,21,26)
	);
	quit;
	data aa;
	 set a;
	run;
	proc sql;
	 create table b as
	 select wflow_exec_id, count(*) as cnt
	 from aa
	 group by wflow_exec_id
	 having count(*) > 4;
	quit;
    proc sql noprint;
	 select wflow_exec_id into: wf separated by ','
	 from b;
	quit;
	data aa;
	 set aa;
	 where wflow_exec_id in (&wf.);
	run;
	data aaa;
	 set aa (keep=start_time);
	run;
	data aaaa;
	 set aaa (obs=1);
	 start_time=.;
	run;
	data aaa;
	 set aaaa aaa;
	run;
    data aa;
	 merge aa aaa;
	run;
	data aa;
	 set aa;
	 if sk_ext_prgm_id in (21,26) then delete;
	run;

	data c;
	set cihold.saswrk_temp;
	run;
	data aa;
	set aa;
	if wflow_exec_id=. then delete;
	run;

		proc sql; 
		  insert into cihold.saswrk_temp
		  (sk_prcs_ctrl_id, sk_ext_prgm_id, wflow_exec_id, start_time, end_time  )
		  select  sk_prcs_ctrl_id, sk_ext_prgm_id, wflow_exec_id, start_time, end_time 		
		  from aa  ; 
		quit;

     proc sql;
      connect to oledb(init_string=&ciedw.);
      execute ( 
					update [bpmmetadata].[dbo].[sk_process_control]  
					set start_time = b.start_time     
					from [bpmmetadata].[dbo].[sk_process_control] a     
					inner join 
					[cihold].[dbo].[saswrk_temp ]  b on          
					a.sk_prcs_ctrl_id=b.sk_prcs_ctrl_id
					and a.wflow_exec_id=b.wflow_exec_id
              ) 
      by oledb; 
    quit;


     proc sql;
      connect to oledb(init_string=&ciedw.);
      execute ( 
			  update [BPMMetaData].[dbo].[SK_PROCESS_CONTROL]
			  set start_time=dateadd(mi, -2, end_time)
			  where  START_TIME > END_TIME
              ) 
      by oledb; 
    quit;


	proc sql;
	connect to oledb(init_string=&sqlci.);
	create table bb as select * from connection to oledb
	(	 
		select  *
		from [bpmmetadata].[dbo].[sk_process_control] 
		where sk_ext_prgm_id in (19,25,20,22,21,26)
	);
	quit;


