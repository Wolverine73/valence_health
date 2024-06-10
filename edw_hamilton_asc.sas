
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hamilton_asc.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load ambulatory surgical center data for PHS        
|
| INPUT:    Ambulatory surgical center data files
|           Data format 29 Hospital - Hamilton Ambulatory 
|
| OUTPUT:   practice_(IDS) dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 07FEB2012 - Winnie Lee  - Clinical Integration  1.0.01
|             Created macro 
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
+-----------------------------------------------------------------------HEADER*/

%macro edw_hamilton_asc;


	*SASDOC--------------------------------------------------------------------------
	| Create filename assignment
	--------------------------------------------------------------------------SASDOC*;	
	%macro filename_assign;
		%global asc_dir_list asc_dir ; 	  

		data _null_;
		%if %length(&filename.) = 0 %then %do;
			call symput('asc_dir_list',"dir /b &file_directory.\*.* ");  
		%end;
		%else %do; 
			call symput('asc_dir_list',"dir /b &file_directory.\&filename. ");
		%end;
		call symput('asc_dir',"&file_directory.\"); 
		run;  
	%mend filename_assign;
	%filename_assign;
	
 
	*SASDOC-------------------------------------------------------------------------
	| Create list of raw hospital files for the workflow                        
	|------------------------------------------------------------------------SASDOC*;
	filename indata pipe "&asc_dir_list."; 
	%let dlm=%str('|');

	data asc_files; 
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
			from cihold.hold_encounter_header_detail nolock
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
		create table asc_files as
			select *
			from asc_files
			where filename not in 
			(
				select filename
				from uploader_history
			)
		;
	quit;

	proc sql noprint;
		select count(*) into: existing_file
		from asc_files
		;
	quit;

	%put NOTE: EXISTING_FILE Macro = &existing_file.;

	%if &existing_file. = 0 %then %do;
		%check_issue_count(dataset_in=asc_files, validation=70);
	%end;


	*SASDOC-------------------------------------------------------------------------
	| Process new lab files for the workflow                         
	|------------------------------------------------------------------------SASDOC*;
	data asc1;
	length fil2read $100. filename $50.;
	set asc_files (drop = filename);
	fil2read="&asc_dir." || file_extract;
	infile dummy filevar=fil2read truncover missover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=2;
	do until (lastrec);
	input
		FacilityName: $50.
		FedTaxID: $9.
		ClaimID: $10.
		LineItemID: $1. 
		NPI: $10.
		ProvFName: $20. 
		ProvLName: $20. 
		PtFName: $20. 
		PtLName: $20. 
		PtMI: $1. 
		PtGender: $1. 
		PtDOB: mmddyy10. 
		_SSN: $11. 
		PlaceOfServ: $2. 
		ServDate: mmddyy10. 
		Admission: mmddyy10. 
		Discharge: mmddyy10. 
		AdmitDx: $6.
		Dx1: $6.
		Dx2: $6.
		Dx3: $6. 
		CPT: $5.
		ProcMod: $2. 
		revenuecode: $5.
		drg: $3.
		;
		
		filename=file_extract;

		drop file_extract;
		output; 
	end;
	run;

	%check_issue_count(dataset_in=asc1, validation=67);
	

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data asc2;
	set asc1;
	format 	submit dollar20.2 filedt disdt admdt svcdt dob mmddyy10.;
	length  system $20. filed $8. filedt 8. claimnum linenum $10.
			ssn memberid $9. lname $25. fname $15. mname $1. sex $1. address1 address2 $50.	city $25. state $2.	zip	$5. phone $10.
			provid npi $10. provfirst $25. provlast	$15. provname $42. tin $9. upin $6.
			svcdt admdt disdt 8. 
			admdiag diag1-diag10 $6. _proccd $10. proccd $5. mod1 mod2 pos $2. majcat units submit 8. revcd dis_cond drg $3. surgical_cd1 $5.
			fac_name $75. ;
	
	
	filename     = upcase(cats(filename));
	filed		 = substr(scan(filename,2,'-'),1,8);
	filedt		 = input(filed,yymmdd8.);
	claimnum	 = upcase(cats(ClaimID));
	linenum		 = upcase(cats(LineItemID));

	fac_name	 = upcase(cats(FacilityName));
	provid		 = upcase(cats(NPI));
	npi			 = '';
	upin		 = '';
	tin			 = trim(compress(fedtaxid,'-'));
	provlast	 = '';
	provfirst	 = '';
	provname     = '';

	ssn			 = cats(compress(_SSN, "-"));
	if ssn*1 in (0,999999999) then memberid = '';
	else memberid = ssn;
	fname		 = upcase(cats(PtFName)); 
	lname		 = upcase(cats(PtLName));
	mname		 = upcase(cats(PtMI)); 
	dob			 = PtDOB;
	sex			 = upcase(cats(PtGender)); 
	address1	 = '';
	address2	 = '';
	city		 = '';
	state		 = '';
	zip			 = '';
	phone		 = '';

	svcdt 		 = servdate;
	admdt 		 = admission;
	disdt        = discharge;
	dis_cond	 = '';
	admdiag		 = upcase(cats(AdmitDx));
	diag1 		 = upcase(cats(Dx1));
	diag2		 = upcase(cats(Dx2));
	diag3		 = upcase(cats(Dx3));
	diag4		 = '';
	diag5		 = '';
	diag6		 = '';
	diag7		 = '';
	diag8		 = '';
	diag9		 = '';
	diag10		 = '';
	_proccd		 = upcase(trim(cpt));
	proccd		 = upcase(cats(cpt));
	mod1		 = upcase(cats(ProcMod));	
	mod2		 = '';
	revcd		 = upcase(cats(revenuecode));
	drg			 = upcase(cats(drg));
	surgical_cd1 = '';
	pos			 = upcase(cats(PlaceOfServ));
	units		 = .;
	submit		 = .;
	
	system 		 = 'ASC';
	source 		 = 'A';
	client_key 	 = &client_id.;
	practice_id  = &do_practice_id.;
	claim_source = &dataformatgroupid.;
	practice_key = &practice_key.;


	/*** ASSIGN MAJCATS ***/
	majcat		= 13;


	/*** E_KEY CREATED TO SATISFY FACILITY CONDITION ***/
	e_key = .;
	
	/*** KEEP VARIABLES ***/
	keep	client_key practice_id source system claimnum linenum filed filedt filename claim_source
		   	upin npi tin provid provlast provfirst provname practice_key
		   	memberid ssn lname fname mname sex dob address1 address2 city state phone zip
		   	svcdt admdt disdt dis_cond 
			admdiag diag1-diag10 _proccd proccd mod1 mod2 revcd drg surgical_cd1 majcat units submit pos 
			fac_name e_key
	;
	run;

	%check_issue_count(dataset_in=asc2, validation=60);


	proc sort data=asc2;
	by 
		Claimnum linenum filename memberID fname lname mname dob sex address1 address2 city state zip
		svcdt admdt disdt dis_cond admdiag diag1-diag10 _proccd proccd revcd drg surgical_cd1 POS;
	run;

	proc summary data=asc2 nway missing;
	class 
	   	upin npi tin provid provlast provfirst provname
	   	memberid ssn lname fname mname sex dob address1 address2 city state phone zip
	   	svcdt admdt disdt dis_cond 
		admdiag diag1-diag10 proccd mod1 mod2 revcd drg surgical_cd1 majcat;
	id claimnum linenum filename filed system source client_key practice_id practice_key claim_source _proccd units submit pos 
		fac_name e_key;
	output out=practice_&do_practice_id. (drop=_type_ _freq_);
	run;

%mend edw_hamilton_asc;
