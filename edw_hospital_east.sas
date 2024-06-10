
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_east.sas
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
| 13JUL2011 - Brian Stropich  - Clinical Integration  1.0.01
|             Created macro 
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 31AUG2012 - Adam Alongi
|			  Added logic in final PROC SQL to update the workflow ID in ProcessQueue for all file records that were
|			  batch-processed.
+-----------------------------------------------------------------------HEADER*/

%macro edw_hospital_east;


	*SASDOC--------------------------------------------------------------------------
	| Create filename assignment
	--------------------------------------------------------------------------SASDOC*;	
	%macro filename_assign;
	  %global selfpay_dir_list selfpay_dir ; 	  
	  
		data _null_;
		  %if %length(&filename) > 0 %then %do;
		    call symput('selfpay_dir_list',"dir /b &file_directory.\*.* ");  
		  %end;
		  %else %do; 
		    call symput('selfpay_dir_list',"dir /b &file_directory.\&filename. "); 
		  %end;
		  call symput('selfpay_dir',"&file_directory.\"); 
		run;  
	  
	%mend filename_assign;
	%filename_assign;
	
 
	*SASDOC-------------------------------------------------------------------------
	| Create list of raw lab files for the workflow                        
	|------------------------------------------------------------------------SASDOC*;
	filename indata pipe "&selfpay_dir_list."; 
	%let dlm=%str('|');

	data selfpay_files; 
	  length filename $40. ;
	  infile indata truncover;
	  input File_Extract $100.;
	  filename=File_Extract;
	  x=index(filename,'.');
	  if x > 0 then do;
	    filename=substr(filename,1,x-1);
	  end;  	  
	  p=scan(filename,1,'-')*1;
	  if p=&do_practice_id.;
	  drop p x;
	run;
	
	*SASDOC-------------------------------------------------------------------------
	| Validate if SAS datasets have been processed in a previous workflow                         
	|------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
	  create table uploader_history as
	  select distinct client_key, practice_id, filename
	  from cihold.hold_encounter_header_detail
	  where practice_id = &do_practice_id.
        and client_key=&client_id.;
	quit;
	
	data uploader_history;
	  set uploader_history;
	  x=index(filename,'.');
	  if x > 0 then do;
	    filename=substr(filename,1,x-1);
	  end;   
	run;

	proc sql noprint;
	  create table selfpay_files as
	  select *
	  from selfpay_files
	  where filename not in (select filename
	                         from   uploader_history);
	quit;
	
	%check_issue_count(dataset_in=selfpay_files, validation=70);

	*SASDOC-------------------------------------------------------------------------
	| Process new lab files for the workflow                         
	|------------------------------------------------------------------------SASDOC*;
	data selfpay_001;
	length fil2read $100. filename $50.  ;
	set selfpay_files (drop = filename);
	fil2read="&selfpay_dir." || file_extract;
	infile dummy filevar=fil2read truncover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=1;
	do until (lastrec);
	input
		fac_code: $3.
		fac_tin:	$9.
		pat_acct_nbr:	$11.
		service_desc:	$19.
		io:	$1.
		adm_source:	$2.
		adm_phy_cd:	$10.
		adm_phy_first_nm:		$30.
		adm_phy_last_nm:	$30.
		attend_phy_npi:	$10.
		attend_phy_first_nm:	$30.
		attend_phy_last_nm:	$30.
		op_phy_npi:	$10.
		op_phy_last_nm_78:	$30.
		op_phy_first_nm_78:	$30.
		oth_phy_npi:	$10.
		oth_phy_last_nm_78:	$30.
		oth_phy_first_nm_78:	$30.
		unit_nbr:	$13.
		pat_name_first:	$15.
		pat_name_last:	$25.
		pat_name_mi:	$5.
		sex:	$1.
		pat_addr_1:	$25.
		pat_addr_2:	$25.
		pat_city:	$18.
		pat_state:	$2.
		pat_zip_code:	$9.
		birthdate: $8.
		pat_ssn: $9.
		adm_dt: $8.
		act_adm_tm: $8.
		dshrg_dt: $8.
		dschrg_tm: $8.
		dschrg_disp:	$3.
		pr_diag_poa:	$1.
		pri_diag_desc:	$6.
		diag_cd1:	$6.
		diag_cd2:	$6.
		diag_cd3:	$6.
		diag_cd4:	$6.
		diag_cd5:	$6.
		diag_cd6:	$6.
		diag_cd7:	$6.
		diag_cd8:	$6.
		diag_cd9:	$6.
		diag_cd10:	$6.
		oth_dx_1_poa: $1.
		dx_2_poa: $1.
		dx_3_poa: $1.
		dx_4_poa: $1.
		dx_5_poa: $1.
		dx_6_poa: $1.
		dx_7_poa: $1.
		dx_8_poa: $1.
		dx_9_poa: $1.
		dx_10_poa: $1.
		serv_dt: $8.
		hcpcs_cd1: $5.
		hcpcs_mod1: $4.
		drg_final_nbr: $3.

		;
		filename=file_extract;
		
		drop file_extract;
		output; 
	end;
	run;


	data adm_source;
	format code $2. desc $50.; 
	code='1';desc='NON HEALTH CARE FAC';output;
	code='10';desc='WORK';output;
	code='11';desc='TCS-TRANS CARE-H/SP';output;
	code='12';desc='NORMAL DELIVERY';output;
	code='13';desc='PREMATURE DELIVERY';output;
	code='14';desc='ILL BABY';output;
	code='15';desc='EXTRAMURAL BIRTH';output;
	code='17';desc='CRITICAL ACCESS HOS';output;
	code='18';desc='TRANS DITRICT UNIT';output;
	code='19';desc='AMBULATORY SURGERY';output;
	code='2';desc='CLINIC/PHYSICIAN OF';output;
	code='20';desc='TRANS FROM HOSPICE';output;
	code='21';desc='BORN INSIDE';output;
	code='22';desc='BORN OUTSIDE';output;
	code='3';desc='HMO REF/ILL BABY';output;
	code='4';desc='TRANSFER HOSPITAL';output;
	code='5';desc='TRANS FROM SNF/ICF';output;
	code='6';desc='TRF OTHER HC FLTY';output;
	code='7';desc='EMERGENCY ROOM';output;
	code='8';desc='COURT/LAW ENFORCE';output;
	code='9';desc='INFO NOT AVAILABLE';output;
	code='B';desc='TRANS FROM HOME HLT';output;
	run;

	data admfmt;
	retain fmtname ("admfmt") type ("c");
	length start $2. label $50. fmtname $6. type $1.;
	set adm_source;
	start=cats(code);
	label=cats(desc);
	keep start label fmtname type;
	run;

	proc sort data=admfmt nodupkey;
	by start;
	run;

	proc format cntlin=admfmt;
	run;

	data facility;
	format code $3. desc $50.;
	code='CCP';desc='CLEVELAND CLINIC PROFESSIONAL';output;
	code='CCH';desc='CLEVELAND CLINIC TECHNICAL';output;
	code='MDE';desc='EUCLID HOSPITAL';output;
	code='MDH';desc='HURON HOSPITAL';output;
	code='MDL';desc='HILLCREST HOSPITAL';output;
	code='MDS';desc='SOUTH POINTE HOSPITAL';output;
	code='FVW';desc='FAIRVIEW HOSPITAL';output;
	code='LUT';desc='LUTHERAN HOSPITAL';output;
	code='LAK';desc='LAKEWOOD HOSPITAL';output;
	code='MAR';desc='MARYMOUNT HOSPITAL';output;
	run;

	data facfmt;
	retain fmtname ("facfmt") type ("c");
	length start $3. label $75. fmtname $6. type $1.;
	set facility;
	start=cats(code);
	label=cats(desc);
	keep start label fmtname type;
	run;

	proc sort data=facfmt nodupkey;
	by start;
	run;

	proc format cntlin=facfmt;
	run;
		

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data selfpay_002 (keep=	system filed claimnum filename practice_id
					   	upin npi tin provid provlast provfirst provname 
					   	memberid ssn lname fname mname sex dob 
					   	diag1-diag10 poa1-poa10 _proccd proccd mod1 mod2 units
					   	svcdt  
		 			   	submit pos surgical_cd1
						system_member_id  source_system_id practice_key
		     			        address1 address2 city state phone zip client_key source
						service_desc vsttype
						/** mrnn interface adm_phy_name surg_name att_npi att_phy_name oth_phy_name 
		                                 mrn adm_npi  surg_npi att_npi  oth_npi fac_tin **/
		                                dis_cond drg facility adm_source disdt admdt PatientAccountNumber fac_name  revcd);
	set selfpay_001;
	format submit dollar20.2 disdt admdt svcdt dob mmddyy10.;
	length  
	ssn     $9.
	lname	$25.
	fname	$15.
	mname	$1.
	sex     $1.
	memberid $9. 
	address1	$50.
	address2	$50.
	city	$25.
	state	$2.
	zip	$5.
	phone	$10.
	provid	$10.
	npi     $10.
	provfirst	$25.
	provlast	$15.  
	proccd $5.
	diag1-diag10 $6.  
	tin $9. 
	provname system $50. 
	interface source_system_id system_member_id $20.
	adm_phy_name surg_name att_phy_name oth_phy_name $75. 
	vsttype $1.  mrn $13. adm_npi  surg_npi att_npi  oth_npi $10. tin $9. 
	dis_cond drg facility $3. adm_source $1. mod1 $4. poa1-poa10  vsttype $1. fac_name $75. filed $8. PatientAccountNumber $11.;



	svcdt=mdy(1*substr(serv_dt, 1, 2),1*substr(serv_dt, 3, 2),1*substr(serv_dt, 5, 4)); 
	admdt=mdy(1*substr(adm_dt, 1, 2),1*substr(adm_dt, 3, 2),1*substr(adm_dt, 5, 4)); 
	disdt=mdy(1*substr(dshrg_dt, 1, 2),1*substr(dshrg_dt, 3, 2),1*substr(dshrg_dt, 5, 4));
	dob=mdy(1*substr(birthdate, 1, 2),1*substr(birthdate, 3, 2),1*substr(birthdate, 5, 4));

	filed=substr(scan(filename,2,'-'),1,8);
	
	mrn = compress(upcase(cats(unit_nbr)), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
	service_desc = upcase(cats(service_desc));
	vsttype = upcase(cats(io));

	adm_npi = cats(adm_phy_cd);
	adm_fname = upcase(cats(adm_phy_first_nm));
	adm_lname = upcase(cats(adm_phy_last_nm));

	adm_phy_name = cats(adm_lname) || ", " || cats(adm_fname);

	att_npi = cats(attend_phy_npi);
	att_fname= upcase(cats(attend_phy_first_nm));
	att_lname= upcase(cats(attend_phy_last_nm));

	attend_phy_name = cats(att_lname) || ", " || cats(att_fname);

	surg_npi = cats(op_phy_npi);
	surg_fname= upcase(cats(op_phy_first_nm_78));
	surg_lname= upcase(cats(op_phy_last_nm_78));

	surg_name = cats(surg_lname) || ", " || cats(surg_fname);

	oth_npi = cats(oth_phy_npi);
	oth_fname= upcase(cats(oth_phy_first_nm_78));
	oth_lname= upcase(cats(oth_phy_last_nm_78));


	oth_phy_name = cats(oth_lname) || ", " || cats(oth_fname);

	if index(cats(adm_provname),",") = 1 then adm_provname = compress(adm_provname,",");
	if index(cats(surg_provname),",") = 1 then surg_provname = compress(surg_provname,",");
	if index(cats(att_provname),",") = 1 then att_provname = compress(att_provname,",");
	if index(cats(oth_provname),",") = 1 then oth_provname = compress(oth_provname,",");



	facility = upcase(cats(fac_code));
	fac_name = put(fac_code, $facfmt.); 
	
	tin = cats(fac_tin);
	PatientAccountNumber = upcase(cats(pat_acct_nbr));	



	ssn = compress(pat_ssn,'-');
	lname = upcase(cats(pat_name_last));
	fname = upcase(cats(pat_name_first));
	mname = upcase(cats(pat_name_mi));
	address1 = cats(pat_addr_1);
	address2 = cats(pat_addr_2);
	city = cats(pat_city);
	city = cats(pat_city);
	zip = substr(cats(pat_zip_code),1,9);
	state=upcase(cats(pat_state));
	dis_cond= upcase(cats(dschrg_disp));

	diag1  = upcase(cats(pri_diag_desc));
	diag2  = upcase(cats(diag_cd1));
	diag3  = upcase(cats(diag_cd2));
	diag4  = upcase(cats(diag_cd3));
	diag5  = upcase(cats(diag_cd4));
	diag6  = upcase(cats(diag_cd5));
	diag7  = upcase(cats(diag_cd6));
	diag8  = upcase(cats(diag_cd7));
	diag9  = upcase(cats(diag_cd8));
	diag10 = upcase(cats(diag_cd9));
	diag11 = upcase(cats(diag_cd10));

	poa1  = upcase(cats(pr_diag_poa));
	poa2  = upcase(cats(oth_dx_1_poa));
	poa3  = upcase(cats(dx_2_poa));
	poa4  = upcase(cats(dx_3_poa));
	poa5  = upcase(cats(dx_4_poa));
	poa6  = upcase(cats(dx_5_poa));
	poa7  = upcase(cats(dx_6_poa));
	poa8  = upcase(cats(dx_7_poa));
	poa9  = upcase(cats(dx_8_poa));
	poa10 = upcase(cats(dx_9_poa));
	poa11 = upcase(cats(dx_10_poa));

	_proccd = upcase(cats(hcpcs_cd1));
	proccd = upcase(cats(hcpcs_cd1));
	mod1 = upcase(cats(hcpcs_mod1));
	drg = upcase(cats(drg_final_nbr));


	if index(cats(adm_phy_name),",") = 1 then adm_phy_name = compress(adm_phy_name,",");
	if index(cats(surg_name),",") = 1 then surg_name = compress(surg_name,",");
	if index(cats(att_phy_name),",") = 1 then att_phy_name = compress(att_phy_name,",");
	if index(cats(oth_phy_name),",") = 1 then oth_phy_name = compress(oth_phy_name,",");

	mrnn=1*mrn;

	adm_source_desc=put(adm_source, $admfmt.);

	if ssn in ('000000000', '111111111', '222222222', '333333333', '444444444', '555555555', '666666666', '777777777', '888888888', '999999999', '123456789') then ssn = "";  
	if (svcdt-dob le 10) and (ssn ne "") then ssn="";


	if cats(facility)='MDL' then interface='310';
	if cats(facility)='MDE' then interface='320';
	if cats(facility)='MDH' then interface='330';
	if cats(facility)='MDS' then interface='340';

	claimnum=pat_acct_nbr;
	npi="";
	provid=npi;
	provname='';
	provfirst='';
	provlast='';
	submit=.;
	phone='';
	revcd='';
	surgical_cd1='';
	
	upin='';
	pos='';
	units=1;
	memberid=ssn;
	system_member_id=mrn;
	source_system_id=interface;
	source = 'H';		
	mod1 = upcase(cats(hcpcs_mod1));
	mod2 = ''; 
	client_key = &client_id.;
	practice_id = &do_practice_id.;
	if facility='MDS' then practice_key=14226;
	else if facility='MDE' then practice_key=14223;
	else if facility='MDL' then practice_key=14224;
	else if facility='MDH' then practice_key=14225;
	else practice_key=0;
	system = "self pay east";

	run;


	*SASDOC--------------------------------------------------------------------------
	| Attached EMPI - enterprise_member_id
	|
	------------------------------------------------------------------------SASDOC*;  
	proc sql;
	  create table selfpay_003 as
	  select a.*,
	       b.enterprise_member_id 
	  from selfpay_002 a left join 
	     vh_empi.client_member b
	  on input(a.system_member_id,20.)=input(b.system_member_id,20.)  
	    and a.source_system_id=b.source_system_id
	    and b.active_flag=1
	    and b.client_key=&client_id. ;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Assign Maj Cat values
	|
	------------------------------------------------------------------------SASDOC*;  
	data practice_&do_practice_id.;
	set selfpay_003;
	where facility ne 'TRA';
	format admdt disdt svcdt dob mmddyy10.;
	length majcat 8.;
	if vsttype='E' then majcat=6;
	  if vsttype='I' then do;
		if cats(service_desc)='*EMERGENCY MEDICINE' then majcat=1;
		else if cats(service_desc)='*FAMILY PRACTICE' then majcat=1;
		else if cats(service_desc)='*MEDICINE (GENERAL)' then majcat=1;
		else if cats(service_desc)='*NEWBORN' then majcat=2;
		else if cats(service_desc)='*OBSTETRICS/GYN' then majcat=1;
		else if cats(service_desc)='*PEDIATRICS' then majcat=1;
		else if cats(service_desc)='*SURGERY (GENERAL)' then majcat=14;
		else if cats(service_desc)='E-TRAUMA' then majcat=1;
		else if cats(service_desc)='EUCLID INP REHAB' then majcat=4;
		else if cats(service_desc)='M-CARDIAC CATH LAB' then majcat=1;
		else if cats(service_desc)='M-CARDIOVASC DISEAS' then majcat=1;
		else if cats(service_desc)='M-CHEM DEPEND (DRUG' then majcat=5;
		else if cats(service_desc)='M-CHEM DEPEND DETOX' then majcat=5;
		else if cats(service_desc)='M-ENDOCRINOLOGY' then majcat=1;
		else if cats(service_desc)='M-GASTROENTEROLOGY' then majcat=1;
		else if cats(service_desc)='M-GERIATRIC PSYCHIA' then majcat=5;
		else if cats(service_desc)='M-INFECTIOUS DISEAS' then majcat=1;
		else if cats(service_desc)='M-INTERNAL MEDICINE' then majcat=1;
		else if cats(service_desc)='M-NEPHROLOGY' then majcat=1;
		else if cats(service_desc)='M-NEUROLOGY' then majcat=1;
		else if cats(service_desc)='M-ONCOLOGY' then majcat=1;
		else if cats(service_desc)='M-PHYSICAL REHAB ME' then majcat=4;
		else if cats(service_desc)='M-PSYCHIATRY' then majcat=5;
		else if cats(service_desc)='M-PULMONARY MEDICIN' then majcat=1;
		else if cats(service_desc)='M-RADIATION ONCOLOG' then majcat=1;
		else if cats(service_desc)='M-RHEUMATOLOGY' then majcat=1;
		else if cats(service_desc)='O-GYNECOLOGY' then majcat=1;
		else if cats(service_desc)='S-NEUROSURGERY' then majcat=14;
		else if cats(service_desc)='S-ORTHOPEDIC SURGER' then majcat=14;
		else if cats(service_desc)='S-OTRHINLARYNGOLOGY' then majcat=1;
		else if cats(service_desc)='S-PLASTIC SURGERY' then majcat=14;
		else if cats(service_desc)='S-UROLOGY SURGERY' then majcat=14;
		else if cats(service_desc)='S-VASCULAR SURGERY' then majcat=14;
		else majcat=1;
	  end;
	  else if vsttype='O' then do;
		if cats(service_desc)='*EMERGENCY MEDICINE' then majcat=6;
		else if cats(service_desc)='*FAMILY PRACTICE' then majcat=13;
		else if cats(service_desc)='*MEDICINE (GENERAL)' then majcat=13;
		else if cats(service_desc)='*NEWBORN' then majcat=2;
		else if cats(service_desc)='*OBSTETRICS/GYN' then majcat=13;
		else if cats(service_desc)='*PEDIATRICS' then majcat=13;
		else if cats(service_desc)='*SURGERY (GENERAL)' then majcat=16;
		else if cats(service_desc)='DEFAULT HOSP SRVC' then majcat=13;
		else if cats(service_desc)='E-TRAUMA' then majcat=6;
		else if cats(service_desc)='EUCLID OUTPATIENT' then majcat=13;
		else if cats(service_desc)='HEART FAIL. CENTER' then majcat=13;
		else if cats(service_desc)='LYNDHURST REHAB CLI' then majcat=11;
		else if cats(service_desc)='M-CARDIAC CATH LAB' then majcat=13;
		else if cats(service_desc)='M-CARDIOVASC DISEAS' then majcat=13;
		else if cats(service_desc)='M-CHEM DEPEND DETOX' then majcat=51;
		else if cats(service_desc)='M-DERMATOLOGY' then majcat=13;
		else if cats(service_desc)='M-ENDOCRINOLOGY' then majcat=13;
		else if cats(service_desc)='M-GASTROENTEROLOGY' then majcat=13;
		else if cats(service_desc)='M-GERIATRIC PSYCHIA' then majcat=51;
		else if cats(service_desc)='M-HEMATOLOGY' then majcat=13;
		else if cats(service_desc)='M-INFECTIOUS DISEAS' then majcat=13;
		else if cats(service_desc)='M-INTERNAL MEDICINE' then majcat=13;
		else if cats(service_desc)='M-NEPHROLOGY' then majcat=13;
		else if cats(service_desc)='M-NEUROLOGY' then majcat=13;
		else if cats(service_desc)='M-ONCOLOGY' then majcat=13;
		else if cats(service_desc)='M-PAIN LIMITED SERV' then majcat=13;
		else if cats(service_desc)='M-PHYSICAL REHAB ME' then majcat=11;
		else if cats(service_desc)='M-PSYCHIATRY' then majcat=51;
		else if cats(service_desc)='M-PULMONARY MEDICIN' then majcat=13;
		else if cats(service_desc)='M-RADIATION ONCOLOG' then majcat=13;
		else if cats(service_desc)='M-RADIOLOGY' then majcat=10;
		else if cats(service_desc)='M-RHEUMATOLOGY' then majcat=13;
		else if cats(service_desc)='MENORAH PK NRSG HME' then majcat=13;
		else if cats(service_desc)='MONTIFIORE NURSINGH' then majcat=13;
		else if cats(service_desc)='NURSING HOME LAB' then majcat=13;
		else if cats(service_desc)='O-GYNECOLOGY' then majcat=13;
		else if cats(service_desc)='S-ANESTHESIOLOGY' then majcat=17;
		else if cats(service_desc)='S-BLK (PAIN CTR)' then majcat=13;
		else if cats(service_desc)='S-CARDIOVASC SURG' then majcat=16;
		else if cats(service_desc)='S-NEUROSURGERY' then majcat=16;
		else if cats(service_desc)='S-OPHTHALMOLOGY' then majcat=13;
		else if cats(service_desc)='S-ORAL SURGERY' then majcat=16;
		else if cats(service_desc)='S-ORTHOPEDIC SURGER' then majcat=16;
		else if cats(service_desc)='S-OTRHINLARYNGOLOGY' then majcat=13;
		else if cats(service_desc)='S-PLASTIC SURGERY' then majcat=16;
		else if cats(service_desc)='S-PODIATRY' then majcat=13;
		else if cats(service_desc)='S-UROLOGY SURGERY' then majcat=16;
		else if cats(service_desc)='S-VASCULAR SURGERY' then majcat=16;
		else if cats(service_desc)='TWINSBRG TWO OUTPT' then majcat=13;
		else if cats(service_desc)='TWINSBRG TWO URGENT' then majcat=13;
		else if cats(service_desc)='TWINSBU CORP HEALTH' then majcat=13;
		else if cats(service_desc)='TWINSBU OUPATIENT' then majcat=13;
		else if cats(service_desc)='TWINSBU URGENT CARE' then majcat=13;
		else if cats(service_desc)='WOUND CENTER' then majcat=13;
	  end;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| IDS Process Queue Update - Update wild card hospital files so the process  
	| queue does not pick them up in the subsequent workflow
	|
	------------------------------------------------------------------------SASDOC*; 
	%let file_extract=%str("xxx");
	
	proc sql noprint;
	select quote(trim(file_extract)) into: file_extract separated by ','
	from selfpay_files 
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

%mend edw_hospital_east;
