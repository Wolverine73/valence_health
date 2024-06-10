
/*HEADER------------------------------------------------------------------------
|
| program:  edw_vmine_extract.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create practice data from the pm system vmine views  
|
| logic:    
|           1.  Extract all non-termed practices for a client and PM system 
|           2.  Extract all claims based on CI start date for the client  
|           3.  Loop through the practices                                      
|           4.  Determine and extract only claims that exceed the maximum process ID 
|           5.  Concatenate the results to the previous month of claims         
|           6.  Remove duplicate values and keep most recent updated claims     
|           7.  Save the practice data set for the client on SAS2                 
|
| input:    Macro parameters and /or SQL server practices
|           system_id   - the pm system id from vmine (e.g., 1=Medisoft) 
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           practice_id - opitional field but the practice id from vmine (e.g., 256) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|                        
| output:   Staging dataset for the PM system - practice
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|  
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 26APR2012 - G Liu - Clinical Integration 1.2.01
|			  Added rename of PATID to SYSTEM_MEMBER_ID if PATID exists
|			  Changed _mlaexist macro variable to source from VH_EMPI.PERSON_WORKFLOW_DETAIL
|
| 30MAY2012 - Brian Stropich  - Clinical Integration  1.2.02
|             Added changes for noload hold reprocess.  the logic is to 
|             by pass the incremental code and go to sections needed for the
|             reprocessing of the nl load hold encounters. search for 
|             nlhold_reprocess within the code.  commented the begin and end
|             for the conditions to easily follow the logic.
|
| 03MAY2012 - Winnie Lee - Clinical Integration 1.2 H07
|			  Added logic to include DATA_SOURCE_ID
|
| 15MAY2012 - G Liu - Clinical Integration 1.2.04
|			  Added list of system_ids where we store PATID in VH_EMPI. Not all systems
|				have the correct PATID format yet. In R1.3 when all PATID is in place
|				for all systems, we should remove the list of system_ids.
|
| 05JUN2012 - G Liu - Clinical Integration 1.3.01
|			  Removed temporary changes for 1.2.04
|
| 14JUN2012 - G Liu - Clinical Integration 1.3.02
|			  If incremental has more providers then EDW, then fail incremental workflow
|				Execute no load hold reprocess for the new providers first, then resume
|				the incremental workflow. (maxprocessid condition #2)
|
| 18JUN2012 - G Liu - Clinical Integration 1.3.03
|			  Add additional list of system_ids to capture PATID
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
|
| 06AUG2012 - B STROPICH - Release 1.3 H01
|             Updated logic for Determine the process ID for the claim extraction. 
|   
+-----------------------------------------------------------------------HEADER*/

