/* wflow_exec_id is used for:
	1. bulkloading to a unique temporary table in cihold 
	2. populating records in person and person_system with a particular created_wflow_exec_id enable us to 
		later upate the CIEDW version of the tables by grabbing only records for those specific wflow
*/
%macro empi_get_person_key(m5_client_id,m5_inset,m5_wflow_exec_id,m5_created_by,m5_return_patient_key=0);
	%if %sysfunc(exist(egpk_person)) %then %do; proc sql; drop table egpk_person; quit; %end;
	proc sql;
		create table egpk_person as
		select 	distinct &m5_client_id. as client_key, person_detail_key, person_system_key, . as person_key, . format 16. as patient_key
		from	&m5_inset.;
	quit;

	%bulkload_to_cio(&m5_wflow_exec_id.,egpk_person);

	/* Load to VH_EMPI, and tag with wflow id */
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute (	declare @interrorcode int
					begin tran
						insert into vh_empi.dbo.person
							(	client_key, person_detail_key, person_system_key, created_wflow_exec_id, created_by)
						select	a.client_key, a.person_detail_key, a.person_system_key, &m5_wflow_exec_id., &m5_created_by.
						from	cihold.dbo.saswrk_bulkload_&m5_wflow_exec_id. a left join
								vh_empi.dbo.person b on a.client_key=b.client_key and a.person_detail_key=b.person_detail_key
														and isnull(a.person_system_key,'')=isnull(b.person_system_key,'')
						where	b.client_key is null
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
	%set_error_flag;
	%on_error(ACTION=ABORT);

	/* Load to EDW, only for those with current wflow id */
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	declare @interrorcode int
					begin tran
						merge ciedw.dbo.person as edw
						using (	select	person_key, client_key, person_system_key, created_by
								from	vh_empi.dbo.person(nolock) 
								where	created_wflow_exec_id=&wflow_exec_id.
							  ) as empi on edw.person_key=empi.person_key 
						when not matched then insert
							(person_key, client_key, person_system_key, created_by)
							values (empi.person_key, empi.client_key, empi.person_system_key, empi.created_by)
						;
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	/* Return newly created person_key (and patient key, if triggered) to cihold temp table to be downloaded later */
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update	cihold.dbo.saswrk_bulkload_&m5_wflow_exec_id.
					set		person_key=b.person_key
					from	cihold.dbo.saswrk_bulkload_&m5_wflow_exec_id. a, vh_empi.dbo.person(nolock) b
					where	a.client_key=b.client_key and a.person_detail_key=b.person_detail_key
					and		isnull(a.person_system_key,'')=isnull(b.person_system_key,'')
				)
		by oledb;
	  %if &m5_return_patient_key.=1 %then %do;
		execute	(	update	cihold.dbo.saswrk_bulkload_&m5_wflow_exec_id.
					set		patient_key=b.patient_key
					from	cihold.dbo.saswrk_bulkload_&m5_wflow_exec_id. a inner join
							vh_empi.dbo.person_patient_map(nolock) b on a.client_key=b.client_key and a.person_key=b.person_key inner hash join
							(	select	min(person_patient_map_key) [myojo]
								from	vh_empi.dbo.person_patient_map(nolock)
								where	client_key=&m5_client_id.
								and		delete_flag=0
								group by person_key
							) b0 on b.person_patient_map_key=b0.myojo
				)
		by oledb;
	  %end;
	quit;

	%if %sysfunc(exist(egpk_person_mapping)) %then %do; proc sql; drop table egpk_person_mapping; quit; %end;
	proc sql;
		create table egpk_person_mapping as
		select	person_detail_key, person_system_key, person_key, patient_key as return_patient_key
		from	cihold.saswrk_bulkload_&m5_wflow_exec_id.;

		drop table cihold.saswrk_bulkload_&m5_wflow_exec_id.;
	quit;

	/* Add person_key (and patient key, if triggered) to input dataset */
	%let m5_dsid=%sysfunc(open(&m5_inset.));
	%let m5_pk_varind=%sysfunc(varnum(&m5_dsid.,patient_key));
	%let m5_dsrc=%sysfunc(close(&m5_dsid.));
	data &m5_inset.(compress=yes bufsize=128k 
						%if &m5_return_patient_key.=0 %then %do; 
							drop=return_patient_key 
						%end;
						%else %if &m5_pk_varind.=0 %then %do; 
							rename=(return_patient_key=patient_key) 
						%end;
					);
		if _n_=0 then set egpk_person_mapping;
		declare hash h_d(dataset:"egpk_person_mapping");
		h_d.definekey("person_detail_key","person_system_key");
		h_d.definedata("person_key","return_patient_key");
		h_d.definedone();
		call missing(person_detail_key, person_system_key, person_key, return_patient_key);

		do while (not lstobs);
			person_key=.; return_patient_key=.;
			set &m5_inset. end=lstobs;
			if h_d.find()=0 then output;
			else output;
		end;
		stop;
	run;
%mend empi_get_person_key;
