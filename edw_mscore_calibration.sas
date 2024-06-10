/*HEADER------------------------------------------------------------------------
|
| program:  edw_mscore_calibration.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create Thresholds for Probability Linking
|
| logic:                  
|
| input:    
|                        
| output:   Match Score Format
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 09MAY2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/


*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("\\sas2\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

*SASDOC--------------------------------------------------------------------------
| Standard Assignments
+------------------------------------------------------------------------SASDOC*; 
%let client_id = 2; /*** Update client_id macro for %bpm_environment macro to execute correctly ***/
%let sas_mode = TEST; /*** Update dev (TEST) or prod (PROD) to toggle between environment ***/
%bpm_environment; 

%macro edw_mscore_calibration(client_key=,samplesize=);

	proc printto log="\\sas2\CI\programs\EDW\Calibration&client_key..log" new; run;

*SASDOC----------------------------------------------------------------------
| Obtain Counter Values for Distinct Member Field Combinations
+----------------------------------------------------------------------SASDOC*;
	proc sql;
	  create table db0 as
	  select distinct
		 a.scrubbed_ssn 												as ssn
		,a.scrubbed_fname												as fname
		,a.scrubbed_lname												as lname
		,a.scrubbed_sex													as sex
		,input(a.scrubbed_dob,yymmdd10.) 								as dob 		format mmddyy10.
		,a.scrubbed_address1											as address1
		,a.scrubbed_city												as city
		,a.scrubbed_state												as state
		,a.scrubbed_zip													as zip
		,a.scrubbed_phone												as phone
		,sum(c.count)													as count
		,int((max(c.maxdt) - input(a.scrubbed_dob,yymmdd10.))/365.25) 	as ageR
	  from vh_empi.person_detail a,vh_empi.person b,
		  (select distinct 
			 person_key
			,sum(counter) 												as count
			,max(input(last_svcdt,yymmdd10.)) 							as maxdt	format mmddyy10.
		  from vh_empi.person_workflow_detail
		  where client_key=&client_key.
		  group by person_key) c
	  where a.client_key=&client_key. and a.scrubbed_ssn ne "" and a.person_detail_key=b.person_detail_key and b.person_key=c.person_key
	  group by a.person_detail_key;
	quit;

*SASDOC----------------------------------------------------------------------
| Obtain Bayesian Weights
+----------------------------------------------------------------------SASDOC*;
	%macro getBayes(input);

		%if %upcase("&input.")="DOB" %then %let missing=.;
		%else %let missing="";

		%let sum=;
		proc sql noprint;
		  select sum(count)
		  into :sum
		  from db0
		  where &input. ne &missing. and ssn > "0";
		quit;
		%put &sum.;

		proc sql;

		  create table &input._DB0 as
		  select distinct 
			 &input.
			,sum(&input._post) as &input._den
		  from 
			  (select distinct 
			  	 a.ssn
				,a.&input.
				,sum(a.count)/&sum. as &input._post
			  from db0 a
			  where &input. ne &missing. and ssn > "0"
			  group by a.ssn,a.&input.)
		  group by &input.;

		  create table Member_&input. as
		  select distinct 
		  	 a.ssn
			,a.&input.
			,case
				when a.&input. ne &missing. then sum(a.count)		
				else 0	
			 end as count
			,case
				when a.&input. ne &missing. then sum(a.count)/(&sum.*b.&input._den) 
				else 0
			 end as &input._Bayes
		  from db0 (where = (ssn > "0")) a left join &input._DB0 b
		  on a.&input.=b.&input.
		  group by a.ssn,a.&input.
		  order by a.ssn,a.&input.;

		quit;

		proc datasets nolist library=work;
		  delete &input._DB0;
		run;
		quit;

		proc datasets library=work nolist;
		  modify member_&input.;
		  index create ssn; 
		run;
		quit;

	%mend getBayes;
	%getBayes(FName);
	%getBayes(LName);
	%getBayes(DOB);
	%getBayes(Address1);
	%getBayes(City);
	%getBayes(State);
	%getBayes(Zip);
	%getBayes(Phone);
	%getBayes(sex);

	proc sort data=db0 (where = (ssn > "0")) out=db1 nodupkey;
	by ssn fname lname city address1 phone zip state dob sex;
	run;
	proc sort data=db0 (where = (ssn > "0")) out=member_unique nodupkey;
	by ssn;
	run;

	data nickname;
	  set vh_empi.pl_nickname (keep = name nickname);
	  length fmtname $8. type $1.;
	  keep fmtname type start label;
	  retain fmtname "nickname" type "C";
	  do;
	  	start = name;
		label = nickname;
		output;
	  end;
	  if _n_=1 then do;
	  	start = "other";
		label = "NOMTCH";
		output;
	  end;
	run;
	proc sort data=nickname nodupkey;
	by start;
	run;
	proc format cntlin=nickname; 
	run;

