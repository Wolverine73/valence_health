/*HEADER------------------------------------------------------------------------
|
| program:  edw_837_institutional_extract.sas
|
| location: M:\ci\programs\standardmacros
|
| purpose:  extract 837 institutional data (hospital data)           
|
| input:    DEV : SQLCIDEV.EDI.CI_InsitutionalClaim (stored procedure)
|			PROD: SQL-CI.EDW.CI_InstitutionalClaim (stored procedure)
|
| output:   claims2 and cistage datasets
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 30NOV2011 - Winnie Lee  - Clinical Integration  1.0.01
|             Initiated
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 M01
|			  Added member's DOD.
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

/*%let maxprocessid = 19620000;*/
/*%let practice_id = 1035; *MAIN;*/
/*%let do_practice_id = 1035;*/
/*%let practice_id = 1036; * EAST;*/
/*%let do_practice_id = 1036;*/
/*%let practice_id = 1037; * WEST;*/
/*%let do_practice_id = 1037;*/
/*%let maxprocessid = 0;*/
/*%let practice_id = 1038; * MEDIN;*/
/*%let do_practice_id = 1038;*/
/*%let client_id = 6;*/
/*%let sysparm=%str(sas_mode=test); */
/*%let wflow_exec_id = 43996;*/
/*%bpm_environment;*/

