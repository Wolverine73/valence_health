
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  dq_thresholds.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  The purpose of the program is to set appropriate thresholds for invalid data rates
|			so that we can catch data team errors in loading data without many false positives.
|
| LOGIC:    The logic of the program is to find the 95th percentile of invalid data rates, by client 
|			for initial loads, then by practice over time. 
|
| INPUT:    Raw hospital data for PHS          
|
| OUTPUT:   SAS data set for PHS
|
+--------------------------------------------------------------------------------
| HISTORY:  
| 05MAY2010 - Abby Isaacs  - Clinical Integration  0.0.1
|             Original
|
| 27AUG2010 - Abby Isaacs  - Clinical Integration  0.0.2
|             Changed phone and zip minimun thresholds to 30%
|
| 24AUG2011 - Nick Williams - Clinical Integration  1.0.03
|             Add New NPI Section (CI participation by NPI).
|             -Will need to revisit once we start getting history for npi_ci_par (probably will have to add 
|              those assessment & validation variables to the history sas dataset. 
|             -may want to put here the lookback logic for claims first history date
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_thresholds(client=, practice=);

	options error=2;

	*SASDOC--------------------------------------------------------------------------
	|  Read in History Data
	+------------------------------------------------------------------------SASDOC*;
	data _null_;
	  cur_month = put(today(),yymmn.);
	  call symputx('cur_month',cur_month);
	run;

	%put NOTE:  Current Month: &cur_month.;

	data summary
		 check;
	  %if %symexist(wflow_exec_id) = 1 %then %do;
	    set history.summary_validation_history_cio;
	  %end;
	  %else %do;
	    set history.summary_validation_history;
	  %end;
	  date=datepart(complete_ts);
	  month=put(date,yymmn.);
	  if month = "&cur_month." then delete;  /** remove current month - needed for re-runs **/
	  if 	validation_memberid_valid = 0 or
			validation_svcdt_valid = 0 or
			validation_proccd_valid = 0 or
			validation_npi_valid = 0 then output check;
	  else output summary;
	run;

	*SASDOC--------------------------------------------------------------------------
	|  Ensure Only Final Load Each Month is Included
	+------------------------------------------------------------------------SASDOC*;
	proc sort data=summary nodupkey; 
	  by practiceid descending complete_ts;
	run;

	proc sort data=summary nodupkey;
	  by practiceid descending month;
	run; 

	data sum;
	  format date mmddyy10. complete_ts datetime16.;
	  length validation_npicipar_valid validation_npicipar_invalid 8. ;
	 
	  set summary;
	  validation_npicipar_valid =0;
      validation_npicipar_invalid=0;
	  where date > '31DEC2009'd; /** date valid data began being collected **/
	run;

	*SASDOC--------------------------------------------------------------------------
	|  Identify New Practices
	+------------------------------------------------------------------------SASDOC*;
	proc freq data=summary noprint;
	  tables practiceid/ out=nmonths;
	run;

	data newfile;
	  merge summary nmonths (keep=practiceid count);
	  by practiceid;
	  if count=1 then newpractice=1;
	  else newpractice =0;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Create Data Set With Missing Rate Variables For Analysis
	+------------------------------------------------------------------------SASDOC*;
	data missingrate;
	  set sum; 
	  address1_rate	= validation_address1_invalid/(validation_address1_invalid+validation_address1_valid);
	  city_rate	= validation_city_invalid/(validation_city_invalid + validation_city_valid);
	  diag1_rate	= validation_diag1_invalid/(validation_diag1_invalid +validation_diag1_valid);
	  dob_rate	= validation_dob_invalid/(validation_dob_invalid + validation_dob_valid );
	  fname_rate	= validation_fname_invalid/( validation_fname_invalid +  validation_fname_valid);
	  lname_rate	= validation_lname_invalid/ ( validation_lname_invalid +  validation_lname_valid);
	  memberid_rate	= validation_memberid_invalid/( validation_memberid_invalid + validation_memberid_valid);
	  npi_rate	= validation_npi_invalid/ (validation_npi_invalid + validation_npi_valid);
	  phone_rate	= validation_phone_invalid/ ( validation_phone_invalid +  validation_phone_valid);
	  pos_rate	= validation_pos_invalid/ (validation_pos_invalid + validation_pos_valid);	
	  proccd_rate	= validation_proccd_invalid/ (validation_proccd_invalid + validation_proccd_valid);
	  sex_rate	= validation_sex_invalid/ (validation_sex_invalid + validation_sex_valid);
	  state_rate	= validation_state_invalid/ ( validation_state_invalid + validation_state_valid);
	  svcdt_rate	= validation_svcdt_invalid/ (validation_svcdt_invalid +  validation_svcdt_valid);
	  zip_rate	= validation_zip_invalid/ (validation_zip_invalid + validation_zip_valid);
	  npicipar_rate	= validation_npicipar_invalid/ (validation_npicipar_invalid + validation_npicipar_valid); 
	  
	  proccd_sum	= (validation_proccd_invalid + validation_proccd_valid);
	  svcdt_sum	= (validation_svcdt_invalid +  validation_svcdt_valid);
	  
	  _TYPE_=0;
	  if proccd_sum ge svcdt_sum then sum=proccd_sum;
	  else sum=svcdt_sum;
	  
	  keep _type_ sum address1_rate city_rate diag1_rate dob_rate fname_rate lname_rate
	  memberid_rate npi_rate phone_rate pos_rate proccd_rate sex_rate state_rate svcdt_rate zip_rate npicipar_rate
	  clientid clientname complete_ts date filename practiceid practicename systemid systemname ; 
	run;

	*SASDOC--------------------------------------------------------------------------
	| Create Weights By Filesize
	+------------------------------------------------------------------------SASDOC*;
	proc means data= missingrate noprint; 
	  title 'Summary of Number of Cases per File';
	  output out=means mean=avgcases n=num nmiss=missnumber sum=totalcases mean=sum ; 
	  var sum;
	run;

	data weight;
	  retain totalcases num; 
	  merge means missingrate; 
	  by _type_; 	  
	  weight=(sum/totalcases)*num;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Log Transform the Data to Make the Distributions Normal
	+------------------------------------------------------------------------SASDOC*;
	data trans;
	  set weight;
	  address1_ln	=	log(address1_rate);
	  city_ln		=	log(city_rate);
	  diag1_ln	=	log(diag1_rate);
	  dob_ln		=	log(dob_rate);
	  fname_ln	=	log(fname_rate);
	  lname_ln	=	log(lname_rate);
	  memberid_ln	=	log(memberid_rate);
	  npi_ln		=	log(npi_rate);
	  phone_ln	=	log(phone_rate);
	  pos_ln		=	log(pos_rate);
	  proccd_ln	=	log(proccd_rate);
	  sex_ln		=	log(sex_rate);
	  state_ln	=	log(state_rate);
	  svcdt_ln	=	log(svcdt_rate);
	  zip_ln		=	log(zip_rate);
	  npicipar_ln	=	log(npicipar_rate); 
	run;

	*SASDOC--------------------------------------------------------------------------
	| Produce Quantiles by Client for New Files, Weighted and Unweighted
	+------------------------------------------------------------------------SASDOC*;
	proc sort data=trans;  
	  by clientid practiceid;
	run;

	proc univariate data= trans noprint; 
	  by clientid;
	  var address1_ln city_ln diag1_ln dob_ln fname_ln lname_ln memberid_ln npi_ln
		phone_ln pos_ln proccd_ln sex_ln state_ln svcdt_ln zip_ln npicipar_ln;
	  output out=percentu pctlpts=95 pctlpre= address1_rate_ city_rate_ diag1_rate_
		dob_rate_ fname_rate_ lname_rate_ memberid_rate_ npi_rate_ phone_rate_	pos_rate_
		proccd_rate_ sex_rate_	state_rate_	svcdt_rate_ zip_rate_ npicipar_rate_;
	run;

	proc univariate data= trans noprint; 
	  by clientid;
	  var address1_ln city_ln diag1_ln dob_ln fname_ln lname_ln memberid_ln npi_ln
		phone_ln pos_ln proccd_ln sex_ln state_ln svcdt_ln zip_ln npicipar_ln;
	  weight weight;
	  output out=percentw pctlpts=95 pctlpre= address1_rate_ city_rate_ diag1_rate_
		dob_rate_ fname_rate_ lname_rate_ memberid_rate_ npi_rate_ phone_rate_	pos_rate_
		proccd_rate_ sex_rate_	state_rate_	svcdt_rate_ zip_rate_ npicipar_rate_;
	run;

	data percentu1;
	  length weighted $5.;
	  set percentu;	  
	  weighted= 'TRUE';
	run;

	data percentw1;
	  length weighted $5.;
	  set percentw;	
	  weighted= 'FALSE';
	run;

	data byclient;
	  set /**percentu1**/ percentw1 ;
	  /*---Untransform Variables----------------------------------*/	
	  address1=	ceil(exp(address1_rate_95)*100)/100;
	  city	=	ceil(exp(city_rate_95)*100)/100;
	  diag1	=	ceil(exp(diag1_rate_95)*100)/100;
	  dob		=	ceil(exp(dob_rate_95)*100)/100;
	  fname	=	ceil(exp(fname_rate_95)*100)/100;
	  lname	=	ceil(exp(lname_rate_95)*100)/100;
	  memberid=	ceil(exp(memberid_rate_95)*100)/100;
	  npi		=	ceil(exp(npi_rate_95)*100)/100;
	  phone	=	ceil(exp(phone_rate_95)*100)/100;
	  pos		=	ceil(exp(pos_rate_95)*100)/100;
	  proccd	=	ceil(exp(proccd_rate_95)*100)/100;
	  sex		=	ceil(exp(sex_rate_95)*100)/100;
	  state	=	ceil(exp(state_rate_95)*100)/100;
	  svcdt	=	ceil(exp(svcdt_rate_95)*100)/100;
	  zip		=	ceil(exp(zip_rate_95)*100)/100;
	  npicipar  =	ceil(exp(npicipar_rate_95)*100)/100; 
	  
	  /*---set minimum invalid threshold for new files---*/
	  if	address1<	0.05 then	address1=	0.05;
	  if	city	<	0.05 then	city	=	0.05;
	  if	diag1	<	0.01 then	diag1	=	0.01;
	  if	dob		<	0.01 then	dob		=	0.01;
	  if	fname	<	0.01 then	fname	=	0.01;
	  if	lname	<	0.01 then	lname	=	0.01;
	  if	memberid<	0.01 then	memberid=	0.01;
	  if	npi		<	0.01 then	npi		=	0.01;
	  if	phone	<	0.30 then	phone	=	0.30;
	  if	pos		<	0.01 then	pos		=	0.01;
	  if	proccd	<	0.01 then	proccd	=	0.01;
	  if	sex		<	0.01 then	sex		=	0.01;
	  if	state	<	0.05 then	state	=	0.05;
	  if	svcdt	<	0.01 then	svcdt	=	0.01;
	  if	zip		<	0.30 then	zip		=	0.30;
	  if	npicipar <	0.01 then	npicipar=   0.01; 
	  keep clientid address1 city diag1 dob fname lname memberid
		 npi phone pos proccd sex state svcdt zip npicipar; 
	run;

	proc sort data = byclient;
	  by clientid;
	run;

	proc transpose data =  byclient out = client_thresholds (rename=(_name_=data_quality col1=reject_threshold_value));
	  by clientid;
	run;

	data client_thresholds;
	  set client_thresholds;
	  reject_threshold_value=reject_threshold_value*100;
	  warning_threshold_value=reject_threshold_value ;
	  if clientid=&client. ;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Produce Quantiles by Practice
	+------------------------------------------------------------------------SASDOC*;
	proc sort data=trans;
	  by practiceid clientid;
	run;

	proc univariate data=trans noprint; 
	  by practiceid clientid;
	  var address1_ln	city_ln	diag1_ln dob_ln fname_ln lname_ln memberid_ln
		npi_ln phone_ln pos_ln proccd_ln sex_ln state_ln svcdt_ln zip_ln npicipar_ln; 
	  output out=percent pctlpre=address1_rate_ city_rate_ diag1_rate_ dob_rate_
	  fname_rate_	lname_rate_ memberid_rate_ npi_rate_ phone_rate_ pos_rate_ proccd_rate_ 
	  sex_rate_ state_rate_ svcdt_rate_ zip_rate_ npicipar_rate_ pctlpts=95;
	run;

	data bypractice;
	  set percent;
	  /*---untransform variables---*/	
	  address1=	ceil(exp(address1_rate_95)*100)/100;
	  city	=	ceil(exp(city_rate_95)*100)/100;
	  diag1	=	ceil(exp(diag1_rate_95)*100)/100;
	  dob		=	ceil(exp(dob_rate_95)*100)/100;
	  fname	=	ceil(exp(fname_rate_95)*100)/100;
	  lname	=	ceil(exp(lname_rate_95)*100)/100;
	  memberid=	ceil(exp(memberid_rate_95)*100)/100;
	  npi		=	ceil(exp(npi_rate_95)*100)/100;
	  phone	=	ceil(exp(phone_rate_95)*100)/100;
	  pos		=	ceil(exp(pos_rate_95)*100)/100;
	  proccd	=	ceil(exp(proccd_rate_95)*100)/100;
	  sex		=	ceil(exp(sex_rate_95)*100)/100;
	  state	=	ceil(exp(state_rate_95)*100)/100;
	  svcdt	=	ceil(exp(svcdt_rate_95)*100)/100;
	  zip		=	ceil(exp(zip_rate_95)*100)/100;
	  npicipar  =	ceil(exp(npicipar_rate_95)*100)/100; 
	  
	  /*---set minimum invalid threshold for new files---*/
	  if	address1<	0.05 then	address1=	0.05;
	  if	city	<	0.05 then	city	=	0.05;
	  if	diag1	<	0.01 then	diag1	=	0.01;
	  if	dob		<	0.01 then	dob		=	0.01;
	  if	fname	<	0.01 then	fname	=	0.01;
	  if	lname	<	0.01 then	lname	=	0.01;
	  if	memberid<	0.01 then	memberid=	0.01;
	  if	npi		<	0.01 then	npi		=	0.01;
	  if	phone	<	0.30 then	phone	=	0.30;
	  if	pos		<	0.01 then	pos		=	0.01;
	  if	proccd	<	0.01 then	proccd	=	0.01;
	  if	sex		<	0.01 then	sex		=	0.01;
	  if	state	<	0.05 then	state	=	0.05;
	  if	svcdt	<	0.01 then	svcdt	=	0.01;
	  if	zip		<	0.30 then	zip		=	0.30;
	  if	npicipar <	0.01 then	npicipar=   0.01;
	  keep practiceid clientid address1 city diag1 dob fname lname memberid
		 npi phone pos proccd sex state svcdt zip npicipar; 
	run;


	*SASDOC--------------------------------------------------------------------------
	| Transpose the data into a vertical format for the DQ process
	+------------------------------------------------------------------------SASDOC*;
	proc sort data = bypractice;
	  by practiceid clientid;
	run;

	proc transpose data =  bypractice 
	               out  = practice_thresholds (rename=(_name_=data_quality col1=reject_threshold_value));
	  by practiceid clientid;
	run;

	data practice_thresholds;
	  set practice_thresholds;
	  reject_threshold_value=reject_threshold_value*100;
	  warning_threshold_value=reject_threshold_value ;
	  if practiceid=&practice. and clientid = &clientid. ;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Determine what threshold to use for the DQ process
	+------------------------------------------------------------------------SASDOC*;	
	proc sql noprint;
	 select count(*) into: client_thresholds
	 from client_thresholds;
	quit;

	proc sql noprint;
	 select count(*) into: practice_thresholds
	 from practice_thresholds;
	quit;

	%put NOTE:  client_thresholds = &client_thresholds. ;
	%put NOTE:  practice_thresholds = &practice_thresholds. ;

	%if &practice_thresholds. ne 0 %then %do;
		data data_threshold;
		 set practice_thresholds ;
		run;
	%end;
	%else %if &client_thresholds. ne 0 %then %do;
		data data_threshold;
		 set client_thresholds ;
		run;
	%end;
	%else %do;
		data data_threshold;
		 set history.data_threshold ; 
		run;
	%end;
	
	data data_threshold;
	 set data_threshold ;
	 if practiceid = 99336 and data_quality = 'proccd' then do;  /** test for cio nsap - 336 **/
	   reject_threshold_value=90;
	   warning_threshold_value=0;
	 end;
	run;
	
	data data_threshold ;
	 set data_threshold ;	 
	 /****** cccpp 837s - always has phone and pos missing *****************/
	 p=&practice_id. ;
	 if p in (1004,1035,1036,1037,1038) then do;
	   if upcase(data_quality) ='PHONE' then do;
	     reject_threshold_value=101 ;
	     warning_threshold_value=100;
	   end;
	   else if upcase(data_quality) ='POS' then do;
	     reject_threshold_value=101 ;
	     warning_threshold_value=100;
	   end;
	 end;
	run;
	
	data _null_;
	  set data_threshold ;
	  put _all_;
	run;

%mend dq_thresholds;









