/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  data_validation.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:  Validate vmine/pgf data and create practice validation dataset   
|           
| INPUT:    allclaims dataset
|
| OUTPUT:   excel file 
|           practice validation dataset for portal
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 25MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created data validation macro
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro data_validation;

	*SASDOC--------------------------------------------------------------------------
	| Determine new and historical files                         
	|------------------------------------------------------------------------SASDOC*;
	proc sort data=dw.&allclaims_dataset out=stat1;
		by practiceid practice filedt;
	run;

	data stat2 (keep=practiceid filedt practice system);
		set stat1;
		by practiceid practice filedt;
		if last.practice then output;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Validate ssn, procedure code and diagnosis code                         
	|------------------------------------------------------------------------SASDOC*;
	Data stat3;
		merge stat1 (in=a) stat2 (in=b);
		by practiceid practice filedt;
		if a;
		if a and b then status = "New";
		else if a then status = "Old";
		if put(diag1,$diag5cd.)=diag1 then bad_diag=1;
		if put(proccd,$cpt.)=proccd then bad_proccd=1;
		if put(memberid,$memberid.)="VALID" then valid_memberid=1;
		count=1;
	run;

	proc summary data=stat3 nway missing;
		where status = "New";
		class practiceid practice;
		var count bad_diag bad_proccd valid_memberid;
		output out=bad1_N (drop=_type_ _freq_ rename=(bad_diag=bad_diag_new count=count_new bad_proccd=bad_proccd_new valid_memberid=valid_memberid_new)) sum=;
		id system;
	run;

	data bad2_n;
		set bad1_n;
		If bad_diag_new = . then bad_diag_new = 0;
		If bad_proccd_new = . then bad_proccd_new = 0;
		If valid_memberid_new = . then valid_memberid_new = 0;
		bad_diag_rate_N = bad_diag_new / count_new;
		bad_proccd_rate_N = bad_proccd_new / count_new;
		valid_memberid_N = valid_memberid_new / count_new;
	run;

	proc summary data=stat3 nway missing;
		where status = "Old";
		class practiceid practice;
		var count bad_diag bad_proccd valid_memberid;
		output out=bad1_O (drop=_type_ _freq_ rename=(bad_diag=bad_diag_old count=count_old bad_proccd=bad_proccd_old valid_memberid=valid_memberid_old)) sum=;
		id system;
	run;

	data bad2_O;
		set bad1_O;
		If bad_diag_old = . then bad_diag_old = 0;
		If bad_proccd_old = . then bad_proccd_old = 0;
		If valid_memberid_old = . then valid_memberid_old = 0;
		bad_diag_rate_O = bad_diag_old / count_old;
		bad_proccd_rate_O = bad_proccd_old / count_old;
		valid_memberid_O = valid_memberid_old / count_old;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Count unique providers in file                        
	|------------------------------------------------------------------------SASDOC*;
	proc summary data=stat3 nway missing;
		where status = "New";
		class practiceid practice provid;
		output out=prov1_N (drop=_type_ _freq_ rename=());
		id system;
	run;

	Data prov2_N;
		set prov1_N;
		count=1;
		run;
		proc summary data=prov2_N nway missing;
		class practiceid practice ;
		var count;
		output out=prov3_N (drop=_type_ _freq_ rename=(count=providers_N)) sum=;
		id system;
	run;

	proc summary data=stat3 nway missing;
		where status = "Old";
		class practiceid practice provid;
		output out=prov1_O (drop=_type_ _freq_ rename=());
		id system;
	run;

	Data prov2_O;
		set prov1_O;
		count=1;
	run;

	proc summary data=prov2_O nway missing;
		class practiceid practice ;
		var count;
		output out=prov3_O (drop=_type_ _freq_ rename=(count=providers_O)) sum=;
		id system;
	run;

	
	*SASDOC--------------------------------------------------------------------------
	| Count unique files by practice                         
	|------------------------------------------------------------------------SASDOC*;

	proc summary data=stat3 nway missing;
		class practiceid practice filedt;
		output out=files1 (drop=_type_ _freq_ rename=());
		id system;
	run;

	Data files2;
		set files1;
		count=1;
	run;

	proc summary data=files2 nway missing;
		class practiceid practice;
		var count;
		output out=files3 (drop=_type_ _freq_ rename=(count=filecount)) sum=;
		id system;
	run;

	
	*SASDOC--------------------------------------------------------------------------
	| Determine first and last service dates                         
	|------------------------------------------------------------------------SASDOC*;

	Data dates1;
		set stat3;
		where status = "New";
	run;

	proc sort data=dates1;
		by practiceid practice svcdt;
	run;

	Data dates2 (keep=practiceid practice firstdt lastdt system);
		set dates1;
		by practiceid practice svcdt;
		retain firstdt lastdt;
		format firstdt lastdt mmddyy10.;
		if first.practice then do;
			firstdt=.;
			lastdt=.;
		end;
		firstdt=min(firstdt,svcdt);
		lastdt=max(lastdt,svcdt);
		if last.practice;
	run;

	Data Hub1 (drop= );
		merge stat2 (in=a) files3 (in=b) Dates2 (in=c) prov3_o (in=d) prov3_n (in=e) bad2_o (in=f) bad2_n (in=g);
		by practiceid practice;
		if a;
	run;

	
	*SASDOC--------------------------------------------------------------------------
	| Count unique members by provider                          
	|------------------------------------------------------------------------SASDOC*;

	proc summary data=stat3 nway missing;
		class npi memberid;
		output out=providers1 (drop=_type_ _freq_);
	run;

	Data providers2;
		set providers1;
		provprac = put(npi,$provprac.);
		provname=put(npi,$provname.);
		directory1 = put(npi,$provdir.);
		if put(memberid,$memberid.)="VALID" then count=1;
	run;

	proc summary data=providers2 nway missing;
		class provname;
		var count;
		output out=providers3 (drop=_type_ _freq_) sum=;
	run;

	
	*SASDOC--------------------------------------------------------------------------
	| Count unique members by practice                         
	|------------------------------------------------------------------------SASDOC*;

	Data prac1;
		set stat3;
		provprac = put(npi,$provprac.);
		provname=put(npi,$provname.);
		directory1 = put(npi,$provdir.);
	run;

	proc summary data=prac1 nway missing;
		class provprac memberid;
		output out=prac2 (drop=_type_ _freq_);
	run;

	Data prac3;
		set prac2;
		if put(memberid,$memberid.)="VALID" then count=1;
	run;

	proc summary data=prac3 nway missing;
		class provprac;
		var count;
		output out=prac4 (drop=_type_ _freq_) sum=;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Count unique members by specialty                        
	|------------------------------------------------------------------------SASDOC*;
	Data spec1;
		set stat3;
		provprac = put(npi,$provprac.);
		provname=put(npi,$provname.);
		directory1 = put(npi,$provdir.);
	run;

	proc summary data=spec1 nway missing;
		class directory1 memberid;
		output out=spec2 (drop=_type_ _freq_);
	run;

	Data spec3;
		set spec2;
		if put(memberid,$memberid.)="VALID" then count=1;
	run;

	proc summary data=spec3 nway missing;
		class directory1;
		var count;
		output out=spec4 (drop=_type_ _freq_) sum=;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Create provider details                      
	|------------------------------------------------------------------------SASDOC*; 
	proc summary data=stat3 nway missing;
		class npi;
		output out=dets1 (drop=_type_ _freq_);
	run;
	
	Data dets2;
		set dets1;
		provprac = put(npi,$provprac.);
		provname=put(npi,$provname.);
		directory1 = put(npi,$provdir.);
	run;

	proc sort data=dets2 nodupkey;
		by provname;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Copy base file to output directory                    
	|------------------------------------------------------------------------SASDOC*; 

	options noxwait xsync; 
	
	data _null_;
		x"copy &monthbase. &monthload.";
	run;

	*SASDOC--------------------------------------------------------------------------
	| Delete data from base file worksheet                         
	|------------------------------------------------------------------------SASDOC*;

	proc datasets lib=rptbase; delete metrics; run; quit;
	proc datasets lib=rptbase; delete Providers_A; run; quit;
	proc datasets lib=rptbase; delete Providers_B; run; quit;
	proc datasets lib=rptbase; delete Providers_C; run; quit;
	proc datasets lib=rptbase; delete Provider_Details; run; quit;

	*SASDOC--------------------------------------------------------------------------
	| Populate base file worksheet                        
	|------------------------------------------------------------------------SASDOC*;

	proc sql;
		create table rptbase.metrics as 
		select system, practiceid, practice, filedt, filecount, firstdt, lastdt,
		providers_o, providers_n, count_old, count_new, valid_memberid_o, valid_memberid_n,
		bad_diag_rate_o, bad_diag_rate_n, bad_proccd_rate_o, bad_proccd_rate_n
		from hub1;
	quit;

	proc sql;
		create table rptbase.Providers_A as 
		select provname, count
		from providers3;
	quit;

	proc sql;
		create table rptbase.Providers_B as 
		select provprac, count
		from prac4;
	quit;

	proc sql;
		create table rptbase.Providers_C as 
		select directory1, count
		from spec4;
	quit;

	proc sql;
		create table rptbase.Provider_Details as 
		select Provname, Provprac, npi, Directory1
		from dets2;
	quit;

	libname rptbase clear;

	*SASDOC--------------------------------------------------------------------------
	| Output practice validation                         
	|------------------------------------------------------------------------SASDOC*;
	Data Hub2;
		set Hub1 (keep= practice system filedt lastdt providers_N);
		format filedt mmddyy10.;
	run;

	data portal.practice_validation;
		set hub2;
	run;

%mend data_validation;


