/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_billtype_hospital_stay_logic.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Create stay for hospital data
|
| INPUT:    SAS staging dataset &dataset_in.
|
| OUTPUT:   SAS staging dataset &dataset_in.
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 15DEC2011 - Winnie Lee  - Clinical Integration  1.0.01 
|
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 M01
|
| 30APR2012 - Winnie Lee  - Clinical Integration Release 1.2 H05
|			  Modify to keep POA1-POA10
|
| 01MAY2012 - Winnie Lee  - Clinical Integration Release 1.2 H02
|			  Modify to keep new field PERSON_KEY
|
| 15JUN2012 - G Liu - Clinical Integration 1.3.01
|			  Dynamically figure out how many diag, surg, poa exist in dataset
+-----------------------------------------------------------------------HEADER*/
%macro edw_billtype_hospital_stay_logic(dataset_in=);
	proc contents data=&dataset_in. out=incoming_contents noprint;
	data _null_;
		set incoming_contents;
		name=upcase(name);
		retain numofdiag numofsurg numofpoa 0;
		if name=:'DIAG' and compress(substr(name,5),'0123456789')='' then numofdiag=max(numofdiag,substr(name,5));
		if name=:'SURG' and compress(substr(name,5),'0123456789')='' then numofsurg=max(numofsurg,substr(name,5));
		if name=:'POA' and compress(substr(name,4),'0123456789')='' then numofpoa=max(numofpoa,substr(name,4));
		call symput('numofdiag',cats(numofdiag));
		call symput('numofsurg',cats(numofsurg));
		call symput('numofpoa',cats(numofpoa));
	run;
	%put NOTE: # of ICD-9 Diagnosis Codes = &numofdiag.;
	%put NOTE: # of ICD-9 Procedure Codes = &numofsurg.;
	%put NOTE: # of POAs = &numofpoa.;
	%put NOTE: Source System ID indicator = &srcsysid_varind.;
	%put NOTE: System Member ID indicator = &sysmemid_varind.;
	%put NOTE: Enterprise Member ID indicator = &empimemid_varind.;

	%let ebhsl_dsid=%sysfunc(open(&dataset_in.));
	%let srcsysid_varind=%sysfunc(varnum(&ebhsl_dsid.,SOURCE_SYSTEM_ID));
	%let sysmemid_varind=%sysfunc(varnum(&ebhsl_dsid.,SYSTEM_MEMBER_ID));
	%let empimemid_varind=%sysfunc(varnum(&ebhsl_dsid.,ENTERPRISE_MEMBER_ID));
	%let pddt_varind=%sysfunc(varnum(&ebhsl_dsid.,PAID_DATE));
	%let chkdt_varind=%sysfunc(varnum(&ebhsl_dsid.,CHECK_DATE));
	%let billedamt_varind=%sysfunc(varnum(&ebhsl_dsid.,BILLED_AMT));
	%let allowedamt_varind=%sysfunc(varnum(&ebhsl_dsid.,ALLOWED_AMT));
	%let paidamt_varind=%sysfunc(varnum(&ebhsl_dsid.,PAID_AMT));
	%let refundamt_varind=%sysfunc(varnum(&ebhsl_dsid.,REFUND_AMT));
	%let copay_varind=%sysfunc(varnum(&ebhsl_dsid.,COPAY_AMT));
	%let ded_varind=%sysfunc(varnum(&ebhsl_dsid.,DEDUCTIBLE_AMT));
	%let coins_varind=%sysfunc(varnum(&ebhsl_dsid.,COINSURANCE_AMT));
	%let cob_varind=%sysfunc(varnum(&ebhsl_dsid.,COB_AMT));
	%let payerlinekey_varind=%sysfunc(varnum(&ebhsl_dsid.,PAYER_LINE_SURROGATE_KEY));
	%let ebhsl_dsrc=%sysfunc(close(&ebhsl_dsid.));

	%macro listvar_loop(m_num,m_prefix,m_suffix=);
		%do i=1 %to &m_num.;
			&m_prefix.&i.&m_suffix. 
		%end;
	%mend;
	%macro setvar_loop(m_num,m_prefix1,m_prefix2,m_suffix1=,m_suffix2=,m_semicolon=0);
		%do i=1 %to &m_num.;
			&m_prefix1.&i.&m_suffix1.=&m_prefix2.&i.&m_suffix2. %if &m_semicolon. %then %do; ; %end;
		%end;
	%mend;
	%macro null_setvar_loop(m_num,m_prefix1,m_prefix2,m_suffix1=,m_suffix2=);
		%do i=1 %to &m_num.;
			if &m_prefix1.&i.&m_suffix1.='' then &m_prefix1.&i.&m_suffix1.=&m_prefix2.&i.&m_suffix2.;
		%end;
	%mend;
	*SASDOC--------------------------------------------------------------------------
	| Create replacement logic within current pull
	|
	+------------------------------------------------------------------------SASDOC*;
	data update_logic
		 member_key_missing;
		set &dataset_in.;
		length facilitytypecode clmfreqcode 3.;
		facilitytypecode = substr(bill_type,1,2) * 1;
		clmfreqcode = substr(bill_type,3,1) * 1;

		if member_key ne 0 then output update_logic;
		else output member_key_missing;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Fix - Filename
	+------------------------------------------------------------------------SASDOC*;	
	data update_filename;
		set &dataset_in. (keep = claim_key filename);
	run;

	proc sort data = update_logic sortseq = uca (numeric_collation = on);
		by	member_key person_key
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end; 
			tin svcdt admdt disdt bill_type sbdate sedate descending moddt descending filedt descending maxprocessid;
	run;

	data update_logic_2;
		set update_logic (keep = member_key person_key
								%if &srcsysid_varind. > 0 %then %do; source_system_id %end; 
								tin svcdt admdt disdt bill_type sbdate sedate moddt filedt maxprocessid);
		by 	member_key person_key
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end; 
			tin svcdt admdt disdt bill_type sbdate sedate descending moddt descending filedt descending maxprocessid;
		if first.sedate then output;
	run;

	proc sql;
		create table update_logic_3 as
			select
				b.*
			from update_logic_2 as a inner join
				 update_logic  as b on 	a.member_key 		= b.member_key and
				 						a.person_key		= b.person_key and
				 						%if &srcsysid_varind. > 0 %then %do;
				 						a.source_system_id 	= b.source_system_id and
										%end;
										a.tin 				= b.tin and
										a.svcdt 			= b.svcdt and
										a.disdt 			= b.disdt and
										a.bill_type 		= b.bill_type and
										a.sbdate 			= b.sbdate and
										a.sedate 			= b.sedate and
										a.moddt 			= b.moddt and
										a.filedt 			= b.filedt and
										a.maxprocessid		= b.maxprocessid
		;
	quit;

	proc sort data = update_logic_3 sortseq = uca (numeric_collation = on);
		by 	member_key person_key
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end;
			tin admdt facilitytypecode sbdate svcdt descending moddt descending sedate 
			descending filedt descending maxprocessid descending linenum descending clmfreqcode;
	run;

	data update_logic_4 (drop=latest_record);
		set update_logic_3;
		by 	member_key person_key
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end;
			tin admdt facilitytypecode sbdate svcdt
			descending moddt descending sedate descending filedt descending maxprocessid descending linenum descending clmfreqcode;
		length clmfreqcode_lag 8. sbdate_lag  $10.;
		retain sbdate_lag clmfreqcode_lag;

		clmfreqcode_lag 		= lag(clmfreqcode);

		if first.facilitytypecode then do;
			latest_record 			= 1;
			clmfreqcode_lag 		= clmfreqcode;
			sbdate_lag				= sbdate;
		end;

		if member_key ne 0 then do;
			if latest_record = 1 then do;
				if clmfreqcode = 1 and clmfreqcode_lag in (1,2,3,4,7) or
				   clmfreqcode = 2 and clmfreqcode_lag in (1,2,7) or 
				   clmfreqcode = 3 and clmfreqcode_lag in (1,2,3) or 
				   clmfreqcode = 4 and clmfreqcode_lag in (1,2,3,4) or
				   clmfreqcode = 7 and clmfreqcode_lag in (1,2,3,4,7) then do;
					sbdate_lag = sbdate;
				end;
			end;
		end;

		rename 
			sbdate					= sbdate_orig
			sbdate_lag				= sbdate
		;
	run;

	proc sort data = update_logic_4 sortseq = uca (numeric_collation = on);
		by 	member_key person_key
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end;
			tin admdt facilitytypecode descending moddt descending sedate descending svcdt
			descending filedt descending maxprocessid descending linenum descending clmfreqcode;
	run;

	data update_logic_5;
		set update_logic_4;
		by 	member_key person_key
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end;
			tin admdt facilitytypecode descending moddt descending sedate descending svcdt
			descending filedt descending maxprocessid descending linenum descending clmfreqcode;
		length disdt_lag moddt_lag clmfreqcode_lag clmfreqcode_lag filedt_lag 8. sedate_lag $10.
			   bill_type_lag $3. /*maxprocessid_lag 8. claimnum_lag $36. no need, make it flexible varchar or num*/
			   admdiag_lag %listvar_loop(&numofdiag.,diag,m_suffix=_lag) $6.
			   %listvar_loop(&numofsurg.,surg,m_suffix=_lag) $5. drg_lag $3. dis_cond_lag $2.;
		format disdt_lag moddt_lag filedt_lag mmddyy10.;
		retain disdt_lag moddt_lag sedate_lag clmfreqcode_lag filedt_lag 
			   bill_type_lag maxprocessid_lag claimnum_lag 
			   admdiag_lag 
				%listvar_loop(&numofdiag.,diag,m_suffix=_lag)
				%listvar_loop(&numofsurg.,surg,m_suffix=_lag)
				%listvar_loop(&numofpoa.,poa,m_suffix=_lag)
			   drg_lag dis_cond_lag;

		clmfreqcode_lag 		= lag(clmfreqcode);

		if first.facilitytypecode then do;
			latest_record 			= 1;
			clmfreqcode_lag 		= clmfreqcode;
			disdt_lag 				= disdt;
			moddt_lag 				= moddt;
			sedate_lag 				= sedate;
			bill_type_lag			= bill_type;
			filedt_lag 				= filedt;
			maxprocessid_lag		= maxprocessid;
			claimnum_lag 			= claimnum;
			admdiag_lag				= admdiag;
			%setvar_loop(&numofdiag.,diag,diag,m_suffix1=_lag,m_semicolon=1)
			%setvar_loop(&numofsurg.,surg,surg,m_suffix1=_lag,m_semicolon=1)
			%setvar_loop(&numofpoa.,poa,poa,m_suffix1=_lag,m_semicolon=1)
			drg_lag					= drg;
			dis_cond_lag			= dis_cond;
		end;
		if member_key ne 0 then do;
			if latest_record = 1 then do;
				if clmfreqcode = 1 and clmfreqcode_lag in (1,2,3,4,7) or
				   clmfreqcode = 2 and clmfreqcode_lag in (1,2,7) or
				   clmfreqcode = 3 and clmfreqcode_lag in (1,2,3) or
				   clmfreqcode = 4 and clmfreqcode_lag in (1,2,3,4) or
				   clmfreqcode = 7 and clmfreqcode_lag in (1,2,3,4,7) then do;
					if disdt_lag 		= . then disdt_lag 			= disdt;
					if moddt_lag 		= . then moddt_lag 			= moddt;
					if sedate_lag 		= '' then sedate_lag 		= sedate;
					if bill_type_lag 	= . then bill_type_lag 		= bill_type;
					if filedt_lag 		= . then filedt_lag 		= filedt;
				  %if &payerlinekey_varind. %then %do; /* for payer, maxprocessid is set to claimnum, which is varchar */
					if maxprocessid_lag = '' then maxprocessid_lag 	= maxprocessid;
				  %end;
				  %else %do;
					if maxprocessid_lag = . then maxprocessid_lag 	= maxprocessid;
				  %end;
					if claimnum_lag		= '' then claimnum_lag 		= claimnum;
					if admdiag_lag		= '' then admdiag_lag		= admdiag;
					%null_setvar_loop(&numofdiag.,diag,diag,m_suffix1=_lag)
					%null_setvar_loop(&numofsurg.,surg,surg,m_suffix1=_lag)
					%null_setvar_loop(&numofpoa.,poa,poa,m_suffix1=_lag)
					if drg_lag			= . then drg_lag			= drg;
					if dis_cond_lag		= . then dis_cond_lag		= dis_cond;
				end;
			end;
		end;

		rename 
			disdt 					= disdt_orig
			moddt 					= moddt_orig
			sedate 					= sedate_orig
			bill_type 				= bill_type_orig
			filedt 					= filedt_orig
			maxprocessid			= maxprocessid_orig
			claimnum 				= claimnum_orig
			admdiag					= admdiag_orig
			%setvar_loop(&numofdiag.,diag,diag,m_suffix2=_orig)
			%setvar_loop(&numofsurg.,surg,surg,m_suffix2=_orig)
			%setvar_loop(&numofpoa.,poa,poa,m_suffix2=_orig)
			drg 					= drg_orig
			dis_cond				= dis_cond_orig
			disdt_lag 				= disdt
			moddt_lag 				= moddt
			sedate_lag 				= sedate
			bill_type_lag			= bill_type
			filedt_lag 				= filedt
			maxprocessid_lag		= maxprocessid
			claimnum_lag 			= claimnum
			admdiag_lag				= admdiag
			%setvar_loop(&numofdiag.,diag,diag,m_suffix1=_lag)
			%setvar_loop(&numofsurg.,surg,surg,m_suffix1=_lag)
			%setvar_loop(&numofpoa.,poa,poa,m_suffix1=_lag)
			drg_lag					= drg
			dis_cond_lag			= dis_cond
		;
	run;

	proc sort data = update_logic_5 sortseq = uca (numeric_collation = on);
	by 	member_key person_key
		%if &srcsysid_varind. > 0 %then %do; source_system_id %end; 
		tin admdt bill_type sbdate svcdt
		moddt sedate filedt maxprocessid linenum filed;
	run;
	
	proc summary data=update_logic_5 nway missing;
	class
		%if &empimemid_varind. > 0 %then %do; enterprise_member_id %end;
		member_key person_key start_date source system claim_source 
		tin bill_type facilitytypecode 
		%if &sysmemid_varind. > 0 %then %do; system_member_id %end;
		%if &srcsysid_varind. > 0 %then %do; source_system_id %end;
		svcdt moddt admdt disdt sbdate sedate
		revcd proccd mod1 mod2  
		facility_indicator majcat 
		dq_claim_flag dq_member_flag wflow_exec_id historical;
	id 	claim_key claimnum linenum maxprocessid FileDt filed 
		npi provname provider_key practice_key group_id practice_id
		memberid ssn lname fname mname dob dod sex address1 address2 city state zip phone
		admdiag %listvar_loop(&numofdiag.,diag) 
		%listvar_loop(&numofpoa.,poa) Dis_Cond
		%listvar_loop(&numofsurg.,surg) drg units submit pos
		payorid1 payorname1
		%if &pddt_varind. %then %do; 		PAID_DATE 				%end;
		%if &chkdt_varind. %then %do; 		CHECK_DATE 				%end;
		%if &billedamt_varind. %then %do; 	BILLED_AMT 				%end;
		%if &allowedamt_varind. %then %do; 	ALLOWED_AMT 			%end;
		%if &paidamt_varind. %then %do; 	PAID_AMT 				%end;
		%if &refundamt_varind. %then %do; 	REFUND_AMT 				%end;
		%if &copay_varind. %then %do; 		COPAY_AMT 				%end;
		%if &ded_varind. %then %do; 		DEDUCTIBLE_AMT 			%end;
		%if &coins_varind. %then %do; 		COINSURANCE_AMT 		%end;
		%if &cob_varind. %then %do; 		COB_AMT 				%end;
		%if &payerlinekey_varind. %then %do; PAYER_LINE_SURROGATE_KEY %end;
		;
	output out=update_logic_6 (drop=_type_ _freq_);
	run;

	proc sort data=update_logic_6 (keep=member_key person_key) out=existing_members nodupkey;
		by member_key person_key;
	run;
	%bulkload_to_cio(&wflow_exec_id.,existing_members);

	*SASDOC--------------------------------------------------------------------------
	| Hospital Case History - Target IP EDW history data based on Practice Key and 
	|                         Member Key based on incoming 837 Institutional data
	|
	+------------------------------------------------------------------------SASDOC*;
	%put NOTE: practice_id = &practice_id;

	proc sql noprint;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table case_logic_history as
		select	max(e_key) as e_key, practice_key, mkey, pkey, admit_date, discharge_date, sbdate, sedate, bill_type length=3, tin
		from	connection to oledb
				( select distinct	eh.encounter_key         	  as e_key,
						            eh.practice_key, 
						            mp.member_key                 as mkey, 
						            em.person_key                 as pkey,
						            eh.admit_date, 
						            eh.discharge_date,
						            eh.statement_begin_date       as sbdate,
						            eh.statement_end_date         as sedate,
						            eh.bill_type                  as bill_type,
						            eh.tin
			      from 	cihold.dbo.saswrk_bulkload_&wflow_exec_id.(nolock)         as em inner join
			            ciedw.dbo.encounter_header(nolock)  as eh on em.person_key=eh.person_key inner join
						ciedw.dbo.encounter_detail(nolock)  as ed on eh.client_key=ed.client_key and eh.encounter_key=ed.encounter_key inner join
			            ciedw.dbo.person_member_map(nolock) as mp on eh.person_key=mp.person_key and eh.client_key=mp.client_key
			      where eh.client_key=&client_id. and
			            ed.data_source_id in (&practice_id.) and 
			            eh.claim_source = &dataformatgroupid.
					%if &dataformatgroupid.=20 %then %do; /* if payer, same claim source can have both ub and hcfa, subset to only ip claims using admdt */
						and eh.admit_date is not null
					%end;
				)
		group by practice_key, mkey, pkey, admit_date, discharge_date, sbdate, sedate, bill_type, tin
		;
		drop table cihold.saswrk_bulkload_&wflow_exec_id.;
	quit;


	data case_logic_history2;
		set case_logic_history;
		length admdt disdt member_key person_key 8. facilitytypecode clmfreqcode 3.;
		format admdt disdt mmddyy10. member_key 16.;
		admdt					= datepart(admit_date);
		disdt					= datepart(discharge_date);
		member_key				= mkey;
		person_key				= pkey;

		facilitytypecode = substr(bill_type,1,2) * 1;
		clmfreqcode = substr(bill_type,3,1) * 1;
		drop admit_date discharge_date mkey;
	run;

	proc sort data = update_logic_6
		  out  = member_keys (keep=member_key person_key practice_key tin admdt) nodupkey;
		by member_key person_key practice_key tin admdt;
	run;

	proc sort data = case_logic_history2;
		by member_key person_key practice_key tin admdt;
	run;

	data case_logic_history3;
		merge case_logic_history2 (in=a)
		      member_keys         (in=b);
		by member_key person_key practice_key tin admdt;
		if a and b;
	run;

	proc sort data=case_logic_history3;
		by member_key person_key practice_key tin admdt facilitytypecode;
	run;

	proc sort data=update_logic_6;
		by member_key person_key practice_key tin admdt facilitytypecode;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Inpatient Outpatient Data Definition + History data from EDW
	|
	| Contents logic is needed for restarts of the workflow
	|
	+------------------------------------------------------------------------SASDOC*;
	data update_logic_7;
		merge update_logic_6		(in=a)
		      case_logic_history3	(in=b rename=(sbdate=sbdate_edw sedate=sedate_edw bill_type=bill_type_edw disdt=disdt_edw
												  clmfreqcode=clmfreqcode_edw));
		by member_key person_key practice_key tin admdt facilitytypecode;
		if a;
		length clmfreqcode 3.;
		clmfreqcode		 = substr(bill_type,3,1);
		output update_logic_7;
		run;

		data update_logic_8;
		set update_logic_7;
		length disdt_new 8. bill_type_new $3. sedate_new $10.;
		format disdt_new mmddyy10.;
		
		if e_key ne . then do;			
			if clmfreqcode_edw=1 and clmfreqcode in (1,2,3,4,7) or 
			   clmfreqcode_edw=2 and clmfreqcode in (1,2,7) or
			   clmfreqcode_edw=3 and clmfreqcode in (1,2,3) or
			   clmfreqcode_edw=4 and clmfreqcode in (1,2,3,4) or
			   clmfreqcode_edw=7 and clmfreqcode in (1,2,3,4,7) then do;
				bill_type_new = bill_type;
				if disdt > disdt_edw then disdt_new = disdt;
				else disdt_new = disdt_edw;
				if sedate > sedate_edw then sedate_new = sedate;
				else sedate_new = sedate_edw;
			end;
			else do;
				bill_type_new = bill_type_edw;
				disdt_new 	  = disdt_edw;
				sedate_new	  = sedate_edw;
			end;
		end;
		else do;
			bill_type_new = bill_type;
			disdt_new 	  = disdt;
			sedate_new	  = sedate;
		end;

		drop bill_type_edw bill_type disdt_edw disdt sbdate_edw sedate_edw sedate facilitytypecode clmfreqcode clmfreqcode_edw;
		rename 
			bill_type_new = bill_type
			disdt_new = disdt
			sedate_new = sedate
		;	
	run;

	proc sort data = update_logic_8 sortseq = uca (numeric_collation = on);
		by 	member_key person_key practice_key tin admdt bill_type sbdate svcdt
			moddt sedate filedt maxprocessid linenum filed e_key;
	run;
	
	proc summary data=update_logic_8 nway missing;
		class
			member_key person_key practice_key tin bill_type 
			svcdt admdt disdt sbdate 
			revcd proccd mod1 mod2 majcat;
		id  sedate claim_key e_key claimnum linenum maxprocessid FileDt filed 
			start_date source system claim_source 
			npi provname provider_key group_id 
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end;
			%if &empimemid_varind. > 0 %then %do; enterprise_member_id %end;
			%if &sysmemid_varind. > 0 %then %do; system_member_id %end;
			memberid ssn lname fname mname dob dod sex address1 address2 city state zip phone
			moddt admdiag %listvar_loop(&numofdiag.,diag)  
			%listvar_loop(&numofpoa.,poa) Dis_Cond
			%listvar_loop(&numofsurg.,surg) drg
			units submit pos facility_indicator practice_id dq_claim_flag dq_member_flag wflow_exec_id historical
			payorid1 payorname1
			%if &pddt_varind. %then %do; 		PAID_DATE 				%end;
			%if &chkdt_varind. %then %do; 		CHECK_DATE 				%end;
			%if &billedamt_varind. %then %do; 	BILLED_AMT 				%end;
			%if &allowedamt_varind. %then %do; 	ALLOWED_AMT 			%end;
			%if &paidamt_varind. %then %do; 	PAID_AMT 				%end;
			%if &refundamt_varind. %then %do; 	REFUND_AMT 				%end;
			%if &copay_varind. %then %do; 		COPAY_AMT 				%end;
			%if &ded_varind. %then %do; 		DEDUCTIBLE_AMT 			%end;
			%if &coins_varind. %then %do; 		COINSURANCE_AMT 		%end;
			%if &cob_varind. %then %do; 		COB_AMT 				%end;
			%if &payerlinekey_varind. %then %do; PAYER_LINE_SURROGATE_KEY %end;
			;
		output out=update_logic_9 (drop=_type_ _freq_);
	run;


	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary - verify the number of obs in this dataset equals the 
	|                      number of obs read from original hospital source
	|
	+------------------------------------------------------------------------SASDOC*; 
	%let miss_cnt=0;
	proc sql noprint; 
	select count(*) into: miss_cnt separated by '' 
	from member_key_missing; 
	quit;

	%put NOTE: MISS_CNT = &miss_cnt.;
	
	data hospital_all;
		set update_logic_9
			member_key_missing;
		if claim_key > 0;
	run;

	proc sort data=hospital_all out=&dataset_in.;
		by 	member_key person_key 
			%if &srcsysid_varind. > 0 %then %do; source_system_id %end; 
			tin admdt sbdate svcdt bill_type;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Fix - Filename
	+------------------------------------------------------------------------SASDOC*;	
	data &dataset_in.;
		if _n_=0 then set update_filename;
		declare hash h_file(dataset:'update_filename');
		h_file.definekey('claim_key');
		h_file.definedata('filename');
		h_file.definedone();
		call missing(claim_key,filename);

		do while (not lstobs);
			filename='';
			set &dataset_in. end=lstobs;
			client_key=&client_id.;
			if h_file.find()=0 then output;
			else output;
			rename	%do i_surg=1 %to &numofsurg.;
						surg&i_surg.=surgical_cd&i_surg.
					%end;
			;
		end;
		stop;
	run;
%mend edw_billtype_hospital_stay_logic;
