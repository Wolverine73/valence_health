
/*HEADER------------------------------------------------------------------------
|
| program:  edw_nonvmine_extract.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create practice data from the pm system pgf files
|
| logic:    
|           1.  Extract all non-termed practices for a client and PGF 
|           2.  Extract all claims from most recent unprocessed files            
|           3.  Determine and extract only claims that have not been previously processed
|           4.  Concatenate the results to the previous month of claims         
|           5.  Remove duplicate values and keep most recent updated claims     
|           6.  Save the practice data set for the client on SAS2                 
|
| input:    Macro parameters and /or SQL server practices
|             sk_prcs_ctrl_id - bpm process identifier
|             wflow_exec_id - bpm work flow identifier
|             sas_prgm - sas program id from BPMMetaData.SK_EXT_PROGRAM
|             client_id   - the client id from vmine (e.g., 4=NSAP) 
|             system_id - system id equals 0 for PGFs
|             practice_id - opitional but would be DataSourceID (e.g., 710 HealthNautica) 
|             group_id - DataSourceID
|             pgf_practice - null for pgf extract
|             sas_mode - prod or test
|             filename - monthly text file to process
|           
|			example of the skelta call:
|             sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=12 client_id=4 
|             system_id=0 group_id=710 pgf_practice= sas_mode=prod filename=710-20110825T09400000.txt
|                        
| output:   Staging dataset for the PGF practice
|
| notes:    NSAP - PGF Practices information    
|			  710 123 Health Nautica
|			  711 31  KLOBilling
|			  656 20  Edimis
|			  ??? 56  Misys - Termed
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 30MAY2012 - Brian Stropich  - Clinical Integration  1.2.01
|             Added changes for noload hold reprocess.  the logic is to 
|             by pass the incremental code and go to sections needed for the
|             reprocessing of the nl load hold encounters. search for 
|             nlhold_reprocess within the code.  commented the begin and end
|             for the conditions to easily follow the logic.
|
| 03MAY20120 - Winnie Lee - Clinical Integration 1.2 H07
|			  Added logic to include DATA_SOURCE_ID
| 
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
+-----------------------------------------------------------------------HEADER*/

%let do_practice_id=&practice_id.;

