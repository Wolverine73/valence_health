
/*HEADER------------------------------------------------------------------------
|
| program:  edw_linking
|
| location: M:\ci\programs\EDW
|
| purpose:  EDW Linking Algorithm and Member DQ Checks
|
| logic:    
|
| input:  	member related data from practice, hosptial, and lab sources    
|			required variables: 
|				ssn fname mname lname sex dob address1 address2 city state zip phone
|				source historical group_id practice_id patient_key dq_member_flag claim_key svcdt 
|			optional variables: 
|				enterprise_member_id system_member_id source_system_id
|                        
| output:  	updated incoming SAS datasets 
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 10DEC2010 - Brandon Barber  - Clinical Integration (CIO)
|       	  Original
| 04MAR2011 - Brandon Barber - Clinical Integration (CIO)
|			  Modification to Permit Exact Matching on PracticeID Blocking
| 07DEC2011 - G Liu - Clinical Integration 1.0.01
|			  Replaced update sql statement to hash
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 02JAN2012 - G Liu - Clinical Integration 1.1.02
|			  Added datasource id exact match on ALL fields ahead of any other linking
| 17FEB2012 - G Liu - Clinical Integration 1.1.03
|			  Added logic to reset member key to 0 if staging has non-zero
| 11MAR2012 - G Liu - Clinical Integration 1.1.04
|			  Added logic to null out incoming DOB prior to 1753. SQL cannot accept date.
| 04APR2012 - G Liu - Clinical Integration 1.1.05
|			  Added fmt.cio_zipcode which is a combination of Apr 2008 and Jan 2012 zip codees from SAS
|			  Added fmt.cio_cityalias to standardize city aliases to "official" city name
| 25APR2012 - G Liu - Clinical Integration 1.2.01
|			  Switch everything to new VH_EMPI database
|			  Add logic to match by system_person_id when available
|			  Change in biz logic, if phys and has system_person_id we will create new mk
|			  Enhance logic to create new member key for each system_person_id, even with same SSNs
|			  Source all linking metadata from VH_EMPI database (instead of SAS format datasets)
|			  Source scrubbed values directly from VH_EMPI database
|			  Changed all patient_key reference to patient_key in anticipation of R1.3
|			  Add linking methodology attribution
|			  (future: reverse DOB 1753 scrubbing once we delete DOB from HOLD and NL HOLD)
| 15MAY2012 - G Liu - Clinical Integration 1.2.02
|			  Add manual code for 1285 and 1288 (client_key=13) to match MRN cross datasourceid
| 24MAY2012 - G Liu - Clinical Integration 1.2.03
|			  Fix typo on %hash_lookup step for client_member_map (lookup set should be client_patient_map)
| 15JUN2012 - G Liu - Clinical Integration 1.3.01 
|			  Add manual code for 1284 (client_key=13) to match MRN cross datasourceid
| 09JUL2012 - G Liu - Clinical Integration 1.4.01
|			  Add dynamic code for vh_empi.pl_datasource_group for grouping relationship of datasourceid
|			  Pick min if multiple mapping from 1 system person id to member key. Eventually they'll be
|				collapsed in member fix anyway.
| 29AUG2012 - B Fletcher - Clinical Integration 1.5.02
|			  Prevent invalid system_member_id linking between old and new systems within the same datasourceid.
| 			  For each client onboarding if the dsID has multiple systems - old and new system -
| 			  the patids might overlap and be linked which should not occur. Investigation prior to onboarding needs to occur
| 			  to identify the datasources and be hard-coded to prevent invalid system_member_id linking.
+-----------------------------------------------------------------------HEADER*/

