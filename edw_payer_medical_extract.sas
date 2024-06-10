/*HEADER------------------------------------------------------------------------
|
| program:  edw_payer_medical_extract.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create Payer UB/HCFA data
|
| logic:    1. payer_ub_view_dataformatid_&dataformatid has to exist, and should
|				return the following fields:
|
|			2. initialize the following variables:
|				source=H or P depending on UB or HCFA (it actually really doesn't matter
|							anyway because eligibility ran first and all will be matched)
|				claim_source=&dataformatgroupid.
|				historical=5 (will never need 1st and 2nd pass even for onboarding)
|				facility_indicator=1 (if UB)
|
| input:    Macro parameters and /or SQL server practices
|             sk_prcs_ctrl_id - bpm process identifier
|             wflow_exec_id - bpm work flow identifier
|             sas_prgm - sas program id from BPMMetaData.SK_EXT_PROGRAM
|             client_id   - the client id from vmine (e.g., 4=NSAP) 
|             practice_id - DataSourceID (e.g., 710 HealthNautica) 
|             sas_mode - prod or test
|             filename - monthly text file to process
|           
| output:   SAS Staging dataset
|
+--------------------------------------------------------------------------------
| history:  
|
| 13JUN2012 - G Liu - Clinical Integration 1.3.01 H01
|             Original
| 16JUL2012 - G Liu - Clinical Integration 1.4.01 TCHP
|			  Perform secondary lookup using provider table is_payer_data if npi/tin
|				combination not in provider_practice_xref.
| 02AUG2012 - G Liu - Clinical Integration 1.5.01 L03
|			  Dedup diagnosis codes for payer
+-----------------------------------------------------------------------HEADER*/

