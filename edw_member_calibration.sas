
/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_calibration.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create mscore dataset which hosts the calibrations needed for 
|           the member linking algorithm
|
| logic:     
|
| input:    ciedw.member, ciedw.mla satellite tables
|                         
| output:   M:\CCCPP\sasdata\CIETL\member\mscore.sas7bdat 
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2012 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/


%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
options sastrace=',,,d';
options bufsize=600k; 

%bpm_environment;

libname bsb  "M:\sastemp\CIStaging\LinkingAnalysis";
libname bsb_ "M:\CCCPP\sastemp\CIprocess\LinkingAnalysis";


%*SASDOC----------------------------------------------------------------------
| Formats    
| 
+----------------------------------------------------------------------SASDOC*;
proc format cntlin=fmt.NickName;    run;
proc format cntlin=fmt.fnameGender; run;
proc format cntlin=fmt.zipcodes;    run;

data x;
d=put(day(today()),z2.);
m=put(month(today()),z2.);
y=put(year(today()),z4.);
date=trim(y)||trim(m)||trim(d);
call symput('date',trim(date));
put _all_ ;
run;

%put note:  date = &date. ; 

%put _all_ ;


%*SASDOC----------------------------------------------------------------------
| CIEDW Member Table  
| 
+----------------------------------------------------------------------SASDOC*;
data vmineandpgf (keep = eid d fname lname city address1 phone zip state sex ageR rename=(d=dob));
format eid 16. d mmddyy10.;
set ciedw.member (in=b keep = member_key fname lname city address1 phone zip state dob sex client_key);
where client_key=6 ;
eid=member_key;
d=datepart(dob);
if svcdt = . then svcdt = today();
ageR = int((svcdt - d) / 365.25);
drop member_key dob client_key;
run;


