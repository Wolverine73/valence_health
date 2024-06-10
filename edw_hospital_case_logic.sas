
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_case_logic.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load Institutional Hospital data for CCCPP        
|
| INPUT:    CCCPP Self Pay pipe delimited files
|
| OUTPUT:   practice_(IDS) dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 01DEC2011 - Brian Stropich  - Clinical Integration  1.0.01
|             Created macro 
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 08JUN2012 - Winnie Lee - Clinical Integration 1.2 H02
|             Added person key and member key to case logic
|
+-----------------------------------------------------------------------HEADER*/

%macro edw_hospital_case_logic(dataset_in=);

	*SASDOC--------------------------------------------------------------------------
	| Hospital Case History - Target IP EDW history data based on Practice Key and 
	|                         Member Key based on incoming self pay data
	|
	+------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
	select distinct(practiceid) into: vlink_id separated by ','
	from ids.datasource_practice
	where datasourceid=&practice_id.;
	quit;

	%put NOTE: vlink_id = &vlink_id;
	%put NOTE: practice_id = &practice_id;

	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table case_logic_history as select * from connection to oledb
		(     
		    select max(eh.encounter_key) as e_key, 
		       eh.practice_key, 
		       m.member_key as mkey, 
		       eh.person_key as pkey,
		       ed.maj_cat_name as majcat,
		       eh.diagnosis_cd1 as diag1, 
		       eh.admit_date, 
		       eh.discharge_date, 
		       eh.tin,
		       ed.service_date, 
		       ed.revenue_code as revcd, 
		       pr.procedure_code as proccd
		    from  
		          [dbo].[encounter_detail] as ed inner join
		          [dbo].[encounter_header] as eh on ed.encounter_key=eh.encounter_key inner join
				  [dbo].[person_member_map] as m on eh.person_key = m.person_key and eh.client_key=m.client_key left outer join
		          [dbo].[procedure_cd] as pr on ed.procedure_code_key=pr.procedure_code_key
		    where eh.client_key=&client_id.
		      and eh.practice_key in (&vlink_id.)
		      and ed.maj_cat_name in (1,2,3,4,5,14,15)
		      and eh.claim_source = &dataformatgroupid.
		    group by  
		       eh.practice_key, 
		       m.member_key, 
		       eh.person_key,
		       ed.maj_cat_name,
		       eh.diagnosis_cd1, 
		       eh.admit_date, 
		       eh.discharge_date, 
		       eh.tin,
		       ed.service_date, 
		       ed.revenue_code,  
		       pr.procedure_code
		);
	quit;

	data case_logic_history;
	format admdt disdt svcdt mmddyy10. member_key 16. person_key 8.;
	set case_logic_history;
	svcdt=datepart(service_date);
	admdt=datepart(admit_date);
	disdt=datepart(discharge_date);
	member_key=mkey;
	person_key=pkey;
	drop service_date admit_date discharge_date mkey;
	run;

	proc sort data = &dataset_in. 
		  out  = member_keys (keep=member_key person_key) nodupkey;
	by member_key person_key;
	run;

	proc sort data = case_logic_history ;
	by member_key person_key;
	run;

	data case_logic_history;
	 merge case_logic_history (in=a)
	       member_keys        (in=b);
	 by member_key person_key;
	 if a and b;
	run;


	*SASDOC--------------------------------------------------------------------------
	| Inpatient Outpatient Data Definition + History data from EDW
	|
	| Contents logic is needed for restarts of the workflow
	|
	+------------------------------------------------------------------------SASDOC*;
	proc contents data = &dataset_in. out = contents_in (keep = name) noprint;
	run;

	data contents_in;
	set contents_in;
	name=lowcase(name); 
	run;
	
	%let contents_in=;

	proc sql noprint;
	select name into: contents_in separated by ' '
	from contents_in
	where name in ('case','record_orig','admdt_orig','disdt_orig','majcat_orig','e_key','d_key','admdt_c','disdt_c','majcat_c');
	quit;

	%put NOTE: contents_in = &contents_in. ;

	data ip op missing;
	set &dataset_in. %if &contents_in. ne %then %do; (drop = &contents_in.) %end;
	    case_logic_history ; 
	if member_key in (0) then output missing;
	else if majcat in (1:5,14,15) then output ip;
	else output op;
	run;

	proc sort data=ip;
	by member_key person_key tin admdt disdt svcdt ;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Inpatient Summary
	|
	+------------------------------------------------------------------------SASDOC*;
	data ip2;
	set ip;
	by member_key person_key tin admdt ;
	retain case;
	x1 = lag(member_key);
	x2 = lag(person_key);
	x3 = lag(tin);
	x4 = lag(admdt);
	x5 = lag(disdt);
	if first.tin then case = 0;
	if member_key = x1 and person_key=x2 and tin = x3 and (admdt = x4 or admdt le (x5 + 1)) then case = case;
	else case = case + 1; 
	drop x1-x5;
	run;
	
	proc sort data = ip2 out = ip2b (keep = member_key person_key tin case e_key);
	  by member_key person_key tin case descending e_key ;
    run;

	proc sort data = ip2b nodupkey;
	  by member_key person_key tin case;
    run; 
    
	proc sort data=ip2;
	by member_key person_key tin case;
	run;

	data ip2c;
	 merge ip2  (in=a)
	       ip2b (in=b rename=(e_key=e));
	by member_key person_key tin case;
	if a and b then do;
	  e_key=e;
	end;
	drop e;
	run;

	proc sort data=ip2c;
	by member_key person_key tin admdt disdt svcdt;
	run;

	proc sort data=ip2c;
	by member_key person_key tin case;
	run;

	data casedates (keep = member_key person_key tin case admdt_c disdt_c majcat_c e_key );
	set ip2c (keep=member_key person_key tin case admdt disdt majcat e_key );
	format admdt_c disdt_c mmddyy8.;
	retain admdt_c majcat_c  ;
	by member_key person_key tin case;
	if first.case then do;
		admdt_c = admdt;
		majcat_c = majcat; 	
	end;
	if last.case then do;
		disdt_c=disdt; 
		output casedates;
	end;
	run; 

	proc sort data=ip2;
	by member_key person_key tin case;
	run;
	
	data ip3;
	merge ip2 (in=a drop = e_key) 
	      casedates (in=b);
	by member_key person_key tin case;
	if a;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary
	|
	+------------------------------------------------------------------------SASDOC*;
	proc sort data=op;
	  by member_key person_key tin admdt disdt svcdt revcd diag1 proccd;
	run;

	data op2;
	set op;
	by member_key person_key tin admdt disdt svcdt revcd diag1 proccd;
	retain record;
	x1 = lag(member_key);
	x2 = lag(person_key);
	x3 = lag(tin);
	x4 = lag(admdt);
	x5 = lag(disdt);
	x6 = lag(svcdt);
	x7 = lag(revcd);
	x8 = lag(diag1);
	x9 = lag(proccd);
	if _n_ = 1 then record = 0;
	if member_key = x1 and person_key = x2 and tin = x3 and admdt = x4 and disdt = x5 and 
		svcdt = x6 and revcd = x7 and diag1 = x8 and proccd = x9 then record = record;
	else record = record + 1;
	drop x1-x9;
	run;

	proc sort data=op2 out=op3 nodupkey;
	  by record;
	run;

	data op4_um;
	merge op3 (in=a) 
	      casedates (in=b);
	by member_key person_key tin;
	if a and not b;
		admdt_c = admdt;
		disdt_c = disdt;
		case = .;
		majcat_c = majcat;
	run;

	proc sql;
	create table op4_m as
	select op3.*,casedates.*
	from op3 inner join casedates
	on op3.member_key=casedates.member_key and op3.person_key=casedates.person_key and op3.tin=casedates.tin;
	quit;

	data op5_ma op5_mb;
	set op4_m;
	if admdt_c le svcdt le disdt_c then do;
	  output op5_ma;
	end;
	else do;
	  admdt_c = admdt;
	  disdt_c = disdt;
	  case = .;
	  majcat_c = majcat;
	  output op5_mb;
	end;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary - Validate Duplicates (none should be present)
	|
	+------------------------------------------------------------------------SASDOC*;
	proc sort data=op5_ma nodupkey;
	by record;
	run;

	proc sort data=op2 ;
	by record;
	run;
	
	data op5_a;
	merge op2 (in=a) 
	      op5_ma (in=b);
	by record;
	if b;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary - Remove Duplicates if they exist
	|
	+------------------------------------------------------------------------SASDOC*;
	proc sort data=op5_mb nodupkey;
	by record;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary - remove claims already classified as ip in op5_ma
	|
	+------------------------------------------------------------------------SASDOC*;
	data op5_mb2;
	merge op5_ma (in=a keep = record) 
	      op5_mb (in=b);
	by record;
	if b and not a;
	run;

	data op5_b;
	merge op2 (in=a) 
	      op5_mb2 (in=b keep = record admdt_c disdt_c case majcat_c);
	by record;
	if b;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary - Validate Duplicates (none should be present)
	|
	+------------------------------------------------------------------------SASDOC*;
	proc sort data=op4_um nodupkey;
	by record;
	run;

	data op5_c;
	merge op2 (in=a) 
	      op4_um (in=b keep = record admdt_c disdt_c case majcat_c);
	by record;
	if b;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary - verify the number of obs in this dataset equals the 
	|                      number of obs in op2
	|
	+------------------------------------------------------------------------SASDOC*; 
	data op5 (drop = record);
	set op5_a op5_b op5_c;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Outpatient Summary - verify the number of obs in this dataset equals the 
	|                      number of obs read from original hospital source
	|
	+------------------------------------------------------------------------SASDOC*; 
	%let miss_cnt=0;
	%let e_key_count=0;
	
	proc sql noprint; 
	select count(*) into: miss_cnt separated by '' 
	from missing; 
	quit;
	
	data hospital_all (rename = (record=record_orig admdt=admdt_orig disdt=disdt_orig majcat=majcat_orig)) ;
	set ip3 op5_a op5_b op5_c 
	%if &miss_cnt ne 0 %then %do; missing (rename = (admdt=admdt_c disdt=disdt_c majcat=majcat_c)) %end;;
	if claim_key > 0;
	run;

	proc sort data=hospital_all 
	     out=&dataset_in.  (rename = (admdt_c=admdt disdt_c=disdt majcat_c=majcat));
	by member_key person_key tin case svcdt;
	run;
	
	proc sql noprint;
	select count(e_key) into: e_key_count separated by ''
	from hospital_all 
	where e_key ne .;
	quit;
	
	%put NOTE: e_key_count = &e_key_count. ;


%mend edw_hospital_case_logic;
