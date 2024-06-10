/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_empi_load.sas
|
| LOCATION: M:\CI\programs\EDW\
|
| PURPOSE:  Load client EMPI information to EDW
|           
| INPUT:    SAS staging dataset with EMPI information (cistage.empi_&client_id.)
|			&client_id
|			&wflow_exec_id
|
| OUTPUT:   1. Insert new EMPIs to CIEDW.client_member_map
|			2. Insert new rows to CIHold.client_member
|			3. Insert/update rows in CIEDW.member
|			4. Insert new rows in CIEDW member satellite tables
|			5. Insert collapsed enterprise_member_id (if exist) to xref table
|
+--------------------------------------------------------------------------------
| History:  
|
| 14OCT2011 - G Liu - Clinical Integration  1.0.01
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 01MAY2012 - G Liu - Clinical Integration 1.2.01 H02
|			  Switch loading to VH_EMPI database, with new table and column names
|			  Move DQ to extract (client macro)
|			  Rewrite _syspersid load to use bcp bulkload
| 07AUG2012 - G Liu - Clinical Integration 1.5.01
|			  When matching by system_person_id, pick min from person_patient_map table
|				when more than 1 mapping exist
| 20AUG2012 - G Liu - Clinical Integration 1.5.02 H03
|			  Construct member record dynamically based on metadata from table
|				vh_empi.dbo.patient_attribute_methodology
+-----------------------------------------------------------------------HEADER*/

options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

%bpm_environment