%macro edw_837_institutional_extract;

	%global src_record_cnt tgt_record_cnt;
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
	| If it is no load hold reprocess workflow (sas_prgm_id=19), do not delete.
	-----------------------------------------------------------------------SASDOC*;
	%if %sysfunc(exist(cistage.claims_&practice_id._&client_id._&wflow_exec_id.)) and &sas_prgm_id. ne 19 %then %do;
		proc datasets library=cistage nolist;
		  delete claims_&practice_id._&client_id._&wflow_exec_id.;
		quit;
	%end;


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
				select * into: claims_837I_cnt from connection to oledb
				(
					SELECT  COUNT(*) as cnt
					FROM [EDI].[dbo].[I_Claim] 			as h left outer join
						 [EDI].[dbo].[I_ClaimLineItem]	as d on h.ClaimUID=d.ClaimUID
					WHERE h.DataSourceID = &do_practice_id. and
						  h.ClaimID > &maxprocessid.
				);
			quit;

			%put NOTE: 837 Institutional Claim Count - &claims_837I_cnt.;

			%set_error_flag;
			%on_error(ACTION=ABORT);

		%end;  /** end - nlhold reprocess 2 **/ 


		*SASDOC--------------------------------------------------------------------------
		| Pull 837 Institutional Claims from EDI
		|
		------------------------------------------------------------------------SASDOC*;

		%if &claims_837I_cnt. > 0 %then %do;


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
					where	client_key=&client_id.
					and		datasourceid=&practice_id.;
			  	quit;

				%put NOTE: DataSourceID_MLAExist - &datasourceid_mlaexist.;

				proc sql;
					connect to oledb(init_string=&edi.);
					create table practice_&do_practice_id. as select * from connection to oledb
					(
						exec dbo.CI_InstitutionalClaim &do_practice_id., &maxprocessid.
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

			%if not %symexist(nlhold_reprocess) %then %do;  /** begin - nlhold reprocess 4 **/			

				proc summary data=practice_&do_practice_id. nway missing;
				class 
					clientid datasourceid
					FileName DateEntered 
					PatientAccountNumber MedicalRecordNumber  
					AttendingPhysicianFirstName AttendingPhysicianLastName AttendingPhysicianID AttendingPhysicianQualifier
					adm_source dis_cond fac_name fac_id fac_tin 
					ssn fname lname mname sex address1 address2 city state zip ID DateOfBirth IndividualRelationshipCode
					ServiceFromDate ServiceToDate TransactionSetDate AdmissionDateTime StatementBeginDate StatementEndDate
					admdiag diag1-diag10 poa1-poa10 drg surg1 revcd
					proccd Mod1-Mod3 submit units 
					payorindicator PayerPrimaryID payorname1 
					FacilityTypeCode ClaimFrequencyCode
					;
				id ClaimID LineNumber;
				output out=practice_&do_practice_id. (drop=_type_ _freq_);
				run;

			%end;  /** end - nlhold reprocess 4 **/

			*SASDOC--------------------------------------------------------------------------
			| 837 Institutional Claims Clean Up
			|
			------------------------------------------------------------------------SASDOC*;
			%if not %symexist(nlhold_reprocess) %then %do;  /** begin - nlhold reprocess 4 **/ 

				data claims_&do_practice_id._2;
				length 	claimnum linenum $36. client_key datasourceid 8. source $1. system $17. claim_source 3. filename $50. filed $8.
						practice $50. tin $9. npi npi2 $10. provname $50. 
						patientaccountnumber medicalrecordnumber $50. bill_type $3. ClaimFrequencyCode $2. 
						memberid $9 ssn $11. lname $25. fname $15. mname $15. dob dod 8. sex $1. address1 address2 $50. city $25. state $2. zip $5. phone $10.
						svcdt moddt admdt disdt 8. sbdate sedate $10. 
						admdiag diag1-diag10 $6. surg1 $5. drg revcd $3. proccd $5. mod1-mod3 $2. units submit 8. pos $2.
						ID $20. IndividualRelationshipCode $2. payorid1 $36. npayorid1 $9.  payorname1 $50. maxprocessid 8. facility_indicator 8.
						fac_Name $50.;

				format 	svcdt moddt FileDt dob dod admdt disdt mmddyy10. 
						PatientAccountNumber $50. MedicalRecordNumber $50. ClaimFrequencyCode $2.
						ssn $9. lname $25. fname $15. address1 $50. city $25. state $2. zip $5.
						diag1-diag9 $6. proccd $5. pos $2. submit dollar10.2 mod1-mod3 $2. 
						payorname1 $50. id $20. individualrelationshipcode $2. practice $50. tin $9.;

				set practice_&do_practice_id. (keep = 	clientid datasourceid
														ClaimID LineNumber FileName DateEntered 
														PatientAccountNumber MedicalRecordNumber  
														AttendingPhysicianFirstName AttendingPhysicianLastName AttendingPhysicianID AttendingPhysicianQualifier
														adm_source dis_cond fac_name fac_id fac_tin 
														ssn fname lname mname sex address1 address2 city state zip ID DateOfBirth IndividualRelationshipCode
														ServiceFromDate ServiceToDate TransactionSetDate AdmissionDateTime StatementBeginDate StatementEndDate
														admdiag diag1-diag10 poa1-poa10 drg surg1 revcd
														proccd Mod1-Mod3 submit units 
														payorindicator PayerPrimaryID payorname1 
														FacilityTypeCode ClaimFrequencyCode 
											   rename = (revcd=_revcd filename=_filename));
				client_key 	= clientid;
				practice_id = datasourceid;
				practice 	= fac_name;
				filedt 		= datepart(DateEntered);
				filename 	= scan(_filename,-1,"\");
				filed 		= put(filedt,yymmddn8.);
				
				/**npi = attendingphysicianid;**/
				npi 	 = '';
				pos 	 = '';
				provname = trim(attendingphysicianlastname) || ", " || trim(attendingphysicianfirstname);
				npi2 	 = fac_id;
				tin 	 = fac_tin;

				payorid1  = substr(cats(PayerPrimaryID),1,36);	
				npayorid1 = substr(cats(PayerPrimaryID),1,5);

				dob 	 = input(DateOfBirth,yymmdd10.);
				if dis_cond in ('20','40','41','42') then dod = input(StatementEndDate,yymmdd10.);
				if dod > today() then dod = .;
				svcdt 	 = input(ServiceFromDate,yymmdd10.);
				admdt 	 = datepart(AdmissionDateTime);
				disdt 	 = input(ServiceToDate,yymmdd10.);
				filedate = datepart(DateEntered);
				moddt 	 = input(TransactionSetDate,yymmdd10.);
				sbdate 	 = StatementBeginDate;
				sedate 	 = StatementEndDate;

				if admdt = . and disdt ne . then admdt = disdt;

					 if cats(FacilityTypeCode) in ("11","18","41","65","66","86","89") 				then majcat = 1;
				else if cats(FacilityTypeCode) in ("84") 											then majcat = 2;
				else if cats(FacilityTypeCode) in ("21","28") 										then majcat = 3;
				else if cats(FacilityTypeCode) in ("83") 											then majcat = 7;
				else if cats(FacilityTypeCode) in ("14") 											then majcat = 9;
				else if cats(FacilityTypeCode) in ("12","13","22","23","32","33","34","43",
												   "71","72","73","74","75","79","81","82","85") 	then majcat = 13;
				else if cats(FacilityTypeCode) in ("76") 											then majcat = 51;
				
				revcd = substr(_revcd,2);

				bill_type = cats(FacilityTypeCode) || cats(ClaimFrequencyCode);

				if claimfrequencycode in ("0","5","6","8") then delete; /** Delete late charges & voids - duplicate claims**/

				drop 	ServiceFromDate _filename DateEntered TransactionSetDate AdmissionDateTime StatementEndDate 
						FacilityTypeCode PayerPrimaryID DateOfBirth _revcd;

				source = "H";
				system = "837_INSTITUTIONAL";
				facility_indicator = &facility_indicator.;
				claim_source = &dataformatgroupid.;
				memberid = compress(trim(left(ssn)),"-");
				phone = '';

				claimnum = trim(left(PatientAccountNumber));
				linenum  = trim(left(linenumber));
				
				maxprocessid = claimid * 1;


				keep 	client_key practice_id claimnum linenum filedt filename filed source system claim_source facility_indicator
					  	provname npi tin
					 	PatientAccountNumber MedicalRecordNumber memberid ssn lname fname mname dob dod sex address1-address2 city state zip phone
					 	svcdt moddt admdt disdt sbdate sedate dis_cond 
						drg surg1 admdiag diag1-diag10 poa1-poa10 proccd mod1-mod2 revcd units submit pos majcat
						payorid1 payorname1 maxprocessid facility_indicator bill_type;

				%empi_837_institutional (client_id=&client_id.);

				run;

			%end;  /** begin - nlhold reprocess 4 **/
			%else %do;

				data claims_&do_practice_id._2;
				format 	filedt dod mmddyy10. 
					fac_name $20. sbdate sedate $10. claimfrequencycode $1. FacilityTypeCode $2. ;  

				set practice_&do_practice_id. ;
	
				practice = fac_name;

				filedt   = today(); 
				filed    = put(filedt,yymmddn8.);
				filename = filename;
				
				/**npi = attendingphysicianid;**/
				npi 	 = '';
				pos 	 = '';
				provname = provname;
				npi2 	 = ''; 
				payorid1 = '';
				npayorid1 = ''; 
				dod = .;

				filedate = today(); 
				sbdate 	 = Statement_Begin_Date;
				sedate 	 = Statement_End_Date;

				if admdt = . and disdt ne . then admdt = disdt;
				
					 if cats(FacilityTypeCode) in ("11","18","41","65","66","86","89") 				then majcat = 1;
				else if cats(FacilityTypeCode) in ("84") 											then majcat = 2;
				else if cats(FacilityTypeCode) in ("21","28") 										then majcat = 3;
				else if cats(FacilityTypeCode) in ("83") 											then majcat = 7;
				else if cats(FacilityTypeCode) in ("14") 											then majcat = 9;
				else if cats(FacilityTypeCode) in ("12","13","22","23","32","33","34","43",
												   "71","72","73","74","75","79","81","82","85") 	then majcat = 13;
				else if cats(FacilityTypeCode) in ("76") 											then majcat = 51;
				
				revcd = revenue_code;

				**bill_type = cats(FacilityTypeCode) || cats(ClaimFrequencyCode);
				bill_type=bill_type; 
				if length(bill_type) = 3 then do;
				  claimfrequencycode=substr(bill_type,3,1);
				  facilitytypecode=substr(bill_type,1,2);
				end;

				if claimfrequencycode in ("0","5","6","8") then delete; /** Delete late charges & voids - duplicate claims**/

				source = "H";
				system = "837_INSTITUTIONAL";
				facility_indicator = &facility_indicator.;
				claim_source = &dataformatgroupid.;
				memberid = compress(trim(left(ssn)),"-");
				phone = '';
				surg1=''; 

				claimnum = claimnum;
				**PatientAccountNumber=claimnum ; /** dropped in empi_837_institutional **/
				**medicalrecordnumber='';         /** dropped in empi_837_institutional **/
				linenum  = linenum; 
				dis_cond='';

				if source_system_id = "400" then fac_name="FLORIDA";
				else if source_system_id = "050" then fac_name="CLEVELAND";
				else if source_system_id = "210" then fac_name="FAIRVIEW";
				else if source_system_id = "230" then fac_name="LAKEWOOD";
				else if source_system_id = "240" then fac_name="MARYMOUNT";
				else if source_system_id = "250" then fac_name="EDINA" ;
				else if source_system_id = "310" then fac_name="HILLCREST";
				else if source_system_id = "320" then fac_name="EUCLID";
				else if source_system_id = "330" then fac_name="HURON";
				else if source_system_id = "340" then fac_name="SOUTHPOINTE"; 
				
				maxprocessid = maxprocessid;


				keep 	client_key practice_id claimnum linenum filedt filename filed source system claim_source facility_indicator
					  	provname npi tin
					 	memberid ssn lname fname mname dob dod sex address1-address2 city state zip phone
					 	svcdt moddt admdt disdt sbdate sedate dis_cond 
						drg surg1 admdiag admit_diagnosis_cd diag1-diag10 proccd mod1-mod2 revcd units submit pos majcat
						payorid1 payorname1 maxprocessid facility_indicator bill_type
						enterprise_member_id source_system_id system_member_id
						poa1-poa10;

				%**empi_837_institutional (client_id=&client_id.);

				run;

			%end;

			%set_error_flag;
			%on_error(ACTION=ABORT);

			%let varexist_id=%sysfunc(open(claims_&do_practice_id._2));
			%let varexist_ind=%sysfunc(varnum(&varexist_id.,source_system_id));
			%let varexist_rc=%sysfunc(close(&varexist_id.));

			%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;

			%if &varexist_ind. > 0 %then %do;
				proc sql;
					create table claims_&do_practice_id._3 as
					(
						select 
							a.*,
							b.enterprise_member_id
						from claims_&do_practice_id._2 	
						%if %symexist(nlhold_reprocess) %then %do;
						(drop = enterprise_member_id) 
						%end; as a left outer join
							 vh_empi.client_member 		as b on a.client_key = b.client_key and 
												a.source_system_id = b.source_system_id and 
												a.system_member_id = b.system_member_id and
												b.active_flag <> 0
					)
					;
				quit;
			%end;
			%else %do;
				data claims_&do_practice_id._3;
				set claims_&do_practice_id._2;
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

			%put NOTE: CIEDW = &ciedw.;

			/**CREATE PROVIDER PRACTICE TABLE**/
			proc sql;
                 create table providerpractice as
                 select 
                       ds.datasourceid,
                       p.provider_key,
                       p.npi1                        as npi length=10,
                       pg.practice_key,
                       pg.primary_practice_ind,
                       g.tin                         as tin length=9,
                       p.provider_name,
                       g.practice_name,
                    datepart(min(coalesce(p.clncl_int_exp_dt,datetime()),coalesce(pg.exp_dt,datetime()))) as ci_term_date format=mmddyy10.
                 from ids.datasource_practice        as ds left outer join
                       ciedw.practice               as g  on ds.practiceid = g.vsource_practice_key left outer join
                       ciedw.provider_practice_xref as pg on g.practice_key = pg.practice_key left outer join
                       ciedw.provider               as p  on pg.provider_key = p.provider_key
                 where ds.datasourceid = &do_practice_id. and 
                         pg.client_key = &client_id. and
                         g.tin is not null and 
                         g.vsource_practice_key ne .
                 order by g.tin
                 ;
           quit;

			%set_error_flag;
			%on_error(ACTION=ABORT);

			/**CHECK HOSPITAL UNIQUE TIN**/
			data providerpractice2;
			set providerpractice;
			by tin;
			if first.tin and last.tin then duplicate_tin = 0;
			else duplicate_tin = 1;
			run;

			proc print data=providerpractice2;
			where duplicate_tin = 1;
			format provider_name $42. practice_name $50.;
			title "DUPLICATE TIN COMBINATION";
			run;

			proc sql noprint;
				select
					case when count(duplicate_tin) in (.,0) then 0
						 else 1 end as duplicate_cnt
				into: duplicate_tin
				from providerpractice2
				where duplicate_tin = 1
				;
			quit;

			%put NOTE: Duplicate TIN - &duplicate_tin.;

			%set_error_flag;
			%on_error(ACTION=ABORT);

			%if &duplicate_tin. = 0 %then %do;

				/**CREATE PROVIDER_KEY AND PRACTICE_KEY BASED UPON UNIQUE NPI AND TIN COMBINATION**/
				proc sql;
					create table claims_&do_practice_id._4 as
					select
						a.*,
						coalesce(b.provider_key,0)									as provider_key,
						case when a.svcdt le b.ci_term_date then b.practice_key
							 else 0												end as practice_key,
						case when a.svcdt le b.ci_term_date then b.practice_key
							 else 0 											end as group_id
					from claims_&do_practice_id._3 as a left outer join
						 providerpractice2 		as b on a.tin=b.tin and duplicate_tin = 0
					order by a.tin
					;
				quit;

				%set_error_flag;
				%on_error(ACTION=ABORT);
			%end;
			%else %if &duplicate_tin. > 0 and &varexist_ind. > 0 %then %do;
				data claims_&do_practice_id._3a;
				set claims_&do_practice_id._3;
				%if &do_practice_id. = 1036 %then %do;
					if source_system_id = "320" then practice_key = 14223;
					else if source_system_id = "310" then practice_key = 14224;
					else if source_system_id = "330" then practice_key = 14225;
					else if source_system_id = "340" then practice_key = 14226;
					else if source_system_id = " " then practice_key = 0;
				%end;
				run;

				proc sql;
					create table claims_&do_practice_id._4 as
					select
						a.*,
						b.provider_key,
						case when a.svcdt le b.ci_term_date then b.practice_key
							 else 0 											end as group_id
					from claims_&do_practice_id._3a as a left outer join
						 providerpractice2			as b on a.practice_key = b.practice_key
					;
				quit;		
			%end;

	
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
			if _n_ = 1 then set ci_start_date ;
			set claims_&do_practice_id._4;
			if svcdt >= start_date ;

			/**%edw_npi_cleansing_rules;**/
			%include "&cistage.\npi_cleanse_rules_&wflow_exec_id..txt";
			run;

			
			*SASDOC--------------------------------------------------------------------------
			| First round of removing duplicates
			|
			------------------------------------------------------------------------SASDOC*; 
			%if &varexist_ind. > 0 %then %do;
				proc summary data=claims_&do_practice_id._5 nway missing;
				class
					start_date client_key source system claim_source filed 
					tin npi provname bill_type 
					memberid ssn lname fname mname dob dod sex address1 address2 city state zip phone
					svcdt moddt admdt disdt sbdate sedate
					admdiag diag1-diag10 poa1-poa10 surg1 drg revcd proccd mod1 mod2 units submit pos
					facility_indicator FileDt Dis_Cond
					practice_id majcat system_member_id source_system_id enterprise_member_id 
					provider_key practice_key group_id;
				id claimnum linenum maxprocessid filename payorid1 payorname1;
				output out=practice_&do_practice_id. (drop=_type_ _freq_);
				run;
			%end;
			%else %do;
				proc summary data=claims_&do_practice_id._5 nway missing;
				class
					start_date client_key source system claim_source filed 
					tin npi provname bill_type 
					memberid ssn lname fname mname dob dod sex address1 address2 city state zip phone
					svcdt moddt admdt disdt sbdate sedate
					admdiag diag1-diag10 poa1-poa10 surg1 drg revcd proccd mod1 mod2 units submit pos
					facility_indicator FileDt Dis_Cond
					practice_id majcat
					provider_key practice_key group_id;
				id claimnum linenum maxprocessid filename payorid1 payorname1;
				output out=practice_&do_practice_id. (drop=_type_ _freq_);
				run;
			%end;

			data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;
			format member_key 16.;
			set practice_&do_practice_id.;

			claim_key=_n_;
			dq_claim_flag=0;
			member_key=0;
			dq_member_flag=0;
			wflow_exec_id=&wflow_exec_id.; 

			historical=2; /** USE EMPI, NO NEED FOR 2 PASSES**/
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

		%end; /** END &claims_837I_cnt. > 0 LOOP **/

		%else %do;
			%let src_record_cnt = 0;
			%let tgt_record_cnt = 0;

			%put ERROR: There are no claims within EDI for 837 Professional Practice - &do_practice_id.;

			%macro send_email_alert;
				filename mail_out email to="wlee@valencehealth.com" subject="CIO Work Flow &wflow_exec_id. - No Claims 837 Professional Failed";

				data _null_;
				file mail_out lrecl=32767;  
				put "837 Institutional";
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

%mend edw_837_institutional_extract;

%edw_837_institutional_extract;
