
/*HEADER------------------------------------------------------------------------
|
| program:  edw_claims_pgf_extract.sas
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
+-----------------------------------------------------------------------HEADER*/


%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
/**"sk_prcs_ctrl_id=1 wflow_exec_id=8 sas_prgm_id=12 client_id=4 system_id=0 group_id=710 pgf_practice= sas_mode=prod filename=710-20110825T09400000.txt" **/

options mprint mlogic symbolgen;

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
%macro edw_pgf_extract;

	%vmine_pmsystem_byvars;

	proc sql noprint;
        select practiceid into: pract_id
        from ids.datasource_practice
        where datasourceid=&group_id;
    quit;

    %let practice_id = %cmpres(&pract_id);

	proc datasets library=cistage nolist;
	  delete claims_&group_id._&client_id._&wflow_exec_id. ;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);

	%let dopid =0;
	%do %while (%scan(&group_id., &dopid+1) ne );  /**begin - do while group_id **/

		%let dopid  =%eval(&dopid+1);
		%let do_practice_id=%scan(&group_id.,&dopid);
    
		%if &do_practice_id. ne 0 %then %do ;  /**begin - do_practice_id **/


			%*SASDOC--------------------------------------------------------------------------
			| Determine the list of active providers and practices from the ciedw  
			------------------------------------------------------------------------SASDOC*;	
			proc sql;
				create table provider_practice_xref as
				select distinct a.provider_key, 
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
				where b.datasourceid=&group_id
				  and a.client_key=&client_id.
				  and c.clncl_int_eff_dt < datetime()
				  and c.clncl_int_exp_dt = .
				  and a.exp_dt = .;
			quit;
			  
			data _null_;
			  set provider_practice_xref;
			  put _all_;
			run;

			proc sql noprint;
			  select distinct(provider_key) into: provider_list separated by ','
			  from provider_practice_xref ;
			quit;

			proc sql noprint;
			  select count(distinct(provider_key)) into: npi_provider_count
			  from provider_practice_xref;
			quit;      
			  
			%put NOTE: practice_id = &practice_id. ; 
			%put NOTE: npi_provider_count = &npi_provider_count. ;  
			%put NOTE: provider_list = &provider_list ;

			%let maxprocessid = 0;
		
			%*SASDOC--------------------------------------------------------------------------
			| Determine if there are any claims within ciedw  
			------------------------------------------------------------------------SASDOC*; 
			proc sql noprint;
				connect to oledb(init_string=&ciedw.);
				select maxprocessid_exist into: maxprocessid_exist from connection to oledb
				(	
					select count(*) as maxprocessid_exist
					from [dbo].[encounter_detail] as ed,
						 [dbo].[encounter_header] as eh 
					where ed.encounter_key=eh.encounter_key 
					  and eh.practice_key in (&practice_id.)
				);
			quit;	

			%*SASDOC--------------------------------------------------------------------------
			| Determine the list of providers from the ciedw claims 
			------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
				connect to oledb(init_string=&ciedw.);
				create table provider_header as select * from connection to oledb
				(	
					select distinct(provider_key) as provider_key
					from [dbo].[encounter_detail] as ed,
						 [dbo].[encounter_header] as eh 
					where ed.encounter_key=eh.encounter_key 
					  and eh.provider_key in (&provider_list.)
				);
			quit; 

			%*SASDOC--------------------------------------------------------------------------
			| Determine if new providers exist to extract a full history of claims 
			------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
			  select count(*) into: npi_header_count
			  from provider_practice_xref as a,		         
				   provider_header        as b
			  where a.provider_key=b.provider_key;
			quit;
			  
			%put NOTE: maxprocessid_exist = &maxprocessid_exist. ; 
			%put NOTE: npi_header_count = &npi_header_count. ; 

			%set_error_flag;
			%on_error(ACTION=ABORT);

			%if &maxprocessid_exist ne 0 and (&npi_header_count. = &npi_provider_count.) %then %do;

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

			*SASDOC--------------------------------------------------------------------------
			| SAS - Get the PM System name to be able to call the correct read-in program.   
			|       Also get the directory where the flat file is located.
			+------------------------------------------------------------------------SASDOC*; 
			proc sql noprint;
			   select distinct left(lowcase(dataformatdescription)), left(lowcase(compress(dataformatdescription)))  into: pmsys, :pmsyst
			   from ids.dataformat a,
					ids.datasource b
			   where a.dataformatid=b.dataformatid 
				 and b.clientid=&client_id. 
				 and b.datasourceid=&do_practice_id.    ;
			quit;

			%let pmsysu = %upcase(&pmsyst);

			%put NOTE: pmsys = &pmsys;
			%put NOTE: pmsyst = &pmsyst;
			%put NOTE: pmsysu = &pmsysu;
			%put NOTE: edw_pgf_&pmsyst..sas ;
		   
		   
			%mvarexist(FILENAME); 
			%if &mvarexist. %then %do;
				%put NOTE: Filename macro variable does exist. ;
			%end;
			%else %do;
				%put NOTE: Filename macro variable does not exist.  Setting the value to missing process HISTORICAL.;
				%global filename;
				%let filename=;
			%end;
       
			/************* no longer needed but left in for testing purposes
			proc sql noprint;
				select compress(left(upcase(destinationdirectory))) into :pmdir
				from ids.dataformat a,ids.datasource b
				where a.dataformatid = b.dataformatid
				  and b.clientid = &client_id.
				  and upcase(dataformatdescription) = "&pmsysu."
				;
			quit;
			**************/

			%let pmdir= ;
			%if "&filename" ne " " %then %do;
			  
			  %let pmdir = \\fs\NSAP\Data\CI\PGF\HealthNautica\stuson\Current_Extract; /** test - healthnautica 123 710 **/
			  %let pmdir = \\skelta\c$\FTP_PGF;
			  
			%end;

			%put NOTE: pmdir = &pmdir.;
			%put NOTE: filename = &filename.;

			*SASDOC--------------------------------------------------------------------------
			| SAS - Get the Client name for the read-in program.   
			|  NOTE:  May not be necessary if we go with a more centralized PGF repository
			| 
			+------------------------------------------------------------------------SASDOC*; 
			proc sql noprint;
			  select distinct left(upcase(clientname)) into: clntname
			  from ids.client
			  where clientid=&client_id. ;
			quit;

			%global clientname;
			%let clientname = %cmpres(&clntname.);
			%put NOTE: Clientname = &clientname.;

			*SASDOC--------------------------------------------------------------------------
			| SAS - Read in the PGF data.   
			| 
			| Create the final output dataset of the practice data and remove any
			| duplicates which may exist.  In addition, initialize and assign claim key, 
			| dq claim flag, member key, and dq member flag for subsequent processes.
			------------------------------------------------------------------------SASDOC*; 
			%edw_pgf_&pmsyst.;
			%set_error_flag;
			%on_error(ACTION=ABORT);

			proc sql noprint;
			  select count(*) into: issue_count
			  from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			quit;

			proc sql noprint;
			  select count(*) into: increment_count
			  from claims2 ;
			quit;

			%if &issue_count eq 0 %then %do;
			  %put ERROR: There are 0 observations within cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			%end;
			%else %if &increment_count ne 0 %then %do;
			  %put NOTE: The creation of cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. was successful.;
			%end;

			%if &issue_count ne 0 %then %do;	/**begin - issue_count **/		
			
				proc sql;
					create table primary_provider_xref as
					select a.provider_key, 
						   a.client_key, 
						   a.practice_key,  
						   c.npi1, 
						   c.provider_name, 
						   d.tin
					from ciedw.provider_practice_xref as a left join 
						 ciedw.provider as c
					on a.provider_key=c.provider_key left join
						 ciedw.practice as d
					on a.practice_key=d.practice_key		    
					where a.practice_key in (&practice_id.)
					  and a.client_key = &client_id.
					  and c.clncl_int_eff_dt < datetime()
					  and c.clncl_int_exp_dt = .
					  and a.exp_dt = .;
				quit;

				proc sql;
				  create table secondary_provider_xref as
				  select c.provider_key, c.client_key, c.npi1, c.provider_name
				  from ciedw.provider as c 	    
				  where c.client_key = &client_id.
					and c.clncl_int_eff_dt < datetime()
					and c.clncl_int_exp_dt = . ;
				quit;
			  
				%*SASDOC--------------------------------------------------------------------------
				| Client - Apply Provider Key Primary (vSource - provider practice definition)
				|
				| 1.  Assign practice key
				| 2.  Assign provider key
				------------------------------------------------------------------------SASDOC*;
				proc sql;
				  create table cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. as 
				  select a.*, 
					 coalesce(b.practice_key,0) as group_id,
					 coalesce(b.practice_key,0) as practice_key, 
					 coalesce(b.provider_key,0) as provider_key 
				  from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. as a left join
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
				  create table cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. as 
				  select a.*,  
					 coalesce(b.provider_key,0) as provider_key_secondary
				  from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. as a left join
				   secondary_provider_xref as        b
				  on a.npi=b.npi1  ;
				quit;
				
				data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
				 set cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;
				 if provider_key = 0 then provider_key=provider_key_secondary;
				run;
				
				*SASDOC-------------------------------------------------------------------------
				|  Remove duplicates and output final dataset                         
				|------------------------------------------------------------------------SASDOC*;
				proc sort data= cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
					by &byvars0;
				run;

				data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.
						dups ; 
					format member_key 16.  ;
					set cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;
					by &byvars0;
					
					claim_key=_n_;
					dq_claim_flag=0;
					member_key=0;
					dq_member_flag=0;
					payer_key = 1;
					historical=&maxprocessid.;
					maxprocessid = &maxprocessid.;

					if first.mod2 and last.mod2 then dupcount=.;
					else if first.mod2 then dupcount =0 ;
					else dupcount = 1;

					if first.mod2 then output cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;
					if dupcount ne . then output dups;
				run;

				proc sql noprint;
				 select count(*) into: issue_count
				 from cistage.claims_&group_id._&client_id._&wflow_exec_id. ;
				quit;

				%let src_record_cnt=&increment_count;
				%let tgt_record_cnt=&issue_count;
				%put NOTE:  count_src = &increment_count;
				%put NOTE:  count_tgt = &issue_count;

			%end;  /**end - issue_count **/

		%end;  /**end -  do_practice_id **/
    
	%end;  /**end - do while group_id **/

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);

%mend edw_pgf_extract;
%edw_pgf_extract;