%macro edw_vmine_extract;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.    
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);

	*SASDOC--------------------------------------------------------------------------
	| Determine the practice IDs which need to be processed for the client 
	| and PM System from vMine SQL Server
	------------------------------------------------------------------------SASDOC*;
	%vmine_pmsystem_information; 
	%set_error_flag;
  	%on_error(ACTION=ABORT);

	*SASDOC--------------------------------------------------------------------------
	| Delete claims dataset if it exists to prevent issues for the cycle of the ETL
	-----------------------------------------------------------------------SASDOC*;
	%if %sysfunc(exist(cistage.claims_&practice_id._&client_id._&wflow_exec_id.)) %then %do;
		proc datasets library=cistage nolist;
		  delete claims_&practice_id._&client_id._&wflow_exec_id. ;
		quit;
	%end;

	%let dopid =0;
	%DO %WHILE (%scan(&practice_id., &dopid+1) ne );  /**begin do_practice_id while **/

		%let dopid  =%eval(&dopid+1);
		%let do_practice_id=%scan(&practice_id.,&dopid);
    
		*SASDOC--------------------------------------------------------------------------
		| Determine maximum process ID for extracting data from the view
		|  
		| Logic:
		| 1.  Validate that the practice ID does not equal 0
		| 2.  Validate if a maximum process ID exists for the practice
		| 3.  If there is a valid maximum process ID assign it to maxprocessid
		| 4.  If there is not a valid maximum process ID assign maxprocessid to 0
		|     and pull a complete history of the practice data from the view 
		| 5.  Determine if a full history extract is needed based on NPIs
		|     exist within the ciedw.provider and ciedw.encounter_header
		| 
		------------------------------------------------------------------------SASDOC*;

		%If &do_practice_id. ne 0 %Then %Do ;  /** begin - do_practice_id **/


		*SASDOC--------------------------------------------------------------------------
		| Determine the list of active providers and practices from the ciedw 
		|
		| 1.  primary_provider_xref   - provider key primary assignment
		------------------------------------------------------------------------SASDOC*;	
		proc sql noprint;
			select distinct(b.practice_key) into: practice_key separated by ','
			from ids.datasource_practice as a inner join
			     ciedw.practice          as b on a.practiceid=b.vsource_practice_key
			where a.datasourceid=&practice_id. and 
			      a.termed = 0 and 
			      b.vsource_practice_key ne .;
		quit;

		  
		  %edw_primsec_provider_xref(&client_id.,m2_save_prim=primary_provider_xref);
		  
		  data primary_provider_xref;
			set primary_provider_xref;
			where datasourceid=&practice_id.;
			put _all_;
		  run;

		  %let npi_provider_count=0;
		  proc sql noprint;
			select count(distinct(provider_key)) into: npi_provider_count
			from primary_provider_xref;
		  quit;   

		  %if &npi_provider_count eq 0 %then %do;
			  %put ERROR: There is an issue with the NPI information for vMine practice - &practice_id.  ;
			  %let err_fl=1;
			  %set_error_flag;
		  	  %on_error(ACTION=ABORT);
		  %end;		

		%if not %symexist(nlhold_reprocess) %then %do;  /** nlhold reprocess 1 **/ 
	
		*SASDOC--------------------------------------------------------------------------
		| Determine if there are any claims within ciedw 
		| 
		| This function is for the incremental claim extractions. We will only pull 
		| claims that exceed the process ID for the ETL process. 
		------------------------------------------------------------------------SASDOC*; 
		  proc sql noprint;
			connect to oledb(init_string=&ciedw.);
			select 	maxprocessid_exist, maxprocessid 
			into	:maxprocessid_exist, :maxprocessid
			from 	connection to oledb
			(	
				select count(*) as maxprocessid_exist, max(vmine_kprocessid) as maxprocessid
				from  [dbo].[encounter_detail](nolock) as ed,
					  [dbo].[encounter_header](nolock) as eh 
				where ed.encounter_key=eh.encounter_key and 
					  ed.client_key=eh.client_key and 
					  ed.client_key=&client_id. and 
					  ed.data_source_id = &practice_id.
			);
		  quit;	

		*SASDOC--------------------------------------------------------------------------
		| Determine the list of providers from the ciedw claims 
		| 
		| This function is for determining if a full historical claim extraction is 
		| needed for any new providers. 
		------------------------------------------------------------------------SASDOC*;
		  proc sql noprint;
			connect to oledb(init_string=&ciedw.);
			create table provider_header1 as select * from connection to oledb
			(	
				select distinct(provider_key) as provider_key
				from  [dbo].[encounter_detail](nolock) as ed,
					  [dbo].[encounter_header](nolock) as eh 
				where ed.encounter_key=eh.encounter_key and 
					  ed.client_key=eh.client_key and 
					  ed.client_key=&client_id. and 
					  ed.data_source_id = &practice_id.
			);
		  quit; 
		 
		  proc sql noprint;
			connect to oledb(init_string=&ciedw.);
			create table provider_header2 as select * from connection to oledb
			(	
				select distinct(provider_key) as provider_key
				from  [cihold].[dbo].[nl_hold_encounter_header_detail](nolock) 
				where client_key=&client_id.
				  and practice_id=&practice_id.
				  and provider_key <> 0
			);
		  quit; 
		  
		  data provider_header;
		   set provider_header1 provider_header2;
		  run;
		  
		  proc sort data = provider_header nodupkey;
		  by provider_key;
		  run;

		*SASDOC--------------------------------------------------------------------------
		| Determine if new providers exist to extract a full history of claims 
		------------------------------------------------------------------------SASDOC*;
		  %let npi_header_count=0;
		  proc sql noprint;
		    select count(*) into: npi_header_count
		    from primary_provider_xref  as a,		         
		         provider_header        as b
            where a.provider_key=b.provider_key;
		  quit;

		*SASDOC--------------------------------------------------------------------------
		| Determine if we have loaded this practice before, i.e. member information
		|	already existed in the person workflow detail tables.
		------------------------------------------------------------------------SASDOC*;
		  %let datasourceid_mlaexist=0;
		  proc sql noprint;
			connect to oledb(init_string=&sqlci.);		
			select	cnt
			into	:datasourceid_mlaexist
			from	connection to oledb
					(	select	count(*) as cnt
						from	vh_empi.dbo.person_workflow_detail(nolock)
						where	client_key=&client_id.
						and		datasourceid=&practice_id.
					);
		  quit;
 
		  options nosymbolgen;

		  %put NOTE: maxprocessid_exist     = &maxprocessid_exist. ; 
		  %put NOTE: maxprocessid           = &maxprocessid. ; 
		  %put NOTE: npi_header_count       = &npi_header_count. ; 
		  %put NOTE: npi_provider_count     = &npi_provider_count. ; 
		  %put NOTE: datasourceid_mlaexist  = &datasourceid_mlaexist. ;
		  %put NOTE: practice_key           = &practice_key. ;  
		  %put NOTE: practice_id/datasource = &practice_id. ; 
		  
		  options symbolgen;
		  
		*SASDOC--------------------------------------------------------------------------
		| Determine the process ID for the claim extraction.
		|
		| If vmine process ID exists and there are no new providers since the prior
		| claims extract then retrieve the vmine process ID from the ciedw to use
		| in the claims extraction.  If this was not true, then a full history extract
		| would be performed. 
		------------------------------------------------------------------------SASDOC*;
		
		proc sql noprint;
		select max(ext_output_log) into: ext_output_log separated by '' 
		from vbpm.sk_process_control 
		where wflow_exec_id=&wflow_exec_id. 
		and client_id=&client_id. ;
		quit;
		
		%PUT NOTE: ext_output_log = &ext_output_log. ;

		  /* 1. If vmine process ID exists in encounter tables and there are no new providers 
					since the prior claims extract then retrieve the vmine process ID from 
					the ciedw to use in the claims extraction. */  
		  %if &maxprocessid_exist ne 0 and (&npi_header_count. = &npi_provider_count.) %then %do;
			  %if &maxprocessid = . %then %let maxprocessid = 0; /* this should never be true */
			  %if &enabled = 0 %then %let maxprocessid = 2; /* where do we initialize this macro variable? */
			  /* We intentionally set vmine_kprocessid=1 in encounter tables during first pass,
			  		to trigger second pass during next round of processing. If so, maxprocessid=1
			  		and we will essentially pull full historical too. */
		  %end;
		  /* 2. If claims exist in encounter tables but we have new providers, stop to perform
		  		no load hold reprocess for the new providers first, then resume incremental workflow */
		  %else %if &maxprocessid_exist ne 0 and ext_output_log eq and (&npi_header_count. ne &npi_provider_count.) %then %do;
		  
				proc sql noprint;
				update vbpm.sk_process_control 
				set ext_output_log = 'NL_HOLD_REPROCESS'
				where wflow_exec_id=&wflow_exec_id. 
				and sk_prcs_ctrl_id = &sk_prcs_ctrl_id.
				and client_id=&client_id. ;
				quit;		  
		  
		  		%put WARNING: Perform No Load Hold Reprocess for the new providers first, then restart this workflow;
				%**let err_fl=1;
				%**set_error_flag;
			  	%**on_error(ACTION=ABORT);
		  %end;
		  /* 3. If no claims in encounter, this is a new practice; pull full historical. We want to
		  			pend practice until it is validated against existing PM system SAS code, but
		  			how do we differentiate onboarding process vs new practice after onboarding?
		  			We don't want to pend all practices during onboarding process. */
		  %else %do;
		      %let maxprocessid = 0;
		  %end;
		%End;
		%Else %Do;
		  %let maxprocessid = 0;
		%End;  /** end - do_practice_id **/
		
	 	%put NOTE: maxprocessid = &maxprocessid. ; 

 		%end;  /** nlhold reprocess 1 **/

		*SASDOC--------------------------------------------------------------------------
		| Connect to SQL Server to retreive the practice data from the PM System view
		------------------------------------------------------------------------SASDOC*;
		%if not %symexist(nlhold_reprocess) %then %do;  /** nlhold reprocess 2 **/ 
		%vmine_view_&system_id.;

		%set_error_flag;
	  	%on_error(ACTION=ABORT);
		
		%check_issue_count(dataset_in=practice_&do_practice_id., validation=62);

		proc sql noprint; 
		  select distinct(MaxProcessID) into: kprocessid separated by ","
		  from practice_&do_practice_id.;
		quit;

		%end;  /** nlhold reprocess 2 **/

		%If %symexist(kprocessid) %Then %Do;   /**start - sysmexist - kprocessid **/

		  %if not %symexist(nlhold_reprocess) %then %do;  /** nlhold reprocess 3 **/

			%put NOTE: kprocessid = &kprocessid. ;

			proc sql;
			  connect to oledb(init_string=&emine.);
			  create table kprocessid_format as select * from connection to oledb
			  (	
				select kProcessID, filename	               
				from  dbo.KTBL_Process
				where kProcessID in (&kprocessid.)
			  );
			quit;

			data kprocessid_format;
			  set kprocessid_format; 
			  retain fmtname 'kprocessid'  type 'N';
			  length fmtname $10  type $1 label $100;	
			  start = kprocessid;
			  label = scan(filename,1,'.');
			  keep start label type fmtname;
			run;

			proc format cntlin=kprocessid_format;
			run; 
			
			*SASDOC--------------------------------------------------------------------------
			| Perform cleaning and edits to the practice data
			------------------------------------------------------------------------SASDOC*;
			%vmine_pmsystem_&system_id.;

			%set_error_flag;
			%on_error(ACTION=ABORT);
			
			%check_issue_count(dataset_in=practice_&do_practice_id., validation=60); 
			
		  %end;  /** nlhold reprocess 3 **/

			*SASDOC--------------------------------------------------------------------------
			| Diagnosis - Cleanse diagnosis of length of 4 with decimal in 4th location     
			------------------------------------------------------------------------SASDOC*;
			%cleanse_diagnosis_length_4(dataset_in=practice_&do_practice_id.);
			

			*SASDOC--------------------------------------------------------------------------
			| BPM - Create source and target counts             
			+------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
			  select count(*) into: src_record_cnt
			  from practice_&do_practice_id.  ;
			quit;
			
	  	    
			*SASDOC--------------------------------------------------------------------------
			| Client - Apply CI Start Date Filter and NPI Cleansing and Edits     
			------------------------------------------------------------------------SASDOC*;
			data ci_start_date;
			  format start_date mmddyy10.  ;
			  set ciedw.client (where = (client_key=&client_id. ));
			  start_date=datepart(ci_start_date);	  
			  keep start_date;
			run;
			
			%create_npi_cleanse_rules;

			data practice_&do_practice_id. ;
			  if _n_ = 1 then set ci_start_date ;
			  set practice_&do_practice_id. ;
			  if svcdt >= start_date ;
			  /**%edw_npi_cleansing_rules;**/
			  %include "&cistage.\npi_cleanse_rules_&wflow_exec_id..txt";
			run;
			
			%check_issue_count(dataset_in=practice_&do_practice_id., validation=60);
			
			proc sql noprint;
			  select count(*) into: npi_count
			  from practice_&do_practice_id. ;
			quit;

			proc sql noprint;
			  select count(*) into: npi_missing_count
			  from practice_&do_practice_id. 
			  where npi = '';
			quit;
			
			%put NOTE: npi_count = &npi_count. ;
			%put NOTE: npi_missing_count = &npi_missing_count. ;

			
			%if &npi_count. eq &npi_missing_count. %then %do;
			  %put ERROR: There are 0 observations within cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			  
			  data cistage.practice_&do_practice_id.;
			   set practice_&do_practice_id. ;
			  run;	
			  
			  %let err_fl=1;
			  %set_error_flag;
		  	  %on_error(ACTION=ABORT);
			%end;	
			

			*SASDOC--------------------------------------------------------------------------
			| Client - Apply Provider Key Primary (vSource - provider practice definition)
			|
			| 1.  Assign practice key
			| 2.  Assign provider key
			------------------------------------------------------------------------SASDOC*;
			%edw_primsec_provider_xref(&client_id.,m2_inset=practice_&do_practice_id.);
		    
			%set_error_flag;
			%on_error(ACTION=ABORT);

			*SASDOC--------------------------------------------------------------------------
			| DQ Validation - Missing TINs
			------------------------------------------------------------------------SASDOC*;		
