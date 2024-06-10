
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_exempla.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load hospital claim data for Exempla        
|
| INPUT:    Exempla hospital claim files
|
| OUTPUT:   practice_(IDS) dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 07FEB2012 - Winnie Lee  - Clinical Integration  1.0.01
|             Created macro 
|
| 01JUN2012 - B Stropich - Clinical Integration 1.0.03 Release 1.3
|             added cleanse_dob_two_digit_year macro xx 
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
|
| 31AUG2012 - Adam Alongi
|			  Added logic in final PROC SQL to update the workflow ID in ProcessQueue for all file records that were
|			  batch-processed.
+-----------------------------------------------------------------------HEADER*/

%macro edw_hospital_exempla;


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
			call symput('hosp_dir_list',"dir /b &file_directory.\*.* "); 
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
	infile dummy filevar=fil2read truncover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=1;
	do until (lastrec);
	input
		Facility: 		$50.
		TaxID: 			$9.
		AccountID: 		$50.
		Counter: 		$15.
		PatID: 			$15.
		Adm_ProvName: 	$50.
		Adm_ProvNPI: 	$50.
		Att_ProvName: 	$50.
		Att_ProvNPI: 	$50.
		_revcd: 		$20.
		_LName: 		$50.
		_FName: 		$50.
		_MName: 		$50.
		_Sex: 			$50.
		SSN: 			$50.
		_Address1: 		$50.
		_Address2: 		$50.
		_City: 			$50.
		_State:			$50.
		_Zip: 			$50.
		_DOB: 			$50.
		AdmitDateTime: 	$50.
		DisDateTime: 	$50.
		CPT : 			$50.
		_Mod1: 			$50.
		ServiceArea: 	$50.
		AdmitSource: 	$50.
		BaseClass: 		$50.
		Accountclass: 	$50.
		DischargeDisp: 	$50.
		_DRG: 			$6.
		ProcedureCode: 	$50.
		ProcedureDate: 	$50.
		Accomodation: 	$50.
		_Adm_Diag: 		$6.
		_Diag1: 		$6.
		Diag1POA: 		$10.
		_Diag2: 		$6.
		Diag2POA: 		$10.
		_Diag3: 		$6.
		Diag3POA: 		$10.
		_Diag4: 		$6.
		Diag4POA: 		$10.
		_Diag5: 		$6.
		Diag5POA: 		$10.
		_Diag6: 		$6.
		Diag6POA: 		$10.
		_Diag7: 		$6.
		Diag7POA: 		$10.
		_Diag8: 		$6.
		Diag8POA: 		$10.
		_Diag9: 		$6.
		Diag9POA: 		$10.
		_Diag10: 		$6.
		Diag10POA: 		$10.
		;
		
		filename=file_extract;

		drop file_extract;
		output; 
	end;
	run;

	%check_issue_count(dataset_in=hosp1, validation=67);
	

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data hosp2;
	set hosp1 (rename = (ssn=_ssn));
	format 	submit dollar20.2 disdt admdt svcdt dob mmddyy10.;
	length  system $20. filed $8. linenum $10.
			ssn memberid $9. lname $25. fname $15. mname $1. sex $1. address1 address2 $50.	city $25. state $2.	zip	$5. phone $10. system_member_id $50.
			provid npi $10. provfirst $25. provlast	$15. provname $42. /**adm_npi surg_npi att_npi oth_npi $10.**/ tin $9. upin $6.
			/**adm_phy_name surg_name att_phy_name oth_phy_name $75.**/
			_admdt _disdt _svcdt $10. svcdt admdt disdt 8. 
			admdiag diag1-diag10 $6. _proccd $10. proccd $5. mod1 $4. majcat units submit 8. revcd dis_cond drg facility $3. surgical_cd1 $5.
			/**visit_type $1.  adm_source $1.  poa1-poa10 $6.**/ fac_name $75. ;

	ssn		 = trim(compress(left(_ssn),"-"));
	memberid = trim(ssn);
	lname 	 = cats(left(upcase(_lname)));
	fname 	 = cats(left(upcase(_fname)));
	mname 	 = substr(left(upcase(_mname)),1,1);
	dob		 = input(_dob, mmddyy10.);
	%cleanse_dob_two_digit_year;
	sex 	 = cats(upcase(_sex));
	address1 = cats(upcase(left(_address1)));
	address2 = cats(upcase(left(_address2)));
	city 	 = cats(upcase(left(_City)));
	state 	 = cats(upcase(left(_state)));
	zip 	 = substr(cats(left(_Zip)),1,5);
	phone	 = "";

	system_member_id = trim(left(patid));

	fac_name 	= facility;
	tin		 	= trim(taxid);
	upin 		= "";
	npi			= "";
	provid		= npi;
	provlast	= "";
	provfirst	= "";
	provname	= "";

	_admdt = scan(admitdatetime,1,' ');
	_disdt = scan(disdatetime,1,' ');
	_svcdt = scan(proceduredate,1,' ');
	admdt  = input(_admdt, mmddyy10.);
	svcdt  = input(_svcdt, mmddyy10.);
	disdt  = input(_disdt, mmddyy10.);