%macro edw_empi_load(incoming);
  options nosymbolgen;
  %client_empi_check(&client_id.)
  %let practice_id=&empi_datasource_id.;
  %let datasource_id=&empi_datasource_id.;
  %let sasprogramby='EDW EMPI LOAD';
  %let incoming_library=%scan(&incoming.,-2,'.');
  %let incoming_dataset=%scan(&incoming.,-1,'.');
  %if &incoming_library.= %then %let incoming_library=work;

  %bpm_process_control(timevar=START)

  %let dsn_id=%sysfunc(open(&incoming.));
  %let dsn_obs=%sysfunc(attrn(&dsn_id.,nobs));
  %let dsn_rc=%sysfunc(close(&dsn_id.));

  %let src_record_cnt=&dsn_obs.;

	%macro del_same_wflow(m_table,m_wflow_var=created_wflow_exec_id);
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute	(	delete from &m_table.
						where	&m_wflow_var.=&wflow_exec_id.
					)
			by oledb;
		quit;
	%mend;

  %IF &client_with_empi_indicator. %THEN %DO;
	%if %sysfunc(exist(&incoming._syspersid)) %then %do; /* begin - load system_member_id mapping to enterprise_member_id */
		%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do; proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit; %end;
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute (	create table cihold.dbo.saswrk_bulkload_&wflow_exec_id.
						(	[client_key] [int] not null,
							[file_received_date] [smalldatetime] not null,
							[enterprise_member_id] [varchar](50) not null,
							[source_system_id] [varchar](50) not null,
							[system_member_id] [varchar](50) not null, 
							[parent_source_system_id] [varchar](50) null, 
							[parent_system_member_id] [varchar](50) null,
							[created_on] [smalldatetime] not null,
							[created_by] [varchar](20) not null
						)
					)
			by oledb;
		quit;

		data eel_view_syspersid / view=eel_view_syspersid;
			length enterprise_member_id source_system_id system_member_id parent_source_system_id parent_system_member_id $50.;
			format enterprise_member_id source_system_id system_member_id parent_source_system_id parent_system_member_id $50.;
			length created_by $20.;
			format created_on file_received_date datetime22. created_by $20.;
			set &incoming._syspersid;
			client_key=&client_id.;
			created_on=datetime();
			created_by=&sasprogramby.;
		run;

		proc append base=bcphold.saswrk_bulkload_&wflow_exec_id. data=eel_view_syspersid force; run;

		%set_error_flag
		%on_error(ACTION=ABORT)

		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute ( 
						create nonclustered index [tablekey] on cihold.dbo.saswrk_bulkload_&wflow_exec_id.
						(
							[client_key] ASC,
							[source_system_id] ASC,
							[system_member_id] ASC
						)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
					)
			by oledb;
		quit;

		/*SASDOC--------------------------------------------------------------------------
		| If client member id information changed, we turn the active_flag=0
		+------------------------------------------------------------------------SASDOC*/
		proc sql;
			connect to oledb(init_string=&vh_empi.);
			execute (	create view dbo.client_member_saswrk_&wflow_exec_id. as
						select	*
						from	vh_empi.dbo.client_member(nolock)
					)
			by oledb;
		quit;

		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute (	update vh_empi.dbo.client_member
						set		active_flag=0, updated_wflow_exec_id=&wflow_exec_id., updated_on=a.created_on, updated_by=a.created_by
						from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a inner join
								vh_empi.dbo.client_member b on a.client_key=b.client_key and a.source_system_id=b.source_system_id and a.system_member_id=b.system_member_id and b.active_flag=1 left join
								vh_empi.dbo.client_member_saswrk_&wflow_exec_id. c on b.client_key=c.client_key and b.parent_client_member_key=c.client_member_key
						where	a.enterprise_member_id <> b.enterprise_member_id
						or		a.parent_system_member_id <> c.system_member_id
					)
			by oledb;
		quit;

		proc sql;
			connect to oledb(init_string=&vh_empi.);
			execute (	drop view dbo.client_member_saswrk_&wflow_exec_id.
					)
			by oledb;
		quit;

		proc sql noprint;
			select 	max(source_system_hierarchy_level)
			into	:m_max_source_level
			from 	vh_empi.client_source_system;
		quit;

		/*SASDOC--------------------------------------------------------------------------
		| Load client member IDs based on hierarchy level in order to populate
		|	parent_client_member_key column with PK.
		+------------------------------------------------------------------------SASDOC*/
		%do i=1 %to &m_max_source_level.;
			proc sql noprint;
				select 	"'"||trim(source_system_id)||"'"
				into	:m_client_source_list&i. separated by ','
				from 	vh_empi.client_source_system 
				where 	source_system_hierarchy_level=&i.;
			quit;

			%put NOTE: Processing Source System Level &i. = &&m_client_source_list&i;
			
			proc sql;
				connect to oledb(init_string=&sqlci.);
				execute (	insert into vh_empi.dbo.client_member
						%if &i.=1 %then %do;
								(	client_key, file_received_date, enterprise_member_id, source_system_id, system_member_id, active_flag, 
									created_wflow_exec_id, created_on, created_by)
							select	a.client_key, a.file_received_date, a.enterprise_member_id, a.source_system_id, a.system_member_id, 1,
									&wflow_exec_id., a.created_on, a.created_by
							from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a left join
									vh_empi.dbo.client_member b on a.client_key=b.client_key and a.source_system_id=b.source_system_id and a.system_member_id=b.system_member_id and b.active_flag=1
						%end;
						%else %do;
								(	client_key, file_received_date, enterprise_member_id, source_system_id, system_member_id, parent_client_member_key, active_flag, 
									created_wflow_exec_id, created_on, created_by)
							select	a.client_key, a.file_received_date, a.enterprise_member_id, a.source_system_id, a.system_member_id, c.client_member_key, 1,
									&wflow_exec_id., a.created_on, a.created_by
							from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a left join
									vh_empi.dbo.client_member b on a.client_key=b.client_key and a.source_system_id=b.source_system_id and a.system_member_id=b.system_member_id and b.active_flag=1 left join
									vh_empi.dbo.client_member c on a.client_key=c.client_key and a.parent_source_system_id=c.source_system_id and a.parent_system_member_id=c.system_member_id and c.active_flag=1
						%end;
							where	a.source_system_id in (&&m_client_source_list&i)
							and		b.client_member_key is null
						)
				by oledb;
			quit;

			%set_error_flag
			%on_error(ACTION=ABORT)
		%end;
	%end; /* end - load system_member_id mapping to enterprise_member_id */

	/*SASDOC--------------------------------------------------------------------------
	| Obtain maximum member_key by Client ID & DataSource ID
	+------------------------------------------------------------------------SASDOC*/
	%empi_all_patient_key(allmemberlist,m_client_id=&client_id.,m_datasource_id=&datasource_id.)

	proc sql noprint;
	  select 	input(substr(put(max(patient_key),z16.),9,8),8.) as VIDmax
	  into 		:VIDmax
	  from		allmemberlist;

	  drop table allmemberlist;
    quit;

    %if &VIDmax=. %then %let VIDmax=0;
    %else %let VIDmax=&VIDmax;

    %put NOTE: VIDmax = &VIDmax.;

	/*SASDOC--------------------------------------------------------------------------
	| 1. Get PERSON_KEY
	| 2. Identify existing person_key (i.e. no change), and the rest is incremental
	| 3. Create new patient_key for new EMPI values
	+------------------------------------------------------------------------SASDOC*/
	%let eel_spi_dsid=%sysfunc(open(&incoming.));
	%let eel_spi_var=%sysfunc(varnum(&eel_spi_dsid.,system_person_id));
	%let eel_emi_var=%sysfunc(varnum(&eel_spi_dsid.,enterprise_member_id));
	%let eel_spi_dsrc=%sysfunc(close(&eel_spi_dsid.));
	%if &eel_emi_var. and &eel_spi_var.=0 %then %do;
		proc datasets lib=&incoming_library. nolist;
			modify &incoming_dataset.;
				rename enterprise_member_id=system_person_id;
		quit;
	%end;
	
	%empi_get_system_key(&client_id.,&incoming.,,&wflow_exec_id.,&sasprogramby.,m7_datasource_id=&datasource_id.)
	%empi_get_detail_key(&client_id.,&incoming.,person,&wflow_exec_id.,&sasprogramby.,m9_return_key=1)
	%empi_get_person_key(&client_id.,&incoming.,&wflow_exec_id.,&sasprogramby.,m5_return_patient_key=1)

	%empi_scrub_person_detail(&client_id.,&wflow_exec_id.)

	/* If person_key macro returns a patient key, it means that person_key already exists with a mapping, and no changes in entire record.
		No need to process these in incremental. */
	data eel_incoming_incremental(compress=yes bufsize=128k drop=patient_key);
		set &incoming.;/*(keep=system_person_id person_key patient_key);*/
		where patient_key in (.,0);
		client_key=&client_id.; datasourceid=&datasource_id.;
	run;

	/* Get existing mapping to patient key */
	%bulkload_to_cio(&wflow_exec_id.,eel_incoming_incremental,m_keepvar=client_key datasourceid system_person_id)

	proc sql;
		connect to oledb(init_string=&sqlci.);
		create table eel_syspersid_mapping(drop=person_patient_map_key) as
		select	system_person_id, patient_key as return_patient_key, person_patient_map_key
		from	connection to oledb
				(	select	distinct a.system_person_id, c.patient_key, c.person_patient_map_key
					from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. z inner join
							vh_empi.dbo.person_system(nolock) a on z.client_key=a.client_key and z.datasourceid=a.datasourceid and z.system_person_id=a.system_person_id inner join
							vh_empi.dbo.person(nolock) b on a.client_key=b.client_key and a.person_system_key=b.person_system_key inner join
							vh_empi.dbo.person_patient_map(nolock) c on b.client_key=c.client_key and b.person_key=c.person_key and c.delete_flag=0
				)
		group by 1
		having	person_patient_map_key=min(person_patient_map_key);
	quit;

	data eel_incoming_incremental(compress=yes bufsize=128k drop=return_patient_key new_empi_cnt)
		 eel_new_patient_key(keep=client_key patient_key);
		if _n_=0 then set eel_syspersid_mapping;
		declare hash h_empi(dataset: "eel_syspersid_mapping");
		h_empi.definekey('system_person_id');
		h_empi.definedata('return_patient_key');
		h_empi.definedone();
		call missing(system_person_id,return_patient_key);
		new_empi_cnt=0;
		delete_flag=0;
		created_wflow_exec_id=&wflow_exec_id.;
		created_on=datetime();
		created_by=&sasprogramby.;
		do while (not lstobs);
			return_patient_key=.;
			set eel_incoming_incremental end=lstobs;
			format patient_key 16.;
			if h_empi.find()=0 then do;
				patient_key=return_patient_key;
				pl_methodology_hierarchy=175;
				output eel_incoming_incremental;
			end;
			else do;
				new_empi_cnt+1;
				patient_key=("&client_id." || put(&datasource_id.,z6.) || put(&VIDmax. + new_empi_cnt,z8.))*1;
				pl_methodology_hierarchy=150;
				output eel_incoming_incremental;
				output eel_new_patient_key;
			end;
		end;
		stop;
	run;

    *SASDOC--------------------------------------------------------------------------
    | VH_EMPI table clean up
    +------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		select	*
		into	:eel_wflow_loaded_cnt separated by ','
		from	connection to oledb
				(	select	count(*)
					from	vh_empi.dbo.person_workflow_detail(nolock)
					where	client_key=&client_id.
					and		created_wflow_exec_id=&wflow_exec_id.
				);
	quit;
	%if &eel_wflow_loaded_cnt. %then %do;
		%put NOTE: Records already loaded with this wflow_exec_id = &eel_wflow_loaded_cnt.;
		%put NOTE: Perform delete statements;
		%del_same_wflow(vh_empi.dbo.person_workflow_detail)
		%del_same_wflow(vh_empi.dbo.person_patient_map)
	%end;

	/*SASDOC--------------------------------------------------------------------------
	| Step 1 - Load new patient keys to patient table
	+------------------------------------------------------------------------SASDOC*/
	%bulkload_to_cio(&wflow_exec_id.,eel_new_patient_key)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	insert into vh_empi.dbo.patient
						(	client_key, patient_key, delete_flag, created_wflow_exec_id, created_by)
					select	a.client_key, a.patient_key, 0, &wflow_exec_id., &sasprogramby.
					from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a left join
							vh_empi.dbo.patient b on a.client_key=b.client_key and a.patient_key=b.patient_key
					where	b.client_key is null
				)
		by oledb;
	quit;
	%set_error_flag
	%on_error(ACTION=ABORT)

	/*SASDOC--------------------------------------------------------------------------
	| Step 2 - Load new mapping to VH_EMPI map table
	+------------------------------------------------------------------------SASDOC*/
	%bulkload_to_cio(&wflow_exec_id.,eel_incoming_incremental,
					 m_desttable=vh_empi.dbo.person_patient_map,
					 m_keepvar=	client_key person_key patient_key delete_flag
								created_wflow_exec_id created_on created_by,
					 m_isdatetime=created_on)
	%set_error_flag
	%on_error(ACTION=ABORT)

	/*SASDOC--------------------------------------------------------------------------
	| Step 3 - Load new person_key to workflow detail
	+------------------------------------------------------------------------SASDOC*/
	/* Get pl_methodology_key for linking attribution */
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table pl_methodology_key as
		select	*
		from	connection to oledb
				(	select	plm.pl_methodology_hierarchy, plm.pl_methodology_key
					from	vh_empi.dbo.pl_methodology plm, vh_empi.dbo.pl_methodology_version plmv
					where	plm.pl_methodology_version=plmv.pl_methodology_version
					and		plmv.active_flag=1
					order by plm.pl_methodology_hierarchy
				);
	quit;

	%if %sysfunc(exist(&incoming._syspersid)) %then %do;
		data _null_;
			set &incoming._syspersid(obs=1);
			call symput('eel_last_svcdt',datepart(file_received_date));
		run;
		%put &eel_last_svcdt.;
	%end;
	%else %do;
		data _null_;
			call symput('eel_last_svcdt',datepart(datetime()));
		run;
		%put &eel_last_svcdt.;
	%end; 
	data eel_incoming_incremental_pwd(compress=yes bufsize=128k drop=pl_methodology_hierarchy);
		if _n_=0 then set pl_methodology_key;
		declare hash h_mk(dataset:'pl_methodology_key');
		h_mk.defineKey('pl_methodology_hierarchy');
		h_mk.defineData('pl_methodology_key');
		h_mk.defineDone();
		call missing(pl_methodology_hierarchy,pl_methodology_key);

		counter=1;
		last_svcdt=&eel_last_svcdt.;
		do while (not lstobs);
			pl_methodology_key=.;
			set eel_incoming_incremental(keep=client_key person_key datasourceid pl_methodology_hierarchy
											  created_wflow_exec_id created_on created_by)
										end=lstobs;
			if h_mk.find()=0 then output;
			else do;
				put person_key= pl_methodology_hierarchy=;
				output;
			end;
		end;
		stop;
	run;

	%bulkload_to_cio(&wflow_exec_id.,eel_incoming_incremental_pwd,
					m_desttable=vh_empi.dbo.person_workflow_detail,
					m_keepvar=client_key person_key datasourceid counter last_svcdt 
								pl_methodology_key created_wflow_exec_id created_on created_by,
					m_isdate=last_svcdt,
					m_isdatetime=created_on)
	%set_error_flag
	%on_error(ACTION=ABORT)


	/*SASDOC--------------------------------------------------------------------------
	| Step 4 - load new EMPI or existing EMPI with new demographic
	+------------------------------------------------------------------------SASDOC*/
	proc sql;
		create table construct_want_person as
		select	distinct &client_id. as client_key, person_key
		from	eel_incoming_incremental;
	quit;
	%edw_construct_member_record(construct_want_person,&client_id.,&wflow_exec_id.,&sasprogramby.,m_empidatasourceid=&practice_id.)

	/* Historical EMPI records all have is_ci_data flagged as =1. Any new EMPI data that comes in, they will just have 
		both is_ci_data and is_payer_data =0. When claims are tied to these new EMPIs, then those will be flipped 
		appropriately. */

	/*SASDOC--------------------------------------------------------------------------
	| Step 5 - Load to EDW tables
	+------------------------------------------------------------------------SASDOC*/
	/* This step is different from member load, sourcing from incremental dataset */
	%bulkload_to_cio(&wflow_exec_id.,eel_incoming_incremental,m_keepvar=client_key person_key)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	insert into ciedw.dbo.person_member_map
						(	client_key, person_key, member_key, created_by)
					select	ppm.client_key, ppm.person_key, ppm.patient_key, &sasprogramby.
					from	vh_empi.dbo.person_patient_map(nolock) ppm inner join							
							(	select	min(person_patient_map_key) [ajinomoto]
								from	vh_empi.dbo.person_patient_map(nolock) x inner join
										cihold.dbo.saswrk_bulkload_&wflow_exec_id. y on x.client_key=y.client_key and x.person_key=y.person_key and x.delete_flag=0
								group by x.person_key
							) z on ppm.person_patient_map_key=z.ajinomoto left join
							ciedw.dbo.person_member_map a on ppm.client_key=a.client_key and ppm.person_key=a.person_key
					where	a.client_key is null
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	/*SASDOC--------------------------------------------------------------------------
	| Load crosswalk if exist and 1-to-1
	| Perform this load last since we need ciedw.client_member_map to be populated
	|	with new enterprise member id first.
	+------------------------------------------------------------------------SASDOC*/
	%if %sysfunc(exist(&incoming._xref)) %then %do;
		%let eel_dsid=%sysfunc(open(&incoming._xref));
		%let eel_xref_obs=%sysfunc(attrn(&eel_dsid.,nobs));
		%let eed_dsrc=%sysfunc(close(&eel_dsid.));
	%end;
	%else %do;
		%let eel_xref_obs=0;
	%end;

	%if %sysfunc(exist(&incoming._xref)) and &eel_xref_obs. %then %do; /* begin - handle xref */
		proc sql;
			create table eel_empi_involved_list as
			select	distinct &client_id. as client_key, enterprise_member_id as system_person_id
			from	&incoming._xref
		  union
			select	distinct &client_id. as client_key, parent_enterprise_member_id as sytem_person_id
			from	&incoming._xref;
		quit;
		%bulkload_to_cio(&wflow_exec_id.,eel_empi_involved_list)

		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			create table syspersid_patientkey_map as
			select	system_person_id as enterprise_member_id, patient_key
			from	connection to oledb
					(	select	distinct ps.system_person_id, ppm.patient_key
						from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a inner join
								vh_empi.dbo.person_system(nolock) ps on a.client_key=ps.client_key and a.system_person_id=ps.system_person_id and ps.datasourceid=&datasource_id. inner join
								vh_empi.dbo.person(nolock) p on ps.client_key=p.client_key and ps.person_system_key=p.person_system_key inner join
								vh_empi.dbo.person_patient_map(nolock) ppm on ppm.client_key=p.client_key and ppm.person_key=p.person_key and ppm.delete_flag=0
						where	ps.client_key=&client_id.
					);
		quit;

		data eel_empi_xref(keep=client_key child_patient_key parent_patient_key created_wflow_exec_id created_by
							rename=(child_patient_key=patient_key parent_patient_key=patient_key_xref));
			if _n_=0 then do;
				set syspersid_patientkey_map(keep=patient_key enterprise_member_id);
				set vh_empi.patient_false_negative(keep=patient_key patient_key_xref rename=(patient_key=patient_key_base));
			end;
			declare hash h_empi(dataset: "syspersid_patientkey_map");
			h_empi.definekey('enterprise_member_id');
			h_empi.definedata('patient_key');
			h_empi.definedone();
			call missing(enterprise_member_id,patient_key);
			declare hash h_xref(dataset: "vh_empi.patient_false_negative(keep=client_key patient_key patient_key_xref rename=(patient_key=patient_key_base) where=(client_key=&client_id.))");
			h_xref.definekey('patient_key_base');
			h_xref.definedata('patient_key_xref');
			h_xref.definedone();
			call missing(patient_key_base,patient_key_xref);

			client_key=&client_id.;
			created_wflow_exec_id=&wflow_exec_id.;
			created_by=&sasprogramby.;
			do while (not lstobs);
				patient_key=.; child_patient_key=.; parent_patient_key=.;
				set &incoming._xref end=lstobs;
				if h_empi.find(key:enterprise_member_id)=0 then child_patient_key=patient_key;
				if h_empi.find(key:parent_enterprise_member_id)=0 then parent_patient_key=patient_key;
				if 	child_patient_key ne . and parent_patient_key ne . and 
					child_patient_key ne parent_patient_key and
					h_xref.find(key:child_patient_key) ne 0
				then output eel_empi_xref;
			end;
			stop;
		run;

		%bulkload_to_cio(&wflow_exec_id.,eel_empi_xref,
						 m_desttable=vh_empi.dbo.patient_false_negative,
						 m_keepvar=	client_key patient_key patient_key_xref 
									created_wflow_exec_id created_by,
						 m_isdatetime=created_on)

		proc datasets lib=work nolist;
			delete eel_empi_xref:;
		quit;
	%end; /* end - handle xref */
  %END;

	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
	%end;

  %bpm_process_control(timevar=COMPLETE)
%mend edw_empi_load;

%edw_empi_load(cistage.empi_&client_id._&wflow_exec_id.)