%macro edw_nonvmine_extract;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);

	*SASDOC--------------------------------------------------------------------------
	| Delete claims dataset if it exists to prevent issues for the cycle of the ETL
	------------------------------------------------------------------------SASDOC*;
	proc datasets library=cistage nolist;
	  delete claims_&practice_id._&client_id._&wflow_exec_id. ;
	quit;

	%let dopid =0;
	%do %while (%scan(&practice_id., &dopid+1) ne );  /**begin - do while practice_id **/

		%let dopid  =%eval(&dopid+1);
		%let do_practice_id=%scan(&practice_id.,&dopid);
    
		%if &do_practice_id. ne 0 %then %do ;  /**begin - do_practice_id **/


		*SASDOC--------------------------------------------------------------------------
		| Determine the list of active providers and practices from the ciedw 
		|
		| 1.  primary_provider_xref   - provider key primary assignment
		------------------------------------------------------------------------SASDOC*;	
		proc sql noprint;
		   select 
		         distinct(b.practice_key) into: practice_key separated by ','
		   from ids.datasource_practice as a inner join
		        ciedw.practice as b on a.practiceid=b.vsource_practice_key 
		   where a.datasourceid=&practice_id. and b.vsource_practice_key ne .;
		quit;

		%put NOTE: practice_key = &practice_key;
		%put NOTE: practice_id = &do_practice_id.;
		  
		  %edw_primsec_provider_xref(&client_id.,m2_save_prim=primary_provider_xref);
		  
		  data primary_provider_xref;
			set primary_provider_xref;
			where datasourceid=&do_practice_id.;  
			put _all_;
		  run;

			proc sql noprint;
			  select distinct(provider_key) into: provider_list separated by ','
			  from primary_provider_xref ;
			quit;

			proc sql noprint;
			  select count(distinct(provider_key)) into: npi_provider_count separated by ''
			  from primary_provider_xref;
			quit;      
			  
			%put NOTE: practice_id = &do_practice_id. ; 
			%put NOTE: npi_provider_count = &npi_provider_count. ;  
			%put NOTE: provider_list = &provider_list ;

			%let maxprocessid = 0;

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
			into	:maxprocessid_exist separated by '', :maxprocessid separated by ''
			from 	connection to oledb
			(	
				select count(*) as maxprocessid_exist, max(vmine_kprocessid) as maxprocessid
				from  [dbo].[encounter_detail] as ed,
					  [dbo].[encounter_header] as eh 
				where ed.encounter_key=eh.encounter_key and 
					  ed.client_key=eh.client_key and 
					  eh.client_key=&client_id. and 
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
				from  [dbo].[encounter_detail] as ed,
					  [dbo].[encounter_header] as eh 
				where ed.encounter_key=eh.encounter_key and 
					  ed.client_key=eh.client_key and 
					  eh.client_key=&client_id. and 
					  ed.data_source_id = &practice_id.
			);
		  quit; 
		  
		  proc sql noprint;
			connect to oledb(init_string=&ciedw.);
			create table provider_header2 as select * from connection to oledb
			(	
				select distinct(provider_key) as provider_key
				from  [cihold].[dbo].[nl_hold_encounter_header_detail]  
				where client_key=&client_id.
				  and practice_key in (&practice_key.)
				  and provider_key <> 0
			);
		  quit; 
		  
		  data provider_header;
		   set provider_header1 provider_header2;
		  run;
		  
		  proc sort data = provider_header nodupkey;
		  by provider_key;
		  run;

			%*SASDOC--------------------------------------------------------------------------
			| Determine if new providers exist to extract a full history of claims 
			------------------------------------------------------------------------SASDOC*;
			%let npi_header_count=0;
			proc sql noprint;
			  select count(*) into: npi_header_count
			  from primary_provider_xref  as a,		         
				   provider_header        as b
			  where a.provider_key=b.provider_key;
			quit;
			  
			%set_error_flag;
			%on_error(ACTION=ABORT);
			
			/** 12.29.2011 - npi header count and npi provider count logic is not needed for non-vmine files - files are static  **/
		
			%if &maxprocessid_exist ne 0 /** and (&npi_header_count. = &npi_provider_count.)**/ %then %do;
			  %if &maxprocessid = . %then %let maxprocessid = 0;
			%end;
			%else %do;
			  %let maxprocessid = 0;
			%end;

		  options nosymbolgen;

		  %put NOTE: maxprocessid_exist     = &maxprocessid_exist. ; 
		  %put NOTE: maxprocessid           = &maxprocessid. ; 
		  %put NOTE: npi_header_count       = &npi_header_count. ; 
		  %put NOTE: npi_provider_count     = &npi_provider_count. ;  
		  %put NOTE: practice_key           = &practice_key. ;  
		  %put NOTE: practice_id/datasource = &do_practice_id. ; 
		  
		  options symbolgen;

			*SASDOC--------------------------------------------------------------------------
			| SAS - Get the PM System name to be able to call the correct read-in program.   
			|       Also get the directory where the flat file is located.
			+------------------------------------------------------------------------SASDOC*; 
			%data_source_information;
		   
			%mvarexist(FILENAME); 
			%if &mvarexist. %then %do;
				%put NOTE: Filename macro variable does exist. ;
			%end;
			%else %do;
				%put NOTE: Filename macro variable does not exist.  Setting the value to missing process HISTORICAL.;
				%global filename;
				%let filename=;
			%end;       
			
			%if "&filename" ne " " %then %do;
			  %let pmdir = \\skelta\c$\FTP_PGF;		  			  
			%end;
			%else %do;
			  %let pmdir= ;
			%end;

			options nosymbolgen;
			%put NOTE: pmdir    = &pmdir.;
			%put NOTE: filename = &filename.;
			%put NOTE: dataformatid  = &dataformatid. ;
			%put NOTE: sasfilelayout = &sasfilelayout. ; 
			%put NOTE: destinationdirectory = &destinationdirectory. ;
			%put NOTE: dataformatgroupid = &dataformatgroupid. ;
			%put NOTE: dataformatgroupdesc = &dataformatgroupdesc. ;
			options symbolgen; 
			

			*SASDOC--------------------------------------------------------------------------
			| SAS - Read in the PGF data.   
			| 
			| Create the final output dataset of the practice data and remove any
			| duplicates which may exist.  In addition, initialize and assign claim key, 
			| dq claim flag, member key, and dq member flag for subsequent processes.
			------------------------------------------------------------------------SASDOC*; 
			%vmine_pmsystem_byvars;
			%&sasfilelayout.;
			%set_error_flag;
			%on_error(ACTION=ABORT);
						
			%check_issue_count(dataset_in=practice_&do_practice_id., validation=60); 

			%end;  /** nlhold reprocess 1 **/
			%else %do;
			  %vmine_pmsystem_byvars;
			%end;
			

			*SASDOC--------------------------------------------------------------------------
			| Diagnosis - Cleanse diagnosis of length of 4 with decimal in 4th location     
			------------------------------------------------------------------------SASDOC*;
			%cleanse_diagnosis_length_4(dataset_in=practice_&do_practice_id.);			


			*SASDOC--------------------------------------------------------------------------
			| BPM - Create source counts             
			+------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
			  select count(*) into: src_record_cnt separated by ''
			  from practice_&do_practice_id. ;
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
			

			%if &issue_count ne 0 %then %do;	/**begin - issue_count **/		

			*SASDOC--------------------------------------------------------------------------
			| NL Hold Reprocess - Set practice key, interface, and enterprise member ID
			| for facilities and self pay data sources
			| 
			------------------------------------------------------------------------SASDOC*;
			%if %symexist(nlhold_reprocess) and &facility_indicator. = 1 %then %do;  /** nlhold reprocess - facility **/ 
				data practice_&do_practice_id.;
				  set practice_&do_practice_id.; 
				  practice_key=p_key;
				  interface=source_system_id;
				run; 
			%end;
			
			%if %symexist(nlhold_reprocess) and (&dataformatgroupid. = 14 or &dataformatgroupid. = 8) %then %do;  /** nlhold reprocess - self pays **/ 
				proc sql;
				  create table practice_&do_practice_id. as
				  select a.*,
				       b.enterprise_member_id 
				  from practice_&do_practice_id. (drop = enterprise_member_id) a left join 
				     vh_empi.client_member b
				  on input(a.system_member_id,20.)=input(b.system_member_id,20.)  
				    and a.source_system_id=b.source_system_id
				    and b.active_flag=1
				    and b.client_key=&client_id. ;
				quit;	
			%end;
			
			*SASDOC--------------------------------------------------------------------------
			| Client - Apply Provider Key Primary (vSource - provider practice definition)
			|
			| 1.  Assign practice key
			| 2.  Assign provider key
			------------------------------------------------------------------------SASDOC*;
			%edw_primsec_provider_xref(&client_id.,m2_datasource_id=&do_practice_id.,m2_inset=practice_&do_practice_id.);
			

			*SASDOC--------------------------------------------------------------------------
			| DQ Validation - Missing TINs
			------------------------------------------------------------------------SASDOC*;			
			%let group_count=0;
			proc sql noprint;
				select	count(*) into: group_count
				from	practice_&do_practice_id.
				where	provider_key ne 0 and verify(substr(tin,1,9),'0123456789');
			quit;
			
			%put NOTE: Claims with NPI and assigned provider key but no practice key = &group_count. ;

			%if &group_count ne 0 %then %do;
			  %put ERROR: There is an issue with the NPI and TIN assignment.  Enter information into cihold.dbo.npi_cleanse_rules for this practice.;
			  
			  %macro send_email_alert;
				filename mail_out email to=("bstropich@valencehealth.com" "bfletcher@valencehealth.com" "gliu@valencehealth.com" "wlee@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - NPI TIN Failed";

				data _null_;
				file mail_out lrecl=32767;   
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


			*SASDOC--------------------------------------------------------------------------
			| Facility Logic    
			------------------------------------------------------------------------SASDOC*;
			%put NOTE: facility_indicator = &facility_indicator. ;

			%if &facility_indicator. = 1 %then %do;	

				*SASDOC-------------------------------------------------------------------------
				|  Remove duplicates and output final dataset
				|
				|  Historical is set higher than 1 to prevent the linking algorithm
				|  to perform a standard onboarding of members through a 2 cycle process.
				|  Instead, this lets the linking algorithm to match both ssn and non-ssn 
				|  members in 1 pass.  This should be done for hospital, self pay i, 837i,
				|  and labs.
				|
				|------------------------------------------------------------------------SASDOC*;
				%facility_sort_routine(dataset_in=practice_&do_practice_id.);
				
				data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ; 
					format member_key 16.  ;
					set practice_&do_practice_id. ; 
					
					claim_key=_n_;
					dq_claim_flag=0;
					member_key=0;
					dq_member_flag=0;
					payer_key = 1;
					%if &maxprocessid. = 0 %then %do;
					  historical=5;
					  maxprocessid = 5;					
					%end;
					%else %do;
					  historical=&maxprocessid.;
					  maxprocessid = &maxprocessid.;
					%end;
					claim_source=&dataformatgroupid.;

				run;
			
			%end;	
			%else %do;
			
				*SASDOC-------------------------------------------------------------------------
				|  Remove duplicates and output final dataset   
				|
				|  PGFUPLOADER condition was added since some practices are classified
				|  as PGF
				|------------------------------------------------------------------------SASDOC*;
				proc sort data= practice_&do_practice_id. ;
					by &byvars0;
				run;

				data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.
						dups ; 
					format member_key 16.  ;
					set practice_&do_practice_id. (%if %symexist(nlhold_reprocess) %then %do;  
									   drop = admdt disdt
									 %end;);					
					by &byvars0;
					
					claim_key=_n_;
					dq_claim_flag=0;
					member_key=0;
					dq_member_flag=0;
					payer_key = 1;
					historical=&maxprocessid.;
					maxprocessid = &maxprocessid.;
					claim_source=&dataformatgroupid.;
					
					%if %upcase(%sysfunc(compress(&deliverytypedescription,' '))) = PGFUPLOADER %then %do;
					  claim_source=11;
					%end;
					/** after onboarding - new practices to be reflected within EDW instantly **/
					%if &dataformatgroupdesc. = PGF and %upcase(%sysfunc(compress(&deliverytypedescription,' '))) = PGFUPLOADER and %length(&filename) > 0 %then %do;
					  historical=2;
					  maxprocessid = 2;
					%end;		
					/** after onboarding - new practices to be reflected within EDW instantly **/
					%else %if &dataformatgroupdesc. = PGF and %length(&filename) > 0 %then %do;
					  historical=2;
					  maxprocessid = 2;
					%end;	
					
					if first.mod2 and last.mod2 then dupcount=.;
					else if first.mod2 then dupcount =0 ;
					else dupcount = 1;

					if first.mod2 then output cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;
					if dupcount ne . then output dups;

					%if %symexist(nlhold_reprocess) %then %do;  /** do not need for reprocess - non facility practices **/
					  drop enterprise_member_id source_system_id system_member_id;
					%end;
				run;
				
			%end;

			
			*SASDOC--------------------------------------------------------------------------
			| BPM - Create target counts             
			+------------------------------------------------------------------------SASDOC*;
			%let tgt_record_cnt = 0 ;
			proc sql noprint;
			  select count(*) into: tgt_record_cnt separated by ''
			  from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			quit;
			
			%check_issue_count(dataset_in=cistage.claims_&do_practice_id._&client_id._&wflow_exec_id., validation=60);

			%put NOTE:  tgt_record_cnt = &tgt_record_cnt;
			%put NOTE:  src_record_cnt = &src_record_cnt;

			%end;  /**end - issue_count **/

		%end;  /**end -  do_practice_id **/
    
	%end;  /**end - do while group_id **/

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
	

%mend edw_nonvmine_extract;
%edw_nonvmine_extract;