/*			%let group_count=0;*/
/*			proc sql noprint;*/
/*				select	count(*) into: group_count*/
/*				from	practice_&do_practice_id.*/
/*				where	provider_key ne 0 and verify(substr(tin,1,9),'0123456789');*/
/*			quit;*/
/*			*/
/*			%put NOTE: Claims with NPI and assigned provider key but no practice key = &group_count. ;*/

			proc sql noprint;
			      create table tin_check as 
			      (
			            select
			                  npi,
							  provider_key,
			                  case when tin = '' then  1
			                        else 0 end as missing_tin,
			                  count(*) as record_count
			            from practice_&do_practice_id.
			            where npi ne ''
			            group by npi, tin
			      );
			quit;
			 
			proc summary data= tin_check nway missing;
			class npi provider_key;
			var record_count;
			output out=tin_ttl (drop=_type_ _freq_) sum=;
			run;
			 
			proc sql noprint;
			      create table tin_check2 as
			      (
			            select
			                  a.*,
			                  b.record_count as total_records,
			                  round((a.record_count/b.record_count)*100,.1) as record_percent
			            from tin_check as a left outer join
			                  tin_ttl as b on a.npi = b.npi
			      );
			 
			      create table tin_check3 as
			      (
			            select *
			            from tin_check2
			            where missing_tin = 1 and provider_key ne 0 and record_percent > 50
			      );
			quit;
			 
			%let group_count=0;
			proc sql noprint;
			      select      count(*) into: group_count
			      from  tin_check3;
			quit;
			 
			%put NOTE: Number of providers with NPIs that are missing more than 50% of TINs - &group_count.;


			%if &group_count ne 0 %then %do;
			  %put ERROR: Number of providers with NPIs that are missing more than 50% of TINs - &group_count. There is an issue with the NPI and TIN assignment. Enter information into cihold.dbo.npi_cleanse_rules for this practice.;
			  
			  %macro send_email_alert;
				filename mail_out email to=("bstropich@valencehealth.com" "bfletcher@valencehealth.com" "gliu@valencehealth.com" "wlee@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - NPI TIN Failed";

				data _null_;
				file mail_out lrecl=32767;  
				put "client ID = &client_id.";
				put "practice ID = &do_practice_id.";
				put "system ID = &system_id.";
				run;
			  %mend send_email_alert;
			  %send_email_alert;
			  
			  data cistage.practice_&do_practice_id.;
			   set practice_&do_practice_id. ;
			  run;	
			  
			  data _null_;
				set primary_provider_xref;
				where datasourceid=&do_practice_id.;  
				put _all_;
			  run;			  
			  
			  %check_issue_count(dataset_in=cistage.practice_&do_practice_id., validation=41, zero_count=no, count_in=&group_count.);
			  
			%end;	
			
			%vmine_pmsystem_byvars;

			proc sort data=practice_&do_practice_id.;
			  %if not %symexist(nlhold_reprocess) %then %do;  
			    by &&byvars&system_id.;
			  %end;
			  %else %do;
			    by &byvars0;
			  %end;
			run;
			
			
			*SASDOC--------------------------------------------------------------------------
			| Create the final output dataset of the practice data and remove any
			| duplicates which may exist.  In addition, initialize and assign claim key, 
			| dq claim flag, member key, and dq member flag for subsequent processes.
			|
			------------------------------------------------------------------------SASDOC*; 	
			%let dsid=%sysfunc(open(practice_&do_practice_id.));
			%let dspatidvar=%sysfunc(varnum(&dsid.,patid));
			%let dsrc=%sysfunc(close(&dsid.));
			
			data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.  
				 dups                 ;
			  format member_key 16. ;
			  set practice_&do_practice_id. (%if %symexist(nlhold_reprocess) %then %do;  
			  				   drop = admdt disdt
			  				 %end;);

			  %if not %symexist(nlhold_reprocess) %then %do;  
			    by &&byvars&system_id.;
			  %end;
			  %else %do;
			    by &byvars0;
			  %end;

			  claim_key=_n_;
			  dq_claim_flag=0;
			  member_key=0;
			  dq_member_flag=0;
			  wflow_exec_id=&wflow_exec_id.; 
			  claim_source=&dataformatgroupid.;
			  source='P';
			  
			  if &datasourceid_mlaexist.=0 then historical=0; /* onboarding first pass */
			  else historical=2;

			  
			  /** after onboarding - new practices to be reflected within EDW instantly **/
			  %if %length(&filename) > 0 %then %do;
			    historical=2; 
			  %end;	

			  if first.mod2 and last.mod2 then dupcount=.;
			  else if first.mod2 then dupcount =0 ;
			  else dupcount = 1;
			  if first.mod2 then output cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;
			  if dupcount ne . then output dups;
			  %if &dspatidvar. %then %do;
				%if &system_id.=1 or &system_id.=2 or &system_id.=3 or &system_id.=4 or &system_id.=5 or 
					&system_id.=6 or &system_id.=7 or &system_id.=8 or &system_id.=9 or &system_id.=10 or 
					&system_id.=11 or &system_id.=12 or &system_id.=13 or &system_id.=16 or &system_id.=19 or 
					&system_id.=20 or &system_id.=21 or &system_id.=25 or &system_id.=27 or &system_id.=29 or &system_id.=31 or &system_id.=43 or 
					&system_id.=54 or &system_id.=66 or &system_id.=72 or &system_id.=96 or &system_id.=99 or 
					&system_id.=111 or &system_id.=143 or &system_id.=155 or &system_id.=416 %then %do;
					rename patid=system_member_id;
				%end;
			  %end;			  
			run;
			
			
			*SASDOC--------------------------------------------------------------------------
			| BPM - Create target counts             
			+------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
			  select count(*) into: tgt_record_cnt separated by ''
			  from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			quit;
			
			%check_issue_count(dataset_in=cistage.claims_&do_practice_id._&client_id._&wflow_exec_id., validation=60);

			%put NOTE:  tgt_record_cnt = &tgt_record_cnt;
			%put NOTE:  src_record_cnt = &src_record_cnt;


		%end;  /**end - sysmexist - kprocessid **/
		%else %do;
			%put ERROR: There are no claims within CIMaster for System - &system_id. Practice - &do_practice_id.;

			%macro send_email_alert;
				filename mail_out email to=("bstropich@valencehealth.com" "bfletcher@valencehealth.com" "gliu@valencehealth.com" "wlee@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - No Claims CIMaster Failed";

				data _null_;
				file mail_out lrecl=32767;  
				put "client ID = &client_id.";
				put "practice ID = &do_practice_id.";
				put "system ID = &system_id.";				
				run;
			%mend send_email_alert;
			%send_email_alert;

		    %check_issue_count(dataset_in=cistage.claims_&do_practice_id._&client_id._&wflow_exec_id., validation=47, zero_count=no, count_in=0); 
		    
		%end;		
    
	%END;  /**end do_practice_id while **/


	*SASDOC--------------------------------------------------------------------------
	| vmine_practice_information - create messages about the practice.        
	+------------------------------------------------------------------------SASDOC*;
	%vmine_practice_information;

	*SASDOC--------------------------------------------------------------------------
	| Delete NPI cleansing rules for the work flow.        
	+------------------------------------------------------------------------SASDOC*;	
	data _null_;
	  x "del &cistage.\npi_cleanse_rules_&wflow_exec_id..txt";
	run;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);
	

%mend edw_vmine_extract;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
%edw_vmine_extract;
