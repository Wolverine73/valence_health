
/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_load
|
| location: M:\ci\programs\EDW
|
| purpose:  EDW Member Load
|
| logic:
|
| input:  member related data from practice, hosptial, and lab sources
|
| output:  CIEDW
|
| usage:
|
|
+--------------------------------------------------------------------------------
| history:
|
| 10DEC2010 - Brandon Barber  - Clinical Integration (CIO)
|             Original
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 06JAN2012 - G Liu 		  - Clinical Integration  1.1.02
|			  HL7 lab will perform count by testnum (instead of count *) to
|				produce counter for satellite tables	
|
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 M01
|			  Updated code to load member's DOD, from 837 Institutional and 
|			  Professional only, to the member table only (no satellites). The
|			  member's DOD will be the latest DOD from it's source and the hierarchy
|			  of overwriting DOD is 837 Institutional trumps 837 Professional trumps
|			  comments trumps SSN Death Database.
|
| 28APR2012 - G Liu			  - Clinical Integration  1.2.01 H02
|			  Renamed hl7lab_indicator to labresult_indicator
|			  Change code to load to VH_EMPI database
|			  Add PERSON_KEY to HL7 work area load
|			  Rewrite DOD to fit new EMPI database codes
|
| 28MAY2012 - G Liu			  - Clinical Integration 1.2.02
|			  Rewrite delete statements when performing VH_EMPI table clean up
|
| 07JUN2012 - G Liu			  - Clinical Integration 1.3.01
|			  Removed MEMBER_KEY from LAB loading to work area
|			  Added tablock for ciedw.person and ciedw.person_system temporarily to prevent
|				parallel processing hitting the table simultaneously and causing duplicate error
|
| 19JUN2012 - G Liu			  - Clinical Integration 1.3.02
|			  Add DOD logic from Payer UB
|			  Payer UB DOD trumps 837 I (basically trumps everything), since payer data is
|				after adjudication, and 837 I that we intercepted is pre-adjudication.
|
| 25JUN2012 - G Liu			  - Clinical Integration 1.4.01 L05
|			  Move the copy process of PERSON_SYSTEM and PERSON tables from VH_EMPI to CIEDW
|				to the empi_get_system_key.sas and empi_get_person_key.sas macros called in step 2
|
| 28JUN2012 - G Liu			  - Clinical Integration 1.4.02 TCHP
|			  Add codes to handle member attribute. Linking is done purely by system_member_id
|
| 20AUG2012 - G Liu			  - Clinical Integration 1.5.01 H03
|			  Call new macro to construct member record based on metadata in 
|				vh_empi.patient_attribute_methodology
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program
|
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments
|
+------------------------------------------------------------------------SASDOC*;
%bpm_environment;


