/*HEADER-----------------------------------------------------------------------------------------------------------------------------
|
| program:  edw_guidelines_formats.sas
|
| location: 
+-------------------------------------------------------------------------------------------------------------------------------------
| history:  
| 05MAR2012 - EM Provyn format represents providers who are ci par at the time the format was created, from the edw view. The view is
|				 created per the client's definition of ci par (this format is used for both the prior and current reporting periods)
| 08MAR2012 - LS implement %macro call.
| 27APR2012 - EM Added Exempla-specific format for ProvType; this is temporary until IT implements a permanent solution
| 07MAY2012 - EM Added PHS-specific format for ProvType; this is temporary until IT implements a permanent solution
+-------------------------------------------------------------------------------------------------------------------------------HEADER*/
%macro edw_guidelines_formats;

%let client_id = &client_id;

data diag5cd (compress=yes keep=fmtname type start label);
  set ciedw.diagnosis;
  length fmtname $8. type $1. start $6. label $500.;
  start=diagnosis_cd;
  label=diagnosis_description;
  retain fmtname 'diag5cd' type 'C';
  output;
  if _n_=1 then do;
      start= 'other';
	  label = 'UNKNOWN';
	  output;
   end;
run;

data procfmt(compress=yes keep=fmtname type start label);
  set ciedw.procedure_cd;
  length fmtname $5. type $1. start $6. label $500.;
  start=procedure_code;
  label=procedure_code_description;
  retain fmtname 'CPT' type 'C';
  output;
run;

proc sort data=ciedw.provider out=provname(where=(client_key=&client_id. and npi1 ne ''));
  by npi1 descending provider_key;
run;

data provname(compress=yes keep=fmtname type start label);
  set provname;
  by npi1 descending provider_key;
  if first.npi1;
  length fmtname $8. type $1. start $10. label $120.;
  start=npi1;
  label=provider_name;
  retain fmtname 'ProvName' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
	 output;
  end;
run;

data provyn(compress=yes keep=fmtname type start label);
/*  set ciedw.provider;*/  /*EM 2/9/2012 - now pulls from vProvYN view in EDW*/
  set ciedw.vProvYN;
 length fmtname $8. type $1. start $10. label $1.;
  where client_key=&client_id and npi1 ne '' /*and (ci_status = 'PAR' or (ci_status = 'NONPAR' and clncl_int_exp_dt > datetime() ))*/;
  start=npi1;
  label='Y';
  retain fmtname 'ProvYN' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
	 output;
  end;
run;
  
proc sort data=ciedw.provider out=npi2pid(where=(client_key=&client_id. and npi1 ne ''));
  by npi1 descending provider_key;
run;
data npi2pid;
  set npi2pid;
  by npi1 descending provider_key;
  if first.npi1;
  length fmtname $8. type $1. start $10. label $10.;
  start=npi1;
  label=provider_key;
  retain fmtname 'NPI2PID' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
     output;
  end;
run;

proc sql;
  create table provspec as
  select a.npi1 as start,c.specialty_code
 from ciedw.PROVIDER a left outer join ciedw.PROVIDER_SPECIALTY_XREF b
  on a.PROVIDER_KEY=b.PROVIDER_KEY left outer join ciedw.SPECIALTY c
  on b.specialty_key=c.specialty_key 
  where isPrimary ne 0 and a.client_key=&client_id 
;

  create table provdir as
  select a.npi1 as start,c.SPECIALTY_DESCRIPTION as label format $50.
  from ciedw.PROVIDER a left outer join ciedw.PROVIDER_SPECIALTY_XREF b
  on a.PROVIDER_KEY=b.PROVIDER_KEY left outer join ciedw.SPECIALTY c
  on b.SPECIALTY_KEY=c.SPECIALTY_KEY
  where isPrimary ne 0 and client_key=&client_id 

