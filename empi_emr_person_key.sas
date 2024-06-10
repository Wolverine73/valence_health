/*HEADER------------------------------------------------------------------------
|
| program:  empi_emr_person_key.sas
|
| location: M:\ci\programs\EDW
|
| purpose:  Load PERSON_KEY to CIMaster.KTBL_XREF_PERSON
|
| logic:	If there are multiple demographics for the same PATID in the incoming file, we
|				arbitrarily pick the latest max PERSON_KEY. We also always update CIMaster 
|				KTBL table using the latest incoming PERSON_KEY.
|
| input:  	CIMaster.sp_master_person stored proc
|			Required parameters: &sas_mode., &sk_prcs_ctrl_id.
|								 &client_id., &datasourceid., &wflow_exec_id., &maxprocessid.
|
| output:  	SQL tables updated:
|				CIMaster.KTBL_XREF_PERSON
|				VH_EMPI.PERSON_DETAIL
|				VH_EMPI.PERSON_SYSTEM
|				VH_EMPI.PERSON
|				CIEDW.PERSON_SYSTEM
|				CIEDW.PERSON
|
| usage:	Load PERSON_KEY to xref table in CIMaster so that EMR data can
|				be loaded to CIEDW without executing patient linking. 
+--------------------------------------------------------------------------------
| history:
|
| 18MAY2012 - G Liu - Clinical Integration 2.0.01
|             Original
+-----------------------------------------------------------------------HEADER*/

/*SASDOC----------------------------------------------------------------------
| Define SAS macros for program
+----------------------------------------------------------------------SASDOC*/
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

/*SASDOC--------------------------------------------------------------------------
| Standard Assignments
+------------------------------------------------------------------------SASDOC*/
%bpm_environment;

%macro empi_emr_person_key;
    /*SASDOC--------------------------------------------------------------------------
    | BPM - Reset the process control tables to start.
    +------------------------------------------------------------------------SASDOC*/
    %bpm_process_control(timevar=START)

/* temp start - temporary reset of macro variables and libname */
	%let sqlci=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;");
	%let cimaster=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=devDB01\CI_R2_LOAD;Initial Catalog=CIMasterSandbox;");
	
	libname cimaster oledb init_string=&cimaster. preserve_tab_names=yes insertbuff=10000 readbuff=10000;
/* temp end */	

	%let incoming=emr_distinct_patient;
	%let sasprogramby='EMPI EMR PERSON KEY';
	proc sql;
/* temp start - should point to emine */
		connect to oledb(init_string=&cimaster. readbuff=10000);
/* temp end */
/*		connect to oledb(init_string=&emine. readbuff=10000);*/
		create table &incoming. as
		select	patid as system_person_id, &datasourceid. as datasourceid,
				ssn, fname, mname, lname, sex, input(dob,yymmdd10.) format mmddyy10. as dob,
				address1, address2, address3, city, state, zip, phone
		from	connection to oledb
				(	exec sp_master_person &datasourceid., &maxprocessid., &client_id.);
	quit;

	%let eepk_dsid=%sysfunc(open(&incoming.));
	%let eepk_nobs=%sysfunc(attrn(&eepk_dsid.,nobs));
	%let eepk_dsrc=%sysfunc(close(&eepk_dsid.));

	%IF &eepk_nobs.=0 %THEN %DO;
		%put NOTE: There are no records returned from SP_MASTER_PERSON stored proc for DataSourceID &datasourceid. with MaxProcessID &maxprocessid.;
	%END;
	%ELSE %DO; /* begin - incoming has records */	
		/*SASDOC--------------------------------------------------------------------------
		| Grab person_key, or if new, add to VH_EMPI
		| Scrub new person_detail rows
		+------------------------------------------------------------------------SASDOC*/
		%empi_get_system_key(&client_id.,&incoming.,datasourceid,&wflow_exec_id.,&sasprogramby.);
		%empi_get_detail_key(&client_id.,&incoming.,person,&wflow_exec_id.,&sasprogramby.,m9_create_person_system_key=1,m9_return_key=1);
		%empi_get_person_key(&client_id.,&incoming.,&wflow_exec_id.,&sasprogramby.);
	
		%empi_scrub_person_detail(&client_id.,&wflow_exec_id.);
	
		/*SASDOC--------------------------------------------------------------------------
		| If an incoming dataset has multiple demographics for the same PATID for whatever 
		|	reason, we arbitrarily pick the max person key so that there is always 1 PATID
		|	to 1 person key. We then load to CIMaster KTBL table and update the PERSON_KEY
		|	to the latest value.
		+------------------------------------------------------------------------SASDOC*/
	/*	proc sql;
			create table eepk_max_person_key as
			select	system_person_id as patid, max(person_key) as person_key
			from	&incoming.
			group by 1;
		quit;	
		%bulkload_to_cio(&wflow_exec_id.,&incoming.,m_keepvar=patid person_key);
	*/
/* temp start - devdb01 does not have cihold DB, can't use regular bulkload macro */
		%if %sysfunc(exist(cimaster.saswrk_bulkload_&wflow_exec_id.)) %then %do; proc sql; drop table cimaster.saswrk_bulkload_&wflow_exec_id.; quit; %end;
		proc sql;
			connect to oledb(init_string=&cimaster.);
			execute	(	create table dbo.saswrk_bulkload_&wflow_exec_id.
							(	[patid] [varchar](50), [person_key] [int])
					)
			by oledb;
		quit;
		proc sql;
			insert into cimaster.saswrk_bulkload_&wflow_exec_id.
			select	system_person_id, max(person_key)
			from	&incoming.
			group by 1;
		quit;
/* temp end - devdb01 does not have cihold DB, can't use regular bulkload macro */
	
/* temp - change following steps to init_string=&emine. and cimaster.dbo.ktbl... and cihold.saswrk_... */
		proc sql;
			connect to oledb(init_string=&cimaster. readbuff=10000);
			execute	(	update 	cimastersandbox.dbo.ktbl_xref_person
						set		person_key=b.person_key
						from	cimastersandbox.dbo.ktbl_xref_person a inner join
								cimastersandbox.dbo.saswrk_bulkload_&wflow_exec_id. b   
	                            on a.datasourceid=&datasourceid. and a.sourcememberid=b.patid
					)
			by oledb;
	
			execute	(	insert into cimastersandbox.dbo.ktbl_xref_person
							(	datasourceid, sourceMemberID, person_key)
						select	&datasourceid., a.patid, a.person_key
						from	cimastersandbox.dbo.saswrk_bulkload_&wflow_exec_id. a left join 
								cimastersandbox.dbo.ktbl_xref_person b on b.datasourceid=&datasourceid. and a.patid=b.sourcememberid
						where	b.sourcememberid is null
					)
			by oledb;
		quit;
		proc sql; drop table cimaster.saswrk_bulkload_&wflow_exec_id.; quit;
	%END; /* end - incoming has records */	

    /*SASDOC--------------------------------------------------------------------------
    | BPM - Reset the process control tables to complete.
    +------------------------------------------------------------------------SASDOC*/
    %bpm_process_control(timevar=COMPLETE)
%mend empi_emr_person_key;
%empi_emr_person_key
