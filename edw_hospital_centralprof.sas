
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_centralprof.sas
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

%macro edw_hospital_centralprof;
	
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

	proc sort data = selfpay_files;
	by descending filename;
	run;
	
	
	*SASDOC-------------------------------------------------------------------------
	| Validate if SAS datasets have been processed in a previous workflow   
	| maxprocessid values: 0=DNE within EDW 
	|                      1=1st cycle exist within EDW only ssn members exist
	|                      2=2nd cycle exist within EDW all members exist
	|------------------------------------------------------------------------SASDOC*;
	%if &maxprocessid ne 0 and &maxprocessid ne 1 %then %do;  
	
		proc sql noprint;
		  create table uploader_history as
		  select distinct client_key, practice_id, filename
		  from cihold.hold_encounter_header_detail
		  where practice_id = &do_practice_id. 
		    and client_key = &client_id.; 
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
		
	%end; 
	

	*SASDOC-------------------------------------------------------------------------
	| Process new lab files for the workflow                         
	|------------------------------------------------------------------------SASDOC*;

	%macro do_selfpay;

	%local cnt;
	%let cnt=0;
	proc sql noprint;
	 select count(*) into :cnt
	 from selfpay_files;
	quit;

	%let firstobs = 1;
	%let lastobs  = 1;

	%let doloop = %eval(%sysfunc(ceil(&cnt/&lastobs)));
	%put doloop = &doloop. ;
	%put firstobs = &firstobs. ;

	%local i;

	%do i = &firstobs %to &doloop;

		data x&i;
		length fil2read $100. filename $50. ;
		set selfpay_files (firstobs = &firstobs. obs = &lastobs. );
		fil2read="&selfpay_dir." || file_extract;
		infile dummy filevar=fil2read truncover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=1;
		do until (lastrec);	
			input
			facility: $3.
			tin:	$9.
			pat_acct_nbr:	$11.
			pos_cd:	$2.
			attend_phy_npi:	$10.
			attend_phy_name:	$75.
			MRN:	$13.
			pat_name_first:	$15.
			pat_name_last:	$25.
			sex:	$1.
			pat_addr_1:	$25.
			pat_addr_2:	$25.
			pat_city:	$18.
			pat_state:	$2.
			pat_zip_code:	$9.
			pat_dob: $10.
			pat_ssn: $9.
			adm_dt: $8.
			dshrg_dt: $8.
			pr_diag:	$6.
			diag_cd1:	$6.
			diag_cd2:	$6.
			diag_cd3:	$6.
			diag_cd4:	$6.
			diag_cd5:	$6.
			serv_dt: $8.
			hcpcs_cd1: $5.
			hcpcs_mod1: $4.  
			; 
			output;
		end;
		run;

		%let firstobs = %eval(&lastobs + 1);
		%let lastobs  = %eval(&lastobs + 1);

	%end;

	proc datasets library=work nolist;
	 delete selfpay_001 (memtype = data);
	quit;

	data selfpay_001  ;
	 set %do j = 1 %to &doloop; x&j %end;; 
	run; 

	proc datasets library=work nolist;
	 delete %do k = 1 %to &doloop; x&k (memtype = data) %end; ;
	quit;  


	%mend do_selfpay;
	%do_selfpay;

	proc sort data = selfpay_001 out = test01 (keep = filename) nodupkey;
	by filename;
	run;

	proc sort data = selfpay_files nodupkey;
	by filename;
	run;

	data test01;
	merge test01 (in=a)
	      selfpay_files (in=b);
	by filename;
	if a and b then flag=' ';
	else flag='X';
	run;

	data POSwalk;
	format code $2. pos $4.;  
	code='A';pos='24';output;
	code='AM';pos='';output;	
	code='B';pos='61';output;
	code='C';pos='20';output;
	code='D';pos='65';output;
	code='E';pos='52';output;
	code='F';pos='15';output;
	code='G';pos='23';output;
	code='H';pos='';output;
	code='I';pos='81';output;
	code='J';pos='13';output;
	code='K';pos='03';output;
	code='L';pos='16';output;
	code='O';pos='32';output;
	code='0';pos='99';output;
	code='1';pos='21';output;
	code='2';pos='22';output;
	code='3';pos='11';output;
	code='4';pos='12';output;
	code='5';pos='33';output;
	code='52';pos='';output;
	code='6';pos='06';output;
	code='7';pos='60';output;
	code='8';pos='31';output;
	code='9';pos='AM';output; 
	run;

	%create_formats(datain=poswalk, dataout=posfmt, where=, fmtname=posfmt, type=c, label=pos, start_length=5, label_length=3, start=code);

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data selfpay_002 (keep=	system filed claimnum filedate filename practice_id
					   	upin npi tin provid provlast provfirst provname 
					   	memberid ssn lname fname mname sex dob 
					   	diag1-diag5 _proccd proccd mod1 mod2 units
					   	svcdt  
		 			   	submit pos
						system_member_id source_system_id 
		     			        address1 address2 city state phone zip client_key source 
						mrnn interface  mrn ssn facility disdt admdt filed  );
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
	city	$20.
	state	$2.
	zip	$5.
	phone	$11.
	provid	$10.
	npi     $10.
	provfirst	$25.
	provlast	$15.  
	proccd $5.
	diag1-diag5 $6.  
	tin $9. 
	provname system $50. 
	interface source_system_id system_member_id $20. 
	mrn $13. tin $9. 
	facility $3.  mod1 $4.  filed $8. ;

	svcdt=mdy(1*substr(serv_dt, 1, 2),1*substr(serv_dt, 3, 2),1*substr(serv_dt, 5, 4)); 
	admdt=mdy(1*substr(adm_dt, 1, 2),1*substr(adm_dt, 3, 2),1*substr(adm_dt, 5, 4)); 
	disdt=mdy(1*substr(dshrg_dt, 1, 2),1*substr(dshrg_dt, 3, 2),1*substr(dshrg_dt, 5, 4));
	dob=mdy(1*substr(pat_dob, 1, 2),1*substr(pat_dob, 3, 2),1*substr(pat_dob, 5, 4));
	
	
	
	fname=cats(pat_name_first);
	lname=cats(pat_name_last);
	mname='';
	address1=cats(pat_addr_1);
	address2=cats(pat_addr_2);
	city=cats(pat_city);
	state=cats(pat_state);	
	zip=cats(pat_zip_code);
	ssn=cats(compress(pat_ssn, '-'));
	diag1=upcase(cats(pr_diag));
	diag2=upcase(cats(diag_cd1));
	diag3=upcase(cats(diag_cd2));
	diag4=upcase(cats(diag_cd3));
	diag5=upcase(cats(diag_cd4));
	proccd=upcase(cats(hcpcs_cd1));
	_proccd=proccd;

	
	filed=substr(scan(filename,2,'-'),1,8);
		
	ssn=cats(compress(pat_ssn, '-'));
	if ssn in ('000000000', '111111111', '222222222', '333333333', '444444444', '555555555', '666666666', '777777777', '888888888', '999999999', '123456789') then ssn = "";  
	if (svcdt-dob le 10) and (ssn ne "") then ssn="";
	interface='050';
	mrnn=1*mrn;
	
	claimnum=pat_acct_nbr;
	npi=cats(attend_phy_npi);
	provid=npi;
	provname=cats(attend_phy_name);
	provfirst='';
	provlast='';
	submit=.;
	phone='';
	
	upin='';
	pos=put(pos_cd, $posfmt.);
	units=1;
	memberid=ssn;
	system_member_id=mrn;
	source_system_id=interface;
	source = 'P';		
	mod1 = upcase(cats(hcpcs_mod1));
	mod2 = ''; 
	client_key = &client_id.;
	practice_id = &do_practice_id.; 
	system = "self pay central prof";
	
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
	
%mend edw_hospital_centralprof;
