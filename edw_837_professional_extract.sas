/*HEADER------------------------------------------------------------------------
|
| program:  edw_837_professional_extract.sas
|
| location: M:\ci\programs\standardmacros
|
| purpose:  extract 837 professional data (practice data)           
|
| input:    DEV : SQLCIDEV.EDI.CI_ProfessionalClaim (stored procedure)
|			PROD: SQL-CI.EDW.CI_ProfessionalClaim (stored procedure)
|
| output:   claims2 and cistage datasets
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 08NOV2011 - Winnie Lee  - Clinical Integration  1.0.01
|             Initiated
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
| 03MAY2012 - Winnie Lee - Clinical Integration Release 1.2 H07 and H02
|			- Added logic to include DATA_SOURCE_ID.
|			- Updated datasource_mlaexist to point to person_workflow_detail 
|			  table instead.
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
+-----------------------------------------------------------------------HEADER*/

/*options sasautos = ("M:\CI\programs\StandardMacros" sasautos);*/
/*options mprint mlogic symbolgen msglevel=i error=2 ls=120 ps=60;*/
/**/
/*%let maxprocessid = 24919000;*/
/*%let practice_id = 1004;*/
/*%let do_practice_id = 1004;*/
/*%let client_id = 6;*/
/*%let sysparm=%str(sas_mode=test); */
/*%let wflow_exec_id = 1000;*/
/*%bpm_environment;*/