%*SASDOC----------------------------------------------------------------------
| Macro - fieldcount 
| Targets the CIEDW mla satellite tables
| 
+----------------------------------------------------------------------SASDOC*;
%macro fieldcount(input);

	%if &input. = dob %then %let missing = .;
	%else %let missing = "";

	%if &input. = dob %then %do;
		data &input._DB    (drop=counter)
		     &input._Count (rename=(counter=&input._count));
		format eid 16. d mmddyy10.;
		set ciedw.mla_member_&input. ( keep = &input counter member_key client_key source rename=(dob=d));
		where client_key=6 ;
		eid=member_key;
		dob=datepart(d);
		%edw_linking_cleaner_dob();
		drop member_key d;
		run;
		
		proc sql noprint;
		create table &input._Count as
		select eid, &input, sum(&input._count) as &input._count
		from &input._count
		group by eid, &input ;
		quit;		
	%end;
	%else %do;
		data &input._DB    (drop=counter)
		     &input._Count (rename=(counter=&input._count));
		format eid 16. ;
		set ciedw.mla_member_&input. ( keep = &input counter member_key client_key source);
		where client_key=6 ;
		eid=member_key;
		%if &input = address1 %then %do; %edw_linking_cleaner_addr(); %end;
		%if &input = city %then %do; %edw_linking_cleaner_city(); %end; 
		%if &input = sex %then %do; if sex not in ("M","F") then sex = put(cats(fname),$fnameGender.); %end;
		%if &input = lname %then %do; 
			lname = upcase(compbl(compress(lname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890")));
			if lname ne '' then lname = substr(lname,1,index(lname,"")-1);
			if cats(lname) in ("BOY","GIRL","TEST","PATIENT","REUSE") then lname = "";
			if length(lname) = 1 then lname = "";
		%end;
		%if &input = phone %then %do; %edw_linking_cleaner_phone(); %end;
		%if &input = state %then %do; %edw_linking_cleaner_state(); %end;
		%if &input = zip %then %do; %edw_linking_cleaner_zip(); %end;
		drop member_key client_key source;
		run;
		
		%if &input = fname %then %do;
			data temp01 (keep=eid);
			 set member_lname;
			 where lname in ("AHN","BAE","BAEK","BAN","BANG","BEA","BYUN",
					 "CHA","CHAE","CHAN","CHANG","CHEN","CHO","CHOE","CHOI","CHON","CHONG","CHOW","CHUN","CHUNG","DO","EAP","EUM",
					 "HA","HAHN","HAN","HONG","HUH","HWANG","IMM","JANG","JEON","JEONG","JI","JIN","JO","JOO","JU","JUN","JUNG",
					 "KANG","KAO","KHAN","KIM","KO","KOH","KONG","KOO","KU","KUK","KWAK","KWAN","KWON","KYE",
					 "LAM","LEE","LI","LIM","LIU","MA","MIN","MOON","MYONG","OH","PAIK","PAK","PARK","PHAN","RHEE","RYOO","RYU",
					 "SEO","SHIM","SHIN","SIM","SOHN","SON","SONG","SUH","SUK","SUL","TSAO","UM",
					 "WANG","WHANG","WON","WOO","YANG","YI","YIM","YOO","YOON","YU","YUM","YUN");
			run;
			
			proc sort data = temp01 nodupkey;
			 by eid;
			run;
			
			proc sort data = &input._DB;
			 by eid;
			run;
			
			proc sort data = &input._Count;
			 by eid;
			run;
			
			data &input._DB;
			 merge &input._DB (in=a)
			       temp01 (in=b);
			 by eid;
			 if a;
			 if a and b then do;
			   fname=compress(fname);
			 end;
			run;		
			
			data &input._Count;
			 merge &input._Count (in=a)
			       temp01 (in=b);
			 by eid;
			 if a;
			 fname = upcase(compbl(compress(fname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890")));
			 if scan(fname,1) in ("BABY","TEST","PATIENT","REUSE") then fname = "";
			 if a and b then do;
			   fname=compress(fname);
			 end;
			 else do;
			   if fname ne '' then fname = scan(fname,1);
			 end;
			run;
			
		%end;
		
		proc sql noprint;
		create table &input._Count as
		select eid, &input, sum(&input._count) as &input._count
		from &input._count
		group by eid, &input ;
		quit;
	%end;

	%let sum = ;
	proc sql noprint;
	select count(*)
	into :sum
	from &input._DB
	where &input. ne &missing.;
	quit;
	%put &sum.;

	data &input._CondRates (drop = &input._Count);
	length &input._post 7.5;
	set &input._Count;
	&input._post = &input._count / &sum.;
	run;

	proc summary data=&input._CondRates;
	class &input.;
	vars &input._post;
	output out=&input._denom (drop = _type_ _freq_ rename = (&input._post=&input._denom)) sum=;
	run;

	/******************* Final Member Satellite Tables **********************/
	proc sql;
	create table Member_&input. as
	select &input._CondRates.EID,&input._CondRates.&input.,&input._count.&input._count,(&input._post/&input._denom) as &input._Bayes
	from &input._CondRates 	left join &input._denom on &input._CondRates.&input.=&input._denom.&input.
							left join &input._count on &input._CondRates.EID=&input._count.EID and &input._CondRates.&input.=&input._count.&input.
	order by EID,&input.;
	quit;

	/***************************************************************************/

	proc datasets nolist library=work;
	delete &input._DB &input._Count &input._CondRates &input._denom; 
	run;
	quit;

	proc datasets library=work nolist;
	  modify member_&input.;
	  index create EID; 
	quit;

%mend fieldcount;

%fieldcount(lname);
%fieldcount(fname);
%fieldcount(dob);
%fieldcount(address1);
%fieldcount(city);
%fieldcount(state);
%fieldcount(zip);
%fieldcount(phone);
%fieldcount(sex);


%*SASDOC----------------------------------------------------------------------
| Target only EMPI members 
| 
+----------------------------------------------------------------------SASDOC*;

data empi;
set	member_lname    (keep = eid)
	member_fname    (keep = eid)
	member_dob      (keep = eid)
	member_address1 (keep = eid)
	member_city     (keep = eid)
	member_state    (keep = eid)
	member_zip      (keep = eid)
	member_phone    (keep = eid)
	member_sex      (keep = eid) ;
run;

proc sort data = empi nodupkey;
by eid;
run;

proc sort data = vmineandpgf ;
by eid;
run;

data vmineandpgf ; 
merge vmineandpgf (in=a)
      empi        (in=b);
by eid;
if a and b;
run;


%*SASDOC----------------------------------------------------------------------
| Merge    
| 
+----------------------------------------------------------------------SASDOC*;
proc sort data=vmineandpgf nodupkey;
by eid fname lname city address1 phone zip state dob sex;
run;

proc sort data=vmineandpgf out=member_unique nodupkey;
by eid;
run;

data member_unique;
set member_unique;
obstotal = _n_;
run;

proc summary data=member_unique;
var obstotal;
output out=membercount (drop= _type_ _freq_) max=;
run;

data _null_;
 set membercount;
 call symput ('obstotal',obstotal);
run;

%put NOTE: obstotal = &obstotal;


%*SASDOC----------------------------------------------------------------------
| Macro - validation age
| 
+----------------------------------------------------------------------SASDOC*;
%macro validation_age(method,trialnum);

	%do i=0 %to &trialnum.;

		data member_test;
		set member_unique;
		where ageR = &i.;/**age experiment;**/ 
		random = rand('BINOMIAL',0.001,&obstotal.);
		run;
		
		proc sort data=member_test;
		by random;
		run;

		data member_test;
		set member_test;
		if _n_ le 500;
		run;
		
		proc sort data=member_test;
		by EID;
		run;

		/**validation and test sets;*/
		data PM_clm (drop = EID memAgeR);
		format memberid 16.;
		merge vmineandpgf (in=a) member_test (in=b keep = EID ageR rename = (ageR=memAgeR));
		by EID;
		if b;
		if ageR = memAgeR;
		memberid = EID;
		run;

		%include &method.;

		proc datasets library=work nolist;
		delete PM_perm PM_clm;
		run;  
		quit;

		data bsb.AgeSet&i.;
		/*data bsb.AgeSet_Miss; *missing DOB only;*/
		set bsb.AgeR1-bsb.AgeR40;
		run;

		proc datasets nolist library=bsb;
		delete AgeR:(gennum=all);
		run;
		quit;

		proc datasets nolist library=work;
		delete Sub:(gennum=all);
		run;
		quit;

	%end;

%mend validation_age;


%*SASDOC----------------------------------------------------------------------
| Macro - validation missing
| 
+----------------------------------------------------------------------SASDOC*;
%macro validation_missing(method,trialnum);

		data member_test;
		set member_unique; 
		where dob = .;
		random = rand('BINOMIAL',0.001,&obstotal.);
		run;
		
		proc sort data=member_test;
		by random;
		run;

		data member_test;
		set member_test;
		if _n_ le 500;
		run;
		
		proc sort data=member_test;
		by EID;
		run;

		/**validation and test sets;*/
		data PM_clm (drop = EID memAgeR);
		merge vmineandpgf (in=a) member_test (in=b keep = EID ageR rename = (ageR=memAgeR));
		by EID;
		if b;
		if ageR = memAgeR;
		memberid = EID;
		run;

		%include &method.;

		proc datasets library=work nolist;
		delete PM_perm PM_clm;
		run;  
		quit;

		data bsb.AgeSet_Miss; /**missing DOB only **/
		set bsb.AgeR1-bsb.AgeR40;
		run;

		proc datasets nolist library=bsb;
		delete AgeR:(gennum=all);
		run;
		quit;

		proc datasets nolist library=work;
		delete Sub:(gennum=all);
		run;
		quit;

%mend validation_missing;


%*SASDOC----------------------------------------------------------------------
| Macro - edw_linking_calibration_sampling2_CC    
| 
+----------------------------------------------------------------------SASDOC*;
%validation_age("M:\CI\programs\edw\edw_member_calibration_score.sas",100);
%validation_missing("M:\CI\programs\edw\edw_member_calibration_score.sas",1);

data bsb.SamplePPV_Age;								
set bsb.AgeSet1-bsb.AgeSet100 
    bsb.AgeSet_Miss;
n = sum(tp,fn);
run;

