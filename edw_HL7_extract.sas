/*HEADER------------------------------------------------------------------------
|
| program:  edw_HL7_extract.sas
|
| location: M:\ci\programs\EDW\
|
| purpose:  extract HL7 data (lab result data)           
|
| input:    DEV : SQLCIDEV.EAV.Extract_LabTestResult (stored procedure)
|			PROD: SQL-CI.EAV.Extract_LabTestResult (stored procedure)
|
| output:   claims2 and cistage datasets
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 27DEC2011 - Winnie Lee  - Clinical Integration  1.0.01
|             Initiated
|
| 01JUN2012 - B Stropich - Clinical Integration 1.0.03 Release 1.3
|             added cleanse_dob_two_digit_year macro 
|
| 04JUL2012 - B Fletcher - Added temp fix for NorthShore 1284 HLF file 
|			  			   No EMPI file so rename enterprise_member to system_member
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
+-----------------------------------------------------------------------HEADER*/

%macro edw_HL7_extract;
	options bufsize=512k;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);

	%let do_practice_id = &practice_id.;

	
	*SASDOC--------------------------------------------------------------------------
	| Find IDS information about DataSourceID
	-----------------------------------------------------------------------SASDOC*;
	%data_source_information;


	*SASDOC--------------------------------------------------------------------------
	| Delete claims dataset if it exists to prevent issues for the cycle of the ETL
	-----------------------------------------------------------------------SASDOC*;
	%if %sysfunc(exist(cistage.claims_&practice_id._&client_id._&wflow_exec_id.)) %then %do;
		proc datasets library=cistage nolist;
			delete claims_&practice_id._&client_id._&wflow_exec_id. ;
		quit;
	%end;

	*SASDOC--------------------------------------------------------------------------
	| Pull 837 Professional Claims from EDI
	|
	------------------------------------------------------------------------SASDOC*;
	proc sql;
		connect to oledb(init_string=&eav.);
		create table claims_&do_practice_id._1 as 
			select * from connection to oledb
			(
				exec dbo.Extract_LabTestResult &ETLIncrId.
			);
	quit;

	%set_error_flag;
	%on_error(ACTION=ABORT);
     
	%check_issue_count(dataset_in=claims_&do_practice_id._1, validation=71);
	
	/* added for NorthShore 1284 or 1428 HLF file - no EMPI file so rename to system_member - BF JULY4 2012*/
	    %if &client_id = 13 and (&practice_id = 1284 or &practice_id = 1428) %then %do;

			proc datasets lib=work nolist;
			modify claims_&do_practice_id._1;
			rename ENTERPRISE_MEMBER_ID=SYSTEM_MEMBER_ID;
			quit;

		%end;
		
	*SASDOC--------------------------------------------------------------------------
	| BPM - Create source and target counts             
	+------------------------------------------------------------------------SASDOC*;
	%let dsn_id=%sysfunc(open(claims_&do_practice_id._1));
	%let src_record_cnt=%sysfunc(attrn(&dsn_id.,nobs));
	%let dsn_rc=%sysfunc(close(&dsn_id.));

	%put NOTE: SRC_RECORD_CNT - &src_record_cnt.;

	%if &src_record_cnt. > 0 %then %do;
			

		*SASDOC--------------------------------------------------------------------------
		| Client - Apply Provider Key Primary (vSource - provider practice definition)
		|
		| 1.  Assign practice key
		| 2.  Assign provider key
		------------------------------------------------------------------------SASDOC*;

		/**CREATE ORDERING PROVIDER KEY**/

		proc sql;
			create table provider as
				select 
					provider_key,
					provider_name,
					npi1							as npi,
					ci_status,
					datepart(clncl_int_exp_dt)		as clncl_int_exp_dt format=mmddyy10.
				from ciedw.provider
				where client_key = &client_id. and
					  npi1 is not null and
					  npi1 ne '' and
					  (
						  (ci_status = 'PAR' and clncl_int_exp_dt >= today()) or 
						  (ci_status = 'PAR' and clncl_int_exp_dt = .)
					   )
				order by npi;
			;
		quit;

		data provider2 provider_dups;
			format npi $10.;
			set provider;
			by npi;
			if first.npi and last.npi then output provider2;
			else output provider_dups;
		run;

		proc sql noprint;
			create table practice as 
			    select
			          a.datasourceid,
			          b.practice_key
			    from ids.datasource_practice as a inner join
			          ciedw.practice                as b on a.practiceid=b.vsource_practice_key
			    where b.vsource_practice_key ne .
			;
		run;

		data claims_&do_practice_id._4(compress=yes bufsize=512k);
			if _n_=0 then do;
				set practice;
				set provider2(keep=npi provider_key rename=(provider_key=ordering_provider_key));
			end;
			declare hash h_prac(dataset:'practice');
			h_prac.defineKey('datasourceid');
			h_prac.defineData('practice_key');
			h_prac.defineDone();
			declare hash h_prov(dataset:'provider2(keep=npi provider_key rename=(provider_key=ordering_provider_key))');
			h_prov.defineKey('npi');
			h_prov.defineData('ordering_provider_key');
			h_prov.defineDone();
			call missing(datasourceid,practice_key,npi,ordering_provider_key);

			do while (not lstobs);
				practice_key=.; ordering_provider_key=.;
				format npi $10.;
				format ssn $9. fname mname $15. lname $25. sex $1. address1 address2 $50. city $25. state $2. zip $5. phone $10.;
				set claims_&do_practice_id._1 end=lstobs;
				format newdob newsvcdt newObservation_Date newTransaction_Date mmddyy10.;
				newdob=datepart(dob); newsvcdt=datepart(svcdt);
				newObservation_Date=datepart(Observation_Date); newTransaction_Date=datepart(Transaction_Date);
				if h_prac.find() or h_prov.find() then output;
				else output;
				drop dob svcdt Observation_Date Transaction_Date;
				rename newdob=dob newsvcdt=svcdt newObservation_Date=Observation_Date newTransaction_Date=Transaction_Date;
			end;
			stop;
		run;
		%set_error_flag;
		%on_error(ACTION=ABORT);

		/* Exempla 941 has 2-digit year. Apply additional logic to scrub data */
		%if &practice_id.=941 %then %do;
			data claims_&do_practice_id._4 ;
				set claims_&do_practice_id._4 ;
				%cleanse_dob_two_digit_year;
			run;
		%end;
			
		*SASDOC--------------------------------------------------------------------------
		| First round of removing duplicates
		|
		| PLus checking for ENTERPRISE_MEMBER_ID (EMPI), SYSTEM_MEMBER_ID(MRN), or BOTH POPULATED VARIABLES
		| The existence of the above variables affects downstream logic and linking.  If view has these columns,
		| but are not populated this could cause an issue in the linking.
		------------------------------------------------------------------------SASDOC*; 
		
		%let dsn_id=%sysfunc(open(claims_&do_practice_id._4));
		%let enterprise_member_exist=%sysfunc(varnum(&dsn_id.,ENTERPRISE_MEMBER_ID));         
		%let system_member_exist=%sysfunc(varnum(&dsn_id.,SYSTEM_MEMBER_ID));
		%let dsn_rc=%sysfunc(close(&dsn_id.));		
		
		proc summary data= claims_&do_practice_id._4 nway missing;
		class 	PatientAccountNumber InternalPatientID ExternalPatientID AlternatePatientID 
				SendingFacility ReceivingFacility SendingApplication ReceivingApplication AlternateFacility AccountNumber
				FName MName LName DOB Sex SSN Address1 Address2 City State Zip phone 
				
				%if &enterprise_member_exist > 0 and &system_member_exist > 0 %then ENTERPRISE_MEMBER_ID SYSTEM_MEMBER_ID;
                %else %if &enterprise_member_exist > 0                        %then ENTERPRISE_MEMBER_ID;
                %else %if &system_member_exist     > 0                        %then SYSTEM_MEMBER_ID;                                                      

				ProvFirst ProvLast OrderingProvider provid provname NPI
				Diag1 TestName TestNum proccd SubtestName SubtestNum Units Normal_High_Low
				Result Result_Abnormal_CD OBR_ResultStatus OBX_ResultStatus 
				Observation_Date Transaction_Date svcdt
				OBR_loinccd OBX_loinccd  OBSERVATION_STATUS 
				RESULT_DATATYPE MESSAGEID FILLER_ORDER_NUMBER
				client_key DataSourceID practice_key ordering_provider_key;
		id		id;
		output out=practice_&do_practice_id. (compress=yes bufsize=512k drop= _freq_ _type_);
		run;

		data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.(compress=yes bufsize=512k);
			set practice_&do_practice_id.;			
			length wflow_exec_id dq_claim_flag dq_member_flag member_key 8.;
			format member_key 16.;
			wflow_exec_id = &wflow_exec_id.;
			source='L'; claim_source=&dataformatgroupid.; historical=2; group_id=practice_key; practice_id=&practice_id.;
			member_key=0; dq_member_flag=0; dq_claim_flag=0;
			claim_key=_n_;
			claim_exists_key=0;
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
			%let err_fl=1;
			%set_error_flag;
			%on_error(ACTION=ABORT);
		%end;
		%else %if &increment_count ne 0 %then %do;
			%put NOTE: The creation of cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. was successful.;
		%end;

	%end; /** END &src_record_cnt. > 0 LOOP **/

	%else %do;

		%let tgt_record_cnt = 0;

		%put ERROR: There are no lab result records within EAV for HL7 - &do_practice_id.;

		%macro send_email_alert;
			filename mail_out email to="edwprod@valencehealth.com" subject="CIO Failed Workflow &wflow_exec_id. - No HL7/HLF Failed";

			data _null_;
			file mail_out lrecl=32767;  
			put "client ID = &client_id.";
			put "HL7/HLF";
			put "practice ID = &do_practice_id.";
			run;
		%mend send_email_alert;
		%send_email_alert;

	    %bpm_additional_validations(validation_rule=96,validation_count=0);
		
		%let err_fl=1;
		%set_error_flag;
		%on_error(ACTION=ABORT);	
	%end;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.  
	| 
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);
%mend edw_HL7_extract;

%edw_HL7_extract;
