
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_centraltech.sas
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

%macro edw_hospital_centraltech;


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

		%put NOTE: selfpay_dir_list = &selfpay_dir_list. ;
	  
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
	
	proc sort data = selfpay_files;
	by  descending filename;
	run;
	
	data selfpay_files;
	 set selfpay_files;
	 filenamedate=substr(scan(filename,2,'-'),1,8);
	 /**if substr(filenamedate,1,6) not in ('201112','201111');**/
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
	length fil2read $100. filename $50.;
	set selfpay_files ;
	fil2read="&selfpay_dir." || file_extract;
	infile dummy filevar=fil2read truncover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=1;
	do until (lastrec);
	input
		facility: $3.
		tin:	$9.
		pat_acct_nbr:	$13.
		acct_no_suffix: $4.
		service_desc:$3.
		io:	$10.
		adm_source: $10.
		adm_phy_npi:	$10.
		adm_phy_fname:	$25.
		adm_phy_lname:	$25.
		attend_phy_npi:	$10.
		attend_phy_fname:	$25.
		attend_phy_lname:	$25.
		oth_phy_npi:	$10.
		oth_phy_fname:	$25.
		oth_phy_lname:	$25.
		MRN:	$13.
		pat_name_first:	$15.
		pat_name_last:	$25.
		pat_mi: $1.
		sex:	$1.
		pat_addr_1:	$25.
		pat_addr_2:	$25.
		pat_city:	$30.
		pat_state:	$2.
		pat_zip_code:	$9.
		dob: mmddyy10.
		pat_ssn: $9.
		admdt: mmddyy10.
		adm_hour: $8.
		disdt: mmddyy10.
		dshrg_hour: $8.
		dis_cond: $2.
		pr_diag:	$10.
		diag_cd1:	$10.
		diag_cd2:	$10.
		diag_cd3:	$10.
		diag_cd4:	$10.
		diag_cd5:	$10.
		svcdt: mmddyy10.
		hcpcs_cd1: $10.
		hcpcs_mod1: $4. 
		drg : $5. 
		;
		
		drop file_extract;
		output;
	end;
	run;
	
	*SASDOC-------------------------------------------------------------------------
	|  Remove duplicates and output final dataset                         
	|------------------------------------------------------------------------SASDOC*;
	%facility_sort_routine(dataset_in=selfpay_001);

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data selfpay_002 (keep=	system filed claimnum filename practice_id
					   	upin npi tin provid provlast provfirst provname 
					   	memberid ssn lname fname mname sex dob 
					   	diag1-diag6 _proccd proccd mod1 mod2 units
					   	svcdt  
		 			   	submit pos
						system_member_id source_system_id practice_key
		     			        address1 address2 city state phone zip client_key source service_desc vsttype
		     			        dis_cond drg facility adm_source disdt admdt PatientAccountNumber filed majcat revcd surgical_cd1
						
						/** adm_phy_name surg_name att_phy_name oth_phy_name adm_npi att_npi oth_np interface mrn mrnn **/  );
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
	proccd $5.
	diag1-diag6 $6. 
	surgical_cd1 $10. 
	system $25. 
	interface source_system_id system_member_id $20. 
	adm_phy_name surg_name att_phy_name oth_phy_name $75. 
	vsttype $1.  mrn $13. adm_npi   att_npi  oth_npi $10.  
	dis_cond drg facility $3. adm_source $1. mod1 $4. vsttype $1.  filed $8. PatientAccountNumber $11.;


	filed=substr(scan(filename,2,'-'),1,8);

	vsttype = upcase(cats(io));

	adm_npi = cats(adm_phy_npi);
	adm_phy_name = cats(adm_phy_lname)|| ", " || cats(adm_phy_fname)  ;

	att_npi = cats(attend_phy_npi);
	att_phy_name = cats(attend_phy_lname)|| ", " || cats(attend_phy_fname)  ;

	oth_npi = cats(oth_phy_npi);
	oth_phy_name =cats(oth_phy_lname)|| ", " || cats(oth_phy_fname)  ;

	PatientAccountNumber = upcase(cats(pat_acct_nbr));	

	ssn=cats(compress(pat_ssn, '-'));

	lname = upcase(cats(pat_name_last));
	fname = upcase(cats(pat_name_first));
	mname = upcase(cats(pat_mi));
	address1 = cats(pat_addr_1);
	address2 = cats(pat_addr_2);
	city = cats(pat_city);
	state = cats(pat_state);
	zip = compress(substr(cats(pat_zip_code),1,9), "-");

	diag1  = upcase(cats(pr_diag));
	diag2  = upcase(cats(diag_cd1));
	diag3  = upcase(cats(diag_cd2));
	diag4  = upcase(cats(diag_cd3));
	diag5  = upcase(cats(diag_cd4));
	diag6  = upcase(cats(diag_cd5));

	proccd = upcase(cats(hcpcs_cd1));
	if index(proccd,'.') > 0 then do;
	  surgical_cd1=proccd;
	  proccd='';
	end;
	_proccd = proccd;
	mod1 = upcase(cats(hcpcs_mod1));
	drg = upcase(cats(drg));


	if index(cats(adm_phy_name),",") = 1 then adm_phy_name = compress(adm_phy_name,",");
	if index(cats(surg_name),",") = 1 then surg_name = compress(surg_name,",");
	if index(cats(att_phy_name),",") = 1 then att_phy_name = compress(att_phy_name,",");
	if index(cats(oth_phy_name),",") = 1 then oth_phy_name = compress(oth_phy_name,",");

	mrnn=1*mrn;
	if ssn in ('000000000', '111111111', '222222222', '333333333', '444444444', '555555555', '666666666', '777777777', '888888888', '999999999', '123456789') then ssn = "";  
	if (svcdt-dob le 10) and (ssn ne "") then ssn="";
	interface='050';

	claimnum=pat_acct_nbr;
	npi="";
	provid=npi;
	provname='';
	provfirst='';
	provlast='';
	submit=.;
	phone='';
	revcd='';	
	
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
	if tin='340714585' then practice_key=14212;
	else if tin='341855775' then practice_key=14220;
	else practice_key=0;
	system = "self pay central tech";
	
	/*****************************************************/
	/** standard major category logic                   **/
	/*****************************************************/
	majcat=99;
	if '10000'<=proccd<'70000' then do;
		if pos in ('21') then maj_cat_name=14;   *IP SURG ;
		else maj_cat_name=16;*OP SURG;
	end;
	else if '00000'<=proccd<'09999' then maj_cat_name =17; * ANESTHESIA ;
	else if '99100'<=proccd<='99140' then maj_cat_name=17; *ANESTHESIA;
	else if ('00000'<=proccd<'69999') and ( mod1 = '23' /* or provspec = '05'*/ ) then maj_cat_name =17; * ANESTHESIA;
	else if '99301'<=proccd<'99333' then maj_cat_name=18; * NURSING FACILITY VISITS ;
	else if '99255'<proccd<'99255' or '99217'<=proccd<='99239'  or '99291'<=proccd<='99301' or  
	'99431'<=proccd<='99440' or proccd='99356' then maj_cat_name=18; * IP VISIT;
	else if proccd='99391' or proccd='99432' then maj_cat_name=19;  *PHYSICAL EXAMS;
	else if '99381'<=proccd<='99404' then maj_cat_name=19; * WELL VISITS;
	else if '99201'<=proccd<='99215' then maj_cat_name = 19; *OTHER VISITS;
	else if '99354'<=proccd<='99355' then maj_cat_name = 19; *OTHER VISITS;
	else if '99347'<=proccd<='99347' then maj_cat_name = 19; *OTHER VISITS;
	else if proccd = 'T1015' then maj_cat_name = 19; *Clinic Visit;
	else if '99281'<=proccd<'99288' then maj_cat_name=20;  * ER OVERLAPS WITH BELOW ;
	else if '99241'<=proccd<='99275' then maj_cat_name =21; * CONSULT ;
	else if '99271'<=proccd<'99275' then maj_cat_name=21;  * CONSULT OVERLAPS WITH BELOW (LOTS MORE CODES>);
	else if '59000'<=proccd<'60000' then DO;
	if pos = '21' then maj_cat_name = 15; * IP SURGERY-OB;
	else maj_cat_name=22; *OB;
	end;
	else if '70000'<=proccd<'80000' then maj_cat_name=23;  *RAD;
	else if '80000'<=proccd<'90000' then maj_cat_name=24;  *PATH;
	else if '90471'<=proccd<'90472' then maj_cat_name=25; * IMMUNIZ;
	else if '90300'<=proccd<'90749' then maj_cat_name=25; * IMMUNIZ;
	else if '90700'<=proccd<='90799' then maj_cat_name=25; * THERE INJECTION;
	else if '92225'<=proccd<='92599' then maj_cat_name=26; *VISION HEAR ALLERGY IMMUNO;
	else if ('95807'<=proccd<='95999') OR ('96100'<=proccd<='96117') then maj_cat_name=26; *NEURO TESTING;
	else if '92900'<=proccd<='94990' then maj_cat_name=26; *CARDIO ;
	else if '90900'<=proccd<='90999' then maj_cat_name=26; *CARDIO ;
	else if '91000'<=proccd<='91299' then maj_cat_name=26; *CARDIO ;
	else if '95004'<=proccd<='95078' then maj_cat_name=26; *ALLERGY ER ;
	else if '92002'<=proccd<='92083' then maj_cat_name=26; * VISION ALLERGY IMMUNO - check;
	else if '95115'<=proccd<='95199' then maj_cat_name=27; * ALLERGY TESTING;
	else if '96900'<=proccd<='96999' then maj_cat_name=27; * SPECIAL DERMATOLIGICAL ;
	else if '97000'<=proccd<='98929' then maj_cat_name=27; * ;
	else if '96400'<=proccd<='96549' then maj_cat_name=27; * THERAPEUTIC INJ;
	else if proccd = '92507' then maj_cat_name = 27;  * changed 11/15/00;
	else if '99000'<=proccd<='99199' then maj_cat_name=28; *MISC  ;
	else if substr(proccd,1,1)='J' then do;
	    if proccd = "J7300" then maj_cat_name=31;
		else if pos = '12' then maj_cat_name = 29;
		else maj_cat_name=25;  *THERA INJ;
	end;
	else if substr(proccd,1,1) = 'A' and (pos = '41' /*or provspec = '03'*/) then maj_cat_name = 30; * ambulance changed 5/29/01;
	else if substr(proccd,1,1) in ('A','B','E','K','L') then maj_cat_name=31; *DME;
	else if '92002'<=proccd<='92286' then maj_cat_name=32; *VISION ;
	else if substr(proccd,1,1) in ('V') then maj_cat_name=32; *vision;
	else if '90801'<=proccd<='90815' then maj_cat_name=33; * MENTAL & NERVOUS OP;
	else if '90816'<=proccd<='90857' then maj_cat_name=33; * MENTAL & NERVOUS IP;
	else if '90862'<=proccd<='90899' then maj_cat_name=33; * MENTAL & NERVOUS OP;
	else if substr(proccd,1,1) in ('D') then maj_cat_name=34; *dental;
	else if ('90801'<=proccd<'90857') or ('90862'<=proccd<'90899')then maj_cat_name=39; * MENTAL & NERVOUS IP&OP; 
	else if proccd in ('96100','H2017','96117','97033','H2017','M0064') then maj_cat_name=39; *MENTAL & NERVOUS;
	/*else if provspec in ('75','36','37','75','74') and ('99222'<=proccd<='99239') then maj_cat_name = 39;  */
	else maj_cat_name = 99;

	if maj_cat_name = 99 then do;
		if proccd = '9020X' then maj_cat_name =19;
		else if proccd = '8000Y' then maj_cat_name =19;
		else if proccd = 'Y6007' then maj_cat_name =30;
		else if pos = '41' then maj_cat_name = 30;
		else if proccd = '5226X' then maj_cat_name =31;
		else maj_cat_name = 28;
	end;
	if maj_cat_name = . then maj_cat_name = 52;	

	run;


	*SASDOC--------------------------------------------------------------------------
	| Attached EMPI - enterprise_member_id
	|
	------------------------------------------------------------------------SASDOC*;  
	proc sql;
	  create table practice_&do_practice_id. as
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

%mend edw_hospital_centraltech;