%macro edw_837_professional_extract;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);

	*SASDOC--------------------------------------------------------------------------
	| Determine if there are any claims within ciedw 
	| 
	| This function is for the incremental claim extractions. We will only pull 
	| claims that exceed the process ID for the ETL process. 
	------------------------------------------------------------------------SASDOC*; 

	%data_source_information;

	proc sql noprint;
	    select 
	         distinct(b.practice_key) into: practice_key separated by ','
	    from ids.datasource_practice as a inner join
	         ciedw.practice as b on a.practiceid=b.vsource_practice_key 
	    where a.datasourceid=&practice_id. and b.vsource_practice_key ne .;
	quit;

   %put NOTE: practice_key = &practice_key;


	%if not %symexist(nlhold_reprocess) %then %do;  /** begin - nlhold reprocess 1 **/ 	

	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
			select 	
				maxprocessid_exist, 
				case when maxprocessid=. then 0
					 else maxprocessid			end as maxprocessid
			into	:maxprocessid_exist, 
					:maxprocessid
			from 	connection to oledb
			(	
				select 
					count(*) 				as maxprocessid_exist, 
					max(vMine_kprocessid) 	as maxprocessid
				from  [dbo].[encounter_detail] as ed left outer join
					  [dbo].[encounter_header] as eh on eh.encounter_key=ed.encounter_key and ed.client_key=eh.client_key
				where eh.client_key=&client_id. and 
					  eh.claim_source = &dataformatgroupid. and
					  ed.data_source_id = &practice_id.;
			);
	quit;

	%put NOTE: MaxProcessID Exist - &maxprocessid_exist., MaxProcessID - &maxprocessid.;

	%set_error_flag;
	%on_error(ACTION=ABORT);

	%end;  /** end - nlhold reprocess 1 **/ 	

	*SASDOC--------------------------------------------------------------------------
	| Delete claims dataset if it exists to prevent issues for the cycle of the ETL
	-----------------------------------------------------------------------SASDOC*;
	proc datasets library=cistage nolist;
	  delete claims_&practice_id._&client_id._&wflow_exec_id. ;
	quit;


	*SASDOC--------------------------------------------------------------------------
	| Begin looping through each practice_id, if there are multiple practice_ids
	-----------------------------------------------------------------------SASDOC*;
	%let dopid =0;
	%do %while (%scan(&practice_id., &dopid+1) ne ); 

		%let dopid  =%eval(&dopid+1);
		%let do_practice_id=%scan(&practice_id.,&dopid);

		%if not %symexist(nlhold_reprocess) %then %do;  /** begin - nlhold reprocess 2 **/ 	
	

		*SASDOC--------------------------------------------------------------------------
		| Check if DataSourceID needs to pull 837 Professional Claims from EDI
		|
		------------------------------------------------------------------------SASDOC*;
		proc sql noprint;
			connect to oledb(init_string=&edi.);
			select * into: claims_837P_cnt from connection to oledb
			(
				SELECT  COUNT(d.LineItemID) as cnt
				FROM [EDI].[dbo].[P_Claim] 			as h left outer join
					 [EDI].[dbo].[P_ClaimLineItem]	as d on h.ClaimUID=d.ClaimUID
				WHERE h.DataSourceID = &do_practice_id. and
					  h.ClaimID > &maxprocessid.
			);
		quit;

		%put NOTE: 837 Professionals Claim Count - &claims_837P_cnt.;

		%set_error_flag;
		%on_error(ACTION=ABORT);

		%end;  /** nlhold reprocess 2 **/ 	
	

		*SASDOC--------------------------------------------------------------------------
		| Pull 837 Professional Claims from EDI
		|
		------------------------------------------------------------------------SASDOC*;

		%if &claims_837P_cnt. > 0 %then %do;

			%if not %symexist(nlhold_reprocess) %then %do;  /** begin - nlhold reprocess 3 **/ 

			*SASDOC--------------------------------------------------------------------------
			| Determine if we have loaded this practice before, i.e. member information
			|	already existed in the satellite tables.
			------------------------------------------------------------------------SASDOC*;
			%let datasourceid_mlaexist=0;
			proc sql noprint;
				select	count(*)
				into	:datasourceid_mlaexist
				from	vh_empi.person_workflow_detail
				where	client_key=&client_id. and
						datasourceid=&practice_id.;
		  	quit;

			%put NOTE: DataSourceID_MLAExist - &datasourceid_mlaexist.;

			proc sql;
				connect to oledb(init_string=&edi.);
				create table practice_&do_practice_id. as select * from connection to oledb
				(
					exec dbo.CI_ProfessionalClaim &do_practice_id., &maxprocessid.
				);
			quit;

			%set_error_flag;
			%on_error(ACTION=ABORT);

			%end;  /** end - nlhold reprocess 3 **/ 


			*SASDOC--------------------------------------------------------------------------
			| BPM - Create source and target counts             
			+------------------------------------------------------------------------SASDOC*;
			proc sql noprint;
				select count(*) into: src_record_cnt
				from practice_&do_practice_id.;
			quit;

			%put NOTE: SRC_RECORD_CNT - &src_record_cnt.;
			

			*SASDOC--------------------------------------------------------------------------
			| 837 Professional Claims Clean Up
			|
			------------------------------------------------------------------------SASDOC*; 
			%if not %symexist(nlhold_reprocess) %then %do;  /** begin - nlhold reprocess 4 **/  

				data claims_&do_practice_id._2;
				length 	claimnum linenum $36. client_key datasourceid 8. source $1. system $16. filename $50. filed $8. claim_source 3.
						practice $50. tin $9. npi NPI2 $10. provname $50. RenderingProviderQualifier $1.
						patientaccountnumber medicalrecordnumber $50. ClaimFrequencyCode $2. 
						memberid $9 ssn $11. lname $25. fname $15. mname $15. dob dod 8. sex $1. address1 address2 $50. city $25. state $2. zip $5. phone $10.
						svcdt moddt 8. diag1-diag9 $6. proccd $5. mod1-mod3 $2. units 8. pos $2.
						ID $20. IndividualRelationshipCode $2. payorid1 $36. npayorid1 $9.  payorname1 $50. maxprocessid 8.;
				format 	svcdt moddt FileDt DOB DOD mmddyy10. PatientAccountNumber $50. MedicalRecordNumber $50. ClaimFrequencyCode $2.
						ssn $9. lname $25. fname $15. address1 $50. city $25. state $2. zip $5.
						diag1-diag9 $6. proccd $5. pos $2. submit dollar10.2 mod1-mod3 $2. 
						payorname1 $50. id $20. individualrelationshipcode $2. practice $50. tin $9. RenderingProviderQualifier;

				set practice_&do_practice_id. (keep = ClientID DataSourceID FileName
													ClaimID LineNumber DateEntered 
													RenderingProviderFirstName RenderingProviderLastName RenderingProviderID RenderingProviderQualifier ServiceFacilityID tin practice
													ssn fname lname mname DateOfDeath DateOfBirth
													address1 city state zip sex weight pregID ID IndividualRelationshipCode
													ServiceFromDate TransactionSetDate diag1-diag8 proccd mod1-mod3 units pos submit
													payorname1 PayerPrimaryID PatientAccountNumber MedicalRecordNumber ClaimSubmissionReasonCode					    
										   rename = (ClaimSubmissionReasonCode=ClaimFrequencyCode filename=_filename));
				client_key = clientid;
				practice_id = datasourceid;
				filedt = datepart(DateEntered);
				filename = scan(_filename,-1,"\");
				filed = put(filedt,yymmddn8.);
				
				if length(RenderingProviderID) = 10 then npi = cats(RenderingProviderID);
				else if length(RenderingProviderID) = 9 and tin = "" then tin = cats(RenderingProviderID);

				npi2 = cats(ServiceFacilityID);

				if RenderingProviderLastName ne "" and RenderingProviderFirstName ne "" then 
					provname = cats(RenderingProviderLastName) || ", " || cats(RenderingProviderFirstName);
				else if RenderingProviderLastName ne "" then provname = cats(RenderingProviderLastName);

				dob = input(DateOfBirth,yymmdd10.);
				dod = input(DateOfDeath,yymmdd10.);
				if dod > today() then dod = .;

				svcdt = input(ServiceFromDate,yymmdd10.);
				moddt = input(TransactionSetDate,yymmdd10.);

				source = "P";
				system = "837_PROFESSIONAL";
				claim_source = &dataformatgroupid.;
				memberid = compress(trim(left(ssn)),"-");
				phone = "";
				diag9 = "";
				payorid1 = substr(cats(PayerPrimaryID),1,36);
				npayorid1 = substr(cats(PayerPrimaryID),1,5);

				claimnum = trim(left(PatientAccountNumber));
				linenum  = trim(left(linenumber));
				
				maxprocessid = claimid * 1;


				keep 	client_key practice_id claimnum linenum filedt source system filename filed
					  	provname npi tin
					 	patientaccountnumber medicalrecordnumber memberid ssn lname fname mname dob dod sex address1-address2 city state zip phone
					 	svcdt moddt diag1-diag9 proccd mod1-mod2 units submit pos
						payorid1 payorname1 maxprocessid claim_source;

				%empi_837_professional(client_id=&client_id.);

				run;

			%end;
			%else %do;

				data claims_&do_practice_id._2; 
				format  filedt dod mmddyy10. ;
				set practice_&do_practice_id. ;

				filedt = today(); 
				filed = put(filedt,yymmddn8.);
				npi2 = '';  
				dod = .;

				source = "P";
				system = "837_PROFESSIONAL";
				claim_source = &dataformatgroupid.;
				memberid = compress(trim(left(ssn)),"-");
				phone = "";
				diag9 = "";
				payorid1 = '';
				npayorid1 = '';  

				PatientAccountNumber = trim(left(claimnum));
				medicalrecordnumber='';


				keep 	client_key practice_id claimnum linenum filedt source system filename filed
					  	provname npi tin
					 	patientaccountnumber medicalrecordnumber memberid ssn lname fname mname dob dod sex address1-address2 city state zip phone
					 	svcdt moddt diag1-diag9 proccd procedure_code_key mod1-mod2 units submit pos
						payorid1 payorname1 maxprocessid claim_source;

				%empi_837_professional(client_id=&client_id.);

				run;

			%end;

			%set_error_flag;
			%on_error(ACTION=ABORT);


			*SASDOC--------------------------------------------------------------------------
			| Client - Apply Provider Key Primary (vSource - provider practice definition)
			|
			| 1.  Assign practice key
			| 2.  Assign provider key
			------------------------------------------------------------------------SASDOC*;

			/**CREATE PROVIDER PRACTICE TABLE**/
			proc sql;
				create table providerpractice as
				select distinct
					p.provider_key,
					p.npi1				as npi length=10,
					pg.practice_key,
					pg.primary_practice_ind,
					g.tin				as tin length=9,
					p.provider_name,
					g.practice_name,
					datepart(min(coalesce(p.clncl_int_exp_dt,datetime()),coalesce(pg.exp_dt,datetime()))) as ci_term_date format=mmddyy10.
				from ciedw.provider 			  as p left outer join
					 ciedw.provider_practice_xref as pg on p.provider_key=pg.provider_key and p.client_key=pg.client_key left outer join
					 ciedw.practice 			  as g  on pg.practice_key=g.practice_key and pg.client_key=g.client_key
				where p.client_key = &client_id. and p.npi1 is not null and g.tin is not null
				order by p.npi1, g.tin, ci_term_date
				;
			quit;

			%set_error_flag;
			%on_error(ACTION=ABORT);

			/**CHECK PROVIDER PRACTICE UNIQUE NPI AND TIN COMBINATION**/
			data providerpractice2;
			set providerpractice;
			by npi tin;
			if first.tin and last.tin then duplicate_npi_tin = 0;
			else duplicate_npi_tin = 1;
			run;

			data _null_;
			set providerpractice2;
			where duplicate_npi_tin = 1;
			if _n_ =1 then put "TITLE - DUPLICATE NPI TIN COMBINATION";
			put _n_ duplicate_npi_tin provider_name  practice_name ;			
			run;


			/**CREATE PROVIDER_KEY AND PRACTICE_KEY BASED UPON UNIQUE NPI AND TIN COMBINATION**/
			proc sql;
				create table claims_&do_practice_id._3 as
				select
					a.*,
					coalesce(b.provider_key,0)									as provider_key,
					case when a.svcdt le b.ci_term_date then b.practice_key
						 else 0												end as practice_key,
					case when a.svcdt le b.ci_term_date then b.practice_key
						 else 0 											end as group_id
				from claims_&do_practice_id._2 as a left outer join
					 providerpractice2 		as b on a.npi=b.npi and a.tin=b.tin and duplicate_npi_tin = 0
				order by a.npi, a.tin
				;
			quit;

			%set_error_flag;
			%on_error(ACTION=ABORT);


			/**CHECK FOR UNIQUE NPI PROVIDER RECORDS**/
			proc sort data=providerpractice2 (keep=npi provider_key provider_name ci_term_date) nodupkey out=provider;
			by npi provider_key;
			run;

			data provider2
				 provider_dups;
			set provider;
			by npi;
			if first.npi and last.npi then output provider2;
			else output provider_dups;
			run; 
			
			data _null_;
			set provider_dups; 
			if _n_ =1 then put "TITLE - SAME NPI UNDER 2 DIFFERENT PROVIDER_KEYS";
			put _n_ provider_name  ;			
			run; 

			/**CREATE PROVIDER_KEY FOR CLAIMS WHERE PROVIDER IS MOONLIGHTING AT OTHER PRACTICES**/
			data claims_&do_practice_id._4 (drop=provider_key2);
			merge claims_&do_practice_id._3 (in=a)
				  provider2 	(in=b keep=provider_key npi rename=provider_key=provider_key2);
			by npi;
			if a then do;
				if provider_key in (0,.) and provider_key2 ne . then provider_key=provider_key2;
				output;
			end;
			run;

			%set_error_flag;
			%on_error(ACTION=ABORT);

			
			*SASDOC--------------------------------------------------------------------------
			| Client - Apply CI Start Date Filter and NPI Cleansing and Edits     
			------------------------------------------------------------------------SASDOC*;
			data ci_start_date;
			format start_date mmddyy10.;
			set ciedw.client (where = (client_key=&client_id.));
			start_date = datepart(ci_start_date);	  
			keep start_date;
			run;

			%create_npi_cleanse_rules;

			data claims_&do_practice_id._5;
			if _n_ = 1 then set ci_start_date;
			set claims_&do_practice_id._4;
			if svcdt >= start_date ;

			/**%edw_npi_cleansing_rules;**/
			%include "&cistage.\npi_cleanse_rules_&wflow_exec_id..txt";

			run;

			
			*SASDOC--------------------------------------------------------------------------
			| First round of removing duplicates
			|
			------------------------------------------------------------------------SASDOC*; 
			%vmine_pmsystem_byvars;

			proc sort data=claims_&do_practice_id._5 out=practice_&do_practice_id.;
			by &byvars000.;
			run;

			data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.  
				 dups;
			format member_key 16.;
			set practice_&do_practice_id.;
			by &byvars000.;

			claim_key=_n_;
			dq_claim_flag=0;
			member_key=0;
			dq_member_flag=0;
			wflow_exec_id=&wflow_exec_id.; 

			/*if &datasourceid_mlaexist. = 0 then historical=0;*/ /* onboarding first pass */
			/*else historical=2;*/
			historical = 2;

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
				select 
					count(*) into: tgt_record_cnt
				from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			quit;

			%put NOTE: TGT_RECORD_CNT - &tgt_record_cnt.;

			proc sql noprint;
				select 
					count(*) into: issue_count
				from cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
			quit;

			proc sql noprint;
				select 
					count(*) into: increment_count
				from practice_&do_practice_id. ;
			quit;

			%if &issue_count eq 0 %then %do;
				%put ERROR: There are 0 observations within cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
				%bpm_additional_validations(validation_rule=60,validation_count=&issue_count.);
				%let err_fl=1;
				%set_error_flag;
				%on_error(ACTION=ABORT);
			%end;
			%else %if &increment_count ne 0 %then %do;
				%put NOTE: The creation of cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. was successful.;
			%end;

		%end; /** END &claims_837P_cnt. > 0 LOOP **/

		%else %do;
			%let src_record_cnt = 0;
			%let tgt_record_cnt = 0;

			%put ERROR: There are no claims within EDI for 837 Professional Practice - &do_practice_id.;

			%macro send_email_alert;
				filename mail_out email to="wlee@valencehealth.com" subject="CIO Work Flow &wflow_exec_id. - No Claims 837 Professional Failed";

				data _null_;
				file mail_out lrecl=32767;  
				put "837 Professional";
				put "practice ID = &do_practice_id.";
				run;
			%mend send_email_alert;
			%send_email_alert;

		    %bpm_additional_validations(validation_rule=52,validation_count=0);
			
			%let err_fl=1;
			%set_error_flag;
			%on_error(ACTION=ABORT);	
		%end;

	%end;  /**end do_practice_id **/
	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.  
	| 
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);

%mend edw_837_professional_extract;

%edw_837_professional_extract;
