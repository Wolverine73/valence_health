
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_NorthShore.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load hospital claim data for NorthShore        
|
| INPUT:    NorthShore hospital claim files
|
| OUTPUT:   practice_(IDS) dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 07FEB2012 - Winnie Lee  - Clinical Integration  1.0.01
|             Created macro 
|			  PATIENT_ACCOUNT_NUMBER is junk, MRN is good
|
+-----------------------------------------------------------------------HEADER*/

%macro edw_hospital_NorthShore;


	*SASDOC--------------------------------------------------------------------------
	| Create filename assignment
	--------------------------------------------------------------------------SASDOC*;	
	%macro filename_assign;
		%global hosp_dir_list hosp_dir ; 	  

		data _null_;
		%if %length(&filename.) = 0 %then %do;
			call symput('hosp_dir_list',"dir /b &file_directory.\*.* ");  
		%end;
		%else %do; 
			call symput('hosp_dir_list',"dir /b &file_directory.\&filename. ");
		%end;
		call symput('hosp_dir',"&file_directory.\"); 
		run;  
	%mend filename_assign;
	%filename_assign;
	
 
	*SASDOC-------------------------------------------------------------------------
	| Create list of raw hospital files for the workflow                        
	|------------------------------------------------------------------------SASDOC*;
	filename indata pipe "&hosp_dir_list."; 
	%let dlm=%str('|');

	data hosp_files; 
	length filename $40.;
	infile indata truncover;
	input File_Extract $100.;
	filename = File_Extract;
	x = index(filename,'.');
	if x > 0 then do;
		filename=substr(filename,1,x-1);
	end;  	  
	p = scan(filename,1,'-')*1;
	if p=&do_practice_id.;
	drop p x;
	run;
	
	*SASDOC-------------------------------------------------------------------------
	| Validate if SAS datasets have been processed in a previous workflow                         
	|------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
		create table uploader_history as
			select distinct 
				client_key, 
				practice_id, 
				filename
			from cihold.hold_encounter_header_detail
			where practice_id = &do_practice_id. and client_key=&client_id.
		;
	quit;
	
	data uploader_history;
	set uploader_history;
	x=index(filename,'.');
	if x > 0 then do;
		filename=substr(filename, 1, x-1);
	end;   
	run;

	proc sql noprint;
		create table hosp_files as
			select *
			from hosp_files
			where filename not in 
			(
				select filename
				from uploader_history
			)
		;
	quit;

	proc sql noprint;
		select count(*) into: existing_file
		from hosp_files
		;
	quit;

	%put NOTE: Number of HCF files to process - &existing_file.;

	%if &existing_file. = 0 %then %do;
		%check_issue_count(dataset_in=hosp_files, validation=70);
	%end;


	*SASDOC-------------------------------------------------------------------------
	| Process new lab files for the workflow                         
	|------------------------------------------------------------------------SASDOC*;
	data hosp1;
	length fil2read $100. filename $50.;
	set hosp_files (drop = filename);
	fil2read="&hosp_dir." || file_extract;
	infile dummy filevar=fil2read truncover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=2;
	do until (lastrec);
	input
		fac_name: $upcase25.
		TIN_: $10.
		Patient_Account_Number: $10.
		claimnum: $10.
		Line_Item_ID: $1.
		clmtype: $upcase25.
		vsttype: $upcase10.
		adm_source: $upcase75.
		adm_npi: $10.
		adm_provname:$25.
		Att_NPI: $10.
		Att_ProvName: $upcase25.
		Srg_NPI: $10. 
		Srg_ProvName: $upcase25.
		Oth_NPI: $10.
		Oth_ProvName: $upcase20.
		MRN: $10.
		_fname: $upcase15.
		_lname: $upcase20.
		_mname: $upcase2.
		_sex: $2.
		_address1: $upcase30.
		_address2: $upcase15.
		_city: $upcase20.
		state: $upcase2.
		_zip: $10.
		phone_: $12.
		dob_: $20.
		_ssn: $10.
		admdt_: $20.
		disdt_: $20.
		_dis_cond: $25.
		admdiag: $upcase6.
		diag1: $upcase6.
		poa1: $upcase1.
		diag2: $upcase6.
		diag3: $upcase6.
		diag4: $upcase6.
		diag5: $upcase6.
		diag6: $upcase6.
		diag7: $upcase6.
		diag8: $upcase6.
		diag9: $upcase6.
		diag10: $upcase6.
		diag11: $upcase6.
		poa2: $upcase1.
		poa3: $upcase1.
		poa4: $upcase1.
		poa5: $upcase1.
		poa6: $upcase1.
		poa7: $upcase1.
		poa8: $upcase1.
		poa9: $upcase1.
		poa10: $upcase1.
		poa11: $upcase1.
		svcdt_: $20.
		proccd: $5.
		_mod1: $upcase1.
		_mod2: $upcase1.
		_mod3: $upcase1.
		_mod4: $upcase1.
		Service_Unit_count: $5.
		_revcd: $10.
		surgical_cd1: $upcase5.
		surgical_cd2: $upcase5.
		surgical_cd3: $upcase5.
		surgical_cd4: $upcase5.
		surgical_cd5: $upcase5.
		surgical_cd6: $upcase5.
		_DRG: $5.
		;
		
		filename=file_extract;
		length dob svcdt admdt disdt 8.;
		format dob svcdt admdt disdt mmddyy10.;
		dob = input (substr(right(trim(dob_)),1,10), mmddyy10.);
		svcdt = input (substr(right(trim(svcdt_)),1,10), mmddyy10.);
		admdt = input (substr(right(trim(admdt_)),1,10), mmddyy10.);
		disdt = input (substr(right(trim(disdt_)),1,10), mmddyy10.);
		units = service_unit_count * 1;

		drop file_extract dob_ svcdt_ admdt_ disdt_ service_unit_count;
		output; 
	end;
	run;

	%check_issue_count(dataset_in=hosp1, validation=67);
	
	
	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data hosp2;
	set hosp1;
	format 	submit dollar20.2 disdt admdt svcdt dob mmddyy10.;
	length  system $20. filed $8. linenum $10.
			ssn memberid $9. lname $25. fname $15. mname $2. sex $1. address1 address2 $50.	city $25. state $2.	zip	$5. phone $10. system_member_id $50.
			provid npi $10. provfirst $25. provlast	$15. provname $42.  tin $9. upin $6.
			_proccd $10. mod1-mod4 pos $2. majcat submit 8. revcd dis_cond drg $3.;

	ssn		 = trim(compress(left(_ssn),"-"));
	memberid = trim(ssn);
	lname 	 = cats(left(upcase(_lname)));
	fname 	 = cats(left(upcase(_fname)));
	mname 	 = substr(left(upcase(_mname)),1,1);
	sex 	 = cats(upcase(_sex));
	address1 = cats(upcase(left(_address1)));
	address2 = cats(upcase(left(_address2)));
	city 	 = cats(upcase(left(_City)));
	zip 	 = substr(cats(left(_Zip)),1,5);
	phone=compress(phone_,'-');

	system_member_id = trim(left(mrn));

	tin 		= compress(tin_,'-');
	upin 		= "";
	npi			= "";
	provid		= npi;
	provlast	= "";
	provfirst	= "";
	provname	= "";

	dis_cond	 = trim(left(_dis_cond));
	_proccd 	 = proccd;
	mod1		 = trim(left(_mod1));
	mod2 		 = trim(left(_mod2));
	mod3		 = trim(left(_mod3));
	mod4		 = trim(left(_mod4));
	revcd 		 = trim(left(_revcd*1));
	drg 		 = trim(left(_drg));
	submit		 = .;
	pos 		 = '';

	linenum		= line_item_id;

	filed=substr(scan(filename,2,'-'),1,8);
	system = 'HOSPITAL';
	source = 'H';
	client_key = &client_id.;
	practice_id = &do_practice_id.;
	claim_source = &dataformatgroupid.;
	if fac_name='EVANSTON HOSPITAL' then practice_key=14405;
	else if fac_name='GLENBROOK HOSPITAL' then practice_key=14406;
	else if fac_name='HIGHLAND PARK HOSPITAL' then practice_key=14407;
	else if fac_name='SKOKIE HOSPITAL' then practice_key=14408;
	else practice_key=14393;


	/*** ASSIGN MAJCATS ***/

	if upcase(vsttype)='EMERGENCY' then do;
	      majcat = 6;
	end;
	else if upcase(vsttype)='INPATIENT' then do;
	      	   if upcase(clmtype)= 'BOARDER BABY' 	then majcat = 1;
	      else if upcase(clmtype)= 'GIFT OF HOPE' 	then majcat = 1;
	      else if upcase(clmtype)= 'INPATIENT' 		then majcat = 1;
	      else if upcase(clmtype)= 'NEWBORN' 		then majcat = 2;
	      else if upcase(clmtype)= 'SURGERY ADMIT' 	then majcat = 3;
	      else majcat=1;
	end;
	else if upcase(vsttype)='OUTPATIENT' then do;
	      	   if upcase(clmtype)= 'CARDIAC REHAB' 				then majcat = 11;
	      else if upcase(clmtype)= 'DENTAL' 					then majcat = 13;
	      else if upcase(clmtype)= 'DIALYSIS' 					then majcat = 12;
	      else if upcase(clmtype)= 'KELLOGG CANCER CARE' 		then majcat = 13;
	      else if upcase(clmtype)= 'LAB STANDING ORDERS' 		then majcat = 13;
	      else if upcase(clmtype)= 'MWPC' 						then majcat = 13;
	      else if upcase(clmtype)= 'OBSERVATION' 				then majcat = 13;
	      else if upcase(clmtype)= 'OMEGA PHYSICAL MEDICINE' 	then majcat = 13;
	      else if upcase(clmtype)= 'OMEGA RADIOLOGY' 			then majcat = 10;
	      else if upcase(clmtype)= 'OMEGA STRESS TEST' 			then majcat = 13;
	      else if upcase(clmtype)= 'OUTPATIENT' 				then majcat = 13;
	      else if upcase(clmtype)= 'OUTPATIENT SURGERY' 		then majcat = 7;
	      else if upcase(clmtype)= 'PBB OUTPATIENT' 			then majcat = 13;
	      else if upcase(clmtype)= 'PHYSICAL MEDICINE' 			then majcat = 13;
	      else if upcase(clmtype)= 'PRENATAL SERVICES' 			then majcat = 8;
	      else if upcase(clmtype)= 'PSYCHIATRY' 				then majcat = 13;
	      else if upcase(clmtype)= 'SPECIMEN ONLY' 				then majcat = 13;
	      else if upcase(clmtype)= 'SURGERY ADMIT' 				then majcat = 13;
	      else majcat=13;
	end;
	else if upcase(vsttype)='' then do;
		majcat=35;
	end;


	/*** KEEP VARIABLES ***/
	keep	client_key practice_id source system claimnum linenum filed filename claim_source
		   	upin npi tin provid provlast provfirst provname practice_key
		   	memberid ssn lname fname mname sex dob address1 address2 city state phone zip system_member_id
		   	svcdt admdt disdt dis_cond 
			admdiag diag1-diag10 poa1-poa10 _proccd proccd mod1 mod2 
			revcd drg surgical_cd1-surgical_cd6 majcat units submit pos 
			fac_name clmtype
	;
	run;

	%check_issue_count(dataset_in=hosp2, validation=60);

	proc sort data=hosp2;
	by 
		Claimnum linenum filename system_member_id memberID fname lname mname dob sex address1 address2 city state zip
		svcdt admdt disdt dis_cond admdiag diag1-diag10 _proccd proccd revcd drg surgical_cd1-surgical_cd6;
	run;

	proc summary data=hosp2 nway missing;
	class 
	   	upin npi tin provid provlast provfirst provname
	   	memberid ssn lname fname mname sex dob address1 address2 city state phone zip system_member_id
	   	svcdt admdt disdt dis_cond 
		admdiag diag1-diag10 poa1-poa10 proccd mod1 mod2 revcd drg surgical_cd1-surgical_cd6 majcat;
	id claimnum linenum filename filed system source client_key practice_id practice_key claim_source _proccd  units submit pos 
		fac_name clmtype;
	output out=practice_&do_practice_id. (drop=_type_ _freq_);
	run;

%mend edw_hospital_NorthShore;