%macro edw_linking(incoming=);
 	%let incoming_library=%scan(&incoming.,-2,'.');
	%let incoming_dataset=%scan(&incoming.,-1,'.');
 	%if &incoming_library.= %then %let incoming_library=work;

	%let el_dsid=%sysfunc(open(&incoming.));
	%let el_mk_ind=%sysfunc(varnum(&el_dsid.,member_key));
	%let el_pk_ind=%sysfunc(varnum(&el_dsid.,patient_key));
	%let el_dsrc=%sysfunc(close(&el_dsid.));
	%if &el_mk_ind. and &el_pk_ind.=0 %then %do;
		proc datasets lib=&incoming_library. nolist;
			modify &incoming_dataset.;
				rename member_key=patient_key;
		quit;
	%end;

	%let starttime=%sysfunc(time());

	proc format cntlin=fmt.NickName; 
	proc format cntlin=fmt.fnameGender; 
	proc format cntlin=fmt.zipcodes; 
	proc format cntlin=fmt.cio_zipcode;
	proc format cntlin=fmt.cio_cityalias; run;

	data el_prac_cnt(keep=practice_id)
		 el_mk_cnt(keep=patient_key)
		 el_baddob_cnt(keep=dob);
	  set &incoming. (keep = source group_id practice_id historical patient_key dob);
	  call symputx("source",source);
	  call symputx("historical",historical);
	  if group_id ne 0 then do; /** group ID = 0 for non CI but reportable   **/
		  call symputx("group_id",practice_id); /** practice ID = vmine ID for vmine and group ID for PGF   **/
		                                        /** needs to be unique ID for group of vmine and pgf claims **/
		                                        /** vmine and pgf may have multiple groups per file         **/ 
		  output el_prac_cnt;
	  end;
	  if patient_key not in (.,0) then output el_mk_cnt;
	  if dob ne . and year(dob) lt 1753 then output el_baddob_cnt;
	run;
	
	%put NOTE: source = &source.;
	%put NOTE: historical = &historical.;
	%put NOTE: group_id = &group_id.;
	/* We will reassign historical variable to 2 if historical=0 and there are no valid SSN. See the step after PM_perm */
	
		/* There are more than one practice ID associated to the file and may cause issues to the linking algorithm. */
	%check_issue_count(dataset_in=el_prac_cnt, validation=57);

	proc sql noprint;
	  select count(distinct(practice_id)) into: practice_count
	  from el_prac_cnt;
	quit;			
	%put NOTE: practice_count = &practice_count. ;

	%if &practice_count ne 1 %then %do;
	  %put ERROR: There are more than one practice ID associated to the file and may cause issues to the linking algorithm.  ;
	  %let err_fl=1;
	  %set_error_flag;
  	  %on_error(ACTION=ABORT);
	%end;

	/* Reset patient key to 0 so workflow can Retry Step 2 properly */
	%let ds_id=%sysfunc(open(el_mk_cnt));
	%let ds_mk_cnt=%sysfunc(attrn(&ds_id.,nobs));
	%let ds_rc=%sysfunc(close(&ds_id.));
	%put There are &ds_mk_cnt. observations in staging dataset with non-zero patient key. Reset patient key to 0;
	%if &ds_mk_cnt. %then %do;
		data &incoming.(compress=yes bufsize=128k);
			set &incoming.(drop=patient_key);
			format patient_key 16.;
			patient_key=0;
		run;
	%end;

	/* Set DOB to null if non-null DOB has year before 1753. SQL table datetime. field cannot accept values before 1753. */
	%let ds_id=%sysfunc(open(el_baddob_cnt));
	%let ds_baddob_cnt=%sysfunc(attrn(&ds_id.,nobs));
	%let ds_rc=%sysfunc(close(&ds_id.));
	%put There are &ds_baddob_cnt. observations in staging dataset with non-null DOB that is before 1753. Null out these DOB values. ;
	%if &ds_baddob_cnt. %then %do;
		data &incoming.(compress=yes bufsize=128k);
			set &incoming.;
			if dob ne . and year(dob) lt 1753 then dob=.;
		run;
	%end;

	%macro hash_lookup(m_dataset=,m_lookupset=,m_keyvar=,m_datavar=,m_updatevar=,m_dropvar=);
		%let dsn_id=%sysfunc(open(&m_lookupset.));
		%let dsn_nobs=%sysfunc(attrn(&dsn_id.,nobs));
		%let dsn_rc=%sysfunc(close(&dsn_id.));
		%if &dsn_nobs. gt 0 %then %do;
			data &m_dataset.(compress=yes bufsize=128k drop=&m_datavar. &m_dropvar. pl_rank);
				if _n_=0 then set &m_lookupset.;
				declare hash h_mk(dataset:"&m_lookupset.");
				h_mk.defineKey("&m_keyvar.");
				h_mk.defineData("&m_datavar.","pl_rank");
				h_mk.defineDone();
				call missing(&m_keyvar.,&m_datavar.,pl_rank);

				do while (not lstobs);
					&m_datavar.=.; pl_rank=.;
					set &m_dataset. end=lstobs;
					if h_mk.find()=0 then do;
						&m_updatevar.=&m_datavar.;
						pl_methodology_hierarchy=pl_rank;
					end;
					output &m_dataset.;
				end;
				stop;
			run;
		%end;
	%mend;
	%macro hash_crosswalk(m_inset=,m_outset=,m_lookupset=,m_keyvar=,m_datavar=,m_keepvar=);
		%let dsn_id=%sysfunc(open(&m_inset.));
		%let dsn1_nobs=%sysfunc(attrn(&dsn_id.,nobs));
		%let dsn_rc=%sysfunc(close(&dsn_id.));
		%let dsn_id=%sysfunc(open(&m_lookupset.));
		%let dsn2_nobs=%sysfunc(attrn(&dsn_id.,nobs));
		%let dsn_rc=%sysfunc(close(&dsn_id.));
		%if &dsn1_nobs. and &dsn2_nobs. %then %do;
			data &m_outset.(compress=yes bufsize=128k keep=&m_keepvar. &m_datavar. pl_rank);
				if _n_=0 then set &m_lookupset.(keep=&m_keyvar. patient_key rename=(patient_key=&m_datavar.));
				declare hash h(dataset:"&m_lookupset.(keep=&m_keyvar. patient_key pl_rank rename=(patient_key=&m_datavar.))");
				h.defineKey("&m_keyvar.");
				h.defineData("&m_datavar.","pl_rank");
				h.defineDone();
				call missing(&m_keyvar.,&m_datavar.,pl_rank);

				do while (not lstobs);
					&m_datavar.=.; pl_rank=.;
					set &m_inset.(keep=&m_keepvar. &m_keyvar.) end=lstobs;
					if h.find()=0 then output &m_outset.;
				end;
				stop;
			run;
		%end;
		%else %do;
			data &m_outset.;
				&m_keepvar.=.;
				&m_datavar.=.;
				pl_rank=.;
				if _n_=0;
			run;
		%end;
	%mend;

	*SASDOC--------------------------------------------------------------------------
	| Client-based scoring
	+------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
		select	max(pl_score_version_key)
		into	:pl_score_version_key separated by ','
		from	vh_empi.pl_score_version
		where	client_key=&client_id.;
	quit;
	%put NOTES: Linking scores for client &client_id. is based on SCORE VERSION &pl_score_version_key.;

	data mscore;
		set vh_empi.pl_score(rename=(score=label));
		where client_key=&client_id. and pl_score_version_key=&pl_score_version_key.;
		if cell=. and age=. then hlo='O';
		default=5; fmtname='$mscore';
		format start $5.;
		start=cats(cell)||cats(age);
		keep fmtname start label hlo default;
	run;
	proc format cntlin=mscore; run;

	/* if client has only payer data, client will not have mscore. later on we will skip probability linking 
		based on this indicator. */
	%let el_dsid=%sysfunc(open(mscore));
	%let el_has_mscore=%sysfunc(attrn(&el_dsid.,nobs));
	%let el_dsrc=%sysfunc(close(&el_dsid.));
	
	*SASDOC--------------------------------------------------------------------------
	| For each client onboarding if the dsID has multiple systems - older and new system
	| The patids might overlap and this should not happen. Investigation needs to occur
	| to identify these datasources and hard-code them to prevent system_member_id linking
	+------------------------------------------------------------------------SASDOC*;
	%let dsn&group_id._id=%sysfunc(open(&incoming.));
	%let dsn&group_id._sysmem_varind=%sysfunc(varnum(&&dsn&group_id._id,system_member_id));
	%let dsn&group_id._rc=%sysfunc(close(&&dsn&group_id._id));
	
	%if &&dsn&group_id._sysmem_varind ne 0 %then %do; 	
		   %if &client_ID = 2 and &practice_id =  51 and &system_ID = 11
			OR &client_ID = 2 and &practice_id =  95  and &system_ID = 96
			OR &client_ID = 2 and &practice_id =  142 and &system_ID = 10
			OR &client_ID = 2 and &practice_id =  187 and &system_ID = 3
			OR &client_ID = 2 and &practice_id =  208 and &system_ID = 4
			OR &client_ID = 2 and &practice_id =  229 and &system_ID = 21
			OR &client_ID = 2 and &practice_id =  236 and &system_ID = 96 
		%then %do;
			Data &incoming.;
			Set &incoming.;
			If NOT MISSING(System_member_id) then system_member_id=cats('OLDSYS[',strip(system_member_id),']');
			Run;
		%end;	
	%end;		
		
	*SASDOC--------------------------------------------------------------------------
	| Check if source system id exists, then create unique system_person_id that is a combination of 
	|	source_system_id and system_member_id
	+------------------------------------------------------------------------SASDOC*;
	%let dsn&group_id._id=%sysfunc(open(&incoming.));
	%let dsn&group_id._srcsys_varind=%sysfunc(varnum(&&dsn&group_id._id,source_system_id));
	%let dsn&group_id._rc=%sysfunc(close(&&dsn&group_id._id));

	%if &&dsn&group_id._srcsys_varind ne 0 %then %do;
		%let srcsys_has_value=0;
		proc sql noprint;
			select	count(*) 
			into	:srcsys_has_value
			from	&incoming.
			where	source_system_id ne '';
		quit;
		%put Row count with Source System ID values = &srcsys_has_value.;
		/* this should imply that there are values in system_member_id column */
		


		%if &srcsys_has_value. %then %do;
			data &incoming.(compress=yes bufsize=128k);
				set &incoming.;
				format system_person_id $50.;
				if source_system_id ne '' and system_member_id ne '' then system_person_id='SYS['||cats(source_system_id)||']ID['||cats(system_member_id)||']';
			run;
		%end;
	%end;

	%let dsn&group_id._id=%sysfunc(open(&incoming.));
	%let dsn&group_id._patid_varind=%sysfunc(varnum(&&dsn&group_id._id,system_member_id));
	%let dsn&group_id._syspersid_varind=%sysfunc(varnum(&&dsn&group_id._id,system_person_id));
	%let dsn&group_id._rc=%sysfunc(close(&&dsn&group_id._id));
	%if &&dsn&group_id._patid_varind and &&dsn&group_id._syspersid_varind=0 %then %do;
		proc datasets lib=&incoming_library. nolist;
			modify &incoming_dataset.;
				rename system_member_id=system_person_id;
		quit;
	%end;

	*SASDOC--------------------------------------------------------------------------
	| Grab person_key, or if new, add to VH_EMPI
	| Scrub new person_detail rows
	+------------------------------------------------------------------------SASDOC*;
	%let dsn&group_id._id=%sysfunc(open(&incoming.));
	%let dsn&group_id._perskey_varind=%sysfunc(varnum(&&dsn&group_id._id,person_key));
	%let dsn&group_id._rc=%sysfunc(close(&&dsn&group_id._id));
