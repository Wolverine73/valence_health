
/*HEADER------------------------------------------------------------------------
|
| program:  dq_descriptive_statistics.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create the descriptive statistics report for the data quality process
|
| logic:    
|
| input:         
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01APR2010 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
|
| 01NOV2010 - Brian Stropich
|             Added the practice file count dataset and macro 
|             variable (practice_files_cnt) to the DQ process.
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_descriptive_statistics_cio;

	%global practice_files_cnt;
	
	*--------------------------------------------------------------------------------
	| Descriptive Statistics Report - Content
	+------------------------------------------------------------------------------*;	
	data ds00a;
	 length textvalue textdesc $70 ;
	 textvalue="&clientid. - &clientname.";
	 textdesc="Client";
	run;
	
	data ds00b;
	 length textvalue textdesc $70 ;
	 textvalue="&systemid. - &systemname.";
	 textdesc="System";
	run;
	
	data ds00c;
	 length textvalue textdesc $70 ;
	 textvalue="&practiceid. - &practicename.";
	 textdesc="Practice";
	run;
	
	data ds00cc;
	 length textvalue textdesc $70 ;
	 textvalue="&vlink_id.";
	 if textvalue = '&vlink_id.' then textvalue = '';
	 textdesc="Group IDs";
	run;
	
	data ds00d;
	 length textvalue textdesc $70 ;
	 textvalue="&filename.";
	 textdesc="File Validated";
	run;
	
	data ds00e;
	 length textvalue textdesc $70 ;
	 textvalue="&filename_last.";
	 if textvalue = '&filename_last.' then textvalue = "&filename.";
	 textdesc="File Expected";
	run;
	
	proc sql noprint; 
	 create table ds01a as
	 select put(count(*),10.) as textvalue,
	        "Total Monthly Observations" as textdesc format=$70.
	 from pm_&practice.;
	quit;	
	
	proc sql noprint; 
	 create table ds01aa as
	 select put(count(*),10.) as textvalue,
	        "Total All Observations" as textdesc format=$70.
	 from &datasetin.;
	quit;
	
	proc contents data = pm_&practice. 
	              out  = tempvars (keep=name) noprint;
	run;
	
	data tempvars;
	 set tempvars;
	 if upcase(name) in ('MEMBER_KEY');
	run;
	
	proc sql noprint;
	 select count(*) into: tempvars
	 from tempvars;
	quit;
	
	%if &tempvars ne 0 %then %do;	
		proc sql noprint; 
		 create table ds01b as
		 select put(count(distinct(MEMBER_KEY)),10.) as textvalue,
			"Total Members" as textdesc format=$70.
		 from pm_&practice.;
		quit;
	%end;
	%else %do;
		data ds01b ;
		 length textvalue textdesc $70 ;
		 textvalue="DNE";
		 textdesc="Total Members";
		run;	
	%end;
	
	proc sql noprint; 
	 create table ds01c as
	 select put(count(distinct(&var_npi.)),10.) as textvalue,
	        "Total Providers" as textdesc format=$70.
	 from pm_&practice.;
	quit;	

	proc sql noprint; 
	 create table ds02 as
	 select	 put(min(svcdt),WEEKDATE37.) as textvalue ,
 	        "Minimum Service Date" as textdesc format=$70.
	 from pm_&practice.;
	quit;

	proc sql noprint; 
	 create table ds03 as
	 select	 put(max(svcdt),WEEKDATE37.) as textvalue ,
 	        "Maximum Service Date" as textdesc format=$70.
	 from pm_&practice.
	 where svcdt < today() ;
	quit;
	
	proc sql noprint; 
	 create table ds04 as
	 select left(put(count(distinct(filename)),10.)) as textvalue,
	        "Total Files" as textdesc format=$70.
	 from &datasetin. ;
	quit;
	
	proc sql noprint;  
	 select  textvalue into: practice_files_cnt  
	 from ds04;
	quit;

	%put NOTE:  practice_files_cnt = &practice_files_cnt. ;

	%if &facility_indicator. = 1 %then %do; 

		data dq1 ;
		set &datasetin. ( keep =  member_key dob sex diag1 proccd drg revcd admdt disdt svcdt majcat surgical_cd1);

		total=1;

		if member_key ne 0 then dq_member = 1;
		else dq_member = 0;

		if (svcdt ne . and dob ne .) and ((svcdt - dob) < 7) then do;
			newborn = 1; 
		end;
		
		if missing(drg) then dq_drg=0;
		else dq_drg=1;

		if missing(diag1) then dq_diag1 = 0;
		else if put(diag1,$diag5cd.) = diag1 then dq_diag1 = 0;
		else dq_diag1 = 1;

		if put(proccd,$cpt.) = proccd then dq_proccd = 0;
		else dq_proccd = 1;

		if missing(surgical_cd1) then dq_surg = 0;
		else dq_surg=1; 

		if revcd not in (1:999) then dq_revcd = 0;
		else dq_revcd = 1;

		if dq_proccd = 0 and dq_revcd = 0 and dq_surg = 0 then dq_revcd_or_cpt = 0;
		else dq_revcd_or_cpt = 1;

		if majcat in (1:5,14,15) then ip = 1;
		else if majcat in (6:13,16,51) then op = 1;

		if svcdt = . or svcdt > today() then dq_svcdt = 0;
		else if (admdt ne . and disdt ne .) and (svcdt < admdt or svcdt > disdt) then dq_svcdt = 0;
		else dq_svcdt = 1;

		if ip = 1 then do;
			if admdt = . or admdt > today() then dq_admdt = 0;
			else if admdt > disdt then dq_admdt = 0;
			else dq_admdt = 1;
			if disdt = . or disdt > today() then dq_disdt = 0;
			else if disdt < admdt then dq_disdt = 0;
			else dq_disdt = 1;
		end;

		if dq_svcdt=1 and (dq_revcd_or_cpt=1 or dq_diag1=1 or dq_drg=1) then dq_claim = 1;
		else dq_claim = 0;


		if "70000" <= proccd <= "79999" then radio = 1;
		else if "80000" <= proccd <= "89999" then lab = 1;
		if proccd in ("80047","80048","80053","80050") then panel = 1;
		else if proccd in ("81000","81001","81002","81003","81005","81007","81020") then urine = 1;
		else if proccd in ("80051") then electro = 1;
		else if proccd in ("84520") then bun = 1;
		else if proccd in ("82565") then creatinine = 1;
		else if proccd in ("84132") then potassium = 1;
		else if proccd in ("84295") then sodium = 1;
		else if proccd in ("85025","85027") then blood = 1;
		else if proccd in ("85018") then hemog = 1;
		else if proccd in ("85014") then hemoc = 1;
		else if proccd in ("85032") then diff = 1;

		if "100" <= revcd <= "249" then room = 1;
		if dq_revcd = 1 then do;
			if (
			"251" <= revcd <= "269" or 
			"279" <= revcd <= "279" or
			"290" <= revcd <= "359" or
			"370" <= revcd <= "410" or
			"412" <= revcd <= "413" or
			"419" <= revcd <= "419" or
			"420" <= revcd <= "540" or
			"542" <= revcd <= "659" or
			"730" <= revcd <= "740" or
			"750" <= revcd <= "759" or
			"761" <= revcd <= "761" or
			"770" <= revcd <= "771" or
			"779" <= revcd <= "779" or
			"790" <= revcd <= "790" or
			"799" <= revcd <= "799" or
			"810" <= revcd <= "859" or
			"880" <= revcd <= "889" or
			"900" <= revcd <= "929" or
			"940" <= revcd <= "989") and dq_proccd = 0 then dq_revcd_and_cpt = 0;
			else dq_revcd_and_cpt = 1;
		end; 

		run;

		proc sql;
		create table dqhosp1 as
		select 
		sum(total ) as total,
		sum(ip ) as ip,
		sum(op ) as op,	
		sum(dq_claim ) as dq_claim,
		sum(dq_diag1 ) as dq_diag1,
		sum(dq_svcdt ) as dq_svcdt,
		sum(dq_proccd ) as dq_proccd, 
		sum(dq_revcd ) as dq_revcd, 
		sum(dq_surg ) as dq_surg, 
		sum(dq_revcd_or_cpt ) as dq_revcd_or_cpt, 		
		sum(dq_admdt ) as dq_admdt,
		sum(dq_disdt ) as dq_disdt,		
		sum(radio ) as radio,
		sum(lab ) as lab,
		sum(panel ) as panel,
		sum(urine ) as urine,
		sum(electro ) as electro,
		sum(bun ) as bun,
		sum(creatinine ) as creatinine,
		sum(potassium ) as potassium,
		sum(sodium ) as sodium,
		sum(blood ) as blood,
		sum(hemog ) as hemog,
		sum(hemoc ) as hemoc
		from dq1;
		quit;

		proc transpose data = dqhosp1 out = dqhosp2 ;
		run;

		data dq_hospital2;
		format textdesc $70. ;
		set dqhosp2;
		textvalue=left(put(col1,10.));
		textdesc=left(_name_);

		if textdesc='total' then textdesc='***** Institutional Record Counts *****';
		if _name_='total' then textvalue=' ';
		if textdesc='ip' then textdesc='Total Inpatient Records';
		if textdesc='op' then textdesc='Total Outpatient Records';
		if textdesc='dq_revcd' then textdesc='Total Valid Revenue Code Records';
		if textdesc='dq_proccd' then textdesc='Total Valid CPT Code Records';
		if textdesc='dq_surg' then textdesc='Total Valid ICD9 Code Records';
		if textdesc='dq_admdt' then textdesc='Total Valid Admission Dates Records';
		if textdesc='dq_disdt' then textdesc='Total Valid Discharge Dates Records';
		if textdesc='dq_claim' then textdesc='Total Valid Claim Hospital Records';
		if textdesc='dq_revcd_or_cpt' then textdesc='Total Valid CPT/ICD/Rev Records';
		if textdesc='radio' then textdesc='Total Valid Radiology Records';
		if textdesc='lab' then textdesc='Total Valid Laboratory Records';
		if textdesc='panel' then textdesc='Total Valid Panel Records';
		if textdesc='urine' then textdesc='Total Valid Urine Records';
		if textdesc='creatinine' then textdesc='TTotal Valid Creatinine Records';
		if textdesc='potassium' then textdesc='TTotal Valid Potassium Records';
		if textdesc='sodium' then textdesc='TTotal Valid Sodium Records';
		if textdesc='blood' then textdesc='Total Valid Blood Records';
		if textdesc='hemog' then textdesc='TTotal Valid Hemog Records';
		if textdesc='hemoc' then textdesc='TTotal Valid Hemoc Records';

		if substr(textdesc,1,5) in ('Total','*****') ;
		drop _name_ col1;
		run;
		
		proc sql;
		/*Unique Members*/
		create table allmem1 as 
		select distinct member_key,dob,sex
		from dq1
		where dq_member = 1;
		quit;

		proc sql;
		/*Independent DQ Counts*/
		create table dq2 as
		select distinct sum(dq_member) as dq_member,sum(dq_diag1) as dq_diag1,sum(dq_proccd) as dq_proccd,
						sum(dq_revcd) as dq_revcd,sum(dq_revcd_or_cpt) as dq_revcd_or_cpt,sum(dq_svcdt) as dq_svcdt,sum(dq_claim) as dq_claim,
						sum(ip) as ip,sum(op) as op,sum(newborn) as newborn,sum(radio) as radio,sum(lab) as lab,sum(dq_admdt) as dq_admdt,sum(dq_disdt) as dq_disdt,
						sum(dq_revcd_and_cpt) as dq_revcd_and_cpt
		from dq1;
		quit;

		proc sql;
		/*Lab Code Counts for Unique Inpatient Stays*/
		create table ip1 as 
		select distinct member_key,dob,sex,admdt,disdt,sum(panel) as panel,sum(urine) as urine,sum(electro) as electro,sum(bun) as bun,
						sum(creatinine) as creatinine,sum(potassium) as potassium,sum(sodium) as sodium,sum(blood) as blood,sum(hemog) as hemog,
						sum(hemoc) as hemoc,sum(diff) as diff,sum(room) as room
		from dq1
		where ip = 1
		group by member_key,dob,sex,admdt,disdt;
		quit;

		proc sql noprint;

		/*Total Records*/
		select count(*)
		into:cnt_clm
		from dq1;

		/*Total Inpatient Records*/
		select count(*)
		into:cnt_ipclm
		from dq1
		where ip = 1;

		/*Total Outpatient Records*/
		select count(*)
		into:cnt_opclm
		from dq1
		where op = 1;

		/*Total Newborn Records*/
		select count(*)
		into:cnt_newbornclm
		from dq1
		where newborn = 1;

		/*Total Valid Revenue Code Records*/
		select count(*)
		into:cnt_revcdclm
		from dq1
		where dq_revcd = 1;

		/*Unique Members*/
		select count(*)
		into:cnt_allmem
		from allmem1;

		/*Unique Inpatient Stays*/
		select count(*)
		into:cnt_ipstays
		from ip1;

		quit;

		%put &cnt_clm.;
		%put &cnt_ipclm.;
		%put &cnt_opclm.;
		%put &cnt_newbornclm.;
		%put &cnt_revcdclm.; 
		%put &cnt_allmem.;
		%put &cnt_ipstays.;

		data dq3 (keep = 	rate_member
							rate_diag1 rate_proccd rate_revcd rate_revcd_or_cpt rate_svcdt rate_claim rate_ip rate_op rate_newborn rate_radio rate_lab
							rate_admdt rate_disdt  rate_revcd_and_cpt);
		set dq2;

		rate_member 		= dq_member			/ &cnt_clm.;
		rate_diag1 			= dq_diag1			/ &cnt_clm.;
		rate_proccd 		= dq_proccd			/ &cnt_clm.; 
		rate_revcd 			= dq_revcd			/ &cnt_clm.;
		rate_revcd_or_cpt 	= dq_revcd_or_cpt	/ &cnt_clm.;
		rate_svcdt 			= dq_svcdt			/ &cnt_clm.;
		rate_claim 			= dq_claim			/ &cnt_clm.;
		rate_ip				= ip				/ &cnt_clm.;
		rate_op				= op				/ &cnt_clm.;
		rate_newborn		= newborn			/ &cnt_clm.;
		rate_radio 			= radio				/ &cnt_clm.;
		rate_lab 			= lab				/ &cnt_clm.; 
		rate_admdt 			= dq_admdt			/ &cnt_ipclm.;
		rate_disdt 			= dq_disdt			/ &cnt_ipclm.;
		rate_revcd_and_cpt 	= dq_revcd_and_cpt	/ &cnt_revcdclm.;
		format 	rate_member
				rate_diag1 rate_proccd rate_revcd rate_revcd_or_cpt rate_svcdt rate_claim rate_ip rate_op rate_newborn rate_radio rate_lab
				rate_admdt rate_disdt rate_revcd_and_cpt percent10.2;
		run;

		proc transpose data=dq3 out=dq4 prefix=dq_rate;
		var rate_member
			rate_diag1 rate_proccd rate_revcd rate_revcd_or_cpt rate_svcdt rate_claim rate_ip rate_op rate_newborn rate_radio rate_lab
			rate_admdt rate_disdt rate_revcd_and_cpt;
		run;

		data ip2 (keep = member_key dob sex admdt disdt dq_ippanel dq_iproom dq_iplabs);
		set ip1;
		if panel >= 1 then dq_ippanel = 1;
		if room >= 1 then dq_iproom = 1;
		if urine >= 1 and (electro >= 1 or (bun >= 1 and creatinine >= 1 and potassium >= 1 and sodium >= 1)) and (blood >= 1 or (hemog >= 1 and hemoc >= 1 and diff >= 1)) then
			dq_iplabs = 1;
		run;

		proc sql;

		create table ip3 as 
		select 	sum(dq_ippanel) / &cnt_ipstays. as rate_ippanel format percent10.2,
				sum(dq_iproom) / &cnt_ipstays. as rate_iproom format percent10.2,
				sum(dq_iplabs) / &cnt_ipstays. as rate_iplabs format percent10.2
		from ip2;

		create table op1 as
		select 	sum(radio) / &cnt_opclm. as rate_opradio format percent10.2,
				sum(lab) / &cnt_opclm. as rate_oplab format percent10.2
		from dq1
		where op = 1;

		quit;

		proc transpose data=ip3 out=ip4 prefix=ip_rate;
		var rate_ippanel rate_iproom rate_iplabs;
		run;

		data ip5;
		set ip4 dq4 (rename = (dq_rate1=ip_rate1) where = (_name_ in ("rate_admdt","rate_disdt")));
		run;

		proc transpose data=op1 out=op2 prefix=op_rate;
		var rate_opradio rate_oplab;
		run;

		data all1;
		set dq4 (drop = dq_rate1) ip4 (drop = ip_rate1) op2 (drop = op_rate1);
		definition = _name_;
		run;

		/*Statistics*/
		proc format;
		value $reportfmt 
		"rate_member" 			= "Member Usage"
		"rate_diag1" 			= "Primary Diagnosis"
		"rate_proccd" 			= "Procedure Code"
		"rate_revcd" 			= "Revenue Code"
		"rate_revcd_or_cpt" 	= "Revenue or Procedure Code"
		"rate_svcdt" 			= "Service Date"
		"rate_claim" 			= "Claim Usage"
		"rate_ip"				= "Inpatient Claims"
		"rate_op"				= "Outpatient Claims"
		"rate_newborn"			= "Newborn Claims"
		"rate_radio" 			= "Radiology Claims"
		"rate_lab" 				= "Laboratory Claims"
		"rate_admdt" 			= "Admission Date"
		"rate_disdt" 			= "Discharge Date"
		"rate_ipadmdt" 			= "IP Admission Date"
		"rate_ipdisdt" 			= "IP Discharge Date"
		"rate_revcd_and_cpt" 	= "Revenue Code CPT Requirement"
		"rate_ippanel"			= "Inpatient Panel"
		"rate_iproom"			= "Inpatient Room and Board"
		"rate_iplabs" 			= "Inpatient Labs"
		"rate_opradio"			= "Outpatient Radiology"
		"rate_oplab"			= "Outpatient Labs"
		;
		run;

		/*Definitions*/
		proc format;
		value $define 
		"rate_npi" 				= "Rate of which NPI passes the Luhn Algorithm"	
		"rate_provyn" 			= "Rate of which NPI maps to a CI Participant"
		"rate_ssn" 				= "Rate of which SSN is a non-missing or true value"
		"rate_fname" 			= "Rate of which FNAME is a non-missing or true value"
		"rate_lname" 			= "Rate of which LNAME is a non-missing or true value"
		"rate_dob" 				= "Rate of which DOB is a non-missing or true value"
		"rate_sex" 				= "Rate of which SEX is a non-missing or true value"
		"rate_address1" 		= "Rate of which ADDRESS1 is a non-missing or true value"
		"rate_city" 			= "Rate of which CITY is a non-missing or true value"
		"rate_state" 			= "Rate of which STATE is a non-missing or true value"
		"rate_zip" 				= "Rate of which ZIP is a non-missing or true value"
		"rate_phone" 			= "Rate of which PHONE is a non-missing or true value"
		"rate_member" 			= "Rate of which claims have a valid SSN or combination of FNAME, LNAME, DOB, and SEX"
		"rate_diag1" 			= "Rate of which DIAG1 maps to a recognized value"
		"rate_proccd" 			= "Rate of which PROCCD maps to a recognized value"
		"rate_drg" 				= "Rate of which DRG maps to a recognized value"
		"rate_revcd" 			= "Rate of which REVCD maps to a recognized value"
		"rate_revcd_or_cpt" 	= "Rate of which claims have a valid REVCD or PROCCD"
		"rate_svcdt" 			= "Rate of which SVCDT is a non-missing or true value"
		"rate_claim" 			= "Rate of which claims have a valid combination of SVCDT, DIAG1, and PROCCD or REVCD"
		"rate_ip"				= "Inpatient percentage of total claims"
		"rate_op"				= "Outpatient percentage of total claims"
		"rate_newborn"			= "Newborn (<7 days old) percentage of total claims"
		"rate_radio" 			= "Radiology percentage of total claims"
		"rate_lab" 				= "Laboratory percentage of total claims"
		"rate_admdt" 			= "Rate of which ADMDT is a non-missing or true value for inpatient claims"
		"rate_disdt" 			= "Rate of which DISDT is a non-missing or true value for inpatient claims"
		"rate_ipadmdt" 			= "Rate of which IP ADMDT is a non-missing or true value for inpatient claims"
		"rate_ipdisdt" 			= "Rate of which IP DISDT is a non-missing or true value for inpatient claims"
		"rate_baby_ssn" 		= "Rate of which newborn patient (<7 days old) is not assigned a valid SSN"
		"rate_revcd_and_cpt" 	= "Rate of which REVCD contains corresponding PROCCD as defined by the NUBC"
		"rate_ippanel"			= "Rate of which inpatient stay contains >0 metabolic or health panels"
		"rate_iproom"			= "Rate of which inpatient stay contains >0 room and board REVCD"
		"rate_iplabs" 			= "Rate of which inpatient stay contains valid urinalysis, electrolyte, and blood work combination"
		"rate_opradio"			= "Radiology procedure percentage of total outpatient claims"
		"rate_oplab"			= "Lab procedure percentage of total outpatient claims"
		;
		run;

		data ip5;
		set ip5;
		if _name_='rate_admdt' then _name_='rate_ipadmdt';
		if _name_='rate_disdt' then _name_='rate_ipdisdt';
		run;

		data dq_hospital;
		 set dq4 (rename=(dq_rate1=rate) where =(_name_ not in ("rate_admdt","rate_disdt")))
		     op2 (rename=(op_rate1=rate))
		     ip5 (rename=(ip_rate1=rate));
		run;

	%end;


	data ds_all;
	 length textvalue textdesc $70 ;
	 set ds00a ds00b ds00c ds00cc ds00d ds00e ds01a ds01aa ds01b 
	     %if %sysfunc(exist(work.ds01c)) %then %do;
	        ds01c 
	     %end;
	     ds04 ds02 ds03
	     %if &facility_indicator. = 1 %then %do;
	       dq_hospital2
	     %end;;
	 textvalue=left(textvalue);
	run;
	
	data quality_control_definitions ;
	 format string_text $105. ;  
	 string_text="Individual Value and Moving Range Control Charts - Total observations within monthly files are";
     output;
     string_text="compared to the monthly history of all files by practice. Control limits are established based";
     output;
     string_text="on statistical significance departures away from the mean number of file records per month. Thus,";
     output;
     string_text="any observation outside of these control limits, whether too high or too low, is considered an";
     output;
     string_text="observational extreme based on the previous file history and is flagged for further review.";
	 output;
     string_text="Values:  0=No Issue 1=Lower Limit Issue 2=Upper Limit Issue";
	 output;
	 string_text=" ";
	 output; 
	 string_text="Fraction Nonconforming Control Charts - The rate of invalid or missing (nonconforming) records ";
     output;
     string_text="within monthly files are compared within respective fields to the monthly history of all files by";
     output;
     string_text="practice.  An upper control limit is established based on statistical significance departure above";
     output;
     string_text="the mean rate of nonconforming records per month.  Thus, any observation above the upper control ";
     output;
     string_text="limit represents an observational extreme based on the previous file history and is flagged for ";
     output;
     string_text="further review.";
     output;
     string_text="Values:  0=No Issue 1=Lower Limit Issue 2=Upper Limit Issue";
	 output; 
	run;


	
%mend dq_descriptive_statistics_cio;
 
