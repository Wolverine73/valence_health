/* This macro will construct the proper demographics for the patient/member based on the various variations of
	demographics that we have received from different sources. The methodology in the vh_empi.patient_attribute_methodology
	table dictates how we construct the demographics, whether using the most frequent occurrence, or the latest version.

	Input: The input dataset (specified in the m_inset parameter) needs to have at least 2 variables:
		CLIENT_KEY (mandatory)
		One of the following:
			PERSON_KEY - if exist, will be used regardless of other variables
			PATIENT_KEY
			MEMBER_KEY - will be renamed as patient_key

	Note:
		primary_data_type, only use record from SSN. client should have 1 consistent type for all 6 attribute_type.

	Parameters:
		m_empidatasourceid - This should ONLY be specified in the EMPI program where all the records that we are constructing
							are of the EMPI member keys.
		m_dataformatgroupid - This should ONLY be specified if the workflow is run for a specific data source id, so that we 
								can flip is_payer_data or is_ci_data in ciedw.member. For member fix that is client wide, 
								both bit fields will be updated outside of this macro.
		m_datasourceid - This is only applicable when m_dataformatgroupid is 20 for payer data source id.

	This macro is called by the following programs:
		edw_member_load.sas
		edw_empi_load.sas
		edw_claims_reprocess_xref.sas
		edw_claims_reprocess_error.sas
*/
%macro edw_construct_member_record(m_inset,m_client_id,m_wflow_exec_id,m_sasprogramby,m_empidatasourceid=,m_dataformatgroupid=,m_datasourceid=);
	/* If the list of person_key is large, we want to ensure that the VH_EMPI tables have the proper statistics for intense joins later.
		50k and 10k are both arbitrary. G 7/2012 */
	%let ecmr_dsid=%sysfunc(open(&m_inset.));
	%let ecmr_pk_nobs=%sysfunc(attrn(&ecmr_dsid.,nobs));
	%let ecmr_pk_var=%sysfunc(varnum(&ecmr_dsid.,person_key));
	%let ecmr_memk_var=%sysfunc(varnum(&ecmr_dsid.,member_key));
	%let ecmr_patk_var=%sysfunc(varnum(&ecmr_dsid.,patient_key));
	%let ecmr_dsrc=%sysfunc(close(&ecmr_dsid.));

  %IF &ecmr_pk_nobs.=0 %THEN %DO;
	%put NOTE: No records to construct.;
  %END;
  %ELSE %DO; /* begin - has record to construct */
	%if &ecmr_pk_var.=1 and &ecmr_pk_nobs. ge 50000 or
		&ecmr_pk_var.=0 and &ecmr_pk_nobs. ge 10000 %then %do;
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute	(	update statistics vh_empi.dbo.person_workflow_detail
						update statistics vh_empi.dbo.person
						update statistics vh_empi.dbo.person_detail
						update statistics vh_empi.dbo.person_patient_map
						update statistics vh_empi.dbo.person_detail_weight						
					)
			by oledb;
		quit;
	%end;

	%if &ecmr_pk_var.=0 and &ecmr_memk_var.=0 and &ecmr_patk_var.=0 %then %do;
		%put ERROR: Incoming dataset must have one of the following variables: PERSON_KEY, MEMBER_KEY, PATIENT_KEY;
		%let err_fl=1;
	    %set_error_flag
	    %on_error(ACTION=ABORT)
	%end;
	%else %if &ecmr_memk_var. and &ecmr_patk_var.=0 %then %do;
	 	%let ecmr_incoming_library=%scan(&m_inset.,-2,'.');
		%let ecmr_incoming_dataset=%scan(&m_inset.,-1,'.');
	 	%if &ecmr_incoming_library.= %then %let ecmr_incoming_library=work;
		proc datasets lib=&ecmr_incoming_library. nolist;
			modify &ecmr_incoming_dataset.;
				rename member_key=patient_key;
		quit;
	%end;

	/* Get metadata */
	%client_empi_check(&m_client_id.)

	%let ecmr_payer_dsid_list=0;
	proc sql noprint;
		select	b.datasourceid
		into	:ecmr_payer_dsid_list separated by ','
		from	ids.datasource a, ids.datasource_payer b
		where	a.datasourceid=b.datasourceid
		and		a.clientid=&m_client_id.;
	quit;
	%put NOTE: Client &m_client_id. has payer datasource id(s) &ecmr_payer_dsid_list.;

	%macro ecmr_init_pat_attrib_method(m9_var);
		if upcase(attribute_type)=upcase("&m9_var.") then do;
			call symput("ecmr_&m9_var._scrub",abs(scrubbed_indicator));
			call symput("ecmr_&m9_var._scrubtiebreak",abs(is_scrubbed_as_tie_breaker));
			call symput("ecmr_&m9_var._primdata",cats(upcase(primary_data_type)));
			call symput("ecmr_&m9_var._update",cats(upcase(update_type)));
		end;
	%mend ecmr_init_pat_attrib_method;

	data _null_;
		set vh_empi.patient_attribute_methodology;
		where client_key=&m_client_id. and delete_flag=0;
		%if &client_with_empi_indicator. and &empi_datasource_id.=&m_empidatasourceid. %then %do;
			scrubbed_indicator=0; is_scrubbed_as_tie_breaker=0; update_type='LAST_SVCDT';
		%end;
		%ecmr_init_pat_attrib_method(ssn)
		%ecmr_init_pat_attrib_method(name)
		%ecmr_init_pat_attrib_method(sex)
		%ecmr_init_pat_attrib_method(dob)
		%ecmr_init_pat_attrib_method(address)
		%ecmr_init_pat_attrib_method(phone)
	run;

	options nosymbolgen;
	%put NOTE: Metadata for attribute methodology: (scrubbed indicator) (scrubbed as tie breaker) (primary data type) (update type);
	%put NOTE: Metadata for SSN:     &ecmr_ssn_scrub. &ecmr_ssn_scrubtiebreak. &ecmr_ssn_primdata. &ecmr_ssn_update.;
	%put NOTE: Metadata for Name:    &ecmr_name_scrub. &ecmr_name_scrubtiebreak. &ecmr_name_primdata. &ecmr_name_update.;
	%put NOTE: Metadata for Sex:     &ecmr_sex_scrub. &ecmr_sex_scrubtiebreak. &ecmr_sex_primdata. &ecmr_sex_update.;
	%put NOTE: Metadata for DOB:     &ecmr_dob_scrub. &ecmr_dob_scrubtiebreak. &ecmr_dob_primdata. &ecmr_dob_update.;
	%put NOTE: Metadata for Address: &ecmr_address_scrub. &ecmr_address_scrubtiebreak. &ecmr_address_primdata. &ecmr_address_update.;
	%put NOTE: Metadata for Phone:   &ecmr_phone_scrub. &ecmr_phone_scrubtiebreak. &ecmr_phone_primdata. &ecmr_phone_update.;
	options symbolgen;

	/* Load incoming dataset to CIHold as temp table to be joined later to VH_EMPI tables */
	%bulkload_to_cio(&m_wflow_exec_id.,&m_inset.)
    %set_error_flag
    %on_error(ACTION=ABORT)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create view v_construct_patient_info as
		select	*
		from	connection to oledb				
			(	select	d.patient_key, b.person_key, 
						case when a.datasourceid in (&ecmr_payer_dsid_list.) then 1 else 0 end as is_payer_data,
						case when a.datasourceid=&empi_datasource_id. then 1 else 0 end as is_empi_data,
						ssn, fname, mname, lname, sex, dob, address1, address2, address3, city, state, zip, phone,
					%if &client_with_empi_indicator. and &empi_datasource_id.=&m_empidatasourceid. %then ;
					%else %do;
						scrubbed_ssn, scrubbed_fname, scrubbed_lname, scrubbed_sex, scrubbed_dob, 
						scrubbed_address1, scrubbed_city, scrubbed_state, scrubbed_zip, scrubbed_phone,
					%end;
						max(case when a.last_svcdt > a.created_on then null else a.last_svcdt end) as last_svcdt,
						sum(a.counter*a.weight_counter*coalesce(weight_ssn,1)) 		as counter_ssn,
						sum(a.counter*a.weight_counter*coalesce(weight_fname,1)) 	as counter_fname,
						sum(a.counter*a.weight_counter*coalesce(weight_mname,1)) 	as counter_mname,
						sum(a.counter*a.weight_counter*coalesce(weight_lname,1)) 	as counter_lname,
						sum(a.counter*a.weight_counter*coalesce(weight_sex,1)) 		as counter_sex,
						sum(a.counter*a.weight_counter*coalesce(weight_dob,1)) 		as counter_dob,
						sum(a.counter*a.weight_counter*coalesce(weight_address1,1)) as counter_address1,
						sum(a.counter*a.weight_counter*coalesce(weight_address2,1)) as counter_address2,
						sum(a.counter*a.weight_counter*coalesce(weight_address3,1)) as counter_address3,
						sum(a.counter*a.weight_counter*coalesce(weight_city,1)) 	as counter_city,
						sum(a.counter*a.weight_counter*coalesce(weight_state,1)) 	as counter_state,
						sum(a.counter*a.weight_counter*coalesce(weight_zip,1)) 		as counter_zip,
						sum(a.counter*a.weight_counter*coalesce(weight_phone,1)) 	as counter_phone
				from	vh_empi.dbo.person_workflow_detail(nolock) 	a inner join
						vh_empi.dbo.person(nolock) 					b on a.client_key=b.client_key and a.person_key=b.person_key inner join
						vh_empi.dbo.person_detail(nolock) 			c on b.client_key=c.client_key and b.person_detail_key=c.person_detail_key inner join
						vh_empi.dbo.person_patient_map(nolock) 		d on b.client_key=d.client_key and b.person_key=d.person_key inner join
					%if &ecmr_pk_var. %then %do;
						(	select	distinct y.patient_key [ajinomoto]
							from	cihold.dbo.saswrk_bulkload_&m_wflow_exec_id. 	x (nolock) inner join
									vh_empi.dbo.person_patient_map 					y (nolock) on x.client_key=y.client_key and x.person_key=y.person_key and y.delete_flag=0
						) e on d.patient_key=e.ajinomoto left join
					%end;
					%else %do;
						cihold.dbo.saswrk_bulkload_&m_wflow_exec_id. e on d.patient_key=e.patient_key left join
					%end;
						vh_empi.dbo.person_detail_weight(nolock) 	z on c.client_key=z.client_key and c.person_detail_key=z.person_detail_key
				where	a.client_key=&m_client_id.
				group by d.patient_key, b.person_key, a.datasourceid, 
						 case when a.datasourceid in (&ecmr_payer_dsid_list.) then 1 else 0 end,
						 case when a.datasourceid=&empi_datasource_id. then 1 else 0 end,
						 ssn, fname, mname, lname, sex, dob, address1, address2, address3, city, state, zip, phone
					%if &client_with_empi_indicator. and &empi_datasource_id.=&m_empidatasourceid. %then ;
					%else %do;
						 , scrubbed_ssn, scrubbed_fname, scrubbed_lname, scrubbed_sex, scrubbed_dob, 
						 scrubbed_address1, scrubbed_city, scrubbed_state, scrubbed_zip, scrubbed_phone
					%end;
			)
		;
	quit;

  %if &ecmr_ssn_primdata.=COMBINATION %then %do;
	%let m_view_inset=v_construct_patient_info;
  %end;
  %else %if &ecmr_ssn_primdata.=PAYER or &ecmr_ssn_primdata.=PROVIDER %then %do;
	%let m_view_inset=v2_construct_patient_info;
	proc sql;
		create view v2_construct_patient_info as
		select	*, case when min(is_payer_data)=1 then 0 else 1 end as has_provider_data, max(is_payer_data) as has_payer_data
		from	v_construct_patient_info
		group by patient_key;
	quit;
  %end;

	data construct_patient_info construct_empi_info;