;

  create table provtype as select distinct
  a.client_key,a.provider_key,c.npi1 as start,
     case when b.data_category in  ('Targeted','Manual')
	    then 'M'
		  when b.data_category = 'vMine' then 'V'
		  when b.data_category = 'PGF' then 'P'
		  else 'U'  end as provtype
  from ciedw.provider_practice_xref a,ciedw.practice b,ciedw.provider c
  where a.practice_key=b.practice_key
  and a.provider_key=c.provider_key
  and data_category is not null
   and a.client_key = &client_id
   and c.npi1 ne ''

  order by npi1;

  create table provprac as 
  select a.client_key,c.npi1 as start,a.PRIMARY_PRACTICE_IND,max(b.PRACTICE_NAME) as practice
  from ciedw.PROVIDER_PRACTICE_XREF a, ciedw.PRACTICE b,ciedw.provider c
  where a.PRACTICE_KEY=b.PRACTICE_KEY 
  and a.provider_key=c.provider_key
  and a.client_key=&client_id
  and c.npi1 ne ''
  group by a.client_key,c.npi1,a.PRIMARY_PRACTICE_IND
  order by NPI1
  ;
quit;

data provprac(compress=yes keep=fmtname type start label);
  set provprac;
  length label $50. fmtname $8.;
  label = practice;
  retain fmtname 'ProvPrac' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='';
     output;
  end;
run;

proc sort data=provtype;
by start descending provtype;
run;

/** Hierarchy of provider types is V, M, P per B Stropich email 13 May 2011 (A. Isaacs info) RDS **/
/*V, U, P, M*/
proc sort data=provtype nodupkey;
by start;
run;

data provtype(compress=yes keep=fmtname type start label);
  set provtype;
  length label $1. fmtname $8.;
  label = provtype;
  retain fmtname 'Provtype' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='';
     output;
  end;
run;

proc sort data=provspec;
by start specialty_code;
run;

data provspec(compress=yes keep=fmtname type start label);
  set provspec;
  by start specialty_code;
  if first.start;
  length label $2. fmtname $8.;
  label=specialty_code;
 retain fmtname 'ProvSpec' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
	 output;
  end;
run;

proc sort data=provdir;
by start label;
run;

data provdir(compress=yes keep=fmtname type start label);
  set provdir;
  by start label;
  if first.start;
  length fmtname $8.;
   retain fmtname 'ProvDir' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
	 output;
  end;
run;

data specdesc(compress=yes keep=fmtname type start label);
  set ciedw.specialty;
  length fmtname $8. label $50.;
  start=specialty_code;
  label=specialty_description;
  retain fmtname 'specd' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
	 output;
  end;
run;

data member_fname(compress=yes keep=fmtname type start label);
  format member_key 16.;
  set ciedw.member;
  *where ssn not in ('','0');
  where client_key = &client_id.;
  length fmtname $8. type $1. start $16. label $25. memberid1 $16.;
  memberid1=member_key;
  start=memberid1;
  label=fname;
  retain fmtname 'fname' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
	 output;
  end;
run;
  
data member_lname(compress=yes keep=fmtname type start label);
  format member_key 16.;
  set ciedw.member;
  *where ssn not in ('','0');
  where client_key = &client_id.;
  length fmtname $8. type $1. start $16. label $25. memberid1 $16.;
  memberid1=member_key;
  start=memberid1;
  label=lname;
  retain fmtname 'lname' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label='UNKNOWN';
	 output;
  end;
run;


data member_dob(compress=yes keep=fmtname type start label);
  format member_key 16.;
  set ciedw.member;
  *where ssn not in ('','0');
  where client_key = &client_id.;
  length fmtname $8. type $1. start $16. label 8. memberid1 $16.;
  memberid1 = member_key;
  start=memberid1;
  label=datepart(dob);
  retain fmtname 'dob' type 'C';
  output;
  if _n_=1 then do;
     start='other';
	 label=.;
	 output;
  end;
run;

proc sort data=provname nodupkey;
by start label;
run;

proc sort data=provyn nodupkey;
by start label;
run;

proc sort data=provspec nodupkey;
by start label;
run;

proc sort data=provdir nodupkey;
by start label;
run;

proc sort data=npi2pid nodupkey;
by start label;
run;

proc sort data=specdesc nodupkey;
by start label;
run;