*SASDOC----------------------------------------------------------------------
| Begin Randomized Sampling for Each Age 0 to 100 & Missing DOB
+----------------------------------------------------------------------SASDOC*;
	proc sql noprint;
	  select count(*)
	  into:obstotal
	  from member_unique;
	quit; 
	%put &obstotal.;

	%do i=0 %to 101;

		data member_test;
		  set member_unique (where = (%if &i.=101 %then %do; dob=. %end;  %else %do; ageR=&i. %end;));
		  random = rand('BINOMIAL',0.001,&obstotal.);
		run;
		proc sort data=member_test;
		by random;
		run;

		proc sql;
		  create table PM_clm (drop = count rename = (ssn=memberid)) as
		  select 
			 a.*
			,soundex(a.lname) as lsound1 length=15
			,soundex(a.fname) as fsound1 length=15
		  from db1 a,
			(select 
				 ssn 
			 	,ageR
			from member_test (obs=&samplesize.)) b
		  where a.ssn=b.ssn and a.ageR=b.ageR
		  order by a.ssn;
		quit;

*SASDOC----------------------------------------------------------------------
| Create Cartesian Products
+----------------------------------------------------------------------SASDOC*;
		%macro block(blockvar);

			%let where=;
			%let missing=;
			%if &blockvar.=dob %then %do;
				%let where=dob.ssn=lname.ssn and dob.ssn=phone.ssn;
				%let missing=.;
					%end;
			%else %do;
				%if &blockvar.=lname %then %let where=lname.ssn=dob.ssn and lname.ssn=phone.ssn;
				%else %if &blockvar.=phone %then %let where=phone.ssn=lname.ssn and phone.ssn=dob.ssn;
				%let missing="";
					%end;
				
			proc sql noprint;
			  create table Iterate as
			  select 	
				 distinct x.*
				,&blockvar..ssn 	as memssn
				,a.address1 		as memaddress1
				,a.address1_Bayes
				,b.city 			as memcity
				,b.city_Bayes
				,dob.DOB 			as memDOB
				,dob.DOB_Bayes
				,d.fname 			as memfname
				,d.fname_Bayes
				,lname.lname 		as memlname
				,lname.lname_Bayes
				,phone.phone 		as memphone
				,phone.phone_Bayes
				,g.state 			as memstate
				,g.state_Bayes
				,h.zip 				as memzip
				,h.zip_Bayes
				,i.sex 				as memsex
			  from 	PM_clm x,Member_Address1 a,Member_City b,Member_DOB dob,Member_fname d,
					Member_lname lname,Member_phone phone,Member_state g,Member_zip h,Member_sex i
			  where x.&blockvar.=&blockvar..&blockvar. and 
					(&blockvar..ssn=a.ssn and &blockvar..ssn=b.ssn and &blockvar..ssn=d.ssn and 
					&blockvar..ssn=g.ssn and &blockvar..ssn=h.ssn and &blockvar..ssn=i.ssn and &where.)
					and x.&blockvar. ne &missing.
					;
			quit;

			proc append base=MatchMaker1 data=Iterate; run;

			proc datasets nolist library=work;
			  delete Iterate;
			run;
			quit;

		%mend;
		%block(dob);
		%block(phone);
		%block(lname);

	*SASDOC----------------------------------------------------------------------
	| Compare
	+----------------------------------------------------------------------SASDOC*;
		data MatchedWeights;
		  set MatchMaker1;
		  %edw_linking_compare;
		run;

	*SASDOC----------------------------------------------------------------------
	| Analyze
	+----------------------------------------------------------------------SASDOC*;
		%macro scoreloop;

			%do mscore = 1 %to 40 %by 1;

				data Probabilistic;
				  set MatchedWeights (keep = memberid memssn matchscore ageR cells);  
				  if (matchscore*10) >= &mscore. and memberid=memssn then tp = 1;
				  else if (matchscore*10) >= &mscore. and memberid ne memssn then fp = 1;
				  else if (matchscore*10) <  &mscore. and memberid=memssn then fn = 1;
				  else tn = 1;
				  count = 1;
				  %if &i.=101 %then %do; test = -1 %end; %else %do; test = &i. %end;;
				  level = &mscore.;
				run;

				proc summary data=Probabilistic nway missing;
				class %if &i. < 101 %then %do; ageR %end; cells;
				vars tp fp fn tn count;
				id test level;
				output out=AgeR&mscore. (drop = _type_ _freq_) sum=;
				run;

			%end;

		%mend;
		%scoreloop;

		data AgeSet&i.;
		  set AgeR1-AgeR40;
		run;

		proc datasets nolist library=work;
		  delete 	AgeR:(gennum=all);
		  delete 	PM_clm
					MatchMaker1 
					MatchedWeights 
					Probabilistic;
		run;
		quit;

	%end;

	data SamplePPV_Age;								
	  set AgeSet0-AgeSet101;
	  n = sum(tp,fn);
	run;

	proc datasets nolist library=work;
	  delete AgeSet:(gennum=all);
	run;
	quit;

	proc summary data=SamplePPV_Age nway missing;
	class ageR cells level;
	vars tp fp fn tn count n;
	output out=PPVbyscore0 (drop = _type_ _freq_) sum=;
	run;
	data PPVbyscore1;
	  set PPVbyscore0;
	  if ageR ne . and cells ne . and level ne . and n ne .;
	  if tp = . then tp = 0;
	  if fp = . then fp = 0;
	  if fn = . then fn = 0;
	  if tn = . then tn = 0;
	  TPR = tp / sum(tp,fn);
	  FPR = fp / sum(tn,fp);
	  p = n / count;
	  PPV = (TPR*p) / ((TPR*p)+(FPR*(1-p)));
	  NPV = ((1-FPR)*(1-p)) / (((1-TPR)*p)+((1-FPR)*(1-p)));
	  Max1 = TPR*PPV / FPR;
	  format TPR PPV FPR NPV percent10.1;

	  if round(FPR,0.001) <= 0.005 and round(TPR,0.001) >= 0.005 and tp > fp;
	  level = level / 10;
	run;
			  
	data mscore (keep = start label fmtname type);
	  length start $5.;
	  set PPVbyscore1 (keep = ageR level cells TPR);
	  by ageR cells level;
	  if cells lt 3 then delete;
	  if first.cells;
	  fmtname = "mscore";
	  type = "C";
	  start = put(cats(cells),$1.)||put(cats(ageR),$4.);
	  label = level;
	  output;
	  if _n_ = 1 then do;
	 	start = "other";
		label = 3;
		output;
	  end;
	run;
	proc sort data=mscore nodupkey;
	by start;
	run;
	proc format cntlin=mscore; run;

	libname store "\\sas2\ci\programs\EDW\mscore";

	data store.mscore_&client_key. ;
	set mscore;
	run;

	proc printto; run;

%mend edw_mscore_calibration;

%**edw_mscore_calibration(client_key=13,samplesize=500);
/*%edw_mscore_calibration(client_key=15,samplesize=500);*/
%edw_mscore_calibration(client_key=2,samplesize=500);














