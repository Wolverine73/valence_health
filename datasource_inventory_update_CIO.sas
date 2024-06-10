/*HEADER------------------------------------------------------------------------
|
| program:  datasource_list_inventory_update_CIO.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Update datasource inventory list on CHISQL.IntegrationDateSource
|
| logic:    
|
| input:  SAS claims dataset       
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 15FEB2011 - Winnie Lee - Clinical Integration
|			1. Ripped from vMine initial loading programs and created
|
| 04MAY2011 - Winnie Lee - Clinical Integration
|			1. Mod to deal with IT changing extensions in Filename
| 
+-----------------------------------------------------------------------HEADER*/

%macro datasource_inventory_update_CIO (where_condition=);

	proc sort data=out1.claims_&group (keep=filename) nodupkey out=listoffiles ;
	by filename;
	run;

	proc print data=listoffiles;
	title "List of Loaded Files from Practice ID &group";
	run;

	%vmine_tbl_rec_cnt(like_statement=%str(&where_condition.));

	data _null_;
	set tblcnts;
	 if dataerrors = 1 then call symput('dataerrors',1);
	 else call symput('dataerrors',0);
	run;

	%put NOTE: DATASOURCE INVENTORY UPDATE Data Errors - &dataerrors.;

	%*SASDOC--------------------------------------------------------------------------
	| Check Missing Percentages And Flag Data Errors
	------------------------------------------------------------------------SASDOC*; 
	data checks (drop=diag1 proccd payorname1 memberid dob sex pos svcdt);
	set out1.claims_&group (keep=diag1 proccd payorname1 memberid dob sex pos svcdt);
	if diag1 = "" then diag1_missing = 1;
	else diag1_missing = 0;
	if proccd = "" then proccd_missing = 1;
	else proccd_missing = 0;
	if memberid = "" then ssn_missing = 1;
	else ssn_missing = 0;
	if dob = . then dob_missing = 1;
	else dob_missing = 0;
	if sex = "" then sex_missing = 1;
	else sex_missing = 0;
	if svcdt = . then svcdt_missing = 1;
	else svcdt_missing = 0;
	if payorname1 = "" then payor_missing = 1;
	else payor_missing = 0;
	if pos = "" then pos_missing = 1;
	else pos_missing = 1;
	run;

	proc summary data=checks nway missing;
	var diag1_missing proccd_missing ssn_missing payor_missing dob_missing sex_missing pos_missing svcdt_missing;
	output out=checks2 (drop=_type_ rename=_freq_=ttl) sum=;
	run;

	data checks3 (keep=diag1_pcnt proccd_pcnt ssn_pcnt payor_pcnt dob_pcnt pos_pcnt sex_pcnt svcdt_pcnt);
	set checks2;
	diag1_pcnt  = round(diag1_missing / ttl);
	proccd_pcnt = round(proccd_missing / ttl);
	ssn_pcnt    = round(ssn_missing / ttl);
	payor_pcnt  = round(payor_missing / ttl);
	dob_pcnt	= round(dob_missing / ttl);
	sex_pcnt	= round(sex_missing / ttl);
	pos_pcnt	= round(pos_missing / ttl);
	svcdt_pcnt	= round(svcdt_missing / ttl);

	if diag1_pcnt > 50 then call symput('dataerrors',1);
	else if proccd_pcnt > 50 then call symput('dataerrors',1);
	else if ssn_pcnt > 50 then call symput('dataerrors',1);
	else if payor_pcnt > 50 then call symput('dataerrors',1);
	else if dob_pcnt > 50 then call symput('dataerrors',1);
	else if sex_pcnt > 50 then call symput('dataerrors',1);
	else if pos_pcnt > 50 then call symput('dataerrors',1);
	else if svcdt_pcnt > 50 then call symput('dataerrors',1);
	else call symput('dataerrors',&dataerrors.);
	run;

	proc summary data=out1.claims_&group (keep=svcdt) nway missing;
	where '01jun2006'd <= svcdt <= today();
	format svcdt yymmn6.;
	class svcdt;
	output out=dt1 (drop=_type_ rename=_freq_=cnt);
	run;

	data dt2;
	set dt1;
	length svcdt2 $6.;
	svcdt2 = put(svcdt,yyq.);
	run;

	proc summary data=out1.claims_&group nway missing;
	format svcdt yyq.;
	class svcdt;
	output out=dt3 (drop=_type_ rename=_freq_=cnt);
	run;

	data dt4;
	set dt3;
	length svcdt2 $6. qtr_avg 8.;
	svcdt2 = put(svcdt,yyq.);
	qtr_avg = round(cnt/3);
	run;

	%put  NOTE: DATASOURCE INVENTORY UPDATE Data Errors - &dataerrors.;

	data dt5 (drop=svcdt2);
	merge dt2 (in=a)
		  dt4 (in=b drop=cnt svcdt);
	by svcdt2;
	if a;
	length diff diff_pcnt 8. flag $4.;
	diff = cnt - qtr_avg;
	diff_pcnt = round(((diff/qtr_avg) * 100),.1);
	if diff_pcnt >= 40 then flag = "HIGH";
	else if diff_pcnt <= -40 then flag = "LOW";
	else flag = "";

	if cats(flag) = "LOW" and last.svcdt2 then call symput('dataerrors',1);
	else call symput('dataerrors',&dataerrors.);
	run;

	%put  NOTE: DATASOURCE INVENTORY UPDATE Data Errors - &dataerrors.;

	proc sort data=dt5 out=dt6;
	by descending svcdt;
	run;

	data dt7;
	set dt6;
	by descending svcdt;
	length lastmonth1 lastmonth2 lastmonth3 8.;
	retain lastmonth1 lastmonth2 lastmonth3;
	if lastmonth1 = . then lastmonth1 = cnt;
	else if lastmonth2 = . and lastmonth1 ne . and cnt ne lastmonth1 then lastmonth2 = cnt;
	else if lastmonth3 = . and lastmonth1 ne . and cnt ne lastmonth2 then lastmonth3 = cnt;
	run;

	proc sort data=dt7 out=dt8;
	by svcdt lastmonth1 lastmonth2 lastmonth3;
	run;

	data dt9 (drop=lastmonth1-lastmonth3 lm1-lm3);
	set dt8;
	by svcdt;
	length lm1 lm2 lm3 8.;
	retain lm1 lm2 lm3;
	if lm1 = . then lm1 = lastmonth1;
	if lm2 = . then lm2 = lastmonth2;
	if lm3 = . then lm3 = lastmonth3;

	length last3monthsavg last3monthsdiff last3monthsdiff_pcnt 8. flag2 $4.;
	last3monthsavg 	 	 = round(sum(lm1,lm2,lm3) / 3);
	last3monthsdiff 	 = cnt - last3monthsavg;
	last3monthsdiff_pcnt = round(((last3monthsdiff/last3monthsavg)*100),.1);
	if last3monthsdiff_pcnt >= 40 then flag2 = 'HIGH';
	else if last3monthsdiff_pcnt <= -40 then flag2 = 'LOW';

	if cats(flag2) = "LOW" and last.svcdt then call symput('dataerrors',1);
	else call symput('dataerrors',&dataerrors.);
	run;

	%put  NOTE: DATASOURCE INVENTORY UPDATE Data Errors - &dataerrors.;

	proc sql;
		update IDS.TRANSMISSION
		set 
			processeddate 	= datetime(),
			dataerrors 		= &dataerrors
/*		where filename = trim("&filename_last") || ".txt";*/
		where substr(filename,1,index(filename,'.') - 1) = trim("&filename_last"); /* 04May2011 - WLee mod to deal with IT changing extensions in Filename*/
	quit;

	ods listing;

	proc print data=IDS.TRANSMISSION;
	where datepart(processeddate)=today() and datasourceid = &group;
	var datasourceid filename dataerrors processeddate;
	title "Updated Practice &group in SQL TRANSMISSION Table";
	run;

	ods listing close;

	proc datasets library = work;
	delete 
	listoffiles
	checks
	checks2
	checks3
	dt0
	dt1-dt9
	dups
	proccdmissing
	run;
	quit;

%mend;
