/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_837hospital_case_logic.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load 837 Institutional hospital data for CCCPP        
|
| INPUT:    claims_1035_6_43996.sas7bdat
|
| OUTPUT:   practice_(IDS) dataset
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
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
+-----------------------------------------------------------------------HEADER*/

%macro edw_837_hospital_case_logic(dataset_in=);

	%let varexist_id=%sysfunc(open(&dataset_in.));
	%let varexist_ind=%sysfunc(varnum(&varexist_id.,source_system_id));
	%let varexist_rc=%sysfunc(close(&varexist_id.));

	%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;

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
		%if &varexist_ind. > 0 %then %do; source_system_id %end; 
		tin svcdt admdt disdt bill_type sbdate sedate descending moddt descending filedt descending maxprocessid;
	run;

	data update_logic_2;
	set update_logic (keep = member_key person_key
							%if &varexist_ind. > 0 %then %do; source_system_id %end; 
							tin svcdt admdt disdt bill_type sbdate sedate moddt filedt maxprocessid);
	by 	member_key person_key
		%if &varexist_ind. > 0 %then %do; source_system_id %end; 
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
				 						%if &varexist_ind. > 0 %then %do;
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
		%if &varexist_ind. > 0 %then %do; source_system_id %end;
		tin admdt facilitytypecode sbdate svcdt descending moddt descending sedate 
		descending filedt descending maxprocessid descending linenum descending clmfreqcode;
	run;

	data update_logic_4 (drop=latest_record);
	set update_logic_3;
	by 	member_key person_key
		%if &varexist_ind. > 0 %then %do; source_system_id %end;
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
			if clmfreqcode = 1 then do;
				if clmfreqcode_lag in (1,2,3,4,7) then do;
					sbdate_lag				= sbdate;
				end;
			end;
			else if clmfreqcode = 2 then do;
				if clmfreqcode_lag in (1,2,7) then do;
					sbdate_lag				= sbdate;
				end;
			end;
			else if clmfreqcode = 3 then do;
				if clmfreqcode_lag in (1,2,3) then do;
					sbdate_lag				= sbdate;
				end;
			end;
			else if clmfreqcode = 4 then do;
				if clmfreqcode_lag in (1,2,3,4) then do;
					sbdate_lag				= sbdate;
				end;
			end;
			else if clmfreqcode = 7 then do;
				if clmfreqcode_lag in (1,2,3,4,7) then do;
					sbdate_lag				= sbdate;
				end;
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
		%if &varexist_ind. > 0 %then %do; source_system_id %end;
		tin admdt facilitytypecode descending moddt descending sedate descending svcdt
		descending filedt descending maxprocessid descending linenum descending clmfreqcode;
	run;

	data update_logic_5;
	set update_logic_4;
	by 	member_key person_key
		%if &varexist_ind. > 0 %then %do; source_system_id %end;
		tin admdt facilitytypecode descending moddt descending sedate descending svcdt
		descending filedt descending maxprocessid descending linenum descending clmfreqcode;
	length disdt_lag moddt_lag clmfreqcode_lag clmfreqcode_lag filedt_lag 8. sedate_lag $10.
		   bill_type_lag $3. maxprocessid_lag 8. claimnum_lag $36. 
		   admdiag_lag diag1_lag diag2_lag diag3_lag diag4_lag diag5_lag diag6_lag diag7_lag diag8_lag diag9_lag diag10_lag $6.
		   surg1_lag $5. drg_lag $3. dis_cond_lag $2.;
	format disdt_lag moddt_lag filedt_lag mmddyy10.;
	retain disdt_lag moddt_lag sedate_lag clmfreqcode_lag filedt_lag 
		   bill_type_lag maxprocessid_lag claimnum_lag 
		   admdiag_lag diag1_lag diag2_lag diag3_lag diag4_lag diag5_lag diag6_lag diag7_lag diag8_lag diag9_lag diag10_lag
		   surg1_lag drg_lag dis_cond_lag;

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
		diag1_lag 				= diag1;
		diag2_lag 				= diag2;
		diag3_lag 				= diag3;
		diag4_lag 				= diag4;
		diag5_lag 				= diag5;
		diag6_lag 				= diag6;
		diag7_lag 				= diag7;
		diag8_lag 				= diag8;
		diag9_lag 				= diag9;
		diag10_lag 				= diag10;
		surg1_lag				= surg1;
		drg_lag					= drg;
		dis_cond_lag			= dis_cond;
	end;

	if member_key ne 0 then do;
		if latest_record = 1 then do;
			if clmfreqcode = 1 then do;
				if clmfreqcode_lag in (1,2,3,4,7) then do;
					if disdt_lag 		= . then disdt_lag 			= disdt;
					if moddt_lag 		= . then moddt_lag 			= moddt;
					if sedate_lag 		= . then sedate_lag 		= sedate;
					if bill_type_lag 	= . then bill_type_lag 		= bill_type;
					if filedt_lag 		= . then filedt_lag 		= filedt;
					if maxprocessid_lag = . then maxprocessid_lag 	= maxprocessid;
					if claimnum_lag		= . then claimnum_lag 		= claimnum;
					if admdiag_lag		= . then admdiag_lag		= admdiag;
					if diag1_lag		= . then diag1_lag 			= diag1;
					if diag2_lag		= . then diag2_lag 			= diag2;
					if diag3_lag		= . then diag3_lag 			= diag3;
					if diag4_lag		= . then diag4_lag 			= diag4;
					if diag5_lag		= . then diag5_lag 			= diag5;
					if diag6_lag		= . then diag6_lag 			= diag6;
					if diag7_lag		= . then diag7_lag 			= diag7;
					if diag8_lag		= . then diag8_lag 			= diag8;
					if diag9_lag		= . then diag9_lag 			= diag9;
					if diag10_lag		= . then diag10_lag 		= diag10;
					if surg1_lag		= . then surg1_lag			= surg1;
					if drg_lag			= . then drg_lag			= drg;
					if dis_cond_lag		= . then dis_cond_lag		= dis_cond;
				end;
			end;
			else if clmfreqcode = 2 then do;
				if clmfreqcode_lag in (1,2,7) then do;
					if disdt_lag 		= . then disdt_lag 			= disdt;
					if moddt_lag 		= . then moddt_lag 			= moddt;
					if sedate_lag 		= . then sedate_lag 		= sedate;
					if bill_type_lag 	= . then bill_type_lag 		= bill_type;
					if filedt_lag 		= . then filedt_lag 		= filedt;
					if maxprocessid_lag = . then maxprocessid_lag 	= maxprocessid;
					if claimnum_lag		= . then claimnum_lag 		= claimnum;
					if admdiag_lag		= . then admdiag_lag		= admdiag;
					if diag1_lag		= . then diag1_lag 			= diag1;
					if diag2_lag		= . then diag2_lag 			= diag2;
					if diag3_lag		= . then diag3_lag 			= diag3;
					if diag4_lag		= . then diag4_lag 			= diag4;
					if diag5_lag		= . then diag5_lag 			= diag5;
					if diag6_lag		= . then diag6_lag 			= diag6;
					if diag7_lag		= . then diag7_lag 			= diag7;
					if diag8_lag		= . then diag8_lag 			= diag8;
					if diag9_lag		= . then diag9_lag 			= diag9;
					if diag10_lag		= . then diag10_lag 		= diag10;
					if surg1_lag		= . then surg1_lag			= surg1;
					if drg_lag			= . then drg_lag			= drg;
					if dis_cond_lag		= . then dis_cond_lag		= dis_cond;
				end;
			end;
			else if clmfreqcode = 3 then do;
				if clmfreqcode_lag in (1,2,3) then do;
					if disdt_lag 		= . then disdt_lag 			= disdt;
					if moddt_lag 		= . then moddt_lag 			= moddt;
					if sedate_lag 		= . then sedate_lag 		= sedate;
					if bill_type_lag 	= . then bill_type_lag 		= bill_type;
					if filedt_lag 		= . then filedt_lag 		= filedt;
					if maxprocessid_lag = . then maxprocessid_lag 	= maxprocessid;
					if claimnum_lag		= . then claimnum_lag 		= claimnum;
					if admdiag_lag		= . then admdiag_lag		= admdiag;
					if diag1_lag		= . then diag1_lag 			= diag1;
					if diag2_lag		= . then diag2_lag 			= diag2;
					if diag3_lag		= . then diag3_lag 			= diag3;
					if diag4_lag		= . then diag4_lag 			= diag4;
					if diag5_lag		= . then diag5_lag 			= diag5;
					if diag6_lag		= . then diag6_lag 			= diag6;
					if diag7_lag		= . then diag7_lag 			= diag7;
					if diag8_lag		= . then diag8_lag 			= diag8;
					if diag9_lag		= . then diag9_lag 			= diag9;
					if diag10_lag		= . then diag10_lag 		= diag10;
					if surg1_lag		= . then surg1_lag			= surg1;
					if drg_lag			= . then drg_lag			= drg;
					if dis_cond_lag		= . then dis_cond_lag		= dis_cond;
				end;
			end;
			else if clmfreqcode = 4 then do;
				if clmfreqcode_lag in (1,2,3,4) then do;
					if disdt_lag 		= . then disdt_lag 			= disdt;
					if moddt_lag 		= . then moddt_lag 			= moddt;
					if sedate_lag 		= . then sedate_lag 		= sedate;
					if bill_type_lag 	= . then bill_type_lag 		= bill_type;
					if filedt_lag 		= . then filedt_lag 		= filedt;
					if maxprocessid_lag = . then maxprocessid_lag 	= maxprocessid;
					if claimnum_lag		= . then claimnum_lag 		= claimnum;
					if admdiag_lag		= . then admdiag_lag		= admdiag;
					if diag1_lag		= . then diag1_lag 			= diag1;
					if diag2_lag		= . then diag2_lag 			= diag2;
					if diag3_lag		= . then diag3_lag 			= diag3;
					if diag4_lag		= . then diag4_lag 			= diag4;
					if diag5_lag		= . then diag5_lag 			= diag5;
					if diag6_lag		= . then diag6_lag 			= diag6;
					if diag7_lag		= . then diag7_lag 			= diag7;
					if diag8_lag		= . then diag8_lag 			= diag8;
					if diag9_lag		= . then diag9_lag 			= diag9;
					if diag10_lag		= . then diag10_lag 		= diag10;
					if surg1_lag		= . then surg1_lag			= surg1;
					if drg_lag			= . then drg_lag			= drg;
					if dis_cond_lag		= . then dis_cond_lag		= dis_cond;
				end;
			end;
			else if clmfreqcode = 7 then do;
				if clmfreqcode_lag in (1,2,3,4,7) then do;
					if disdt_lag 		= . then disdt_lag 			= disdt;
					if moddt_lag 		= . then moddt_lag 			= moddt;
					if sedate_lag 		= . then sedate_lag 		= sedate;
					if bill_type_lag 	= . then bill_type_lag 		= bill_type;
					if filedt_lag 		= . then filedt_lag 		= filedt;
					if maxprocessid_lag = . then maxprocessid_lag 	= maxprocessid;
					if claimnum_lag		= . then claimnum_lag 		= claimnum;
					if admdiag_lag		= . then admdiag_lag		= admdiag;
					if diag1_lag		= . then diag1_lag 			= diag1;
					if diag2_lag		= . then diag2_lag 			= diag2;
					if diag3_lag		= . then diag3_lag 			= diag3;
					if diag4_lag		= . then diag4_lag 			= diag4;
					if diag5_lag		= . then diag5_lag 			= diag5;
					if diag6_lag		= . then diag6_lag 			= diag6;
					if diag7_lag		= . then diag7_lag 			= diag7;
					if diag8_lag		= . then diag8_lag 			= diag8;
					if diag9_lag		= . then diag9_lag 			= diag9;
					if diag10_lag		= . then diag10_lag 		= diag10;
					if surg1_lag		= . then surg1_lag			= surg1;
					if drg_lag			= . then drg_lag			= drg;
					if dis_cond_lag		= . then dis_cond_lag		= dis_cond;
				end;
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
		diag1 					= diag1_orig
		diag2 					= diag2_orig
		diag3 					= diag3_orig
		diag4 					= diag4_orig
		diag5 					= diag5_orig
		diag6 					= diag6_orig
		diag7 					= diag7_orig
		diag8 					= diag8_orig
		diag9 					= diag9_orig
		diag10 					= diag10_orig
		surg1 					= surg1_orig
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
		diag1_lag 				= diag1
		diag2_lag 				= diag2
		diag3_lag 				= diag3
		diag4_lag 				= diag4
		diag5_lag 				= diag5
		diag6_lag 				= diag6
		diag7_lag 				= diag7
		diag8_lag 				= diag8
		diag9_lag 				= diag9
		diag10_lag 				= diag10
		surg1_lag				= surg1
		drg_lag					= drg
		dis_cond_lag			= dis_cond
	;
	run;

	proc sort data = update_logic_5 sortseq = uca (numeric_collation = on);
	by 	member_key person_key
		%if &varexist_ind. > 0 %then %do; source_system_id %end; 
		tin admdt bill_type sbdate svcdt
		moddt sedate filedt maxprocessid linenum filedt filed;
	run;
	
	proc summary data=update_logic_5 nway missing;
	class
		%if &varexist_ind. > 0 %then %do; enterprise_member_id %end;
		member_key person_key start_date source system claim_source 
		tin bill_type facilitytypecode 
		%if &varexist_ind. > 0 %then %do; system_member_id source_system_id  %end;
		svcdt moddt admdt disdt sbdate sedate
		revcd proccd mod1 mod2  
		facility_indicator majcat 
		dq_claim_flag dq_member_flag wflow_exec_id historical;
	id 	claim_key claimnum linenum maxprocessid FileDt filed 
		npi provname provider_key practice_key group_id practice_id
		memberid ssn lname fname mname dob dod sex address1 address2 city state zip phone
		admdiag diag1 diag2 diag3 diag4 diag5 diag6 diag7 diag8 diag9 diag10 
		poa1 poa2 poa3 poa4 poa5 poa6 poa7 poa8 poa9 poa10 Dis_Cond
		surg1 drg units submit pos
		payorid1 payorname1;
	output out=update_logic_6 (drop=_type_ _freq_);
	run;

	proc sort data=update_logic_6 (keep=member_key person_key) out=existing_members nodupkey;
	by member_key person_key;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Hospital Case History - Target IP EDW history data based on Practice Key and 
	|                         Member Key based on incoming 837 Institutional data
	|
	+------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
       select 
                   distinct(b.practice_key) into: practice_key separated by ','
       from ids.datasource_practice as a inner join
            ciedw.practice as b on a.practiceid=b.vsource_practice_key 
       where a.datasourceid=&practice_id. and b.vsource_practice_key ne .;
	quit;

	%put NOTE: practice_key = &practice_key;
	%put NOTE: practice_id = &practice_id;

	proc sql noprint;
	create table case_logic_history as
	      select distinct
	            max(eh.encounter_key)         as e_key,
	            eh.practice_key, 
	            mp.member_key                 as mkey, 
	            em.person_key                 as pkey,
	            eh.admit_date, 
	            eh.discharge_date,
	            eh.statement_begin_date       as sbdate,
	            eh.statement_end_date         as sedate,
	            eh.bill_type                  as bill_type length=3,
	            eh.tin
	      from existing_members         as em inner join
	            ciedw.encounter_header  as eh on em.person_key=eh.person_key inner join
				ciedw.encounter_detail  as ed on eh.client_key=ed.client_key and eh.encounter_key=ed.encounter_key inner join
	            ciedw.person_member_map as mp on eh.person_key=mp.person_key and eh.client_key=mp.client_key
	      where       eh.client_key=&client_id. and
	                  ed.data_source_id in (&practice_id.) and 
	                  eh.claim_source = &dataformatgroupid.
	      group by  
	            eh.practice_key, 
	            mp.member_key, 
	            eh.person_key,
	            eh.admit_date, 
	            eh.discharge_date, 
	            eh.statement_begin_date,
	            eh.statement_end_date,
	            eh.bill_type,
	            eh.tin
	;
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
		
		if clmfreqcode_edw = 1 then do;
			if clmfreqcode in (1,2,3,4,7) then do;
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
		else if clmfreqcode_edw = 2 then do;
			if clmfreqcode in (1,2,7) then do;
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
		else if clmfreqcode_edw = 3 then do;
			if clmfreqcode in (1,2,3) then do;
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
		else if clmfreqcode_edw = 4 then do;
			if clmfreqcode in (1,2,3,4) then do;
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
		else if clmfreqcode_edw = 7 then do;
			if clmfreqcode in (1,2,3,4,7) then do;
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
		moddt sedate filedt maxprocessid linenum filedt filed e_key;
	run;
	
	proc summary data=update_logic_8 nway missing;
	class
		member_key person_key practice_key tin bill_type 
		svcdt admdt disdt sbdate 
		revcd proccd mod1 mod2 majcat;
	id  sedate claim_key e_key claimnum linenum maxprocessid FileDt filed 
		start_date source system claim_source 
		npi provname provider_key group_id 
		%if &varexist_ind. > 0 %then %do; source_system_id enterprise_member_id system_member_id %end;
		memberid ssn lname fname mname dob dod sex address1 address2 city state zip phone
		moddt admdiag diag1 diag2 diag3 diag4 diag5 diag6 diag7 diag8 diag9 diag10 
		poa1 poa2 poa3 poa4 poa5 poa6 poa7 poa8 poa9 poa10 Dis_Cond surg1 drg
		units submit pos facility_indicator practice_id dq_claim_flag dq_member_flag wflow_exec_id historical
		payorid1 payorname1;
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

	proc sort data=hospital_all out=&dataset_in. (rename=surg1=surgical_cd1);
	by 	member_key person_key 
		%if &varexist_ind. > 0 %then %do; source_system_id %end; 
		tin admdt sbdate svcdt bill_type;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Fix - Filename
	+------------------------------------------------------------------------SASDOC*;	
	proc sort data = update_filename;
	 by claim_key ;
	run;

	proc sort data = &dataset_in.;
	 by claim_key ;
	run;
	
	data &dataset_in. ;
	 merge &dataset_in.     (in=a)
	       update_filename  (in=b);
	 by claim_key;
	 if a;
	 client_key=&client_id. ;
	run;

%mend edw_837_hospital_case_logic;