/*	%if &&dsn&group_id._perskey_varind=0 %then %do;*/
		%empi_get_system_key(&client_id.,&incoming.,practice_id,&wflow_exec_id.,'bpm - sas');
		%empi_get_detail_key(&client_id.,&incoming.,person,&wflow_exec_id.,'bpm - sas',m9_create_person_system_key=1,m9_return_key=1);
		%empi_get_person_key(&client_id.,&incoming.,&wflow_exec_id.,'bpm - sas',m5_return_patient_key=1);
/*	%end;*/

	%empi_scrub_person_detail(&client_id.,&wflow_exec_id.,m_inset=&incoming.);

	/* Exact match of all fields */
	data &incoming.(compress=yes bufsize=128k);
		set &incoming.;
		pl_methodology_hierarchy=0;
		if return_patient_key ne . then do;
			patient_key=return_patient_key;
			pl_methodology_hierarchy=50;
		end;
		drop return_patient_key;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Check to see if client has EMPI
	| Obtain maximum patient_key by Client ID & DataSource ID
	+------------------------------------------------------------------------SASDOC*;	
	%client_empi_check(&client_id.);
	%empi_all_patient_key(allmemberlist,m_client_id=&client_id.,m_datasource_id=&group_id.);

	proc sql noprint;
	  select 	input(substr(put(max(patient_key),z16.),9,8),8.) as VIDmax
	  into 		:VIDmax
	  from		allmemberlist;
    quit;

    %if &VIDmax=. %then %let VIDmax=0;
    %else %let VIDmax=&VIDmax;

    %put NOTE: VIDmax = &VIDmax.;

	*SASDOC--------------------------------------------------------------------------
	| Check for EMPI variable. If exist and has value, lookup EMPI xref table
	+------------------------------------------------------------------------SASDOC*;
	%let dsn&group_id._id=%sysfunc(open(&incoming.));
	%let dsn&group_id._empi_varind=%sysfunc(varnum(&&dsn&group_id._id,enterprise_member_id));
	%let dsn&group_id._rc=%sysfunc(close(&&dsn&group_id._id));

	%let EMPInew=0;
	%if &&dsn&group_id._empi_varind ne 0 and &client_with_empi_indicator. %then %do; /* Start - EMPI variable exist, and client has EMPI */
		%let empi_has_value=0;
		proc sql noprint;
			select	count(*) 
			into	:empi_has_value
			from	&incoming.
			where	enterprise_member_id ne '';
		quit;
		%put Row count with EMPI values = &empi_has_value.;

		%if &empi_has_value. gt 0 %then %do;
			proc sql;
				connect to oledb(init_string=&sqlci.);
				create table client_patient_map(drop=person_patient_map_key rename=(pl_methodology_hierarchy=pl_rank)) as
				select	system_person_id as enterprise_member_id, patient_key as VID, person_patient_map_key, 100 as pl_methodology_hierarchy
				from	connection to oledb
						(	select	ps.system_person_id, ppm.patient_key, ppm.person_patient_map_key
							from	vh_empi.dbo.person_system(nolock) ps inner join
									vh_empi.dbo.person(nolock) p on ps.client_key=p.client_key and ps.person_system_key=p.person_system_key inner join
									vh_empi.dbo.person_patient_map(nolock) ppm on p.client_key=ppm.client_key and p.person_key=ppm.person_key and ppm.delete_flag=0
							where	ps.client_key=&client_id. and ps.datasourceid=&empi_datasource_id.
						)
				group by system_person_id
				having	person_patient_map_key=min(person_patient_map_key);
			quit;

			%hash_lookup(m_dataset=&incoming.,m_lookupset=client_patient_map,m_keyvar=enterprise_member_id,m_datavar=VID,m_updatevar=patient_key); 
		
			*SASDOC--------------------------------------------------------------------------
			| If EMPI has value, but not in EMPI xref table, then create new member key
			|	using the datasource id. We will reconcile the member keys later when
			|	the EMPI comes in from the EMPI file.
			| With EMPI, only create new member key if source=P. All other sources, push it to 
			|	next step to see if we can find a match with existing population base. 
			|	Hospital and Lab are not suppose to create orphan patients (patient with 
			|	no physician claims).
			+------------------------------------------------------------------------SASDOC*;
			%if %upcase(&source.)=P %then %do;
				proc sql;
					create table empi_yes_mk_new as
					select	distinct enterprise_member_id
					from	&incoming.(keep=enterprise_member_id patient_key)
					where 	enterprise_member_id ne '' 
					and 	patient_key in (.,0);
				quit;

				proc sql noprint;
					select	count(*)
					into	:EMPInew
					from	empi_yes_mk_new;
				quit;
				%put NOTE: EMPInew = &EMPInew.;

				%if &EMPInew. ne 0 %then %do;
					data empi_yes_mk_new(rename=(pl_methodology_hierarchy=pl_rank) index=(enterprise_member_id));
						set empi_yes_mk_new;
						VID=("&client_id." || put(&group_id.,z6.) || put(&VIDmax. + _n_,z8.))*1;
						pl_methodology_hierarchy=150;
					run;
					%hash_lookup(m_dataset=&incoming.,m_lookupset=empi_yes_mk_new,m_keyvar=enterprise_member_id,m_datavar=VID,m_updatevar=patient_key);
				%end;
			%end;
		%end;
	%end; /* End - EMPI variable exist, and client has EMPI */

	*SASDOC--------------------------------------------------------------------------
	| Match by system person id if datasource has unique patient id
	| Check if system_person_id is mapped to a patient
	+------------------------------------------------------------------------SASDOC*;
	%let dsn&group_id._id=%sysfunc(open(&incoming.));
	%let dsn&group_id._syspersid_varind=%sysfunc(varnum(&&dsn&group_id._id,system_person_id));
	%let dsn&group_id._rc=%sysfunc(close(&&dsn&group_id._id));

	%if &&dsn&group_id._syspersid_varind %then %do; /* Start - system_person_id match */
		%let syspersid_nomk=1;
		%if &client_with_empi_indicator. %then %do; 
			/* if client has empi, let's see if we still have records left to be mapped by syspersid */
			/* if not, then we must have syspersid to match */
			%let syspersid_nomk=0;
			proc sql noprint;
				select	count(*)
				into	:syspersid_nomk
				from	&incoming.
				where 	system_person_id ne '' 
				and 	patient_key in (.,0);
			quit;
		%end;

		%if &client_with_empi_indicator.=0 or &syspersid_nomk. %then %do;
			%let datasource_grouping_list=;
			proc sql noprint;
				connect to oledb(init_string=&sqlci.);
				select	dsid.datasourceid
				into	:datasource_grouping_list separated by ','
				from	vh_empi.pl_datasource_group grp inner join
						vh_empi.pl_datasource_group dsid on grp.datasourceid=&practice_id. and grp.datasourceid_group=dsid.datasourceid_group;
			quit;

			proc sql;
				connect to oledb(init_string=&sqlci.);
				create table el_sysperid_mapping(drop=person_patient_map_key rename=(pl_methodology_hierarchy=pl_rank)) as
				select	system_person_id, patient_key as VID, person_patient_map_key, 175 as pl_methodology_hierarchy
				from	connection to oledb
						(	select	a.system_person_id, c.patient_key, c.person_patient_map_key
							from	vh_empi.dbo.person_system(nolock) a inner join
									vh_empi.dbo.person(nolock) b on a.client_key=b.client_key and a.person_system_key=b.person_system_key inner join
									vh_empi.dbo.person_patient_map(nolock) c on b.client_key=c.client_key and b.person_key=c.person_key and c.delete_flag=0
							where	a.client_key=&client_id. 
						  %if %str(&datasource_grouping_list.)= %then %do;
							and 	a.datasourceid=&practice_id.
						  %end;
						  %else %do;
							and		a.datasourceid in (&datasource_grouping_list.)
						  %end;
						)
				group by 1
				having	person_patient_map_key=min(person_patient_map_key);
			quit;
			%hash_lookup(m_dataset=&incoming.,m_lookupset=el_sysperid_mapping,m_keyvar=system_person_id,m_datavar=VID,m_updatevar=patient_key);
		%end;
	%end; /* End - system_person_id match */

	%if &&dsn&group_id._syspersid_varind %then %let el_syspersid_var=system_person_id;
	%else %let el_syspersid_var=;


	*SASDOC--------------------------------------------------------------------------
	| Output valid SSN claims to PM_Perm
	+------------------------------------------------------------------------SASDOC*;
	%let linking_required_var=patient_key &el_syspersid_var. ssn lname mname fname dob sex address1 address2 city state zip phone
							  scrubbed:
							  source claim_key svcdt; 
	data PM_perm(keep=claim_key ssn fname dob scrubbed_ssn scrubbed_fname scrubbed_dob)
		 PM_perm_ssnlist(keep=ssn);
	  length fname mname $15. lname $25. city $25. ssn $9. address1-address2 $50. phone $10. zip $5. state $2. sex $1.;
	  format ssn lname mname fname dob sex address1 address2 city state zip phone;
	  set &incoming.(keep=&linking_required_var.);
	  where ssn ne '' and patient_key in (.,0);
	  if ssn ne '' then output PM_perm_ssnlist;
	  %ssntest;
	  if ssnTYPE = "VALID" then output PM_perm;
	proc sort data=PM_perm; by ssn fname dob;
	proc sort data=PM_perm_ssnlist nodup; by ssn;
	run;

	%let dsn_id=%sysfunc(open(PM_perm));
	%let dsn_pmperm_nobs=%sysfunc(attrn(&dsn_id.,nobs));
	%let dsn_rc=%sysfunc(close(&dsn_id.));

	%let SSNnew=0;
	%If &dsn_pmperm_nobs.=0 %Then %do;
		/* If historical=0 (1st pass), and there are no valid SSN, we would never automatically cycle through 2nd pass because
			no claims will ever be loaded from 1st pass, and 2nd pass will still look like first pass (historical still set to 0). 
			So, we will attempt to figure out it is no longer 1st pass (by looking for vmine_kprocessid > 1, and if so, reset 
			historical variable to 2 to load invalid SSN. This will not work if the data source with no SSN is the first data source
			id in onboarding process, since beginning of 2nd pass, all vmine_kprocessid is still =1. If this is the case, we'll
			have to manually onboard this data source the 3rd time. */
		%if &historical.=0 %then %do;
			proc sql noprint;
				connect to oledb(init_string=&sqlci.);
				select	indicator
				into	:onboard_firstpass_ind
				from	connection to oledb
						(	select 	case when max(vmine_kprocessid) > 1 then 0 else 1 end as indicator
							from 	ciedw.dbo.encounter_detail(nolock)
							where	client_key=&client_id.
						);
			quit;

			%if &onboard_firstpass_ind.=0 %then %do;
				%let historical=2;
				proc sql;
					update &incoming.
					set historical=2;
				quit;
			%end;
		%end;
	%End;
	%Else %If &dsn_pmperm_nobs. %Then %Do; /* has valid SSN records */
		*SASDOC--------------------------------------------------------------------------
		| Attempt to find SSN associated with multiple family members. There will be
		| 	some false positives and false negatives, since the algorithm is not
		|	rigorous. We will rely on xref and error tables to fix the rest. But by
		|	doing this up front, we eliminate a good chunk of errors.
		| Create cartesian product of all possible combination of ssn, fname and dob
		|	for matching purpose. If no match, go to normal process of member key with
		|	largest counter.
		+------------------------------------------------------------------------SASDOC*;
		%bulkload_to_cio(&wflow_exec_id.,PM_perm_ssnlist);

		/* If client has EMPI, we'll attempt to match by group_key first, then we'll attempt to match to EMPI records second., then to all others */
		proc sql;
			connect to oledb(init_string=&sqlci.);
			create table t_sasPL_sfd as
			select	datasourceid, patient_key, 
					ssn, scrubbed_ssn, fname, scrubbed_fname, 
					input(dob,yymmdd10.) format mmddyy10. as dob, input(scrubbed_dob,yymmdd10.) format mmddyy10. as scrubbed_dob,
					counter_ssn
			from	connection to oledb
					(	select	pwd.datasourceid, ppm.patient_key,
								pd.ssn, pd.scrubbed_ssn, pd.fname, pd.scrubbed_fname, pd.dob, pd.scrubbed_dob,
								sum(pwd.counter*pwd.weight_counter*coalesce(pdw.weight_ssn,1)) as counter_ssn
						from	vh_empi.dbo.person_workflow_detail(nolock) pwd inner join
								vh_empi.dbo.person_patient_map(nolock) ppm on pwd.client_key=ppm.client_key and pwd.person_key=ppm.person_key inner join 
								vh_empi.dbo.person(nolock) p on ppm.client_key=p.client_key and ppm.person_key=p.person_key and ppm.delete_flag=0 inner join
								vh_empi.dbo.person_detail(nolock) pd on p.client_key=pd.client_key and p.person_detail_key=pd.person_detail_key inner join
								cihold.dbo.saswrk_bulkload_&wflow_exec_id. z on pd.ssn=z.ssn left join
								vh_empi.dbo.person_detail_weight(nolock) pdw on pd.client_key=pdw.client_key and pd.person_detail_key=pdw.person_detail_key
						where	pwd.client_key=&client_id.
						and		pd.ssn is not null and pd.fname is not null and pd.dob is not null
						group by pwd.datasourceid, ppm.patient_key,
								pd.ssn, pd.scrubbed_ssn, pd.fname, pd.scrubbed_fname, pd.dob, pd.scrubbed_dob
					);
		quit;

		data t2_sasPL_sfd1_nonscrubbed(keep=ssn fname dob patient_key)
			 t2_sasPL_sfd2(keep=scrubbed_ssn scrubbed_fname scrubbed_dob patient_key)
			 t2_sasPL_sfd3(keep=scrubbed_ssn scrubbed_fname scrubbed_dob patient_key);
			set t_sasPL_sfd;
			if datasourceid=&group_id. and ssn ne '' then output t2_sasPL_sfd1_nonscrubbed;
		  %if &client_with_empi_indicator. %then %do;
			else if datasourceid=&empi_datasource_id. and scrubbed_ssn ne '' then output t2_sasPL_sfd2;
		  %end;
			else if datasourceid not in (&group_id.,&empi_datasource_id.) and scrubbed_ssn ne '' then output t2_sasPL_sfd3;
		run;

		proc sql;
			create table sasPL_sfd1_nonscrubbed(rename=(patient_key=VID1)) as
			select	distinct *
			from	t2_sasPL_sfd1_nonscrubbed
			group by ssn, fname, dob
			having	count(distinct patient_key)=1
			order by ssn, fname, dob;
			drop table t2_sasPL_sfd1_nonscrubbed;

			create table sasPL_sfd2(rename=(patient_key=VID2)) as
			select	distinct *
			from	t2_sasPL_sfd2
			where	scrubbed_ssn is not null
			and		scrubbed_fname is not null
			and		scrubbed_dob is not null
			group by scrubbed_ssn, scrubbed_fname, scrubbed_dob
			having	count(distinct patient_key)=1
			order by scrubbed_ssn, scrubbed_fname, scrubbed_dob;
			drop table t2_sasPL_sfd2;

			create table sasPL_sfd3(rename=(patient_key=VID3)) as
			select	distinct *
			from	t2_sasPL_sfd3
			where	scrubbed_ssn is not null
			and		scrubbed_fname is not null
			and		scrubbed_dob is not null
			group by scrubbed_ssn, scrubbed_fname, scrubbed_dob
			having	count(distinct patient_key)=1
			order by scrubbed_ssn, scrubbed_fname, scrubbed_dob;
			drop table t2_sasPL_sfd3;

			drop table cihold.saswrk_bulkload_&wflow_exec_id.;
		quit;

		data PM_perm2(drop=VID VID1 VID2 VID3) PM_strictSSNmatch(keep=claim_key VID pl_methodology_hierarchy 
																rename=(pl_methodology_hierarchy=pl_rank));
			if _n_=0 then do;
				set sasPL_sfd1_nonscrubbed;
				set sasPL_sfd2;
				set sasPL_sfd3;
			end;
			declare hash h1(dataset:'sasPL_sfd1_nonscrubbed');
			h1.defineKey('ssn','fname','dob');
			h1.defineData('VID1');
			h1.defineDone();
			declare hash h2(dataset:'sasPL_sfd2');
			h2.defineKey('scrubbed_ssn','scrubbed_fname','scrubbed_dob');
			h2.defineData('VID2');
			h2.defineDone();
			declare hash h3(dataset:'sasPL_sfd3');
			h3.defineKey('scrubbed_ssn','scrubbed_fname','scrubbed_dob');
			h3.defineData('VID3');
			h3.defineDone();
			call missing(ssn,fname,dob,scrubbed_ssn,scrubbed_fname,scrubbed_dob,VID1,VID2,VID3);

			do while (not lstobs);
				VID1=.; VID2=.; VID3=.;
				set PM_perm end=lstobs;
					 if h1.find()=0 then do; VID=VID1; pl_methodology_hierarchy=200; output PM_strictSSNmatch; end;
				else if h2.find()=0 then do; VID=VID2; pl_methodology_hierarchy=220; output PM_strictSSNmatch; end;
				else if h3.find()=0 then do; VID=VID3; pl_methodology_hierarchy=240; output PM_strictSSNmatch; end;
				else output PM_perm2;
			end;
			stop;
		run;

		%hash_lookup(m_dataset=&incoming.,m_lookupset=PM_strictSSNmatch,m_keyvar=claim_key,m_datavar=VID,m_updatevar=patient_key);

		*SASDOC--------------------------------------------------------------------------
		| Download MLA_MEMBER_SSN and test for validity before linking
		+------------------------------------------------------------------------SASDOC*;
		proc sql;
			create view v_sasPL_ssn as
			select	scrubbed_ssn, patient_key, sum(counter_ssn) as counter
			from	t_sasPL_sfd
			where	scrubbed_ssn ne ''
			group by 1,2
			order by 1,counter;
		quit;
		data sasPL_ssn(keep=scrubbed_ssn patient_key rename=(patient_key=VID));
			set v_sasPL_ssn;
			by scrubbed_ssn counter;
			if last.scrubbed_ssn;
		run;

		*SASDOC--------------------------------------------------------------------------
		| Identify previously existing SSN values and find most frequent patient_key
		| Identify new SSN values
		+------------------------------------------------------------------------SASDOC*;
		proc sql;
			create table SSN_Unique as
			select 	distinct scrubbed_ssn
			from 	PM_perm2
			order by scrubbed_ssn;
		quit;
			
			
		data MEMBER_Exist2(keep=scrubbed_ssn VID pl_rank) MEMBER_New1(keep=scrubbed_ssn pl_rank);
			format VID 16.;
			merge SSN_Unique(in=a) sasPL_ssn(in=b);
			by scrubbed_ssn;
			if a and b then do;
				pl_methodology_hierarchy=300;/* 300	DESC - MATCH SSN HIGHEST COUNT */
				output MEMBER_Exist2;
			end;
			else if a then do;
				pl_methodology_hierarchy=350;/* 350	DESC - NEWMK SSN */
				output Member_New1;
			end;
			rename pl_methodology_hierarchy=pl_rank;
		run;

		*SASDOC--------------------------------------------------------------------------
		| Create new patient_key for new SSN members, only for source=P
		+------------------------------------------------------------------------SASDOC*;
	    %put NOTE:  VIDmax = &VIDmax.;
	    %put NOTE:  EMPInew = &EMPInew.;

		%if %upcase(&source.)=P %then %do;
			data MEMBER_New2(keep=scrubbed_ssn VID pl_rank);
				retain VID_;
				format VID 16.;
				set MEMBER_New1;
				by scrubbed_ssn;
				VID_ = &VIDmax. + &EMPInew. + _n_;
				VID = ("&client_id." || put(&group_id.,z6.) || put(VID_,z8.))*1;  	
			run;

			proc sql noprint;
				select count(*) into :SSNnew
				from MEMBER_New2;
			quit;
		%end;
		%else %do;
			%let SSNnew=0;
		%end;

		%put NOTE: SSNnew = &SSNnew.;

		*SASDOC--------------------------------------------------------------------------
		| Update patient_key to incoming dataset
		+------------------------------------------------------------------------SASDOC*;
		data MEMBER_Update;
			set %if %sysfunc(exist(MEMBER_New2)) %then %do; MEMBER_New2 %end; MEMBER_Exist2;
		run;

		%hash_lookup(m_dataset=&incoming.,m_lookupset=MEMBER_Update,m_keyvar=scrubbed_ssn,m_datavar=VID,m_updatevar=patient_key);

	%End; /* has valid SSN records */

	*SASDOC--------------------------------------------------------------------------
	| Establish unique set of member field combinations by RID 
	+------------------------------------------------------------------------SASDOC*; 

  %IF &historical. gt 0 %THEN %DO; /* historical indicator <> 0 */

	*SASDOC--------------------------------------------------------------------------
	| Output invalid SSN claims to PM_clm
  	| Or Non-physician claims that have not been linked yet
	| Replace all variables with scrubbed version.
	+------------------------------------------------------------------------SASDOC*;
	data PM_clm(compress=yes bufsize=128k index=(tablekey=(&el_syspersid_var. lname fname dob address1 phone city zip state sex)));
		length fname mname $15. lname $25. city $25. address1-address2 $50. phone $10. zip $5. state $2. sex $1.;
		format lname mname fname dob sex address1 address2 city state zip phone;
		set &incoming.(keep=&linking_required_var.);
		where patient_key in (.,0);
		fname=scrubbed_fname; mname=scrubbed_mname; lname=scrubbed_lname; sex=scrubbed_sex; dob=scrubbed_dob;
		address1=scrubbed_address1; address2=scrubbed_address2; city=scrubbed_city; state=scrubbed_state; zip=scrubbed_zip; phone=scrubbed_phone;
		drop scrubbed: ssn;
	run;

	%let dsn_id=%sysfunc(open(PM_clm));
	%let dsn_pmclm_nobs=%sysfunc(attrn(&dsn_id.,nobs));
	%let dsn_rc=%sysfunc(close(&dsn_id.));

	%put NOTE: ClmNum = &dsn_pmclm_nobs.;

	%If &dsn_pmclm_nobs. ge 1 %Then %Do; /* has invalid SSN records */

		*SASDOC--------------------------------------------------------------------------
		| Download scrubbed data for linking
		+------------------------------------------------------------------------SASDOC*;
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			create table linking_scrubbed_data as
			select	patient_key, datasourceid, 
					scrubbed_fname, scrubbed_lname, 
					scrubbed_sex, input(scrubbed_dob,yymmdd10.) format mmddyy10. as scrubbed_dob, 
					scrubbed_address1, scrubbed_city, scrubbed_state, scrubbed_zip, 
					scrubbed_phone, 
					counter_fname, counter_mname, counter_lname, counter_sex, counter_dob,
					counter_address1, /*counter_address2, counter_address3,*/ counter_city, counter_state, counter_zip, counter_phone
			from	connection to oledb
				(	select	patient_key, a.datasourceid, 
							scrubbed_fname, scrubbed_lname, 
							scrubbed_sex, scrubbed_dob, 
							scrubbed_address1, scrubbed_city, scrubbed_state, scrubbed_zip, 
							scrubbed_phone, 
							sum(a.counter*a.weight_counter*coalesce(weight_fname,1)) as counter_fname,
							sum(a.counter*a.weight_counter*coalesce(weight_mname,1)) as counter_mname,
							sum(a.counter*a.weight_counter*coalesce(weight_lname,1)) as counter_lname,
							sum(a.counter*a.weight_counter*coalesce(weight_sex,1)) as counter_sex,
							sum(a.counter*a.weight_counter*coalesce(weight_dob,1)) as counter_dob,
							sum(a.counter*a.weight_counter*coalesce(weight_address1,1)) as counter_address1,
/*							sum(a.counter*a.weight_counter*coalesce(weight_address2,1)) as counter_address2,*/
/*							sum(a.counter*a.weight_counter*coalesce(weight_address3,1)) as counter_address3,*/
							sum(a.counter*a.weight_counter*coalesce(weight_city,1)) as counter_city,
							sum(a.counter*a.weight_counter*coalesce(weight_state,1)) as counter_state,
							sum(a.counter*a.weight_counter*coalesce(weight_zip,1)) as counter_zip,
							sum(a.counter*a.weight_counter*coalesce(weight_phone,1)) as counter_phone
					from	vh_empi.dbo.person_workflow_detail(nolock) a inner join
							vh_empi.dbo.person(nolock) b on a.client_key=b.client_key and a.person_key=b.person_key inner join
							vh_empi.dbo.person_detail(nolock) c on b.client_key=c.client_key and b.person_detail_key=c.person_detail_key inner join
							vh_empi.dbo.person_patient_map(nolock) d on b.client_key=d.client_key and b.person_key=d.person_key and d.delete_flag=0 inner join
							(	select	min(person_patient_map_key) [myojo]
								from	vh_empi.dbo.person_patient_map(nolock)
								where	client_key=&client_id.
								and		delete_flag=0
								group by person_key
							) d0 on d.person_patient_map_key=d0.myojo left join
							vh_empi.dbo.person_detail_weight(nolock) z on c.client_key=z.client_key and c.person_detail_key=z.person_detail_key
					where	a.client_key=&client_id.
					group by patient_key, a.datasourceid, 
							scrubbed_fname, scrubbed_lname, 
							scrubbed_sex, scrubbed_dob, 
							scrubbed_address1, scrubbed_city, scrubbed_state, scrubbed_zip, 
							scrubbed_phone						
				)
		/* temporary fix for northshore */
		%if &client_id.=13 %then %do;
			where	put(patient_key,z16.) not in ('1300128800477330','1300124400006228','1300125200037727','1300128800478138','1300123600002080',
												  '1300128800058042','1300128800217332','1300124400026912','1300128800059656','1300125200059684','1300128800328757','1300128800329458')
		%end;
			;
		quit;

		%macro el_pl_setup(m_var,m_composite_index_var=datasourceid patient_key);
			proc sql;
				create table sasPL_&m_var.(index=(tablekey=(&m_composite_index_var.))) as 
				select	datasourceid, scrubbed_&m_var. as &m_var., patient_key, 
						sum(counter_&m_var.) as counter
				from	linking_scrubbed_data
				group by 1,2,3;
			quit;
		%mend;
		%el_pl_setup(fname);
		%el_pl_setup(lname);
		%el_pl_setup(sex);
		%el_pl_setup(dob,m_composite_index_var=datasourceid dob);
		%el_pl_setup(address1);
		%el_pl_setup(city);
		%el_pl_setup(state);
		%el_pl_setup(zip);
		%el_pl_setup(phone);


		*SASDOC--------------------------------------------------------------------------
		| Identify unique RID for linking
		+------------------------------------------------------------------------SASDOC*;
		/* Append all linking to all_mk_update dataset, initialize dataset */

		%if %sysfunc(exist(all_mk_update)) %then %do;
			proc sql;
				drop table all_mk_update;
			quit;
		%end;

		data PM_clm2(compress=yes index=(RID)) PM_roster1(keep=RID RID_ &el_syspersid_var. dob lname fname sex phone address1 city zip state ageR);
			length RID $20.;
			retain RID_;
			set PM_clm;
			if _n_ = 1 then RID_ = 0;
			by &el_syspersid_var. lname fname dob address1 phone city zip state sex;
		  %if &el_syspersid_var. ne %then %do;
			x0 = lag(&el_syspersid_var.);
		  %end;
			x1 = lag(lname);
			x2 = lag(fname);
			x3 = lag(dob);
			x4 = lag(address1);
			x5 = lag(phone);
			x6 = lag(city);
			x7 = lag(zip);
			x8 = lag(state);
			x9 = lag(sex);

			if	%if &el_syspersid_var. ne %then %do;
					&el_syspersid_var.=x0 and
				%end;
			lname=x1 and fname=x2 and dob=x3 and address1=x4 and phone=x5 and city=x6 and zip=x7 and state=x8 and sex=x9 			
			then RID_ = RID_;
			else RID_ = RID_ + 1;

			RID = put(RID_,20.);
			ageR = int((svcdt - dob) / 365.25);
			drop x1-x9;
			output PM_clm2;
			output PM_roster1;
		run;

		proc sort data=PM_Roster1 out=PM_Roster2(index=(DOB)) nodupkey;
		  by RID;
		run;

  		*SASDOC--------------------------------------------------------------------------
		| Logic to link patient_key to identical member information for matched group_key
		+------------------------------------------------------------------------SASDOC*; 
		%edw_linking_exact_match(PM_Roster2,	practiceMatch1,DOB,		match_by_datasource=&group_id.,match_start=1);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,FName,	match_by_datasource=&group_id.);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,LName, 	match_by_datasource=&group_id.);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,Address1,match_by_datasource=&group_id.);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,City,	match_by_datasource=&group_id.);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,State,	match_by_datasource=&group_id.);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,Zip,		match_by_datasource=&group_id.);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,Phone,	match_by_datasource=&group_id.);
		%edw_linking_exact_match(practiceMatch1,practiceMatch1,Sex,		match_by_datasource=&group_id.,match_end=1,assign_pl_rank=400);

		%hash_crosswalk(m_inset=PM_clm2,m_outset=practiceMatch2,m_lookupset=practiceMatch1,m_keyvar=RID,m_datavar=VID,m_keepvar=claim_key);

		proc append base=all_mk_update data=practiceMatch2 force; run;

		%let grpmtch = ;

		proc sql noprint;
		  select count(*) into:grpmtch
		  from practiceMatch1;
		quit;

		%put NOTE: grpmtch = &grpmtch.;

		%if &grpmtch. ge 1 %then %let practiceMatch1 = practiceMatch1 (in=b keep = RID patient_key where = (patient_key not in (.,0)));
		%else %let practiceMatch1 = ;

		data PM_Roster3_t(index=(DOB));
		  merge PM_Roster2 &practiceMatch1.;
		  by RID;
		  %if &grpmtch. ge 1 %then %do; 
			if not b;
			drop patient_key;
		  %end;
		run;

  		*SASDOC--------------------------------------------------------------------------
		| Logic to link patient_key to identical member information to non-null EMPI data
		+------------------------------------------------------------------------SASDOC*; 
		%let dsn_id=%sysfunc(open(PM_Roster3_t));
		%let dsn_pmroster3t_nobs=%sysfunc(attrn(&dsn_id.,nobs));
		%let dsn_rc=%sysfunc(close(&dsn_id.));

		%if &client_with_empi_indicator. and &dsn_pmroster3t_nobs. %then %do;
			%edw_linking_exact_match(PM_Roster3_t,empiMatch1,DOB,		match_by_datasource=&empi_datasource_id.,match_nonnull_only=1,match_start=1);
			%edw_linking_exact_match(empiMatch1,empiMatch1,FName,		match_by_datasource=&empi_datasource_id.,match_nonnull_only=1);
			%edw_linking_exact_match(empiMatch1,empiMatch1,LName, 		match_by_datasource=&empi_datasource_id.,match_nonnull_only=1);
			%edw_linking_exact_match(empiMatch1,empiMatch1,Address1,	match_by_datasource=&empi_datasource_id.,match_nonnull_only=1);
			%edw_linking_exact_match(empiMatch1,empiMatch1,City,		match_by_datasource=&empi_datasource_id.,match_nonnull_only=1);
			%edw_linking_exact_match(empiMatch1,empiMatch1,State,		match_by_datasource=&empi_datasource_id.,match_nonnull_only=1);
			%edw_linking_exact_match(empiMatch1,empiMatch1,Zip,			match_by_datasource=&empi_datasource_id.,match_nonnull_only=1);

			/* split exact match to 2 separate tracks:
				1a. incoming with null scrubbed phone, bypass matching with phone
				1b. incoming with non-null scrubbed phone, match with satellite phone
			*/
			data empiMatch1a empiMatch1b;
				set empiMatch1;
				if phone='' then output empiMatch1a;
				else output empiMatch1b;
			run;

			/* 1a */
			%edw_linking_exact_match(empiMatch1a,empiMatch1a,Sex,		match_nonnull_only=1,match_end=1,assign_pl_rank=425);

			/* 1b */
			%edw_linking_exact_match(empiMatch1b,empiMatch1b,Phone,		match_nonnull_only=1);
			%edw_linking_exact_match(empiMatch1b,empiMatch1b,Sex,		match_nonnull_only=1,match_end=1,assign_pl_rank=450);
			data empiMatch1;
				set empiMatch1a empiMatch1b;
			run;
			proc sort data=empiMatch1; by RID; run;

			%hash_crosswalk(m_inset=PM_clm2,m_outset=empiMatch2,m_lookupset=empiMatch1,m_keyvar=RID,m_datavar=VID,m_keepvar=claim_key);

			proc append base=all_mk_update data=empiMatch2 force; run;

			%let empimtch = ;

			proc sql noprint;
			  select count(*) into :empimtch
			  from empiMatch1;
			quit;

			%put NOTE: empimtch = &empimtch.;

			%if &empimtch. ge 1 %then %let empiMatch1 = empiMatch1 (in=b keep = RID patient_key where = (patient_key not in (.,0)));
			%else %let empiMatch1 = ;

			data PM_Roster3(index=(DOB));
			  merge PM_Roster3_t &empiMatch1.;
			  by RID;
			  %if &empimtch. ge 1 %then %do; 
				if not b;
				drop patient_key;
			  %end;
			run;
		%end;
		%else %do;
			%if %sysfunc(exist(PM_Roster3)) %then %do;
				proc sql; drop table PM_Roster3; quit;
			%end;
			proc datasets lib=work nolist;
				change PM_Roster3_t=PM_Roster3;
			quit;
		%end;


		*SASDOC--------------------------------------------------------------------------
		| Logic to link patient_key to identical member information for ALL non-NULL fields
		+------------------------------------------------------------------------SASDOC*; 
		%let dsn_id=%sysfunc(open(PM_Roster3));
		%let dsn_pmroster3_nobs=%sysfunc(attrn(&dsn_id.,nobs));
		%let dsn_rc=%sysfunc(close(&dsn_id.));

		%if &dsn_pmroster3_nobs. %then %do;
			%edw_linking_exact_match(PM_Roster3,AllMatch1,DOB,		match_nonnull_only=1,match_start=1);
			%edw_linking_exact_match(AllMatch1,AllMatch1,FName,		match_nonnull_only=1);
			%edw_linking_exact_match(AllMatch1,AllMatch1,LName, 	match_nonnull_only=1);
			%edw_linking_exact_match(AllMatch1,AllMatch1,Address1,	match_nonnull_only=1);
			%edw_linking_exact_match(AllMatch1,AllMatch1,City,		match_nonnull_only=1);
			%edw_linking_exact_match(AllMatch1,AllMatch1,State,		match_nonnull_only=1);
			%edw_linking_exact_match(AllMatch1,AllMatch1,Zip,		match_nonnull_only=1);

			/* split exact match to 2 separate tracks:
				1a. incoming with null scrubbed phone, bypass matching with phone
				1b. incoming with non-null scrubbed phone, match with satellite phone
			*/
			data AllMatch1a AllMatch1b;
				set AllMatch1;
				if phone='' then output AllMatch1a;
				else output AllMatch1b;
			run;

			/* 1a */
			%edw_linking_exact_match(AllMatch1a,AllMatch1a,Sex,		match_nonnull_only=1,match_end=1,assign_pl_rank=475);

			/* 1b */
			%edw_linking_exact_match(AllMatch1b,AllMatch1b,Phone,	match_nonnull_only=1);
			%edw_linking_exact_match(AllMatch1b,AllMatch1b,Sex,		match_nonnull_only=1,match_end=1,assign_pl_rank=500);
			data AllMatch1;
				set AllMatch1a AllMatch1b;
			run;
			proc sort data=AllMatch1; by RID; run;

			%hash_crosswalk(m_inset=PM_clm2,m_outset=AllMatch2,m_lookupset=AllMatch1,m_keyvar=RID,m_datavar=VID,m_keepvar=claim_key);

			proc append base=all_mk_update data=AllMatch2 force; run;

			%let allmtch = ;

			proc sql noprint;
			  select count(*) into:allmtch
			  from AllMatch1;
			quit;

			%put NOTE: allmtch = &allmtch.;

			%if &allmtch. ge 1 %then %let AllMatch1 = AllMatch1 (in=b keep = RID patient_key where = (patient_key not in (.,0)));
			%else %let AllMatch1 = ;

			data PM_Roster4(index=(DOB phone LName));
			  merge PM_Roster3 &AllMatch1.;
			  by RID;
			  %if &allmtch. ge 1 %then %do; 
				if not b;
				drop patient_key;
			  %end;
			run;
		%end;
		%else %do;
			%if %sysfunc(exist(PM_Roster4)) %then %do;
				proc sql; drop table PM_Roster4; quit;
			%end;
			proc datasets lib=work nolist;
				change PM_Roster3=PM_Roster4;
			quit;
			proc datasets lib=work nolist;
				modify PM_Roster4;
					index create phone;
					index create LName;
			quit;
		%end;


		*SASDOC--------------------------------------------------------------------------
		| Calculate posterior probabilities for scoring weights
		+------------------------------------------------------------------------SASDOC*;
		proc sql noprint;
			select	count(*), max(rid_)
			into	:linknum, :max_ridnum
			from	pm_roster4;
		quit;
		%let linknum=&linknum.;
		%let max_ridnum=&max_ridnum.;

		%put NOTE: linknum = &linknum.;
		%put NOTE: max_ridnum = &max_ridnum.;

		%if &linknum. ge 1 %then %do; /* start - linknum ge 1 */
			%if &dataformatgroupid.=20 and &el_has_mscore.=0 %then %do; 
				/* If payer has no mscore, it will skip probability linking. This should only happen when client has payer
					data only and no CI data. Payer will always have system_person_id, and member key will be created for
					each id. */
				data MatchMaker3; if _n_=0; run;
				data UnderThreshold_NewMK;
					set PM_Roster4(obs=0);
					pl_rank =.;
				run;
			%end;
			%else %do;
				%edw_linking_probability_hash;
			%end;

			*SASDOC--------------------------------------------------------------------------
			| Assign new patient_key to Unmatched dataset members, for source=P
			+------------------------------------------------------------------------SASDOC*;
			%if %upcase(&source.)=P %then %do; /* create new member key only for source=P */
				%let dsn_id=%sysfunc(open(MatchMaker3));
				%let dsn_obs=%sysfunc(attrn(&dsn_id.,nobs));
				%let dsn_rc=%sysfunc(close(&dsn_id.));

				%if &dsn_obs. %then %do;
					proc format cntlin=mm3fmt; run;
				%end;

				proc sql;
					create table Unmatched as
					select	distinct RID, %if &el_syspersid_var. ne %then %do; &el_syspersid_var., %end;
							fname, lname, sex, dob, soundex(fname) as fsound1, soundex(lname) as lsound1, pl_rank
					from	UnderThreshold_NewMK
				   %if &dsn_obs. %then %do;
					where	put(rid,$mm3fmt.) ne 'Y'
				   %end;
				  union
					select	distinct RID, %if &el_syspersid_var. ne %then %do; &el_syspersid_var., %end;
							fname, lname, sex, dob, soundex(fname) as fsound1, soundex(lname) as lsound1, 
					  %if &el_syspersid_var. ne %then %do;
							case when &el_syspersid_var. ne '' then 900 else 950 end as pl_rank
					  %end;
					  %else %do;
							950 as pl_rank
					  %end;
					from	PM_Roster4
					where	RID not in (select distinct RID from UnderThreshold_NewMK)
				   %if &dsn_obs. %then %do;
					and		put(rid,$mm3fmt.) ne 'Y'
				   %end;
					and	(	fname ne '' and lname ne '' and sex ne '' and dob ne . and (	phone ne ''
						 																or address1 ne '' and (city ne '' or zip ne '')
																						)
					  %if &el_syspersid_var. ne %then %do;
						 or &el_syspersid_var. ne ''
					  %end;
						)
					order by %if &el_syspersid_var. ne %then %do; &el_syspersid_var., %end; lsound1, fsound1, dob, sex;
				quit;


				%let UM_cnt = ;

				proc sql noprint;
				  select count(*) into:UM_cnt
				  from Unmatched;
				quit;

				%put NOTE: UM_cnt = &UM_cnt.;

				%put NOTE: VIDmax = &VIDmax.;
				%put NOTE: EMPInew = &EMPInew.;
				%put NOTE: SSNnew = &SSNnew.;

				%if &UM_cnt. ge 1 %then %do;
					data NewMembers1 (keep = RID VID pl_rank rename=(VID=patient_key));
					  retain VID_;
					  format VID 16.;
					  set Unmatched;
					  if _n_ = 1 then VID_ = &VIDmax. + &EMPInew. + &SSNnew.;
					  by &el_syspersid_var. lsound1 fsound1 dob sex;
					 %if &el_syspersid_var. ne %then %do; 
					  x0 = lag(&el_syspersid_var.);
					 %end;
					  x1 = lag(lsound1);
					  x2 = lag(fsound1);
					  x3 = lag(dob);
					  x4 = lag(sex);
					  if %if &el_syspersid_var. ne %then %do; 
					  		&el_syspersid_var.=x0 and 
					  	 %end;
						 lsound1=x1 and fsound1=x2 and dob=x3 and sex=x4 then VID_ = VID_;
					  else VID_ = VID_ + 1;
					  VID = ("&client_id." || put(&group_id.,z6.) || put(VID_,z8.))*1;	
					  drop x1-x4;	
					run;

					%hash_crosswalk(m_inset=PM_clm2,m_outset=NewMembers2,m_lookupset=NewMembers1,m_keyvar=RID,m_datavar=VID,m_keepvar=claim_key);

					proc append base=all_mk_update data=NewMembers2 force; run;
				%end;
			%end; /* create new member key only for source=P */

		%end; /* end - linknum ge 1 */

		/* Tag linked/new member keys to input dataset */
		%if %sysfunc(exist(all_mk_update)) %then %do;
			%let dsn_id=%sysfunc(open(all_mk_update));
			%let dsn_amku_nobs=%sysfunc(attrn(&dsn_id.,nobs));
			%let dsn_rc=%sysfunc(close(&dsn_id.));

			%if &dsn_amku_nobs. %then %do;
				%hash_lookup(m_dataset=&incoming.,m_lookupset=all_mk_update,m_keyvar=claim_key,m_datavar=VID,m_updatevar=patient_key);
			%end;
		%end;
	%End; /* has invalid SSN records */

  %END; /* historical indicator <> 0 */

	proc sql noprint; 
		update 	&incoming.
		set 	dq_member_flag = 1 
		where 	patient_key in (.,0);
	quit;

	/* Rename variables back to match HOLD and NL HOLD */
	%let dsn_id=%sysfunc(open(&incoming.));
	%let dsn_sysmemid_varind=%sysfunc(varnum(&dsn_id.,system_member_id));
	%let dsn_syspersid_varind=%sysfunc(varnum(&dsn_id.,system_person_id));
	%let dsn_rc=%sysfunc(close(&dsn_id.));

	proc datasets lib=&incoming_library. nolist;
		modify &incoming_dataset.;
			rename patient_key=member_key;
		  %if &dsn_syspersid_varind. and &dsn_sysmemid_varind.=0 %then %do;
			rename system_person_id=system_member_id;
		  %end;
	quit;

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

	proc sql;
		create table &incoming._plmk as
		select	distinct person_key, pl_methodology_hierarchy
		from	&incoming.;
	quit;

	data &incoming._plmk(compress=yes bufsize=128k drop=pl_methodology_hierarchy);
		if _n_=0 then set pl_methodology_key;
		declare hash h_mk(dataset:'pl_methodology_key');
		h_mk.defineKey('pl_methodology_hierarchy');
		h_mk.defineData('pl_methodology_key');
		h_mk.defineDone();
		call missing(pl_methodology_hierarchy,pl_methodology_key);

		do while (not lstobs);
			pl_methodology_key=.;
			set &incoming._plmk end=lstobs;
			if h_mk.find()=0 then output;
			else do;
				put person_key= pl_methodology_hierarchy=;
				output;
			end;
		end;
		stop;
	run;


 
	%let endtime=%sysfunc(time());

	data _null_; 
	  seconds=&endtime.-&starttime.;
	  minutes=seconds/60;
	  hours=minutes/60;
	  call symputx('seconds', seconds);
	  call symputx('minutes', minutes);
	  call symputx('hours', hours);
	run;

	%put NOTE: EDW Linking Time (seconds, minutes, hours) = &seconds. &minutes. &hours.;

%mend edw_linking;