/*	dis_cond 	= DischargeDisp;*/
	if dischargedisp in ('1','2','3','4','5',
						 '6','7','9','20','40',
						 '41','42','43','50','51',
						 '61','62','63','64','65',
						 '66') 									then dis_cond = dischargedisp;
	else if dischargedisp in ('206','207','208','217','224',
							  '225','226','227','228','229') 	then dis_cond = '2';
	else if dischargedisp in ('100','201','202') 				then dis_cond = '7';
	else if dischargedisp in ('211','218') 						then dis_cond = '21';
	else if dischargedisp in ('222') 							then dis_cond = '30';
	else if dischargedisp in ('30','213') 						then dis_cond = '50';
	else if dischargedisp in ('204','210') 						then dis_cond = '51';
	else if dischargedisp in ('223') 							then dis_cond = '63';
	else if dischargedisp in ('205','209') 						then dis_cond = '65';
	else if dischargedisp in ('8','10','200','203','212',
							  '214','215','216','219','220',
							  '221') 							then dis_cond = '70';
	else dis_cond = '';
	
	admdiag = trim(upcase(_adm_diag));
	diag1 	= trim(upcase(_diag1));
	diag2 	= trim(upcase(_diag2));
	diag3 	= trim(upcase(_diag3));
	diag4 	= trim(upcase(_diag4));
	diag5 	= trim(upcase(_diag5));
	diag6 	= trim(upcase(_diag6));
	diag7 	= trim(upcase(_diag7));
	diag8 	= trim(upcase(_diag8));
	diag9 	= trim(upcase(_diag9));
	diag10 	= trim(upcase(_diag10));

	poa1  = trim(upcase(Diag1POA));
	poa2  = trim(upcase(Diag2POA));
	poa3  = trim(upcase(Diag3POA));
	poa4  = trim(upcase(Diag4POA));
	poa5  = trim(upcase(Diag5POA));
	poa6  = trim(upcase(Diag6POA));
	poa7  = trim(upcase(Diag7POA));
	poa8  = trim(upcase(Diag8POA));
	poa9  = trim(upcase(Diag9POA));
	poa10 = trim(upcase(Diag10POA));

	_proccd 	 = trim(left(upcase(cpt)));
	if length(trim(left(_proccd))) > 5 then proccd = '';
	else proccd = substr(trim(cpt),1,5);
	mod1		 = trim(left(upcase(_mod1)));
	mod2 		 = "";
	revcd 		 = cats(_Revcd)*1;
	drg 		 = trim(_drg);
	surgical_cd1 = .;
	units 		 = .;
	submit 		 = .;

	claimnum 	= accountid;
	linenum		= counter;
	clmtype		= ServiceArea;
/*	pos			= baseclass;*/
	if baseclass = "ED" then pos = "23";
	else if baseclass = "IP" then pos = "21";
	else if baseclass = "OP" then pos = "22";

	filed=substr(scan(filename,2,'-'),1,8);
	system = 'HOSPITAL';
	source = 'H';
	client_key = &client_id.;
	practice_id = &do_practice_id.;
	claim_source = &dataformatgroupid.;
	practice_key = &practice_key.;


	/*** ASSIGN MAJCATS ***/

	if ServiceArea = '1' or baseclass='ED' 	then majcat = 6;	*ER;
	else if 450 <= revcd <= 459  			then majcat = 6; 	*ER;
	else if '99281' <= proccd < '99288' 	then majcat = 6; 	*ER;
	else if baseclass='OP' 					then majcat = 13;	*OP;
	else if ServiceArea = '13' 				then majcat = 2; 	*Maternity;
	else if ServiceArea in ('4','58')  		then majcat = 5; 	*Psych;
	else 										 majcat = 1; 	*IP;


	/*** KEEP VARIABLES ***/
	keep	client_key practice_id source system claimnum linenum filed filename claim_source
		   	upin npi tin provid provlast provfirst provname practice_key
		   	memberid ssn lname fname mname sex dob address1 address2 city state phone zip system_member_id
		   	svcdt admdt disdt dis_cond 
			admdiag diag1-diag10 poa1-poa10 _proccd proccd mod1 mod2 revcd drg surgical_cd1 majcat units submit pos 
			fac_name clmtype
	;
	run;

	%check_issue_count(dataset_in=hosp2, validation=60);

	proc sql;
		select count(*) into: unmapped_dis_cond
		from hosp2
		where dis_cond = '';
	quit;

	%if &unmapped_dis_cond. > 0 %then %do;
		%check_issue_count(dataset_in=hosp2, validation=69);
	%end;

	proc sort data=hosp2;
	by 
		Claimnum linenum filename memberID fname lname mname dob sex address1 address2 city state zip
		svcdt admdt disdt dis_cond admdiag diag1-diag10 _proccd proccd revcd drg surgical_cd1 POS;
	run;

	proc summary data=hosp2 nway missing;
	class 
	   	upin npi tin provid provlast provfirst provname
	   	memberid ssn lname fname mname sex dob address1 address2 city state phone zip system_member_id
	   	svcdt admdt disdt dis_cond 
		admdiag diag1-diag10 poa1-poa10 proccd mod1 mod2 revcd drg surgical_cd1 majcat;
	id claimnum linenum filename filed system source client_key practice_id practice_key claim_source _proccd  units submit pos 
		fac_name clmtype;
	output out=practice_&do_practice_id. (drop=_type_ _freq_);
	run;
	
	/** update wild card hospital files so the process queue does not pick them up in the subsequent workflow **/
	%let file_extract=%str("xxx");
	proc sql noprint;
	select quote(trim(file_extract)) into: file_extract separated by ','
	from hosp_files 
    	where file_extract not in ("&filename.");
	quit;
	
	%put NOTE: file_extract = &file_extract. ;
	
	proc sql noprint;
	update ids.processqueue 
	set processqueuestatusid=4,
      wflow_exec_id=&wflow_exec_id. /*AA - 8/31/2012*/
	where filename in (&file_extract. )
	  and processqueuestatusid  in (1) ;
	quit;
	
	

%mend edw_hospital_exempla;
