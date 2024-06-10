
/*HEADER------------------------------------------------------------------------
|
| program:  edw_uploader_extract.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create practice data from the pgf uploader files
|
| logic:                     
|
| input:    Macro parameters and /or SQL server practices
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           practice_id - opitional field but the practice id from EDW practice table (e.g., 256) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|                        
| output:   Staging dataset for the PGF Uploader practice
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/


%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

/**%let sysparm=%str(sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=12 client_id=4 system_id=1 practice_id=742 pgf_practice= sas_mode=prod); **/
/**%let sysparm=%str(sk_prcs_ctrl_id=1  wflow_exec_id=8 sas_prgm_id=12 client_id=4 system_id=1 practice_id=743 pgf_practice= sas_mode=prod); **/



*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment;


*SASDOC--------------------------------------------------------------------------
| Macro -  vmine_loop      
|
| Process a practice data file for a particular client
------------------------------------------------------------------------SASDOC*; 
%macro edw_uploader_extract;

	proc datasets library=cistage nolist;
	 delete claims_&practice_id._&client_id._&wflow_exec_id. ;
	quit;
	

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);

	%let dopid =0;
	%do %while (%scan(&practice_id., &dopid+1) ne );  /**begin do_practice_id **/

		%let dopid  =%eval(&dopid+1);
		%let do_practice_id=%scan(&practice_id.,&dopid);

		/**%let do_practice_id=&practice_id.;**/
    
		%if &do_practice_id. ne 0 %then %do ;  /**start - sysmexist - kprocessid **/


		    %*SASDOC--------------------------------------------------------------------------
		    | Determine the list of active providers and practices from the ciedw  
		    ------------------------------------------------------------------------SASDOC*;	
		  proc sql noprint;
		    select distinct(practiceid) into: vlink_id separated by ','
		    from ids.datasource_practice
			where datasourceid=&practice_id.;
		  quit;
		  
		  proc sql;
		    create table secondary_provider_xref as
		    select c.provider_key, c.client_key, c.npi1, c.provider_name
		    from ciedw.provider as c 	    
		    where c.client_key = &client_id.
              and c.clncl_int_eff_dt < datetime()
              and c.clncl_int_exp_dt = . ;
		  quit;

		  proc sql;
		    create table primary_provider_xref as
		    select a.provider_key, 
                   a.client_key, 
                   a.practice_key, 
                   b.practiceid as vmine_key, 
                   c.npi1, 
                   c.provider_name, 
                   d.tin
		    from ciedw.provider_practice_xref as a left join
		         ids.datasource_practice as b
		    on a.practice_key=b.practiceid left join
		         ciedw.provider as c
		    on a.provider_key=c.provider_key left join
		         ciedw.practice as d
		    on a.practice_key=d.practice_key		    
		    where b.datasourceid=&practice_id
		      and a.client_key=&client_id
              and c.clncl_int_eff_dt < datetime()
              and c.clncl_int_exp_dt = .
              and a.exp_dt = .;
		  quit;

		  data _null_;
		   set primary_provider_xref;
		   put _all_;
		  run;


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
	
		  %let maxprocessid = 0;
	
		%*SASDOC--------------------------------------------------------------------------
		| Determine if there are any claims within ciedw 
		| 
		| This function is for the incremental claim extractions. We will only pull 
		| claims that exceed the process ID for the ETL process. 
		------------------------------------------------------------------------SASDOC*; 
		  proc sql noprint;
			connect to oledb(init_string=&ciedw.);
			select maxprocessid_exist into: maxprocessid_exist from connection to oledb
			(	
				select count(*) as maxprocessid_exist
				from  [dbo].[encounter_detail] as ed,
					  [dbo].[encounter_header] as eh 
				where ed.encounter_key=eh.encounter_key
						  and eh.practice_key in (&vlink_id.)
			);
		  quit;	

		%*SASDOC--------------------------------------------------------------------------
		| Determine the list of providers from the ciedw claims 
		| 
		| This function is for determining if a full historical claim extraction is 
		| needed for any new providers. 
		------------------------------------------------------------------------SASDOC*;
		  proc sql noprint;
			connect to oledb(init_string=&ciedw.);
			create table provider_header as select * from connection to oledb
			(	
				select distinct(provider_key) as provider_key
				from  [dbo].[encounter_detail] as ed,
					  [dbo].[encounter_header] as eh 
				where ed.encounter_key=eh.encounter_key
						  and eh.practice_key in (&vlink_id.)
			);
		  quit; 

		%*SASDOC--------------------------------------------------------------------------
		| Determine if new providers exist to extract a full history of claims 
		------------------------------------------------------------------------SASDOC*;
		  proc sql noprint;
		    select count(*) into: npi_header_count
		    from primary_provider_xref  as a,		         
		         provider_header        as b
            where a.provider_key=b.provider_key;
		  quit;
		  
		  %put NOTE: maxprocessid_exist = &maxprocessid_exist. ; 
		  %put NOTE: npi_header_count   = &npi_header_count. ; 
		  %put NOTE: npi_provider_count = &npi_provider_count. ; 
		  %put NOTE: datasource         = &vlink_id. ;  
		  %put NOTE: practice_id        = &practice_id. ; 

	
		%*SASDOC--------------------------------------------------------------------------
		| Determine if there are any claims within ciedw 
		| 
		| This function is for the incremental claim extractions. We will only pull 
		| claims that exceed the process ID for the ETL process. 
		------------------------------------------------------------------------SASDOC*; 
		  proc sql noprint;
			connect to oledb(init_string=&ciedw.);
			select maxprocessid_exist into: maxprocessid_exist from connection to oledb
			(	
				select count(*) as maxprocessid_exist
				from  [dbo].[encounter_detail] as ed,
					  [dbo].[encounter_header] as eh 
				where ed.encounter_key=eh.encounter_key
						  and eh.practice_key in (&vlink_id.)
			);
		  quit;	

			%set_error_flag;
			%on_error(ACTION=ABORT);

			%if &maxprocessid_exist ne 0 %then %do;

			  proc sql noprint;
				connect to oledb(init_string=&ciedw.);
				select maxprocessid into: maxprocessid from connection to oledb
				(	
					select max(vmine_kprocessid) as maxprocessid
					from  [dbo].[encounter_detail] as ed,
						  [dbo].[encounter_header] as eh 
					where ed.encounter_key=eh.encounter_key
							  and eh.practice_key in (&practice_id.)
				);
			  quit;	

			  %if &maxprocessid = . %then %let maxprocessid = 0;

		    %end;
		    %else %do;
		      %let maxprocessid = 0;
		    %end;
		    
		    %let maxprocessid = 2;

				 

			*SASDOC--------------------------------------------------------------------------
			| SAS - Get the PM System name to be able to call the correct read-in program.   
			| 
			+------------------------------------------------------------------------SASDOC*; 
			%let pmsys=uploader;
			%let pmsys = %cmpres(&pmsys);

			%put NOTE: pmsys = &pmsys; 
			%put NOTE: edw_&pmsys..sas ;

			*SASDOC--------------------------------------------------------------------------
			| SAS - Get the Client name for the read-in program.   
			|  NOTE:  May not be necessary if we go with a more centralized PGF repository
			| 
			+------------------------------------------------------------------------SASDOC*; 
			proc sql noprint;
			   select distinct left(upcase(clientshort)) into: clientname
			   from vlink.dtblclient
			   where clientid=&client_id.  ;
			quit;

			%let clientname = %cmpres(&clientname.);
			%put NOTE: Clientname = &clientname. ;


			%*SASDOC--------------------------------------------------------------------------
			| SAS - Read in the lab data
			|
			------------------------------------------------------------------------SASDOC*; 
			%edw_&pmsys.;
			%set_error_flag;
			%on_error(ACTION=ABORT);
			

			*SASDOC--------------------------------------------------------------------------
			| BPM - Create source and target counts             
			+------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
			  select count(*) into: src_record_cnt
			  from practice_&do_practice_id.  ;
			quit;
			

			%*SASDOC--------------------------------------------------------------------------
			| Client - Apply CI Start Date Filter and NPI Cleansing and Edits     
			------------------------------------------------------------------------SASDOC*;
			data ci_start_date;
			  format start_date mmddyy10.  ;
			  set ciedw.client (where = (client_key=&client_id. ));
			  start_date=datepart(ci_start_date);	  
			  keep start_date;
			run;

			data practice_&do_practice_id. ;
			  if _n_ = 1 then set ci_start_date ;
			  set practice_&do_practice_id. ;
			  if svcdt >= start_date ;
			  %edw_npi_cleansing_rules;
			run;
			
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
			  %let err_fl=1;
			  %set_error_flag;
		  	  %on_error(ACTION=ABORT);
			%end;	
			
			

			%*SASDOC--------------------------------------------------------------------------
			| Client - Apply Provider Key Primary (vSource - provider practice definition)
			|
			| 1.  Assign practice key
			| 2.  Assign provider key
			------------------------------------------------------------------------SASDOC*;
			proc sql;
			  create table practice_&do_practice_id. as 
			  select a.*, 
				 coalesce(b.practice_key,0) as group_id,
				 coalesce(b.practice_key,0) as practice_key,
				 coalesce(b.provider_key,0) as provider_key
			  from practice_&do_practice_id. as a left join
			   primary_provider_xref as        b
		      on a.npi=b.npi1 
		       and a.tin=b.tin;
		    quit; 
		    
			%*SASDOC--------------------------------------------------------------------------
			| Client - Apply Provider Key Secondary (vSource - provider cipar definition) 
			|
			| 1.  Assign provider key 
			------------------------------------------------------------------------SASDOC*;		    
			proc sql;
			  create table practice_&do_practice_id. as 
			  select a.*,  
				 coalesce(b.provider_key,0) as provider_key_secondary
			  from practice_&do_practice_id. as a left join
			   secondary_provider_xref as        b
		      on a.npi=b.npi1  ;
		    quit;
		    
		    data practice_&do_practice_id. ;
		     set practice_&do_practice_id. ;
		     if provider_key = 0 then provider_key=provider_key_secondary;
		    run;
			
			proc sql noprint;
			  select count(*) into: group_count
			  from practice_&do_practice_id. 
			  where group_id ne 0;
			quit;
			
			%put NOTE: group_count = &group_count. ;

			%if &group_count eq 0 %then %do;
			  %put ERROR: There is an issue with the NPI and TIN assignment.  Edit the edw_npi_cleansing_rules.sas for this practice. ;
			  %let err_fl=1;
			  %set_error_flag;
		  	  %on_error(ACTION=ABORT);
			%end;			
	
			*SASDOC-------------------------------------------------------------------------
			|  Remove duplicates and output final dataset                         
			|------------------------------------------------------------------------SASDOC*;
			%vmine_pmsystem_byvars;
			
			proc sort data=practice_&do_practice_id.;
			  by &byvars00.;
			run;
			
			
			%*SASDOC--------------------------------------------------------------------------
			| Create the final output dataset of the practice data and remove any
			| duplicates which may exist.  In addition, initialize and assign claim key, 
			| dq claim flag, member key, and dq member flag for subsequent processes.
			|
			------------------------------------------------------------------------SASDOC*; 
			data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. 
				 dups ; 
			  format member_key 16. ;
			  set practice_&do_practice_id. ;
				historical=2;
				claim_key=_n_;
				dq_claim_flag=0;
				member_key=0;
				dq_member_flag=0;
				payer_key = 1;
				maxprocessid=&maxprocessid.;
			  by &byvars0.;
			  if first.mod2 and last.mod2 then dupcount=.;
			  else if first.mod2 then dupcount =0 ;
			  else dupcount = 1;     
			  if first.mod2 then output cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;
			  if dupcount ne . then output dups;
			run;
			
			
			*SASDOC--------------------------------------------------------------------------
			| BPM - Create source and target counts             
			+------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
			  select count(*) into: tgt_record_cnt
			  from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			quit;

			proc sql noprint;
			  select count(*) into: issue_count
			  from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			quit;

			proc sql noprint;
			  select count(*) into: increment_count
			  from practice_&do_practice_id. ;
			quit;

			%put NOTE: increment_count = &increment_count. ;

			%if &issue_count eq 0 %then %do;
			  %put ERROR: There are 0 observations within cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			  %let err_fl=1;
			  %set_error_flag;
		  	  %on_error(ACTION=ABORT);
			%end;
			%else %if &increment_count ne 0 %then %do;
			  %put NOTE: The creation of cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. was successful.;
			%end;

		%end;  /**end - sysmexist - kprocessid **/
		%else %do;
		    %put ERROR: There are no claims within CIMaster for System - &system_id. Practice - &do_practice_id.;
			%let err_fl=1;
			%set_error_flag;
		  	%on_error(ACTION=ABORT);			
		%end;		
    
   
	%end;  /**end do_practice_id **/

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);

%mend edw_uploader_extract;
%edw_uploader_extract;