%macro edw_payer_medical_extract;
	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	+------------------------------------------------------------------------SASDOC*/
	%bpm_process_control(timevar=START)

	/*SASDOC--------------------------------------------------------------------------
	| Delete claims dataset if it exists to prevent issues for the cycle of the ETL
	------------------------------------------------------------------------SASDOC*/
	%if %sysfunc(exist(cistage.claims_&practice_id._&client_id._&wflow_exec_id.)) %then %do;
		proc datasets library=cistage nolist;
			delete claims_&practice_id._&client_id._&wflow_exec_id.;
		quit;
	%end;

	/*SASDOC--------------------------------------------------------------------------
	| Pull UB claims from VHSTAGE_PAYER
	------------------------------------------------------------------------SASDOC*/
	%data_source_information

	%if &PayerContainUB. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._ub_batch&batch_key.))=0 %then %do;
		%let facility_indicator=1; /* hardcode to overwrite %data_source_information since payer might have both UB and HCFA */
		%let incoming=payer_ub_data;
		%payer_ub_view_dataformatid_&dataformatid.(&batch_key.,&practice_id.)
	%end;
	%else %if &PayerContainHCFA. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._hcfa_batch&batch_key.))=0 %then %do;
		%let facility_indicator=0; /* hardcode to overwrite %data_source_information since payer might have both UB and HCFA */
		%let incoming=payer_hcfa_data;
		%payer_hcfa_view_dataformatid_&dataformatid.(&batch_key.,&practice_id.)
	%end;

	%set_error_flag
	%on_error(ACTION=ABORT)

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Create source and target counts             
	+------------------------------------------------------------------------SASDOC*/
	%let dsn_id=%sysfunc(open(&incoming.));
	%let src_record_cnt=%sysfunc(attrn(&dsn_id.,nobs));
	%let dsn_rc=%sysfunc(close(&dsn_id.));

	%put NOTE: SRC_RECORD_CNT - &src_record_cnt.;

	%IF &src_record_cnt. %THEN %DO; /* begin - payer dataset has records */
		/*SASDOC--------------------------------------------------------------------------
		| Get PROVIDER_KEY and PRACTICE_KEY
		+------------------------------------------------------------------------SASDOC*/
		/* use the physician version (m2_trigger_facility=0) to get both provider and practice key 
			can't use primsec, there is an &m2_datasource_id ne condition that initialize the ppx_facility_cnt, which then
			assume practice_key exists, which is not true for payer
		%edw_primsec_provider_xref(&client_id.,m2_datasource_id=&practice_id.,m2_inset=payer_ub_data,m2_trigger_facility=0)*/

		proc sql;
			create table provider_practice as 
			select 	c.npi1 as npi, b.tin, c.provider_key, b.practice_key, count(*) as dupcnt
			from 	ciedw.provider_practice_xref a, ciedw.practice b, ciedw.provider c
			where 	a.practice_key=b.practice_key and a.provider_key=c.provider_key
			and		b.is_payer_data and c.is_payer_data
			and 	a.client_key=&client_id.
			and		c.npi1 is not null and c.provider_key gt 0
			and 	b.tin is not null and b.practice_key gt 0
			group by 1,2
			order by 1,2;

			create table provider as
			select	npi1 as npi, provider_key, count(*) as dupcnt
			from	ciedw.provider
			where	client_key=&client_id.
			and		npi1 is not null and provider_key gt 0
			and		is_payer_data
			group by 1
			order by 1;
		quit;

		data _null_;
			set provider_practice;
			where dupcnt ne 1;
			if _n_=1 then put 'NPI/TIN combination with multiple provider/practice keys';
			put _all_;
		data _null_;
			set provider;
			where dupcnt ne 1;
			if _n_=1 then put 'NPI with multiple provider keys';
			put _all_;
		run;
		
		data cistage.claims_&practice_id._&client_id._&wflow_exec_id.(drop=dupcnt compress=yes bufsize=512k);
			if _n_=0 then set provider_practice(keep=npi tin provider_key practice_key dupcnt);
			declare hash h_provprac(dataset:'provider_practice(keep=npi tin provider_key practice_key dupcnt where=(dupcnt=1))');
			h_provprac.defineKey('npi','tin');
			h_provprac.defineData('provider_key','practice_key');
			h_provprac.defineDone();
			declare hash h_prov(dataset:'provider(keep=npi provider_key dupcnt where=(dupcnt=1))');
			h_prov.defineKey('npi');
			h_prov.defineData('provider_key');
			h_prov.defineDone();
			call missing(npi,tin,provider_key,practice_key);

			do while (not lstobs);
							/* initialize practice key to 0 because this field is non-nullable in edw.
								during stay logic when we download claims from edw, those might have 0 value too,
								so, we need to match data in EDW */
				provider_key=.; practice_key=0;
				claim_key+1; dod=.;
				set &incoming. end=lstobs;
				payer_key = &payer_key.;
			  %if &facility_indicator. %then %do;
				source='H'; 
				system = "PAYER UB";
				if dis_cond in ('20','40','41','42') then dod=disdt;
				facility_indicator=&facility_indicator.;
			  %end;
			  %else %do;
				source='P'; 
				system = "PAYER HCFA";
			  %end;
				client_key=&client_id.; group_id=&practice_id.;
				dq_claim_flag=0;
				member_key=0; dq_member_flag=0;
				wflow_exec_id=&wflow_exec_id.; 
				historical=5;
				filename="&filename.";
				claim_source=&dataformatgroupid.;
				if h_provprac.find() then output;
				else if h_prov.find() then output;
				else output;
			end;
			stop;
		run;
		%set_error_flag
		%on_error(ACTION=ABORT)

		/* Dedup Diagnosis (and POA if exists) */
		%let epme_dsid=%sysfunc(open(cistage.claims_&practice_id._&client_id._&wflow_exec_id.));
		%let epme_poa=%sysfunc(varnum(&epme_dsid.,poa1));
		%let epme_poapfkey=%sysfunc(varnum(&epme_dsid.,poa1_pfkey));
		%let epme_dsrc=%sysfunc(close(&epme_dsid.));

		%if &epme_poa.=0 and &epme_poapfkey.=0 %then %do;
			%dedup_diagnosis(cistage.claims_&practice_id._&client_id._&wflow_exec_id.,diag,)
		%end;
		%else %if &epme_poapfkey. %then %do;
			%dedup_diagnosis(cistage.claims_&practice_id._&client_id._&wflow_exec_id.,diag,poa,m_poa_suffix=_pfkey)
		%end;
		%else %if &epme_poa. %then %do;
			%dedup_diagnosis(cistage.claims_&practice_id._&client_id._&wflow_exec_id.,diag,poa)
		%end;
		%set_error_flag
		%on_error(ACTION=ABORT)

		/*SASDOC--------------------------------------------------------------------------
		| BPM - Create target counts             
		+------------------------------------------------------------------------SASDOC*/
		%let dsn_id=%sysfunc(open(cistage.claims_&practice_id._&client_id._&wflow_exec_id.));
		%let tgt_record_cnt=%sysfunc(attrn(&dsn_id.,nobs));
		%let dsn_rc=%sysfunc(close(&dsn_id.));

		%put NOTE:  tgt_record_cnt = &tgt_record_cnt;
		%put NOTE:  src_record_cnt = &src_record_cnt;

	%END; /* end - payer dataset has records */
	%ELSE %DO; /* no payer data */
		%let tgt_record_cnt=0;

		%put ERROR: There are no records for client &client_id. payer dataformatgroup &dataformatgroupid. for batch &batch_key.;

		%macro send_email_alert;
			filename mail_out email to="edwprod@valencehealth.com" subject="CIO Failed Workflow &wflow_exec_id. - No Payer Data Failed";

			data _null_;
			file mail_out lrecl=32767;  
			put "client ID = &client_id.";
			put "payer dataformatgroup ID = &dataformatgroupid.";
			put "batch = &batch_key.";
			put "practice ID = &practice_id.";
			run;
		%mend send_email_alert;
		%send_email_alert

	    %bpm_additional_validations(validation_rule=95,validation_count=0)
		
		%let err_fl=1;
		%set_error_flag
		%on_error(ACTION=ABORT)
	%END;  /* no payer data */

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*/
	%bpm_process_control(timevar=COMPLETE)
%mend edw_payer_medical_extract;
%edw_payer_medical_extract