%if %QUPCASE(&client.) = EXEMPLA %then %do;

	proc sql;
	create table provtype as
	select   all.client_key
			,all.provider_key	/*remove for view*/
			,all.npi as start
			,all.provtype
			,all.rank	/*remove for view*/
		from

	(	select distinct	 a.client_key
						,a.provider_key
						,c.npi1 as NPI
						,case when b.data_category in  ('Targeted','Manual') then 'M'
							  when b.data_category = 'vMine' then 'V'
							  when b.data_category = 'PGF' then 'P'
							  else 'U'  
						 end as provtype
						,case when b.data_category in  ('Targeted','Manual') then 3
							  when b.data_category = 'vMine' then 1
							  when b.data_category = 'PGF' then 2
							  else 4  
						 end as provrank
						,b.PRACTICE_EXP_DATE
						,a.EXP_DT
						,min(calculated provrank) as rank

			from 	 ciedw.provider_practice_xref a
					,ciedw.practice b
					,ciedw.provider c
					,ciedw.vprovyn d

				where 	a.practice_key=b.practice_key and 
						a.provider_key=c.provider_key and 
						data_category is not null and 
						a.client_key = 8 and 
						c.npi1=d.npi1 and
						(a.EXP_DT = . or today() < a.EXP_DT)

				group by npi
	) as all
		where all.provrank = all.rank
		order by all.npi, all.provrank;
	quit;

	/** Hierarchy of provider types is V, M, P per B Stropich email 13 May 2011 (A. Isaacs info) RDS **/
	/*V, U, P, M*/
	proc sort data=provtype nodupkey;
	by start;
	run;

	data provtype(compress=yes keep=fmtname type start label);
	  set provtype;
	  length label $1. fmtname $8.;
	  label = provtype;
	  retain fmtname 'Provtype' type 'C';
	  output;
	  if _n_=1 then do;
	     start='other';
		 label='';
	     output;
	  end;
	run;

%end;

%if %QUPCASE(&client.) = PHS %then %do;

	proc sql;
	create table provtype as
	select   all.client_key
			,all.provider_key	/*remove for view*/
			,all.npi as start
			,all.provtype
			,all.rank	/*remove for view*/
		from

	(	select distinct	 a.client_key
						,a.provider_key
						,c.npi1 as NPI
						,case when b.data_category in  ('Manual') then 'M'
							  when b.data_category = 'vMine' then 'V'
							  when b.data_category = 'PGF' then 'P'
							  when b.data_category = '837' then 'E'
							  else 'U'  
						 end as provtype
						,case when b.data_category in  ('Manual') then 4
							  when b.data_category = 'vMine' then 1
							  when b.data_category = 'PGF' then 2
							  when b.data_category = '837' then 3
							  else 5  
						 end as provrank
						,b.PRACTICE_EXP_DATE
						,a.EXP_DT
						,min(calculated provrank) as rank

			from 	 ciedw.provider_practice_xref a
					,ciedw.practice b
					,ciedw.provider c
					,ciedw.vprovyn d

				where 	a.practice_key=b.practice_key and 
						a.provider_key=c.provider_key and 
						data_category is not null and 
						a.client_key = 5 and 
						c.npi1=d.npi1 and
						(a.EXP_DT = . or today() < a.EXP_DT)

				group by npi
	) as all
		where all.provrank = all.rank
		order by all.npi, all.provrank;
	quit;

	/** Hierarchy of provider types is V, M, P per B Stropich email 13 May 2011 (A. Isaacs info) RDS **/
	/*V, U, P, M*/
	proc sort data=provtype nodupkey;
	by start;
	run;

	data provtype(compress=yes keep=fmtname type start label);
	  set provtype;
	  length label $1. fmtname $8.;
	  label = provtype;
	  retain fmtname 'Provtype' type 'C';
	  output;
	  if _n_=1 then do;
	     start='other';
		 label='';
	     output;
	  end;
	run;

%end;


proc format cntlin=diag5cd;
proc format cntlin=procfmt;
proc format cntlin=provname;
proc format cntlin=provyn;
proc format cntlin=provspec;
proc format cntlin=provdir;
proc format cntlin=member_fname;
proc format cntlin=member_lname;
proc format cntlin=member_dob;
proc format cntlin=npi2pid;
proc format cntlin=specdesc;
proc format cntlin=provtype;
*proc format cntlin=provprac;
run;

%mend edw_guidelines_formats;




