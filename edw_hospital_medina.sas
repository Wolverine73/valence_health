
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_medina.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load Institutional Hospital data for CCCPP          
|
| INPUT:    CCCPP Medina Self Pay pipe delimited files
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
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
|
| 31AUG2012 - Adam Alongi
|			  Added logic in final PROC SQL to update the workflow ID in ProcessQueue for all file records that were
|			  batch-processed.
+-----------------------------------------------------------------------HEADER*/

%macro edw_hospital_medina;


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
	
	data selfpay_files;
	 set selfpay_files;
	 filenamedate=substr(scan(filename,2,'-'),1,8);
	 /**if substr(filenamedate,1,6) in ('201104');**/
	run;
	
	%put WARNING:  Remove test condition for Medina Self Pay files. ;
	
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
	length fil2read $100. filename $50.;
	set selfpay_files (drop = filename);
	fil2read="&selfpay_dir." || file_extract;
	infile dummy filevar=fil2read truncover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=1;
	do until (lastrec);
	input
		facility: $3.
		fac_tin:	$9.
		pat_acct_nbr:	$11.
		acct_no_sffx: $10.
		line_item: $10.
		service_desc:	$19.
		io:	$1.
		adm_source:	$1.
		adm_phy_npi:	$10.
		adm_phy_first_nm:		$10.
		adm_phy_name:	$75.
		attend_phy_npi:	$10.
		attend_phy_first_nm:		$10.
		attend_phy_name:	$75.
		surg_phy_npi:	$10.
		surg_phy_first_nm:	$10.
		surg_name:	$75.
		oth_phy_npi:	$10.
		oth_phy_first_nm:	$10.
		oth_phy_name:	$75.
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
		pat_dob: $10.
		pat_ssn: $9.
		adm_dt: $8.
		adm_tm: $8.
		dshrg_dt: $8.
		dschrg_tm: $8.
		dschrg_disp:	$10.
		pr_diag_poa:	$1.
		pr_diag:	$5.
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
		diag_cd11:	$6.
		dx_1_poa: $1.
		dx_2_poa: $1.
		dx_3_poa: $1.
		dx_4_poa: $1.
		dx_5_poa: $1.
		dx_6_poa: $1.
		dx_7_poa: $1.
		dx_8_poa: $1.
		dx_9_poa: $1.
		dx_10_poa: $1.
		dx_11_poa: $1.
		serv_dt: $8.
		hcpcs_cd1: $5.
		hcpcs_mod1: $4.
		revcd: $4.
		drg_final_nbr: $3.    
		;
	
	filename=file_extract;
	drop file_extract;
	output;
	end;
	run;

	data facility;
	  format code $3. desc $80.;
	  code='CCP'; desc='CLEVELAND CLINIC PROFESSIONAL';output;
	  code='MDE'; desc='EUCLID HOSPITAL';output;
	  code='MDH'; desc='HURON HOSPITAL';output;
	  code='MDL'; desc='HILLCREST HOSPITAL';output;
	  code='MDS'; desc='SOUTH POINTE HOSPITAL';output;
	  code='FVW'; desc='AIRVIEW HOSPITAL';output;
	  code='LUT'; desc='LUTHERAN HOSPITAL';output;
	  code='LAK'; desc='LAKEWOOD HOSPITAL';output;
	  code='MAR'; desc='MARYMOUNT HOSPITAL';output;
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
		 			   	submit pos
						system_member_id source_system_id filed  revcd disdt admdt drg
		     			        ssn address1 address2 city state phone zip client_key source 
		     			        vsttype service_desc surgical_cd1 practice_key
		     			        /**
						service_desc mrnn interface  adm_phy_name surg_name att_phy_name oth_phy_name 
		                                vsttype mrn adm_npi  surg_npi att_npi  oth_npi fac_tin  
		                                dis_cond facility adm_source vsttype  PatientAccountNumber fac_name 
		                                **/ );
	set selfpay_001;
	format submit dollar20.2 filedate disdt admdt svcdt dob mmddyy10.;
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
	interface system_member_id source_system_id $20.
	adm_phy_name surg_name att_phy_name oth_phy_name $75. 
	vsttype $1.  mrn $13. adm_npi  surg_npi att_npi  oth_npi $10. tin $9. 
	dis_cond drg facility $3. adm_source $1. mod1 $4. poa1-poa10  vsttype $1. fac_name $75. filed $8. PatientAccountNumber $11.;

	svcdt=mdy(1*substr(serv_dt, 1, 2),1*substr(serv_dt, 3, 2),1*substr(serv_dt, 5, 4)); 
	admdt=mdy(1*substr(adm_dt, 1, 2),1*substr(adm_dt, 3, 2),1*substr(adm_dt, 5, 4)); 
	disdt=mdy(1*substr(dshrg_dt, 1, 2),1*substr(dshrg_dt, 3, 2),1*substr(dshrg_dt, 5, 4));
	dob=mdy(1*substr(pat_dob, 1, 2),1*substr(pat_dob, 3, 2),1*substr(pat_dob, 5, 4));

	
	filed=substr(scan(filename,2,'-'),1,8);
	
	mrn = compress(upcase(cats(unit_nbr)), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
	vsttype = upcase(cats(service_desc));
	vsttype = upcase(cats(io));

	adm_npi = cats(adm_phy_npi);
	adm_phy_name = cats(adm_phy_name);

	att_npi = cats(attend_phy_npi);
	att_phy_name = cats(attend_phy_name);

	surg_npi = cats(surg_phy_npi);
	surg_name = cats(surg_name);

	oth_npi = cats(oth_phy_npi);
	oth_phy_name = cats(oth_phy_name);

	facility = cats(facility);
	fac_name = put(facility, $facfmt.);	
	tin = cats(fac_tin);
	PatientAccountNumber = upcase(cats(pat_acct_nbr));
	
	if length(revcd) =4 then do;
	 if substr(revcd,1,1)='0' then do;
	   revcd=substr(revcd,2);
	 end;
	end;	

	ssn=cats(compress(pat_ssn, '-'));
	lname = upcase(cats(pat_name_last));
	fname = upcase(cats(pat_name_first));
	mname = upcase(cats(pat_name_mi));
	address1 = cats(pat_addr_1);
	address2 = cats(pat_addr_2);
	city = cats(pat_city);
	state = cats(pat_state);
	zip = substr(cats(pat_zip_code),1,9);

	dis_cond= upcase(cats(dschrg_disp));

	diag1  = upcase(cats(pr_diag));
	diag2  = upcase(cats(diag_cd1));
	diag3  = upcase(cats(diag_cd2));
	diag4  = upcase(cats(diag_cd3));
	diag5  = upcase(cats(diag_cd4));
	diag6  = upcase(cats(diag_cd5));
	diag7  = upcase(cats(diag_cd6));
	diag8  = upcase(cats(diag_cd7));
	diag9  = upcase(cats(diag_cd8));
	diag10 = upcase(cats(diag_cd9));

	poa1  = upcase(cats(pr_diag_poa));
	poa2  = upcase(cats(dx_1_poa));
	poa3  = upcase(cats(dx_2_poa));
	poa4  = upcase(cats(dx_3_poa));
	poa5  = upcase(cats(dx_4_poa));
	poa6  = upcase(cats(dx_5_poa));
	poa7  = upcase(cats(dx_6_poa));
	poa8  = upcase(cats(dx_7_poa));
	poa9  = upcase(cats(dx_8_poa));
	poa10 = upcase(cats(dx_9_poa)); 

	proccd = upcase(cats(hcpcs_cd1));
	_proccd=proccd;

	drg = upcase(cats(drg_final_nbr));

	if index(cats(adm_phy_name),",") = 1 then adm_phy_name = compress(adm_phy_name,",");
	if index(cats(surg_name),",") = 1 then surg_name = compress(surg_name,",");
	if index(cats(att_phy_name),",") = 1 then att_phy_name = compress(att_phy_name,",");
	if index(cats(oth_phy_name),",") = 1 then oth_phy_name = compress(oth_phy_name,",");

	mrnn=1*mrn;
	if ssn in ('000000000', '111111111', '222222222', '333333333', '444444444',
		   '555555555', '666666666', '777777777', '888888888', '999999999', '123456789') then ssn = "";  
	if (svcdt-dob le 10) and (ssn ne "") then ssn="";
	
	interface='250';

	claimnum=pat_acct_nbr;
	npi="";
	provid=npi;
	provname='';
	provfirst='';
	provlast='';
	submit=.;
	phone='';
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
	practice_key = &practice_key.;
	system = "self pay medina"; 

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
	data practice_&do_practice_id. (drop = vsttype service_desc);
	  format admdt disdt svcdt dob mmddyy10.;
	  length majcat 8.;
	  set selfpay_003;
	  if vsttype='I' then do;
		if cats(service_desc)='ABORTED' then majcat=2;
		else if cats(service_desc)='CARDIOLOGY' then majcat=1;
		else if cats(service_desc)='ENDOCRINOLOGY' then majcat=1;
		else if cats(service_desc)='GASTROENTEROLOGY' then majcat=1;
		else if cats(service_desc)='GENERAL MEDICINE' then majcat=1;
		else if cats(service_desc)='GENERAL SURGERY' then majcat=14;
		else if cats(service_desc)='GYNECOLOGY - SURGER' then majcat=14;
		else if cats(service_desc)='INTERNAL MEDICINE' then majcat=1;
		else if cats(service_desc)='MATERNITY' then majcat=2;
		else if cats(service_desc)='NEUROLOGY' then majcat=2;
		else if cats(service_desc)='NEUROSURGERY' then majcat=14;
		else if cats(service_desc)='NURSERY' then majcat=2;
		else if cats(service_desc)='OB ANTEPARTUM' then majcat=2;
		else if cats(service_desc)='OB DELIVERED' then majcat=2;
		else if cats(service_desc)='ONCOLOGY, MEDICAL' then majcat=1;
		else if cats(service_desc)='ONCOLOGY, SURGICAL' then majcat=14;
		else if cats(service_desc)='ORAL SURGERY/DENTAL' then majcat=14;
		else if cats(service_desc)='PULMONOLOGY' then majcat=1;
		else if cats(service_desc)='RHEUMATOLOGY' then majcat=1;
		else if cats(service_desc)='SURGERY' then majcat=14;
		else if cats(service_desc)='SURGICAL ORTHOPEDIC' then majcat=14;
		else if cats(service_desc)='THORACIC SURGERY' then majcat=14;
		else if cats(service_desc)='UROLOGY' then majcat=1;
		else if cats(service_desc)='VASCULAR SURGERY' then majcat=14;
		else if cats(service_desc)='VASCULAR, MEDICAL' then majcat=1;
		else majcat=1;
	  end;
	  else if vsttype='O' then do;
		if cats(service_desc)='ABORTED' then majcat=8;
		else if cats(service_desc)='ANESTHESIOLOGY' then majcat=17;
		else if cats(service_desc)='BRUNSWICK - ER' then majcat=6;
		else if cats(service_desc)='CARDIOLOGY' then majcat=13;
		else if cats(service_desc)='DEAD ON ARRIVAL' then majcat=13;
		else if cats(service_desc)='EMERGENCY ADMISSION' then majcat=6;
		else if cats(service_desc)='GASTROENTEROLOGY' then majcat=13;
		else if cats(service_desc)='GASTROINTESTINAL SR' then majcat=16;
		else if cats(service_desc)='GENERAL MEDICINE' then majcat=13;
		else if cats(service_desc)='GENERAL SURGERY' then majcat=16;
		else if cats(service_desc)='GYNECOLGY, MEDICAL' then majcat=13;
		else if cats(service_desc)='GYNECOLOGY - SURGER' then majcat=16;
		else if cats(service_desc)='MATERNITY' then majcat=8;
		else if cats(service_desc)='NEUROLOGY' then majcat=13;
		else if cats(service_desc)='OB ANTEPARTUM' then majcat=8;
		else if cats(service_desc)='PHY MED & REHAB' then majcat=11;
		else if cats(service_desc)='PULMONOLOGY' then majcat=13;
		else if cats(service_desc)='SURGERY' then majcat=16;
		else if cats(service_desc)='SURGICAL ORTHOPEDIC' then majcat=16;
		else if cats(service_desc)='UROLOGY' then majcat=13;
		else if cats(service_desc)='VASCULAR SURGERY' then majcat=16;
		else majcat=13;
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

%mend edw_hospital_medina;