%macro edw_member_load(incoming=);
    *SASDOC--------------------------------------------------------------------------
    | BPM - Reset the process control tables to start.
    +------------------------------------------------------------------------SASDOC*;
    %bpm_process_control(timevar=START)


    *SASDOC--------------------------------------------------------------------------
    | Set created_by and updated_by variable depending on SAS program ID
    +------------------------------------------------------------------------SASDOC*;
	%if &sas_prgm_id.=18 %then %do;
		%let sasprogramby='REPROCESS - ERROR';
	%end;
	%else %if &sas_prgm_id.=19 %then %do;
		%let sasprogramby='REPROCESS - NL HOLD';
	%end;
	%else %do;
		%let sasprogramby='BPM - SAS';
	%end;

	%macro procsqldroptable(m_table);
		%if %sysfunc(exist(&m_table.)) %then %do;
			proc sql;
				drop table &m_table.;
			quit;
		%end;
	%mend;

   	%data_source_information

	%if %sysfunc(exist(&incoming.))=0 %then %do;
		%if &dataformatgroupid.=20 and &PayerContainMemberElig. %then %do; /* payer data, if incoming is missing, and has elig, reset &incoming. */ 
			%let incoming=cistage.memelig_&practice_id._&client_id._&wflow_exec_id.;
			data &incoming.;
				set &incoming.;
				claim_exists_key=0;
			run;
		%end;
		%else %do;
			%put ERROR: Data set &incoming. does not exist.;
			%let err_fl=1;
		%end;
	%end;

	%set_error_flag
	%on_error(ACTION=ABORT)

 	%let incoming_library=%scan(&incoming.,-2,'.');
	%let incoming_dataset=%scan(&incoming.,-1,'.');
 	%if &incoming_library.= %then %let incoming_library=work;

    *SASDOC--------------------------------------------------------------------------
    | Identify whether incoming dataset is HL7 or HLF lab results
	| We will count counter differently since lab result records are not at proccd level
    +------------------------------------------------------------------------SASDOC*;
	%let datasource_is_labresult_ind=0;	
	proc sql noprint;
		select	case when dataformatid=53 then 1 
					 when dataformatgroupid=16 then 1 
					 else 0 
				end
		into	:datasource_is_labresult_ind separated by ','
		from	data_source_information
		where	datasourceid=&practice_id.;
	quit;
	%put DataSource is LAB result indicator = &datasource_is_labresult_ind.;

    *SASDOC--------------------------------------------------------------------------
    | Send dq_claim_flag = 1 members to NOLOAD table
    +------------------------------------------------------------------------SASDOC*;
    %let sum_NL = ;
    proc sql noprint;
		select count(*)
		into :sum_NL
		from &incoming.
		where dq_member_flag  = 1;
    quit;
    %put NOTE: sum_NL = &sum_NL.;

    %if &sum_NL. ge 1 %then %do;
		proc sort data = &incoming.(keep=member_key person_key wflow_exec_id client_key
										 ssn fname lname address1 address2 dob phone city state zip sex
										 practice_id dq_member_flag dq_claim_flag 
									where=(dq_member_flag=1))
					out=nl_hold_member nodupkey;
			by member_key person_key ssn fname lname;
		run;

        proc sql;
			insert into cihold.nl_hold_member
               (	wflow_exec_id, client_key, person_key, member_key,
					ssn, fname, lname, address1, address2, dob, phone, city, state, zip, sex,
					created_on, created_by, updated_on, updated_by, group_key )
			select	wflow_exec_id, client_key, person_key, member_key,
					ssn, fname, lname, address1, address2, dhms(dob,0,0,0), phone, city, state, zip, sex,
					datetime() format datetime., &sasprogramby., datetime() format datetime., &sasprogramby., practice_id
			from 	nl_hold_member;
		quit;
		%set_error_flag
		%on_error(ACTION=ABORT)
    %end;

    *SASDOC--------------------------------------------------------------------------
    | Prepare incoming data for count and weight calculations
    +------------------------------------------------------------------------SASDOC*;
	%let keep_variables=person_key member_key wflow_exec_id practice_id source client_key; /* if add var here, please add in hl7 sql step below */

	%if &datasource_is_labresult_ind. %then %do;
		%let dsn_id=%sysfunc(open(&incoming.));
		%let dsn_testnum_ind=%sysfunc(varnum(&dsn_id.,testnum));
		%let dsn_rc=%sysfunc(close(&dsn_id.));
		%if &dsn_testnum_ind. %then %do;
			proc sql;
				create table labresult_testnum_level(compress=yes bufsize=512k) as
				select	distinct person_key, ssn, fname, mname, lname, sex, dob, address1, address2, city, state, zip, phone,
						svcdt, dq_claim_flag, dq_member_flag, 0 as claim_exists_key,
						wflow_exec_id, practice_id, source, client_key,
						member_key, testnum
				from	&incoming.
				where	dq_member_flag=0;
			quit;
			%let incoming_temporary=&incoming.;
			%let incoming=labresult_testnum_level;

			proc datasets lib=work nolist;
				copy in=&incoming_library. out=work;
					select &incoming_dataset._plmk;
				change &incoming_dataset._plmk=&incoming._plmk;
			quit;
		%end;
	%end;

	*SASDOC--------------------------------------------------------------------------
    | Find most latest value for DATE_OF_DEATH for incoming members
    +------------------------------------------------------------------------SASDOC*;
	%let varexist_id=%sysfunc(open(&incoming.));
	%let dodvarexist_ind=%sysfunc(varnum(&varexist_id.,dod));
	%let varexist_rc=%sysfunc(close(&varexist_id.));

	%put NOTE: MACRO VARIABLE TO CHECK IF DOD EXISTS - dodvarexist_ind = &dodvarexist_ind.;

	%if &dodvarexist_ind. > 0 %then %do;
		%if &dataformatgroupid. = 3 or &dataformatgroupid. = 12 or &dataformatgroupid.=20 %then %do;
			%macro member_best_dod (input=, incoming=);
				%if &input.=dod %then %let missing_dod = .;
				%else %let missing_dod = "";

				proc sql noprint;
		            create table member_&input. as
		            select distinct 
						   member_key format 16.,
						   dhms(dod,0,0,0) as date_of_death format=datetime22.3 informat=datetime22.3,
						   max(svcdt) as svcdt
						   %if &dataformatgroupid. = 3 %then %do;
							, case when dod = . then .
								   else 8 end as date_of_death_source
						   %end;
						   %else %if &dataformatgroupid. = 12 %then %do;
							, case when dod = . then .
								   else 9 end as date_of_death_source
						   %end;
						   %else %if &dataformatgroupid. = 20 %then %do;
							, case when dod = . then .
								   else 63 end as date_of_death_source
						   %end;
		            from	&incoming. (keep=member_key &input. svcdt dq_member_flag)
			    where	dq_member_flag=0
		            group by member_key, &input.
		            order by member_key, svcdt desc;
		        quit;

				data member_best_&input.(keep = member_key rtdate_of_death rtdate_of_death_source 
										 rename=(rtdate_of_death=date_of_death rtdate_of_death_source=date_of_death_source) );
		            set member_&input.;
		            by member_key descending svcdt;
					retain rtdate_of_death rtdate_of_death_source;
					if first.member_key then do;
						rtdate_of_death		   = date_of_death;
						rtdate_of_death_source = date_of_death_source;
					end;
					else if date_of_death ne &missing_dod. then do;
						rtdate_of_death		   =date_of_death;
						rtdate_of_death_source = date_of_death_source;
					end;
					if last.member_key;
		        run;
			%mend member_best_dod;

			%member_best_dod(input=dod, incoming=&incoming.)
		%end;
	%end;

    *SASDOC--------------------------------------------------------------------------
    | VH_EMPI table clean up
    +------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		select	*
		into	:eml_wflow_loaded_cnt separated by ','
		from	connection to oledb
				(	select	count(*)
					from	vh_empi.dbo.patient
					where	client_key=&client_id.
					and		created_wflow_exec_id=&wflow_exec_id.
				);
	quit;

	%if &eml_wflow_loaded_cnt. %then %do;
		%put NOTE: Records already loaded with this wflow_exec_id = &eml_wflow_loaded_cnt.;
		%put NOTE: Perform delete statements;

		%macro del_same_wflow(m_table,m_wflow_var=created_wflow_exec_id);
			proc sql;
				connect to oledb(init_string=&sqlci.);
				execute	(	delete from &m_table.
							where	&m_wflow_var.=&wflow_exec_id.
						)
				by oledb;
			quit;
		%mend;
		/* Commenting these 2 out. It is not safe to delete records from these 2 tables. If it is RetryMemberLoad,
			then yes, it doesn't matter, because we will be loading the same mapping anyway. However, if it is
			RestartWorkflow, and we loaded some mapping previously, those mapping could've been used by other workflows
			and if we just delete them, it would cause issues to other workflows that already used those mappings. 
			RestartWorkflow might not guarantee that we will get the same set of PERSON_KEYs again, or even the same
			mapping, since things could've changed in the EMPI database, or we could restart workflow because now we 
			fixed the demographic or have PATID, which will have different person_key. G 7/13/2012 */
		/*%del_same_wflow(vh_empi.dbo.patient_detail_map)*/
		%del_same_wflow(vh_empi.dbo.person_workflow_detail)
		/*%del_same_wflow(vh_empi.dbo.person_patient_map)*/
	%end;

    *SASDOC--------------------------------------------------------------------------
    | Unique member_key values observed within incoming dataset
    +------------------------------------------------------------------------SASDOC*;
	/* Step 1 - Load patient key first so that FK constraint will work on other tables */
	proc sql;
		create table patient as
		select	distinct &client_id. as client_key, patient_key
		from	&incoming.(rename=(member_key=patient_key))
		where	patient_key not in (.,0);
	quit;

	%bulkload_to_cio(&wflow_exec_id.,patient)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	declare @interrorcode int
					begin tran
						insert into vh_empi.dbo.patient
							(	client_key, patient_key, delete_flag, created_wflow_exec_id, created_by)
						select	a.client_key, a.patient_key, 0, &wflow_exec_id., &sasprogramby.
						from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a left join
								vh_empi.dbo.patient b on a.client_key=b.client_key and a.patient_key=b.patient_key
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

	/* Step 2 - Load mapping to VH_EMPI */
	proc sql;
		create table person_patient_map as
		select	distinct &client_id. as client_key, person_key, patient_key
		from	&incoming.(rename=(member_key=patient_key))
		where	patient_key not in (.,0);
		/* claim_exists_key=0 doesn't imply person_key has a mapping to patient_key, so, look at everything */
	quit;

	%bulkload_to_cio(&wflow_exec_id.,person_patient_map)

	/* Whichever workflows that populates the person_key first, that's the mapping that "sticks". */
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	declare @interrorcode int
					begin tran
						insert into vh_empi.dbo.person_patient_map
							(	client_key, person_key, patient_key, delete_flag, created_wflow_exec_id, created_by)
						select	a.client_key, a.person_key, a.patient_key, 0, &wflow_exec_id., &sasprogramby.
						from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a left join
								vh_empi.dbo.person_patient_map b on a.client_key=b.client_key and a.person_key=b.person_key
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

	/* Step 3 - load counters to workflow table */
	proc sql undo_policy=none;
		create table person_workflow_detail as
		select	&client_id. as client_key, person_key, practice_id as datasourceid, 
				max(1,count(distinct svcdt)) as counter, max(svcdt) format mmddyy10. as last_svcdt, 
				&wflow_exec_id. as created_wflow_exec_id, &sasprogramby. as created_by
		from	&incoming.
		where	dq_member_flag=0 and claim_exists_key=0
		group by 1,2,3;
	
		create table person_workflow_detail as
		select	a.*, coalesce(b.pl_methodology_key,0) as pl_methodology_key
		from	person_workflow_detail a left join 
				&incoming._plmk b on a.person_key=b.person_key;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	%bulkload_to_cio(&wflow_exec_id.,person_workflow_detail,m_desttable=vh_empi.dbo.person_workflow_detail)
    %set_error_flag
    %on_error(ACTION=ABORT)

	/* Step 4,5,6 - construct member record, insert into vh_empi.patient_ tables, update ciedw.member */
	proc sql;
		create table construct_want_person as
		select	distinct &client_id. as client_key, person_key
		from	&incoming.
		where	dq_member_flag=0;
	quit;
	%edw_construct_member_record(construct_want_person,&client_id.,&wflow_exec_id.,&sasprogramby.,m_dataformatgroupid=&dataformatgroupid.,m_datasourceid=&practice_id.)

	/* Step 7 - Load mapping to CIEDW */
	proc sql;
		create table person_member_map as
		select	distinct &client_id. as client_key, person_key
		from	&incoming.;
	quit;

	%bulkload_to_cio(&wflow_exec_id.,person_member_map)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	declare @interrorcode int
					begin tran
						insert into ciedw.dbo.person_member_map
							(	client_key, person_key, member_key, created_by)
						select	ppm.client_key, ppm.person_key, ppm.patient_key, &sasprogramby.
						from	vh_empi.dbo.person_patient_map(tablock) ppm inner hash join							
								(	select	min(person_patient_map_key) [ajinomoto]
									from	vh_empi.dbo.person_patient_map(nolock) x inner join
											cihold.dbo.saswrk_bulkload_&wflow_exec_id. y on x.client_key=y.client_key and x.person_key=y.person_key and x.delete_flag=0
									group by x.person_key
								) z on ppm.person_patient_map_key=z.ajinomoto left join
								ciedw.dbo.person_member_map a on ppm.client_key=a.client_key and ppm.person_key=a.person_key
						where	a.client_key is null
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	/* Step 8 - Load DOD directly to ciedw.member for now. Create EMPI table to store DOD in R1.3. */
	%if &dodvarexist_ind. > 0 %then %do;
		%bulkload_to_cio(&wflow_exec_id.,member_best_dod,m_isdatetime=date_of_death)

		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			execute	(	declare @interrorcode int
						begin tran
							update	ciedw.dbo.member
							set		date_of_death =	b.date_of_death,
									date_of_death_source = b.date_of_death_source
							from	ciedw.dbo.member a, cihold.dbo.saswrk_bulkload_&wflow_exec_id. b
							where 	a.member_key=b.member_key
							and		b.date_of_death_source is not null
							and	(	a.date_of_death_source is null
								 or b.date_of_death_source=63
								 or b.date_of_death_source=8 and a.date_of_death_source in (8,9,10,11)
								 or b.date_of_death_source=9 and a.date_of_death_source in (9,10,11)
								 or b.date_of_death_source=10 and a.date_of_death_source in (10,11)
								 or b.date_of_death_source=11 and a.date_of_death_source in (11)
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

	/* Step 9 - Load payer member eligibility data to CIEDW */
	%if &dataformatgroupid.=20 and &PayerContainMemberElig. and %substr(%upcase(&incoming_dataset.),1,7)=MEMELIG %then %do; /* start - step 9 payer member eligibility data */ 
		/* See what variable exists in incoming dataset - only optional variables can be missing in incoming dataset */
		%let eml_dsid=%sysfunc(open(&incoming.));
		%let expp_county=%sysfunc(varnum(&eml_dsid.,county));
		%let expp_race=%sysfunc(varnum(&eml_dsid.,race));
		%let expp_subscrssn=%sysfunc(varnum(&eml_dsid.,subscriber_ssn));
		%let expp_relcd=%sysfunc(varnum(&eml_dsid.,relationship_code_pfkey));
		%let exmep_prod=%sysfunc(varnum(&eml_dsid.,product_type));
		%let exmep_plan=%sysfunc(varnum(&eml_dsid.,plan_code));
		%let exmep_polno=%sysfunc(varnum(&eml_dsid.,policy_number));
		%let exmep_emnm=%sysfunc(varnum(&eml_dsid.,employer_name));
		%let exmep_emid=%sysfunc(varnum(&eml_dsid.,employer_id));
		%let eml_dsrc=%sysfunc(close(&eml_dsid.));

		/* #1 - Load member */
		proc sql;
			create table load_person_payer as
			select	distinct payer_key, person_key, person_system_key, 
					ssn, fname, mname, lname, sex, dob, address1, address2, address3, city, state, zip, phone,
					%if &expp_county. %then %do; 	county, 					%end;
					%if &expp_race. %then %do;		race, 						%end;
					%if &expp_subscrssn. %then %do;	subscriber_ssn, 			%end;
					%if &expp_relcd. %then %do;		relationship_code_pfkey, 	%end;
					. as person_payer_key
			from	&incoming.;
		quit;

		%bulkload_to_cio(&wflow_exec_id.,load_person_payer,m_isdate=dob)

		/* Insert new person_key to create a new person_payer_key 
		   If person_key exists, update fields that are not part of person_key construction only when incoming value is non-null
		*/
		%macro notnullupdate(m9_var,m9_value);
			when b.&m9_var. is not null and b.&m9_var. <> isnull(a.&m9_var.,'') then &m9_value.
		%mend;
		%macro exppdynamicwhen(m8_value);
			%if &expp_county. %then %do;	%notnullupdate(county,&m8_value.)					%end;
			%if &expp_race. %then %do;		%notnullupdate(race,&m8_value.)						%end;
			%if &expp_subscrssn. %then %do;	%notnullupdate(subscriber_ssn,&m8_value.)			%end;
			%if &expp_relcd. %then %do;		%notnullupdate(relationship_code_pfkey,&m8_value.)	%end;
		%mend;		
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute	(	declare @interrorcode int
						begin tran
							merge 	ciedw.dbo.person_payer as a
							using	cihold.dbo.saswrk_bulkload_&wflow_exec_id. as b on a.person_key=b.person_key
						  %if &expp_county. or &expp_race. or &expp_subscrssn. or &expp_relcd. %then %do;
							when matched then update set
						  %end;
								%if &expp_county. %then %do; 	county=coalesce(b.county,a.county), %end;
								%if &expp_race. %then %do;		race=coalesce(b.race,a.race), %end;
								%if &expp_subscrssn. %then %do;	subscriber_ssn=coalesce(b.subscriber_ssn,a.subscriber_ssn), %end;
								%if &expp_relcd. %then %do;		relationship_code_pfkey=coalesce(b.relationship_code_pfkey,a.relationship_code_pfkey), %end;
						  %if &expp_county. or &expp_race. or &expp_subscrssn. or &expp_relcd. %then %do;
								updated_wflow_exec_id=(case %exppdynamicwhen(&wflow_exec_id.) 	else a.updated_wflow_exec_id 	end),
								updated_on=			  (case %exppdynamicwhen(getdate())			else a.updated_on 				end),
								updated_by=			  (case %exppdynamicwhen(&sasprogramby.)	else a.updated_by				end)
						  %end;
							when not matched then insert
									(	payer_key, person_key, person_system_key, 
										ssn, fname, mname, lname, sex, dob, address1, address2, address3, city, state, zip, phone,
										%if &expp_county. %then %do; 	county, 					%end;
										%if &expp_race. %then %do;		race, 						%end;
										%if &expp_subscrssn. %then %do;	subscriber_ssn, 			%end;
										%if &expp_relcd. %then %do;		relationship_code_pfkey, 	%end;
										created_wflow_exec_id, created_by)
								values(	b.payer_key, b.person_key, b.person_system_key, 
										b.ssn, b.fname, b.mname, b.lname, b.sex, b.dob, b.address1, b.address2, b.address3, b.city, b.state, b.zip, b.phone,
										%if &expp_county. %then %do; 	b.county, 					%end;
										%if &expp_race. %then %do;		b.race, 					%end;
										%if &expp_subscrssn. %then %do;	b.subscriber_ssn, 			%end;
										%if &expp_relcd. %then %do;		b.relationship_code_pfkey, 	%end;
										&wflow_exec_id., &sasprogramby.)
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

		/* Update all rows tie to the same person_system_key with the parent surrogate key indicating which person_payer_key
			record has the latest demographics. This also allows claims with old person_key to tie to the newest person_payer_key. */
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute (	update 	ciedw.dbo.person_payer
						set		latest_person_payer_key=b.ajinomoto
						from	ciedw.dbo.person_payer a inner hash join
								(	select	person_system_key, max(person_payer_key) [ajinomoto]
									from	ciedw.dbo.person_payer
									group by person_system_key
								) b on a.person_system_key=b.person_system_key
					)
			by oledb;
		quit;		
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		/* Add person_payer_key to cihold temp table for download later */
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute	(	update	cihold.dbo.saswrk_bulkload_&wflow_exec_id.
						set		person_payer_key=b.person_payer_key
						from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a inner join
								ciedw.dbo.person_payer b on a.person_key=b.person_key
					)
			by oledb;
		quit;
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		%procsqldroptable(eml_person_payer_mapping)
		proc sql;
			create table eml_person_payer_mapping as
			select	person_key, person_payer_key
			from	cihold.saswrk_bulkload_&wflow_exec_id.;

			drop table cihold.saswrk_bulkload_&wflow_exec_id.;
		quit;

		/* Add person_payer_key to incoming dataset */
		data &incoming.(compress=yes bufsize=128k);
			if _n_=0 then set eml_person_payer_mapping;
			declare hash h_d(dataset:"eml_person_payer_mapping");
			h_d.definekey("person_key");
			h_d.definedata("person_payer_key");
			h_d.definedone();
			call missing(person_key, person_payer_key);

			do while (not lstobs);
				person_payer_key=.;
				set &incoming. end=lstobs;
				if h_d.find()=0 then output;
				else output;
			end;
			stop;
		run;

		/* #2 - Load member eligibility */
		%bulkload_to_cio(&wflow_exec_id.,&incoming.,
						 m_keepvar=person_payer_key elig_effective_date elig_termination_date is_drug_eligible 
									%if &exmep_prod. %then %do; 	product_type 	%end;
									%if &exmep_plan. %then %do; 	plan_code		%end;
									%if &exmep_polno. %then %do; 	policy_number	%end;
									%if &exmep_emnm. %then %do; 	employer_name	%end;
									%if &exmep_emid. %then %do; 	employer_id		%end;
						 ,
						 m_isdate=elig_effective_date elig_termination_date)

		/* Since eligibility spans can be messy with corrections and updates, it is hard to update existing rows. We decided it will be easier to 
			delete all existing rows for a member (i.e. person_system_key) then reload all eligibilities for that member. This only works assuming
			that incremental batch has full historical eligibilities for the member. If this assumption is not true, the following code will not work. */
		%procsqldroptable(cihold.saswrk_matchcnt_&wflow_exec_id.)
		%procsqldroptable(cihold.saswrk_incomingcnt_&wflow_exec_id.)
		%procsqldroptable(cihold.saswrk_ppkdiff_&wflow_exec_id.)
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			execute (	select	a.person_payer_key, 
								%if &exmep_prod. or &exmep_plan. or &exmep_polno. or &exmep_emnm. or &exmep_emid. %then %do;
									sum(case %if &exmep_prod. %then %do; 	when isnull(a.product_type,'') 	<> isnull(b.product_type,'') then 0		%end;
											 %if &exmep_plan. %then %do; 	when isnull(a.plan_code,'') 	<> isnull(b.plan_code,'') then 0 		%end;
											 %if &exmep_polno. %then %do; 	when isnull(a.policy_number,'') <> isnull(b.policy_number,'') then 0 	%end;
											 %if &exmep_emnm. %then %do; 	when isnull(a.employer_name,'') <> isnull(b.employer_name,'') then 0 	%end;
											 %if &exmep_emid. %then %do; 	when isnull(a.employer_id,'') 	<> isnull(b.employer_id,'') then 0		%end;
											 else 1 end) as matchcnt
								%end;
								%else %do; count(*) as matchcnt %end;
						into	cihold.dbo.saswrk_matchcnt_&wflow_exec_id.
						from	ciedw.dbo.member_eligibility_payer a, cihold.dbo.saswrk_bulkload_&wflow_exec_id. b
						where	a.person_payer_key=b.person_payer_key
						and		a.elig_effective_date=b.elig_effective_date
						and		a.elig_termination_date=b.elig_termination_date
						group by a.person_payer_key
					)
			by oledb;

			execute	(	select	person_payer_key, count(*) as incomingcnt
						into	cihold.dbo.saswrk_incomingcnt_&wflow_exec_id.
						from	cihold.dbo.saswrk_bulkload_&wflow_exec_id.
						group by person_payer_key
					)
			by oledb;

			execute	(	select	i.person_payer_key,
								case when m.matchcnt is null then 'NEW' else 'UPDATE' end as action
						into	cihold.dbo.saswrk_ppkdiff_&wflow_exec_id.
						from 	cihold.dbo.saswrk_incomingcnt_&wflow_exec_id. i left join
								cihold.dbo.saswrk_matchcnt_&wflow_exec_id. m on i.person_payer_key=m.person_payer_key
						where	i.incomingcnt <> m.matchcnt
						or		m.matchcnt is null
					)
			by oledb;
		quit;
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		%procsqldroptable(cihold.saswrk_matchcnt_&wflow_exec_id.)
		%procsqldroptable(cihold.saswrk_incomingcnt_&wflow_exec_id.)
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute (	delete 	a
						from 	ciedw.dbo.member_eligibility_payer a inner join
								cihold.dbo.saswrk_ppkdiff_&wflow_exec_id. b on a.person_payer_key=b.person_payer_key
						where	action='UPDATE'
					)
			by oledb;
		quit;		
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute (	set ansi_warnings off
						declare @interrorcode int
						begin tran
							insert into ciedw.dbo.member_eligibility_payer
								(	person_payer_key, elig_effective_date, elig_termination_date, is_drug_eligible,
									%if &exmep_prod. %then %do; 	product_type, 	%end;
									%if &exmep_plan. %then %do; 	plan_code, 		%end;
									%if &exmep_polno. %then %do; 	policy_number,	%end;
									%if &exmep_emnm. %then %do; 	employer_name,	%end;
									%if &exmep_emid. %then %do; 	employer_id,	%end;
									created_wflow_exec_id, created_on, created_by)
							select	a.person_payer_key, elig_effective_date, elig_termination_date, is_drug_eligible,
									%if &exmep_prod. %then %do; 	product_type, 	%end;
									%if &exmep_plan. %then %do; 	plan_code, 		%end;
									%if &exmep_polno. %then %do; 	policy_number,	%end;
									%if &exmep_emnm. %then %do; 	employer_name,	%end;
									%if &exmep_emid. %then %do; 	employer_id,	%end;
									&wflow_exec_id., getdate(), &sasprogramby.
							from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a inner join
									cihold.dbo.saswrk_ppkdiff_&wflow_exec_id. b on a.person_payer_key=b.person_payer_key
						if (@interrorcode <> 0) begin
							rollback tran
						end
						commit tran
					)
			by oledb;
		quit;
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		%procsqldroptable(cihold.saswrk_ppkdiff_&wflow_exec_id.)
	%end; /* end - step 9 payer member eligibility data */ 

	/* Step 10 - Load payer member attribute data (after eligibility) to CIEDW */
	%if &dataformatgroupid.=20 and &PayerContainMemberElig. and &PayerContainMemberAttr. 
							   and %substr(%upcase(&incoming_dataset.),1,7)=MEMELIG %then %do; /* start - step 10 payer member attribute data */ 
		%payer_memattr_view_dataformat&dataformatid.(&batch_key.)
		
		data payer_memattr_conso(drop=effective_date termination_date lagend 
								rename=(finalbeg=effective_date finalend=termination_date));
			set payer_member_attribute;
			by system_member_id attribute_type_key attribute_value effective_date termination_date;
			lagend=lag(termination_date);
			retain finalbeg finalend;
			if first.attribute_value then do;
				finalbeg=effective_date; finalend=termination_date;
			end;
			else if effective_date le lagend+1 then do;
				finalend=termination_date;
			end;
			else do;
				output;
				finalbeg=effective_date; finalend=termination_date;
			end;
			if last.attribute_value then output;
		run;

		/* Get person_payer_key using latest for each system_member_id */
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			create table latest_person_payer_key as
			select	system_member_id, person_payer_key, count(*) as dupcnt
			from	connection to oledb
					(	select	distinct ps.system_person_id as system_member_id, pp.latest_person_payer_key as person_payer_key
						from	ciedw.dbo.person_payer(nolock) pp, ciedw.dbo.person(nolock) p, ciedw.dbo.person_system(nolock) ps
						where	pp.person_key=p.person_key and p.person_system_key=ps.person_system_key
						and		pp.payer_key=&payer_key. and p.client_key=&client_id. and ps.client_key=&client_id.
					)
			group by 1
			order by 1
			;
		quit;
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		/* Audit to make sure we always have 1 to 1 mapping, if not, there is data integrity issue. */
		data syspersid_notunique;
			set latest_person_payer_key;
			where dupcnt ne 1;
			put _all_;
		run;
		
		%let eml_dsid=%sysfunc(open(syspersid_notunique));
		%let eml_nobs=%sysfunc(attrn(&eml_dsid.,nobs));
		%let eml_dsrc=%sysfunc(close(&eml_dsid.));
		%if &eml_nobs. %then %do;
			%put ERROR: SYSTEM_MEMBER_ID should have a one-to-one mapping to PERSON_PAYER_KEY.;
			%let err_fl=1;
		    %set_error_flag
		    %on_error(ACTION=ABORT)
		%end;

		/* There should always be a mapping to PERSON_PAYER_KEY */
		data payer_memattr_ppkgood payer_memattr_ppkbad;
			if _n_=0 then set latest_person_payer_key(keep=system_member_id person_payer_key);
			declare hash h_ppk(dataset:'latest_person_payer_key(where=(dupcnt=1))');
			h_ppk.definekey('system_member_id');
			h_ppk.definedata('person_payer_key');
			h_ppk.definedone();
			call missing(system_member_id,person_payer_key);

			do while (not lstobs);
				set payer_memattr_conso end=lstobs;
				if h_ppk.find()=0 then output payer_memattr_ppkgood;
				else output payer_memattr_ppkbad;
			end;
			stop;
		run;

		%let eml_dsid=%sysfunc(open(payer_memattr_ppkbad));
		%let eml_nobs=%sysfunc(attrn(&eml_dsid.,nobs));
		%let eml_dsrc=%sysfunc(close(&eml_dsid.));
		%if &eml_nobs. %then %do;
			%put ERROR: Incoming SYSTEM_MEMBER_ID should always be able to find mapping to PERSON_PAYER_KEY.;
			%let err_fl=1;
		    %set_error_flag
		    %on_error(ACTION=ABORT)
		%end;

		/* Figure out if there are any changes, and if so, dump old records and load new records 
			If a system_member_id did not change but person_payer changed, we will keep the attribute records and won't delete it. There
			is no harm keeping extra records, but when we join to attribute, it should be based on the latest_person_payer_key, i.e. these
			old attribute records won't come in to play anyway. G 7/2012
		*/
		%bulkload_to_cio(&wflow_exec_id.,payer_memattr_ppkgood,
						m_keepvar=person_payer_key attribute_type_key attribute_value effective_date termination_date,
						m_isdate=effective_date termination_date);

		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute ( 
						create nonclustered index [tablekey] on cihold.dbo.saswrk_bulkload_&wflow_exec_id.
						(
							[person_payer_key] ASC,
							[attribute_type_key] ASC,
							[attribute_value] ASC
						)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
					)
			by oledb;
		quit;

		%procsqldroptable(cihold.saswrk_matchcnt_&wflow_exec_id.)
		%procsqldroptable(cihold.saswrk_incomingcnt_&wflow_exec_id.)
		%procsqldroptable(cihold.saswrk_ppkdiff_&wflow_exec_id.)
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			execute (	select	a.person_payer_key, a.attribute_type_key, count(*) as matchcnt
						into	cihold.dbo.saswrk_matchcnt_&wflow_exec_id.
						from	ciedw.dbo.member_attribute_payer a, cihold.dbo.saswrk_bulkload_&wflow_exec_id. b
						where	a.person_payer_key=b.person_payer_key
						and		a.attribute_type_key=b.attribute_type_key
						and		a.attribute_value=b.attribute_value
						and		a.effective_date=b.effective_date
						and		a.termination_date=b.termination_date
						group by a.person_payer_key, a.attribute_type_key
					)
			by oledb;

			execute	(	select	person_payer_key, attribute_type_key, count(*) as incomingcnt
						into	cihold.dbo.saswrk_incomingcnt_&wflow_exec_id.
						from	cihold.dbo.saswrk_bulkload_&wflow_exec_id.
						group by person_payer_key, attribute_type_key
					)
			by oledb;

			execute	(	select	i.person_payer_key, i.attribute_type_key,
								case when m.matchcnt is null then 'NEW' else 'UPDATE' end as action
						into	cihold.dbo.saswrk_ppkdiff_&wflow_exec_id.
						from 	cihold.dbo.saswrk_incomingcnt_&wflow_exec_id. i left join
								cihold.dbo.saswrk_matchcnt_&wflow_exec_id. m on i.person_payer_key=m.person_payer_key and i.attribute_type_key=m.attribute_type_key
						where	i.incomingcnt <> m.matchcnt
						or		m.matchcnt is null
					)
			by oledb;
		quit;
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		%procsqldroptable(cihold.saswrk_matchcnt_&wflow_exec_id.)
		%procsqldroptable(cihold.saswrk_incomingcnt_&wflow_exec_id.)
		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute (	delete 	a 
						from 	ciedw.dbo.member_attribute_payer a inner join
								cihold.dbo.saswrk_ppkdiff_&wflow_exec_id. b on a.person_payer_key=b.person_payer_key and a.attribute_type_key=b.attribute_type_key
						where	action='UPDATE'
					)
			by oledb;
		quit;		
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		proc sql;
			connect to oledb(init_string=&sqlci.);
			execute (	set ansi_warnings off
						declare @interrorcode int
						begin tran
							insert into ciedw.dbo.member_attribute_payer
								(	person_payer_key, attribute_type_key, attribute_value, effective_date, termination_date,
									created_wflow_exec_id, created_on, created_by)
							select	a.person_payer_key, a.attribute_type_key, a.attribute_value, a.effective_date, a.termination_date,
									&wflow_exec_id., getdate(), &sasprogramby.
							from	cihold.dbo.saswrk_bulkload_&wflow_exec_id. a inner join
									cihold.dbo.saswrk_ppkdiff_&wflow_exec_id. b on a.person_payer_key=b.person_payer_key and a.attribute_type_key=b.attribute_type_key
						if (@interrorcode <> 0) begin
							rollback tran
						end
						commit tran
					)
			by oledb;
		quit;
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		%procsqldroptable(cihold.saswrk_ppkdiff_&wflow_exec_id.)
	%end; /* end - step 10 payer member attribute data */ 


	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; 
			drop table cihold.saswrk_bulkload_&wflow_exec_id.; 
		quit;
	%end;

	*SASDOC--------------------------------------------------------------------------
    | Load lab results to work area table 
    +------------------------------------------------------------------------SASDOC*;
	%if &datasource_is_labresult_ind. %then %do;

		%let cnt_wk_pre_lab_clinical = 100;	
		%let cnt_sleep_cycle=0;
		%do %until (&cnt_wk_pre_lab_clinical = 0);

			proc sql noprint;
			connect to oledb(init_string=&ciedw. );
			select cnt into: cnt_wk_pre_lab_clinical separated by '' from connection to oledb
			(	select count(*) as cnt
				from etl_ciedw_work_area.dbo.wk_pre_lab_clinical_combined  );
			quit;

			%put NOTE: cnt_wk_pre_lab_clinical = &cnt_wk_pre_lab_clinical. ; 

			%if &cnt_wk_pre_lab_clinical. = 0 %then %do ;
			%end;
			%else %do;
				%let cnt_sleep_cycle=%eval(&cnt_sleep_cycle.+1);
				%if &cnt_sleep_cycle.=3 or &cnt_sleep_cycle.=6 or &cnt_sleep_cycle.=12 or &cnt_sleep_cycle.=24 or &cnt_sleep_cycle.=36 or &cnt_sleep_cycle.=48 %then %do;
					%macro send_email_alert;
						filename mail_out email to=("edwprod@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - Lab Work Area Not Cleared";

						data _null_;
						file mail_out lrecl=32767;
						put "WK_PRE_LAB_CLINICAL_COMBINED table is occupied. Please check.";
						put "client ID = &client_id."; 
						put "datasource ID = &practice_id.";
						run;
					%mend send_email_alert;
					%send_email_alert
				%end;
				/** sleep for 10 minutes **/
				data _null_;
				x sleep 600;
				run;
			%end;

		%end;

		%let incoming=&incoming_temporary.;

		/* This step is to load the incoming dataset to a temporary SQL table in work area so that SSIS steps in Skelta can take over from there.
			Technically this is somewhat of a "claims_load" operation. But, currently HL7 has no arrows in Skelta workflow to go through the
			claims_load program. It goes straight from member_load to SSIS. */	
		proc datasets lib=&incoming_library. nolist;
			modify &incoming_dataset.;
				rename claim_source=etl_source_key ordering_provider_key=provider_key;
		quit;
		%bulkload_to_cio(&wflow_exec_id.,&incoming.,m_desttable=ETL_CIEDW_WORK_AREA.dbo.WK_PRE_LAB_CLINICAL_COMBINED,m_truncate=1,
				m_keepvar=client_key id wflow_exec_id etl_source_key DataSourceID PatientAccountNumber InternalPatientID ExternalPatientID AlternatePatientID 
						  SendingFacility ReceivingFacility SendingApplication ReceivingApplication AlternateFacility AccountNumber
						  fname mname lname ProvFirst ProvLast sex ssn dob address1 address2 city state zip phone 
						  OrderingProvider Diag1 TestName TestNum proccd SubtestName SubtestNum Units Normal_High_Low Result Result_Abnormal_CD 
						  OBR_ResultStatus OBX_ResultStatus Observation_Date Transaction_Date svcdt provid provname OBR_loinccd OBX_loinccd NPI 
						  OBSERVATION_STATUS provider_key practice_key dq_claim_flag dq_member_flag person_key
						  RESULT_DATATYPE MESSAGEID FILLER_ORDER_NUMBER)
	    %set_error_flag
	    %on_error(ACTION=ABORT)
	    
		%let ds_id=%sysfunc(open(&incoming.));
		%let ds_nobs=%sysfunc(attrn(&ds_id.,nobs));
		%let ds_rc=%sysfunc(close(&ds_id.));
		%macro send_email_alert;
			filename mail_out email to=("edwprod@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - Lab Loaded to Work Area";

			data _null_;
			file mail_out lrecl=32767;
			put "Please check to confirm SSIS package is executed by Skelta successfully.";
			put "Total # of records loaded to work area table is &ds_nobs.";
			put "client ID = &client_id."; 
			put "datasource ID = &practice_id.";
			run;
		%mend send_email_alert;
		%send_email_alert
	%end;

    proc sql noprint;
      select count(distinct(person_key)) into: src_record_cnt
      from &incoming. ;
    quit;

    proc sql noprint;
      select count(distinct(person_key)) into: tgt_record_cnt
      from &incoming.
      where dq_member_flag = 0;
    quit;

    *SASDOC--------------------------------------------------------------------------
    | BPM - Reset the process control tables to complete.
    +------------------------------------------------------------------------SASDOC*;
    %bpm_process_control(timevar=COMPLETE)


%mend edw_member_load;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
%edw_member_load(incoming=cistage.claims_&practice_id._&client_id._&wflow_exec_id.)

