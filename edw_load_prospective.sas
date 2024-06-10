
%macro load_tables;

%if %symexist(data_mart) = 0 %then %do;

  %if &client_key. ne 12 %then %do;

       %let init_string2=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=sql-ci;
                Initial Catalog=CIEDW;" );

    proc sql noprint;
		     connect to oledb(init_string=&init_string2.);
		     select data_mart 
		     into :data_mart separated by '' 
		     from connection to oledb
		     (	
			select  data_mart
			from  [dbo].[client]  
			where client_key=&client_key. 
		     );
		   quit;

		   %put NOTE: Client_key = &client_key.;
		   %put NOTE: Data Mart = &data_mart.;

		   %if %QUPCASE(&sas_mode.) = TEST %then %do;
		   		%let data_mart=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=devserv1;Initial Catalog=&data_mart.;");
			%end;
			%if %QUPCASE(&sas_mode.) = PROD %then %do;
				%let data_mart=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=&data_mart.;");
			%end;

	%end;
/*    %else %do;*/
/*		%let data_mart=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=devserv1;Initial Catalog=DM_PFK;");*/
/*    %end;*/

	%put &data_mart;
%end;


/*-------------------------------------------------*/
/*  The following is a work-around until we can    */
/*  get a stored procedure in SQL                  */
/*-------------------------------------------------*/

	%put DATA MART REFERENCE = &data_mart;

data care_el;
  format visit1_dt visit2_dt recall_dt datetime.;
  set registry.prospective_final;
  where member_key ne -99;
  client_key = &client_key;
  visit1_dt=dhms(visit1,0,0,0);
  visit2_dt=dhms(visit2,0,0,0);
  recall_dt=dhms(recall_date,0,0,0);
 run;

data registry;
  format onset_condition_dt term_condition_dt single_onset_dt em_onset_dt
    em_priorseen_dt em_lastseen_dt lab_onset_dt lab_prior_dt lab_last_dt
    double_onset_dt double_priorseen_dt double_lastseen_dt datetime.;
  set registry.registry_final;
  where member_key ne -99;
  client_key = &client_key;
  onset_condition_dt=dhms(onset_condition,0,0,0);
  term_condition_dt=dhms(term_condition,0,0,0);
  single_onset_dt=dhms(single_onset,0,0,0);
  em_onset_dt=dhms(em_onset,0,0,0);
  em_priorseen_dt=dhms(em_priorseen,0,0,0);
  em_lastseen_dt = dhms(em_lastseen,0,0,0);
  lab_onset_dt=dhms(lab_onset,0,0,0);
  lab_prior_dt=dhms(lab_prior,0,0,0);
  lab_last_dt=dhms(lab_last,0,0,0);
  double_onset_dt=dhms(double_onset,0,0,0);
  double_priorseen_dt=dhms(double_priorseen,0,0,0);
  double_lastseen_dt=dhms(double_lastseen,0,0,0);
run;


 proc sql;
   connect to oledb(init_string=&data_mart.);
     select * from connection to oledb
 	(
 EXEC dbo.TRUNCATEPROSPECTIVETABLES;
 
 EXEC dbo.DISABLE_INDEXES @TableName = 'CARE_ELEMENTS';
 )
 ;
 quit;

	libname dmart oledb init_string=&data_mart.  preserve_tab_names=yes insertbuff=10000 readbuff=10000;

 proc sql;
/*   connect to oledb(init_string=&data_mart.);*/
/*     exec*/
/*	 (*/
   insert into dmart.CARE_ELEMENTS
       (member_key
	    ,care_element
		,type
		,screen_name
		,visit1
		,visit_val1
		,detail_key1
		,visit2
		,visit_val2
		,detail_key2
		,timely_flag
		,recall_date
		,overdue_flag
		,contraindicator_flag
		,portal_display
		,client_key
		)
		select
		member_key
	    ,care_element
		,type
		,screen_name
		,visit1_dt
		,visit_val1
		,detail_key1
		,visit2_dt
		,visit_val2
		,detail_key2
		,timely_flag
		,recall_dt
		,overdue_flag
		,contraindicator_flag
		,portal_display
		,client_key
   from care_el;
 quit;

proc sql; 
    connect to oledb(init_string=&data_mart.);
     select * from connection to oledb
 	(
 EXEC dbo.REBUILD_INDEXES @tablename = 'CARE_ELEMENTS';   
  )
  ;
quit;

 proc sql;
   connect to oledb(init_string=&data_mart.);
     select * from connection to oledb
 	(
 
 EXEC dbo.DISABLE_INDEXES @TableName = 'REGISTRY';
 )
 ;
 quit;
  

 proc sql ;         

	  insert into dmart.registry
		(member_key
		 ,condition
		 ,onset_key
		 ,term_key
		 ,single_onset
		 ,em_onset_key
		 ,em_prior_key
		 ,em_last_key
		 ,double_onset_key
		 ,double_prior_key
		 ,double_last_key
		 ,lab_onset_key
		 ,lab_prior_key
		 ,lab_last_key
		 ,onset_condition
		 ,term_condition
		 ,single_onset
		 ,em_onset
		 ,em_priorseen
		 ,em_lastseen
		 ,lab_onset
		 ,lab_prior
		 ,lab_last
		 ,double_onset
		 ,double_priorseen
		 ,double_lastseen
		 ,client_key
		 ,screen_name
		 ,display)
	  select 
		member_key
		 ,condition
		 ,onset_key
		 ,term_key
		 ,single_onset
		 ,em_onset_key
		 ,em_prior_key
		 ,em_last_key
		 ,double_onset_key
		 ,double_prior_key
		 ,double_last_key
		 ,lab_onset_key
		 ,lab_prior_key
		 ,lab_last_key
		 ,onset_condition_dt
		 ,term_condition_dt
		 ,single_onset_dt
		 ,em_onset_dt
		 ,em_priorseen_dt
		 ,em_lastseen_dt
		 ,lab_onset_dt
		 ,lab_prior_dt
		 ,lab_last_dt
		 ,double_onset_dt
		 ,double_priorseen_dt
		 ,double_lastseen_dt
		 ,client_key
		 ,screen_name
		 ,display
	  from registry;
	quit;

proc sql; 
    connect to oledb(init_string=&data_mart.);
     select * from connection to oledb
 	(
 EXEC dbo.REBUILD_INDEXES @tablename = 'REGISTRY';   
  )
  ;
quit;

/*
proc sql;
		connect to oledb(init_string=&data_mart.);
		select * from connection to oledb
		(
				exec dbo.spRegCareEle  
		);
quit;
*/

%mend load_tables;
%load_tables;