/* pc sas - start */
		set &m_view_inset.(rename=(dob=orgdob));
		dob=input(orgdob,yymmdd10.);
		drop orgdob;
/* pc sas - end */

/* linux sas - start */
/*		set &m_view_inset.;*/
/* linux sas - end */

		/* For EMPI member keys, only EMPI records should be primdata, and we should always pick the 
			latest svcdt record */
		if substr(put(patient_key,z16.),3,6)=put(&empi_datasource_id.,z6.) then is_empi_patk=1;
		else is_empi_patk=0;
		if is_payer_data=0 then is_provider_data=1; else is_provider_data=0;
	  %if &client_with_empi_indicator. %then %do;
		if is_empi_patk and is_empi_data then output construct_empi_info;
		else 
	  %end;
	  %if &ecmr_ssn_primdata.=COMBINATION %then %do;
		if is_empi_patk=0 then output construct_patient_info;
	  %end;
	  %else %if &ecmr_ssn_primdata.=PAYER %then %do;
		if is_empi_patk=0 and 
			(has_payer_data and is_payer_data or has_payer_data=0) then output construct_patient_info;
	  %end;
	  %else %if &ecmr_ssn_primdata.=PROVIDER %then %do;
		if is_empi_patk=0 and 
			(has_provider_data and is_provider_data or has_provider_data=0) then output construct_patient_info;
	  %end;
	run;
	%set_error_flag
    %on_error(ACTION=ABORT)

	%macro construct_record(m_pattype,m_var);
			%let m_var=%upcase(&m_var.);
			%macro ecmr_cp_tiebreak_case(m9_var);
				,case when b.patient_key ne . then b.&m9_var. else a.&m9_var. 
					 end 
				as &m9_var.
			%mend ecmr_cp_tiebreak_case;

	  %IF &m_var.=NAME %THEN %DO;
		%if &&ecmr_&m_var._scrub. %then %do;
			%let m_varlistas=scrubbed_fname as fname, mname, scrubbed_lname as lname;
			%let m_varlistgrp=2,3,4;
		%end;
		%else %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do;
			%let m_varlistas=fname, mname, lname, scrubbed_fname, scrubbed_lname;
			%let m_varlistgrp=2,3,4,5,6;
			%let m_varlistas_tiebreak=scrubbed_fname as fname, mname, scrubbed_lname as lname;
			%let m_varlistgrp_tiebreak=2,3,4;
			%macro ecmr_cp_tiebreak;
				%ecmr_cp_tiebreak_case(fname)
				%ecmr_cp_tiebreak_case(mname)
				%ecmr_cp_tiebreak_case(lname)
			%mend;
		%end;
		%else %do;
			%let m_varlistas=fname, mname, lname;
			%let m_varlistgrp=2,3,4;
		%end;
			%let m_varlistsumm=sum(counter_fname+counter_mname+counter_lname)/3;
			%let m_varlistretain=rtfname rtmname rtlname;
			%let m_varlistoutput=%str(rtfname=fname; rtmname=mname; rtlname=lname);
			%let m_varlistlogic1=fname ne '' and lname ne ''; /* mname is not considered in the logic coz it can be null */
			%let m_varlistrename=rtfname=fname rtmname=mname rtlname=lname;
			%macro m_varlistlogic2;
				if rtfname='' or rtlname='' then do;
					if fname ne '' or lname ne '' then do;
						&m_varlistoutput.;
					end;
				end;
			%mend;
	  %END;
	  %ELSE %IF &m_var.=ADDRESS %THEN %DO;
		%if &&ecmr_&m_var._scrub. %then %do;
			%let m_varlistas=scrubbed_address1 as address1, address2, address3, scrubbed_city as city, scrubbed_state as state, scrubbed_zip as zip;
			%let m_varlistgrp=2,3,4,5,6,7;
		%end;
		%else %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do;
			%let m_varlistas=address1, address2, address3, city, state, zip, scrubbed_address1, scrubbed_city, scrubbed_state, scrubbed_zip;
			%let m_varlistgrp=2,3,4,5,6,7,8,9,10,11;
			%let m_varlistas_tiebreak=scrubbed_address1 as address1, address2, address3, scrubbed_city as city, scrubbed_state as state, scrubbed_zip as zip;
			%let m_varlistgrp_tiebreak=2,3,4,5,6,7;
			%macro ecmr_cp_tiebreak;
				%ecmr_cp_tiebreak_case(address1)
				%ecmr_cp_tiebreak_case(address2)
				%ecmr_cp_tiebreak_case(address3)
				%ecmr_cp_tiebreak_case(city)
				%ecmr_cp_tiebreak_case(state)
				%ecmr_cp_tiebreak_case(zip)
			%mend;
		%end;
		%else %do;
			%let m_varlistas=address1, address2, address3, city, state, zip;
			%let m_varlistgrp=2,3,4,5,6,7;
		%end;
			%let m_varlistsumm=sum(counter_address1+counter_address2+counter_address3+counter_city+counter_state+counter_zip)/6;
			%let m_varlistretain=rtaddress1 rtaddress2 rtaddress3 rtcity rtstate rtzip;
			%let m_varlistoutput=%str(rtaddress1=address1; rtaddress2=address2; rtaddress3=address3; rtcity=city; rtstate=state; rtzip=zip);
			%let m_varlistlogic1=address1 ne '' and (city ne '' or zip ne '');
			%let m_varlistrename=rtaddress1=address1 rtaddress2=address2 rtaddress3=address3 rtcity=city rtstate=state rtzip=zip;
			%macro m_varlistlogic2;
				if rtaddress1='' or rtcity='' and rtzip='' then do;
					if address1 ne '' or city ne '' or zip ne '' then do;
						&m_varlistoutput.;
					end;
				end;
			%mend;
	  %END;
	  %ELSE %DO;
		%if &&ecmr_&m_var._scrub. %then %do;
			%let m_varlistas=scrubbed_&m_var. as &m_var.;
			%let m_varlistgrp=2;
		%end;
		%else %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do;
			%let m_varlistas=&m_var., scrubbed_&m_var.;
			%let m_varlistgrp=2,3;
			%let m_varlistas_tiebreak=scrubbed_&m_var. as &m_var.;
			%let m_varlistgrp_tiebreak=2;
			%macro ecmr_cp_tiebreak;
				%ecmr_cp_tiebreak_case(&m_var.)
			%mend;
		%end;
		%else %do;
			%let m_varlistas=&m_var.;
			%let m_varlistgrp=2;
		%end;
			%let m_varlistsumm=sum(counter_&m_var.);
			%let m_varlistretain=rt&m_var.;
			%let m_varlistoutput=rt&m_var.=&m_var.;
			%let m_varlistlogic1=&m_var. ne '';
			%let m_varlistrename=rt&m_var.=&m_var.;
			%macro m_varlistlogic2;
			%mend;
	  %END;
			proc sql;
			  %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do;
				create table v_mem_attribute_&m_var. as
			  %end;
			  %else %do;
				create view v_mem_attribute_&m_var. as
			  %end;
				select	patient_key, &m_varlistas., 
					%if &&ecmr_&m_var._update.=COUNTER %then %do; 
						&m_varlistsumm. as counter, 
					%end;
					%else %if &&ecmr_&m_var._update.=LAST_SVCDT %then %do;
						max(last_svcdt) as last_svcdt, 
					%end;
						min(person_key) as person_key
				from	&m_pattype._info
				group by 1,&m_varlistgrp.
				order by patient_key, &&ecmr_&m_var._update., person_key desc;
			quit;

		%If %upcase(&m_pattype.)=CONSTRUCT_EMPI %Then %Do; /* begin - empi, strictly latest svcdt, no non-null retain logic */
			data &m_pattype._&m_var.;
	            set v_mem_attribute_&m_var.;
	            by patient_key &&ecmr_&m_var._update. descending person_key;
				if last.patient_key;
				drop &&ecmr_&m_var._update. person_key;
	        run;
		%End;
		%Else %If %upcase(&m_pattype.)=CONSTRUCT_PATIENT %Then %Do;
			data &m_pattype._&m_var. %if &&ecmr_&m_var._update.=COUNTER %then %do; (drop=counter) %end;
			  %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do;
				&m_pattype._&m_var._tb(keep=patient_key counter)
			  %end;
				;
	            set v_mem_attribute_&m_var.;
	            by patient_key &&ecmr_&m_var._update. descending person_key;
			  %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do;
				lagcounter=lag(counter);
			  %end;
			  %if %upcase(&m_var.)=SEX %then %do; 
				if sex not in ('M','F') then sex=''; 
			   %if &ecmr_sex_update.=COUNTER and &ecmr_sex_scrubtiebreak. %then %do;
				if scrubbed_sex not in ('M','F') then scrubbed_sex=''; 
			   %end;
			  %end;
				retain &m_varlistretain.;
				if first.patient_key or (&m_varlistlogic1.) then do; &m_varlistoutput.; end;

				if last.patient_key then do;
					%m_varlistlogic2
					output &m_pattype._&m_var.;
				  %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do;
					if counter=lagcounter then output &m_pattype._&m_var._tb;
				  %end;
				end;
				keep patient_key rt: %if &&ecmr_&m_var._update.=COUNTER %then %do; counter %end; ;
				rename &m_varlistrename.;
	        run;
		%End;

	  %if &&ecmr_&m_var._update.=COUNTER and &&ecmr_&m_var._scrubtiebreak. %then %do; /* begin - if counter and wants tie breaker */
		/* currently only sex has tie breaker. to break tie for sex it is much easier since there are only 2 possible values,
	  		but if we have tie breaker for other fields, we will have to go this long route of re-summarizing and picking the
	  		multiple scrubbed values with highest counter to tie break anyway, so, might as well use the long code for everything
	  		including sex */
		%let ecmr_cp_dsid=%sysfunc(open(&m_pattype._&m_var._tb));
		%let ecmr_cp_nobs=%sysfunc(attrn(&ecmr_cp_dsid.,nobs));
		%let ecmr_cp_dsrc=%sysfunc(close(&ecmr_cp_dsid.));
		%if &ecmr_cp_nobs. %then %do;
			proc sql;
				create view v_&m_pattype._&m_var._tb as
				select	a.patient_key, &m_varlistas_tiebreak., sum(a.counter) as counter, min(person_key) as person_key
				from	v_mem_attribute_&m_var. a, &m_pattype._&m_var._tb b
				where	a.patient_key=b.patient_key and a.counter=b.counter
				and		scrubbed_&m_var. is not null
				group by 1,&m_varlistgrp_tiebreak.
				order by patient_key, counter, person_key desc;
			quit;
			data v_&m_pattype._&m_var._tb2 / view=v_&m_pattype._&m_var._tb2;
				set v_&m_pattype._&m_var._tb;
				by patient_key counter descending person_key;
				if last.patient_key;
				drop counter person_key;
			run;

			proc sql undo_policy=none;
				create table &m_pattype._&m_var. as
				select	a.patient_key
						%ecmr_cp_tiebreak
				from	&m_pattype._&m_var. a left join
						v_&m_pattype._&m_var._tb2 b on a.patient_key=b.patient_key;
			quit;
		%end;
	  %end; /* end - if counter and wants tie breaker */
	%mend construct_record;

	%macro construct_type(m2_pat);
		sasfile &m2_pat._info load;
	    %construct_record(&m2_pat.,ssn)
	    %construct_record(&m2_pat.,sex)
	    %construct_record(&m2_pat.,dob)
	    %construct_record(&m2_pat.,phone)
		%construct_record(&m2_pat.,name)
		%construct_record(&m2_pat.,address)
		sasfile &m2_pat._info close;

		data &m2_pat.;
			merge &m2_pat._ssn &m2_pat._name &m2_pat._sex &m2_pat._dob &m2_pat._address &m2_pat._phone;
			by patient_key;
			client_key=&m_client_id.;
		run;
	%mend construct_type;

	/* Construct patient or empi based on different rules. Combine them back after. */
	%let ecmr_cpi_dsid=%sysfunc(open(construct_patient_info));
	%let ecmr_cpi_nobs=%sysfunc(attrn(&ecmr_cpi_dsid.,nobs));
	%let ecmr_cpi_dsrc=%sysfunc(close(&ecmr_cpi_dsid.));
	%let ecmr_cei_dsid=%sysfunc(open(construct_empi_info));
	%let ecmr_cei_nobs=%sysfunc(attrn(&ecmr_cei_dsid.,nobs));
	%let ecmr_cei_dsrc=%sysfunc(close(&ecmr_cei_dsid.));

	%if %sysfunc(exist(construct_record)) %then %do; proc sql; drop table construct_record; quit; %end;
	%if &ecmr_cpi_nobs. %then %do;
		%construct_type(construct_patient)
		proc append base=construct_record data=construct_patient force; run;
	%end;
	%if &ecmr_cei_nobs. %then %do;
		%if &ecmr_cpi_nobs. %then %do;
			proc datasets lib=work nolist; delete v_mem_attribute_:; quit;
		%end;
		data _null_;
			set vh_empi.patient_attribute_methodology;
			where client_key=&m_client_id. and delete_flag=0;
			scrubbed_indicator=0; is_scrubbed_as_tie_breaker=0; update_type='LAST_SVCDT';
			%ecmr_init_pat_attrib_method(ssn)
			%ecmr_init_pat_attrib_method(name)
			%ecmr_init_pat_attrib_method(sex)
			%ecmr_init_pat_attrib_method(dob)
			%ecmr_init_pat_attrib_method(address)
			%ecmr_init_pat_attrib_method(phone)
		run;

		%construct_type(construct_empi)
		proc append base=construct_record data=construct_empi force; run;
	%end;

	/* Insert into vh_empi.patient_detail table */
	%empi_get_detail_key(&m_client_id.,construct_record,patient,&m_wflow_exec_id.,&m_sasprogramby.,m9_return_key=1)

    %set_error_flag
    %on_error(ACTION=ABORT)

	/* Load to patient_detail_map table */
	%bulkload_to_cio(&m_wflow_exec_id.,construct_record,m_keepvar=client_key patient_key patient_detail_key)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	declare @interrorcode int
					begin tran
						update 	vh_empi.dbo.patient_detail_map
						set		delete_flag=1, updated_wflow_exec_id=&m_wflow_exec_id., updated_on=getdate(), updated_by=&m_sasprogramby.
						from	vh_empi.dbo.patient_detail_map a inner join
								cihold.dbo.saswrk_bulkload_&m_wflow_exec_id. b on a.client_key=b.client_key and a.patient_key=b.patient_key and a.delete_flag=0
						where	a.patient_detail_key <> b.patient_detail_key
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	declare @interrorcode int
					begin tran
						insert into vh_empi.dbo.patient_detail_map
							(	client_key, patient_key, patient_detail_key, delete_flag, created_wflow_exec_id, created_by)
						select	a.client_key, a.patient_key, a.patient_detail_key, 0, &m_wflow_exec_id., &m_sasprogramby.
						from	cihold.dbo.saswrk_bulkload_&m_wflow_exec_id. a left join
								vh_empi.dbo.patient_detail_map b on a.client_key=b.client_key and a.patient_key=b.patient_key and b.delete_flag=0
						where	b.client_key is null
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)


	%if &ecmr_pk_var.=1 and &ecmr_pk_nobs. ge 50000 or
		&ecmr_pk_var.=0 and &ecmr_pk_nobs. ge 10000 %then %do;
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute	(	/*update statistics ciedw.dbo.member */ /*skeltaadmin has no permission*/
						update statistics vh_empi.dbo.patient_detail_map
						update statistics vh_empi.dbo.patient_detail						
					)
			by oledb;
		quit;
	%end;

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	set ansi_warnings off
					declare @interrorcode int
					begin tran
						update	ciedw.dbo.member
						set		ssn=c.ssn, fname=c.fname, mname=c.mname, lname=c.lname, sex=c.sex, dob=c.dob,
								address1=c.address1, address2=c.address2, address3=c.address3, city=c.city, state=c.state, zip=c.zip, phone=c.phone,
							%if &m_dataformatgroupid.=20 %then %do;
								is_payer_data=1,
							%end;
							%else %if &m_dataformatgroupid. ne %then %do;
								is_ci_data=1,
							%end;
								updated_by=convert(varchar(50),ltrim(rtrim(b.created_wflow_exec_id))), updated_on=getdate()
						from	ciedw.dbo.member(nolock) a inner join 
								vh_empi.dbo.patient_detail_map(nolock) b on a.client_key=b.client_key and a.member_key=b.patient_key and 
																			b.client_key=&m_client_id. and b.delete_flag=0 and b.created_wflow_exec_id=&m_wflow_exec_id. inner join
								vh_empi.dbo.patient_detail(nolock) c on b.client_key=c.client_key and b.patient_detail_key=c.patient_detail_key
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	set ansi_warnings off
					declare @interrorcode int
					begin tran
						insert into ciedw.dbo.member
							(	client_key, member_key,
								ssn, fname, mname, lname, sex, dob,
								address1, address2, address3, city, state, zip, phone,
								is_ci_data, is_payer_data,
								wflow_exec_id, created_by)
						select	b.client_key, b.patient_key, 
								c.ssn, c.fname, c.mname, c.lname, c.sex, c.dob, 
								c.address1, c.address2, c.address3, c.city, c.state, c.zip, c.phone,
							%if &m_dataformatgroupid.=20 %then %do;
								0, 1,
							%end;
							%else %if &m_dataformatgroupid. ne %then %do;
								1, 0,
							%end;
							%else %do;
								0, 0,
							%end;
								b.created_wflow_exec_id, b.created_by
						from	vh_empi.dbo.patient_detail_map(nolock) b inner join
								vh_empi.dbo.patient_detail(nolock) c on b.client_key=c.client_key and b.patient_detail_key=c.patient_detail_key and
																		b.client_key=&m_client_id. and b.delete_flag=0 and b.created_wflow_exec_id=&m_wflow_exec_id. left join
								ciedw.dbo.member(nolock) a on a.client_key=b.client_key and a.member_key=b.patient_key
						where	a.member_key is null
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)
	
	/* If client has empi, we do not construct the member record tie to client's EMPI, so, flipping the bit fields above won't be complete, because
		there won't be any new patient_detail_map records for those patient keys. So, run the additional logic below */
	%if &client_with_empi_indicator. and &m_dataformatgroupid.=20 %then %do; /* client has empi, and incoming is payer data */
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			execute	(	set ansi_warnings off
						declare @interrorcode int
						begin tran
							update	ciedw.dbo.member
							set		is_payer_data=1									
							where	member_key in (	select	distinct pmm.member_key
													from	vh_empi.dbo.person_workflow_detail(nolock) pwd, ciedw.dbo.person_member_map(nolock) pmm
													where	pwd.client_key=pmm.client_key and pwd.person_key=pmm.person_key
													and		pwd.created_wflow_exec_id=&m_wflow_exec_id.
													and		pwd.datasourceid=&m_datasourceid.
												  )
						if (@interrorcode <> 0) begin
							rollback tran
						end
						commit tran
					)
			by oledb;
		quit;
	    %set_error_flag
	    %on_error(ACTION=ABORT)
	%end;
  %END; /* end - has record to construct */
%mend edw_construct_member_record;
