
/*HEADER------------------------------------------------------------------------
|
| program:  edw_noload_hold_reprocess.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Reprocess claims from NL HOLD ENCOUNTER HEADER DETAIL table
|
| logic:    
|
| input:    Macro parameters and /or SQL server practices
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|	    sas_prgm_id - needs value of 19 since other programs reference
|                         the value (e.g., steps 1-5)
|                        
| output:   Staging dataset for all clients/practices needing reprocessing
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 25APR2011 - G Liu  - Clinical Integration  1.0.01
|             Original
|             
| 17JAN2012 - G Liu  - Clinical Integration  1.1.01
|	      Add Step 1 program call so that we do not duplicate codings
|	      Each extract program will have conditional statement to perform
|	      fresh data pull or bypass and use NL HOLD staging dataset.
|
| 30MAY2012 - Brian Stropich  - Clinical Integration  1.2.01
|             Added and updated changes for noload hold reprocess.  
|
| 15JUN2012 - Brian Stropich  - Clinical Integration  1.2.02
|             Added logic to target client or practice specific data for 
|             edw_pick_latest_nlhold.  
|
+-----------------------------------------------------------------------HEADER*/


*SASDOC-----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos); 


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment;


%macro edw_noload_hold_reprocess;

	
	%global filename nlhold_reprocess kprocessid datasourceid_mlaexist claims_837P_cnt claims_837I_cnt;

	%let filename=NLHOLD-REPROCESS;
	%let nlhold_reprocess=1;
	%let kprocessid=1;
	%let datasourceid_mlaexist=1; 
	%let claims_837P_cnt=1;
	%let claims_837I_cnt=1;
	%let crnh_list_newnpi='';
	%let crnh_list_newcpt='';
	%let sas_prgm_id=19;

	%bpm_process_control(timevar=START);
	
	*SASDOC-----------------------------------------------------------
	| Table Driven Solution
	|
	+---------------------------------------------------------SASDOC*;
	%put NOTE: practice_id_target = &practice_id_target. ;
	
	%if &practice_id_target. eq 1 %then %do;
	
	  data temp_datasources;
	  set cihold.nl_hold_reprocess (keep = nl_hold_reprocess_key /*pk*/ client_key data_source_id
	                                        processed created_on created_by );
	  where client_key = &client_id. and processed=0;
	  run;
	  
	  %let cnt_data_source_id=0;
	
	  proc sql noprint;
	    select count(*) into: cnt_data_source_id separated by ''
	    from temp_datasources ;
	  quit;
	  
	  %put NOTE: cnt_data_source_id = &cnt_data_source_id. ;	
	  
	  %if &cnt_data_source_id. ne 0 %then %do;	  
	  
	    /** select only 1 since there could be multiple data sources within the table that need reprocessing **/
	    proc sort data = temp_datasources;
	    by created_on;
	    run;
	    
	    data temp_datasources;
	    set temp_datasources;
	    put _all_;
	    run;
	    
	    data temp_datasources;
	    set temp_datasources (obs=1); 
	    run;	
	    
	    proc sql noprint;
	    select nl_hold_reprocess_key into: nl_hold_reprocess_key separated by ''
	    from temp_datasources ;
	    quit;
	  
	    %put NOTE: nl_hold_reprocess_key = &nl_hold_reprocess_key. ;	
	    
	    proc sql noprint;
	      select data_source_id into: practice_id_target separated by ''
	      from temp_datasources ;
	    quit;
	    
	    proc sql noprint;
	      update cihold.nl_hold_reprocess
	      set processed = 1
	      where nl_hold_reprocess_key = &nl_hold_reprocess_key. ;
	    quit;
	  
	  %end;
	  %else %do;
	  
	    /** default to 1 if the process was kicked off for table driven solution 99999 **/
	    %let practice_id_target=1;
	  	
	  %end;
	  
	  %put NOTE: practice_id_target = &practice_id_target. ;
	  
	%end;


	*SASDOC-----------------------------------------------------------
	| Determine to target client or practice specific data
	|
	+---------------------------------------------------------SASDOC*;
	%if &practice_id_target ne 0 %then %do;
	  %edw_pick_latest_nlhold(crnh_reproc_ehd,&client_id.,m_datasource_id=&practice_id_target.);
	%end;
	%else %do;
	  %edw_pick_latest_nlhold(crnh_reproc_ehd,&client_id.);
	%end;
	
	%data_source_information;	

	proc sort data = crnh_reproc_ehd;
	by practice_id;
	run;

	proc sort data = client_facility_information nodupkey;
	by datasourceid;
	run;

	data crnh_reproc_ehd;
	 merge crnh_reproc_ehd (in=a)
	       client_facility_information (in=b rename=(datasourceid=practice_id));
	 by practice_id;
	 if a;
	run; 


	*SASDOC-----------------------------------------------------------
	| Get new/updated NPIs and new CPT/HCPCS codes since last 
	| NL reprocess to figure out what claims that needs 
	| reprocessing in NL HOLD.
	|
	| If does not exist, use all records updated within the last 
	| six months from the provider and procedure tables.
	+---------------------------------------------------------SASDOC*;
	proc sql noprint;
		select	count(*) 
		into	: cnt_reprocess
		from	cihold.nl_hold_encounter_header_detail
		where	lowcase(created_by)='reprocess - nl hold'
          and   client_key=&client_id.;
	quit;

	%put NOTE: cnt_reprocess = &cnt_reprocess. ;

	proc sql noprint;
		select	quote(cats(npi1)) into	:crnh_list_newnpi separated by ','
		from	ciedw.provider
		where	client_key=&client_id.
		and		ci_status='PAR'
		and 
		%if &cnt_reprocess. = 0 %then %do;
			(updated_on > today() - 180 or created_on > today() - 180 );
		%end;
		%else %do;
			updated_on gt (	select	max(created_on)
							from	cihold.nl_hold_encounter_header_detail
							where	lowcase(created_by)='reprocess - nl hold'
				  and   client_key=&client_id.);
		%end;
	quit;

	proc sql noprint;
		select	quote(cats(procedure_code)) into	:crnh_list_newcpt separated by ','
		from	ciedw.procedure_cd
		where 
		%if &cnt_reprocess. = 0 %then %do;
			(updated_on > today() - 180 or created_on > today() - 180 );
		%end;
		%else %do;
			updated_on gt (	select	max(created_on)
							from	cihold.nl_hold_encounter_header_detail
							where	lowcase(created_by)='reprocess - nl hold'
				  and   client_key=&client_id.);
		%end;
	quit;

	%put NOTE: CPT/HCPCS codes created since last load to NL HOLD = &crnh_list_newcpt.;
	%put NOTE: NPIs updated since last load to NL HOLD = &crnh_list_newnpi.;

	*SASDOC-----------------------------------------------------------
	| remove encounters based on the critical validations
	|
	| note:  claim key needs to be assign uniquely to all records
	|        for the dataset from the edw_pick_latest_nlhold since
	|        one workflow is representing all data sources.  this
	|        prevents issues for the encounter bulk load. 
	|
	+---------------------------------------------------------SASDOC*;
	data crnh_reproc_ehd2 (bufsize=512k) 
             crnh_reproc_ehd2_bad;
		set Crnh_reproc_ehd;		
		
		/**---- claim key ------------**/
		claim_key=_n_; 		
		
		/**----- providers -----------**/
		if npi ne '' and provider_key=0 and npi in (&crnh_list_newnpi.) then temp_failed_npi=0;
		else if provider_key ne 0 then temp_failed_npi=0;
		else temp_failed_npi=1;

		/**----- procedure codes -----**/
		if proccd ne '' and procedure_code_key=0 and proccd in (&crnh_list_newcpt.) then temp_failed_cpt=0;
		else if procedure_code_key ne 0 then temp_failed_cpt=0;
		else if facility_indicator  = 1 then temp_failed_cpt=0;
		else temp_failed_cpt=1;

		/**----- member keys ---------**/
		if member_key=0 then temp_failed_mkey=0; 
		else temp_failed_mkey=0;

		/**----- service dates -------**/
		if service_date < created_on then temp_failed_svcdate=0;
		else temp_failed_svcdate=1;

		if sum(temp_failed_npi,temp_failed_cpt,temp_failed_mkey,temp_failed_svcdate)=0 then output crnh_reproc_ehd2;
		else output crnh_reproc_ehd2_bad;	

	run;


	%let dsn_id=%sysfunc(open(crnh_reproc_ehd2));
	%let crnh_nlh_cnt=%sysfunc(attrn(&dsn_id.,nobs));
	%let dsn_rc=%sysfunc(close(&dsn_id.));

	%put NOTE: No Load HOLD count = &crnh_nlh_cnt.;

	*SASDOC-----------------------------------------------------------
	| if fixing is needed, loop through all practices needed fixing. 
	| False positives vs Other errors are reprocessed differently:
	|	False positives: no linking, but Group Match only.
	|	Other errors   : normal edw_linking
	| then claims transformation, member load, and claims load
	+---------------------------------------------------------SASDOC*;
	%if &crnh_nlh_cnt. ge 1 %then %do;  /**begin crnh_nlh_cnt **/
	
		%if %symexist(practice_id_target) %then %do;
		  %if &practice_id_target ne 0 %then %do;
		    %let practice_id=&practice_id_target.;
		    %put NOTE: Practice ID to target = &practice_id. ;
		  %end;
		%end; 	

		proc sql;
			create table crnh_reproc_nlh_praclist as
			select	distinct case when source='P' then 1 
                             else 2 end as rank,
					practice_id,
					system,
					count(*) as cnt
			from	crnh_reproc_ehd (keep=practice_id source system)
			%if %symexist(practice_id_target) %then %do;
			  %if &practice_id_target ne 0 %then %do;
			    where practice_id in (&practice_id.)
			  %end;
			%end; 			
            		group by rank, practice_id, system 
			order by rank, practice_id;
		quit;

		proc sort data = crnh_reproc_nlh_praclist nodupkey;
		  by practice_id;
		run;
		
		data crnh_reproc_nlh_praclist;
		set crnh_reproc_nlh_praclist;
		**where practice_id in (752,753,707,740);        /** exempla - testing **/
		**where practice_id in (1029,1004,1037,801,830); /** cccpp   - testing **/
		run;
		
		%let crnh_nlh_numofprac=0;

		data _null_;
			set crnh_reproc_nlh_praclist end=lstobs;
			by rank practice_id;
			call symput('crnh_nlh_pracnum'||cats(_n_),cats(practice_id));
			if lstobs then call symput('crnh_nlh_numofprac',cats(_n_));
		run; 

		%put NOTE: Number of practices with No Load HOLD = &crnh_nlh_numofprac.;

		%do crnh_nlh = 1 %to &crnh_nlh_numofprac.;  /**begin crnh_nlh **/

			%global incoming system_id;

			%let practice_id=&&crnh_nlh_pracnum&crnh_nlh;
			%let incoming=practice_&practice_id.;
			%let incoming_subsequent=cistage.claims_&practice_id._&client_id._&wflow_exec_id. ;
			%let system_id=0; 
			%let err_fl=0;
			%let src_record_cnt=0;
			%let tgt_record_cnt=0;
			
			proc sql noprint; 
			  create table datasource as
			  select  datasourceid, a.versionid, systemid   
			  from    ids.datasource a left outer join 
			          ids.version b on a.versionid=b.versionid ;			  
			quit;

			data _null_;
				set datasource end=lstobs;
				where   datasourceid=&practice_id.; 
				if systemid < 0 or systemid = . then systemid=0;
				call symput('system_id',cats(systemid)); 
			run;

			%let system_id=%trim(&system_id);
			%put NOTE: wflow_exec_id=&wflow_exec_id.;
			%put NOTE: system_id=&system_id.;
			%put NOTE: practice_id=&practice_id.;
			%put NOTE: client_id=&client_id.;
			%put NOTE: incoming=&incoming.;
			%put NOTE: incoming_subsequent=&incoming_subsequent.;

			%**edw_primsec_provider_xref(&client_id.,m2_save_prim=crnh_primary_xref);
			%**data_source_information;
			
			/** need to fix admin and discharge dates in nl hold for self pays and 837i **/
			%if (&dataformatgroupid. = 1000000 or &dataformatgroupid. = 14 or &dataformatgroupid. = 8 or &dataformatgroupid. = 3) %then %do; /** filter loop **/
			%end;
			%else %do;

				*SASDOC--------------------------------------------------------------------------
				| Delete claims dataset if it exists to prevent issues for the cycle of the ETL
				------------------------------------------------------------------------SASDOC*;
				%if %sysfunc(exist(cistage.claims_&practice_id._&client_id._&wflow_exec_id.)) %then %do;
					proc datasets library=cistage nolist;
					  delete claims_&practice_id._&client_id._&wflow_exec_id.;
					quit;
				%end;

				*SASDOC--------------------------------------------------------------------------
				| these are variables that have both the source version and the target version. 
				| all we need to do is drop them
				------------------------------------------------------------------------SASDOC*; 
				%let drop_tgt_var1=diagnosis_cd1-diagnosis_cd9 group_id provider_key  ;
				%let drop_tgt_var2=svcdt2 dob2 moddt2 discharge_date admit_date created_on service_date drg_key;

				*SASDOC--------------------------------------------------------------------------
				| for variables that we only store the target version, we rename it back to the  
				| source version variable name not here but in the respective extract program
				------------------------------------------------------------------------SASDOC*;				
				data adiag5cd;
				  set ciedw.diagnosis (where=(lowcase(diagnosis_cd) ne 'other')) end=end; 
				  length fmtname $10  type $1 label $50;
				  retain fmtname 'aDiag5cd'  type 'N';		  	
				  label = diagnosis_cd;
				  start = left(diagnosis_key);
				  output; 
				  if end then do;
				   start = "other";
				   label = '0';
				   output;
				  end;
				  keep start label type fmtname;
				run;

				proc sort data = adiag5cd nodupkey;
				  by start;
				run;

				%proc_format(datain=work.adiag5cd);		

				data &incoming.;
					format 	dob svcdt moddt mmddyy10. 
						member_key 16. service_date2 datetime. filed $8.;
					set crnh_reproc_ehd(drop   = orig_nl_hold_ehd_key orig_wflow_exec_id &drop_tgt_var1.
							    rename = (	nl_hold_ehd_key=orig_nl_hold_ehd_key 
									svcdt=svcdt2
									dob=dob2
									moddt=moddt2
									practice_key=p_key
									));
					where practice_id=&practice_id.;

					svcdt=datepart(svcdt2);
					service_date2=dhms(svcdt,0,0,0);
					dob=datepart(dob2);
					moddt=datepart(moddt2);
					disdt=datepart(discharge_date);
					admdt=datepart(admit_date);
					patid=system_member_id;
					admdiag=put(admit_diagnosis_cd, aDiag5cd.);
					drg=put(left(drg_key),3.);
					if drg='.' then drg='';
					poa10='';
					diag10='';

					orig_wflow_exec_id=wflow_exec_id;				
					updated_by='reprocess - nl hold'; 
					updated_on=datetime();

					if index(filename,'-') > 0 then do;
					  filed=left(scan(filename,2,'-'));
					end;
					else do;
					  filed=filename;
					end;		        	
					rename vmine_kprocessid=maxprocessid;
					drop &drop_tgt_var2. ;
				run;

				options nosymbolgen;
				%put NOTE: Looping datasource id &crnh_nlh. of &crnh_nlh_numofprac.;
				%put NOTE: GLOBAL practice_id = &practice_id.;
				%put NOTE: GLOBAL system_id = &system_id.;
				%put NOTE: GLOBAL incoming = &incoming.;
				%put NOTE: LOCAL facility_indicator = &facility_indicator.;

				*SASDOC--------------------------------------------------------------------------
				| if running DEV, use programs from \Development folder
				------------------------------------------------------------------------SASDOC*;
				%if %index(%str(&sqlci.),%str(Data Source=SQLCIDEV)) ne 0 %then %do;
					%let crnh_prog_folder=\\sas2\ci\programs\development\EDW;
				%end;
				%else %if %index(%str(&sqlci.),%str(Data Source=SQL-CI)) ne 0 %then %do;
					%let crnh_prog_folder=\\sas2\ci\programs\EDW;
				%end;

				*SASDOC-----------------------------------------------------------
				| Call Step 1 program, and variables will be re-initialized 
				| or re-created there
				+---------------------------------------------------------SASDOC*; 
				%put NOTE: Start - edw_main_extract for Datasource ID &practice_id.;
				%put NOTE: Directory = &crnh_prog_folder. ;
				%include "&crnh_prog_folder.\edw_main_extract.sas";

				*SASDOC-----------------------------------------------------------
				| if we have non-zero provider keys, then move on to Step 2-5,  
				| otherwise, they will never get loaded to EDW anyway.
				+---------------------------------------------------------SASDOC*; 
				data &incoming_subsequent.;
				  set &incoming_subsequent.;
				  where provider_key ne 0;
				  %if &facility_indicator. = 0 %then %do;
					if procedure_code_key ne 0;
				  %end;
				run;

				%let dsn_step1_obs=0;
				%let dsn_id=%sysfunc(open(&incoming_subsequent.));
				%let dsn_step1_obs=%sysfunc(attrn(&dsn_id.,nobs));
				%let dsn_rc=%sysfunc(close(&dsn_id.));
				%put NOTE: Incoming dataset &incoming_subsequent. has &dsn_step1_obs. observations with some chances of going to EDW.;


				%if &dsn_step1_obs. ne 0 %then %do;

					%put NOTE: Start - edw_member_extract for Datasource ID &practice_id.;
					%include "&crnh_prog_folder.\edw_member_extract.sas";

					*SASDOC-----------------------------------------------------------
					| if we have non-zero member keys, then move on to Step 3-5,  
					| otherwise, they will never get loaded to EDW anyway.
					+---------------------------------------------------------SASDOC*; 
					data &incoming_subsequent.;
					  set &incoming_subsequent.;
					  where dq_member_flag=0; 
					run;

					%let dsn_step2_obs=0;

					proc sql noprint;
						select	count(*)
						into	:dsn_step2_obs
						from	&incoming_subsequent. ;
					quit;

					%put NOTE: Incoming dataset has &dsn_step2_obs. observations with legitimate member key.;

					%if &dsn_step2_obs. ne 0 %then %do;
						%put NOTE: Start - edw_claims_transformations for Datasource ID &practice_id.;
						%include "&crnh_prog_folder.\edw_claims_transformations.sas";

						data &incoming_subsequent.;
						  set &incoming_subsequent.;
						  where load_flag=0 and dq_member_flag=0 and dq_claim_flag=0; 
						run;	

						%let dsn_step4_obs=0;

						proc sql noprint;
							select	count(*)
							into	:dsn_step4_obs
							from	&incoming_subsequent. ;
						quit;	

						%put NOTE: Incoming dataset has &dsn_step4_obs. observations with legitimate encounters and member to load.;

						%if &dsn_step4_obs. ne 0 %then %do;					

							%put NOTE: Start - edw_member_load for Datasource ID &practice_id.;
							%let sas_prgm_id=19;
							%include "&crnh_prog_folder.\edw_member_load.sas";

							%put NOTE: Start - edw_claims_load for Datasource ID &practice_id.;
							%let sas_prgm_id=19;
							%include "&crnh_prog_folder.\edw_claims_load.sas";

						%end;
						%else %do;
							%put NOTE: Will not execute Steps 4-5 for Datasource ID &practice_id.;
						%end;					
					%end;
					%else %do;
						%put NOTE: Will not execute Steps 3-5 for Datasource ID &practice_id.;
					%end;
				%end;
				%else %do;
					%put NOTE: Will not execute Steps 2-5 for Datasource ID &practice_id.;
				%end;
			
			%end;  /** filter loop **/


		%end;  /**end crnh_nlh **/


	%end;  /**end crnh_nlh_cnt **/

	%bpm_process_control(timevar=COMPLETE);
	
	%macro send_email_alert;
		filename mail_out email to=("bstropich@valencehealth.com") subject="NoLoad Hold Reprocess - Complete";

		data _null_;
		file mail_out lrecl=32767; 		
		run;
	%mend send_email_alert;
	%send_email_alert;

%mend edw_noload_hold_reprocess;

%edw_noload_hold_reprocess;
