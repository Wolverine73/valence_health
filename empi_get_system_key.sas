/* wflow_exec_id is used for:
	1. bulkloading to a unique temporary table in cihold 
	2. populating records in person and person_system with a particular created_wflow_exec_id enable us to 
		later upate the CIEDW version of the tables by grabbing only records for those specific wflow
*/
%macro empi_get_system_key(m7_client_id,m7_inset,m7_datasource_id_var,m7_wflow_exec_id,m7_created_by,m7_datasource_id=0);
	%let m7_dsid=%sysfunc(open(&m7_inset.));
	%let m7_patid_var=%sysfunc(varnum(&m7_dsid.,system_person_id));
	%let m7_dsid_exist_var=%sysfunc(varnum(&m7_dsid.,datasourceid));
	%let m7_dsrc=%sysfunc(close(&m7_dsid.));

	%if &m7_patid_var. %then %do;
		%if %sysfunc(exist(egsk_person_system)) %then %do; proc sql; drop table egsk_person_system; quit; %end;
		proc sql;
			create table egsk_person_system as
			select	distinct &m7_client_id. as client_key, 
				%if &m7_datasource_id. ne 0 %then %do;
					&m7_datasource_id. as datasourceid, 
				%end;
				%else %do;
					&m7_datasource_id_var. as datasourceid, 
				%end;
					system_person_id, . as person_system_key
			from	&m7_inset.
			where	system_person_id ne '';
		quit;
		%set_error_flag;
		%on_error(ACTION=ABORT);

		%let m7_ds1_id=%sysfunc(open(egsk_person_system));
		%let m7_ds1_nobs=%sysfunc(attrn(&m7_ds1_id.,nobs));
		%let m7_ds1_rc=%sysfunc(close(&m7_ds1_id.));
		%if &m7_ds1_nobs. %then %do;
			%bulkload_to_cio(&m7_wflow_exec_id.,egsk_person_system);

			/* Load to VH_EMPI, and tag with wflow id */
			proc sql;
				connect to oledb(init_string=&sqlci.);
				execute (	declare @interrorcode int
							begin tran
								insert into vh_empi.dbo.person_system
									(	client_key, datasourceid, system_person_id, created_wflow_exec_id, created_by)
								select	a.client_key, a.datasourceid, a.system_person_id, &m7_wflow_exec_id., &m7_created_by.
								from	cihold.dbo.saswrk_bulkload_&m7_wflow_exec_id. a left join
										vh_empi.dbo.person_system b on a.client_key=b.client_key and a.datasourceid=b.datasourceid and a.system_person_id=b.system_person_id
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
								merge ciedw.dbo.person_system as edw
								using (	select	person_system_key, client_key, datasourceid, system_person_id, created_by
										from 	vh_empi.dbo.person_system(nolock)
										where	created_wflow_exec_id=&wflow_exec_id.
									  ) as empi on edw.person_system_key=empi.person_system_key 
								when not matched then insert
									(person_system_key, client_key, datasourceid, system_person_id, created_by)
									values (empi.person_system_key, empi.client_key, empi.datasourceid, empi.system_person_id, empi.created_by)
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

			/* Return newly created person_system_key to cihold temp table to be downloaded later */
			proc sql;
				connect to oledb(init_string=&sqlci.);
				execute	(	update	cihold.dbo.saswrk_bulkload_&m7_wflow_exec_id.
							set		person_system_key=b.person_system_key
							from	cihold.dbo.saswrk_bulkload_&m7_wflow_exec_id. a, vh_empi.dbo.person_system(nolock) b
							where	a.client_key=b.client_key and a.datasourceid=b.datasourceid and a.system_person_id=b.system_person_id
						)
				by oledb;
			quit;

			%if %sysfunc(exist(egsk_person_system_mapping)) %then %do; proc sql; drop table egsk_person_system_mapping; quit; %end;
			proc sql;
				create table egsk_person_system_mapping as
				select	datasourceid, system_person_id, person_system_key
				from	cihold.saswrk_bulkload_&m7_wflow_exec_id.;

				drop table cihold.saswrk_bulkload_&m7_wflow_exec_id.;
			quit;

			/* Add person_system_key to input dataset */
			data &m7_inset.(compress=yes bufsize=128k);
				if _n_=0 then set egsk_person_system_mapping;
				declare hash h_d(dataset:"egsk_person_system_mapping");
				h_d.definekey("datasourceid","system_person_id");
				h_d.definedata("person_system_key");
				h_d.definedone();
				call missing(datasourceid, system_person_id, person_system_key);

				do while (not lstobs);
					person_system_key=.;
					set &m7_inset. end=lstobs;
				  %if &m7_datasource_id. ne 0 %then %do;
					temp_dsid_var=&m7_datasource_id.;
					if h_d.find(key:temp_dsid_var,key:system_person_id)=0 then output;
				  %end;
				  %else %do;
					if h_d.find(key:&m7_datasource_id_var.,key:system_person_id)=0 then output;
				  %end;
					else output;
				end;
				stop;
			  %if &m7_datasource_id. ne 0 %then %do;
				drop temp_dsid_var;
			  %end;
			  %if %upcase(&m7_datasource_id_var.) ne DATASOURCEID and &m7_dsid_exist_var.=0 %then %do;
				drop datasourceid;
			  %end;
			run;
		%end;
	%end;
%mend empi_get_system_key;
