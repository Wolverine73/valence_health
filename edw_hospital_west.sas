
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_hospital_west.sas
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
| 16AUG2012 - Adam Alongi
|			  Changed logic for reading in internal code lookup files to read permanent datasets instead of Excel files.
|			  This should prevent a fatal error caused by two processes attempting to read the same file simultaneously.
|			  Code was taken from Brian's fix implemented in the Linux grid version of the macro.
|			  To find new code, Ctrl-F for "Linux-world".
|
| 31AUG2012 - Adam Alongi
|			  Added logic in final PROC SQL to update the workflow ID in ProcessQueue for all file records that were
|			  batch-processed.
+-----------------------------------------------------------------------HEADER*/

%macro edw_hospital_west;


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
	length fil2read $100. filename $50.;
	set selfpay_files ;
	fil2read="&selfpay_dir." || file_extract;
	infile dummy filevar=fil2read truncover delimiter=&dlm. dsd lrecl=10000 end=lastrec firstobs=1;
	do until (lastrec);
	input
		facility: $3.
		tin:	$9.
		pat_acct_nbr:	$11.
		acct_no_sffx: $10.
		line_item: $10.
		service_desc:	$19.
		io:	$1.
		adm_source:	$10.
		adm_phy_npi:	$10.
		adm_phy_first_nm:		$10.
		adm_phy_name:	$75.
		attend_phy_npi:	$10.
		attend_phy_first_nm:		$10.
		attend_phy_name:	$75.
		surg_npi:	$10.
		surg_first_nm:	$10.
		surg_name:	$75.
		oth_phy_npi:	$10.
		oth_phy_first_nm:	$10.
		oth_phy_name:	$75.
		MRN:	$13.
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
		pr_diag:	$6.
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
		serv_dt: $8.
		hcpcs_cd1: $5.
		hcpcs_mod1: $4.
		revcd: $4.
		drg_final_nbr: $3.   ; 
	output; 
	end;
	run;

	/**Begin Brian's Linux-world code to avoid access conflicts on the Excel files - AA**/

	data fvw_adm_source;
	set history.fvw_adm_source;
	run;

	data lak_adm_source;
	set history.lak_adm_source;
	run;

	data mar_adm_source;
	set history.mar_adm_source;
	run;

	data fvw_dis_disp;
	set history.fvw_dis_disp;
	run;

	data lak_dis_disp;
	set history.lak_dis_disp;
	run;

	data mar_dis_disp;
	set history.mar_dis_disp;
	run;

	data fvw_HOSPSVC;
	set history.fvw_HOSPSVC;
	run;

	data lak_HOSPSVC;
	set history.lak_HOSPSVC;
	run;

	data mar_HOSPSVC;
	set history.mar_HOSPSVC;
	run;

	data FVW_io ;
	set history.FVW_io;
	run;

	data LAK_io ;
	set history.LAK_io;
	run;

	data MAR_io ;
	set history.MAR_io;
	run;
	/** end Linux-world code**/

	libname SQL oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vLinkNSAP;" ;

	%create_formats(datain=sql.tblProvider, dataout=prov_cipar, where=client=6, fmtname=cipar, type=C, label=p_cipar, start_length=10, label_length=1, start=p_npi, obs=, date=);

	%create_formats(datain=FVW_dis_disp, dataout=FVW_dd, where=, fmtname=FVW_dd, type=C, label=UB, start_length=2, label_length=2, start=code, obs=, date=);
	%create_formats(datain=MAR_dis_disp, dataout=MAR_dd, where=, fmtname=MAR_dd, type=C, label=UB, start_length=2, label_length=2, start=code, obs=, date=);
	%create_formats(datain=LAK_dis_disp, dataout=LAK_dd, where=, fmtname=LAK_dd, type=C, label=UB, start_length=2, label_length=2, start=code, obs=, date=);

	%create_formats(datain=FVW_adm_source, dataout=FVW_as, where=, fmtname=FVW_as, type=C, label=UB, start_length=2, label_length=1, start=code, obs=, date=);
	%create_formats(datain=MAR_adm_source, dataout=MAR_as, where=, fmtname=MAR_as, type=C, label=UB, start_length=2, label_length=1, start=code, obs=, date=);
	%create_formats(datain=LAK_adm_source, dataout=LAK_as, where=, fmtname=LAK_as, type=C, label=UB, start_length=2, label_length=1, start=code, obs=, date=);

	%create_formats(datain=FVW_io, dataout=FVW_io_fmt, where=, fmtname=FVW_io, type=C, label=f2, start_length=1, label_length=1, start=start, obs=, date=);
	%create_formats(datain=MAR_io, dataout=MAR_io_fmt, where=, fmtname=MAR_io, type=C, label=f6, start_length=1, label_length=1, start=start, obs=, date=);
	%create_formats(datain=LAK_io, dataout=LAK_io_fmt, where=, fmtname=LAK_io, type=C, label=f4, start_length=1, label_length=1, start=start, obs=, date=);


	*SASDOC-------------------------------------------------------------------------
	|  Apply formats to self pay data                                         
	|------------------------------------------------------------------------SASDOC*;
	data selfpay_001; 
	  format interface $20. ;
	  set selfpay_001;
		if facility='LAK' then do;
		  patient_type=put(io, $lak_io.);
		  admit_source=put(adm_source, $lak_as.);
		  dis_disp=put(dschrg_disp, $lak_dd.);
		  interface='230';
		  practice_key=14229;
		end;
		else if facility='LUT' then do;
		  patient_type=put(io, $FVW_io.);
		  admit_source=put(adm_source, $FVW_as.);
		  dis_disp=put(dschrg_disp, $FVW_dd.);
		  interface='210';
		  practice_key=14228;
		end;
		else if facility='MAR' then do;
		  patient_type=put(io, $MAR_io.);
		  admit_source=put(adm_source, $MAR_as.);
		  dis_disp=put(dschrg_disp, $MAR_dd.);
		  interface='240';
		  practice_key=14230;
		end;
		else if facility='FVW' then do;
		  patient_type=put(io, $FVW_io.);
		  admit_source=put(adm_source, $FVW_as.);
		  dis_disp=put(dschrg_disp, $FVW_dd.);
		  interface='210';
		  practice_key=14227;
		end;
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
						system_member_id source_system_id practice_key
		     			        address1 address2 city state phone zip client_key source service_desc 
						/** interface  adm_phy_name surg_name oth_phy_name mrn mrnn adm_npi  surg_npi oth_npi **/
		                     
		               vsttype dis_cond drg facility adm_source  disdt admdt PatientAccountNumber filed  revcd surgical_cd1);
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
	source_system_id system_member_id $20.
	adm_phy_name surg_name oth_phy_name $75. 
	vsttype $1.  mrn $13. adm_npi  surg_npi oth_npi $10. tin $9. 
	dis_cond drg facility $3. adm_source $1. mod1 $4. poa1-poa10  vsttype $1. filed $8. PatientAccountNumber $11.;


	svcdt=mdy(1*substr(serv_dt, 1, 2),1*substr(serv_dt, 3, 2),1*substr(serv_dt, 5, 4)); 
	admdt=mdy(1*substr(adm_dt, 1, 2),1*substr(adm_dt, 3, 2),1*substr(adm_dt, 5, 4)); 
	disdt=mdy(1*substr(dshrg_dt, 1, 2),1*substr(dshrg_dt, 3, 2),1*substr(dshrg_dt, 5, 4));
	dob=mdy(1*substr(pat_dob, 1, 2),1*substr(pat_dob, 3, 2),1*substr(pat_dob, 5, 4)); 
	filed=substr(scan(filename,2,'-'),1,8);
	
	if length(revcd) =4 then do;
	 if substr(revcd,1,1)='0' then do;
	   revcd=substr(revcd,2);
	 end;
	end;
	
	mrnn=1*mrn;
	ssn=cats(compress(pat_ssn, '-'));
	if ssn in ('000000000', '111111111', '222222222', '333333333', '444444444', '555555555', '666666666', '777777777', '888888888', '999999999', '123456789') then ssn = "";  
	if (svcdt-dob le 10) and (ssn ne "") then ssn="";
	
	diag1=pr_diag;	      
	diag2=diag_cd1;      
	diag3=diag_cd2;     
	diag4=diag_cd3;      
	diag5=diag_cd4;      
	diag6=diag_cd5;      
	diag7=diag_cd6;      
	diag8=diag_cd7;      
	diag9=diag_cd8;      
	diag10=diag_cd9;  
 
	poa1=pr_diag_poa;   
	poa2=dx_1_poa;      
	poa3=dx_2_poa;      
	poa4=dx_3_poa;      
	poa5=dx_4_poa;      
	poa6=dx_5_poa;      
	poa7=dx_6_poa;      
	poa8=dx_7_poa;      
	poa9=dx_8_poa;      
	poa10=dx_9_poa;  
 
	address1=pat_addr_1;    
	address2=pat_addr_2;    
	city=pat_city;      
	fname=pat_name_first;
	lname=pat_name_last; 
	mname=pat_name_mi;   
	state=pat_state;     
	zip=pat_zip_code;  
	
	proccd=hcpcs_cd1; 
	_proccd=proccd; 
	    
	drg=drg_final_nbr; 
	adm_npi=adm_phy_npi;   
	attend_npi=attend_phy_npi;
	oth_npi=oth_phy_npi;   
	adm_source=admit_source;  
	dis_cond=dis_disp;      
	PatientAccountNumber=pat_acct_nbr;      
	vsttype=patient_type;       

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
	mod1=hcpcs_mod1;
	mod2 = ''; 
	client_key = &client_id.;
	practice_id = &do_practice_id.; 
	system = "self pay west"; 

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
	format admdt disdt svcdt dob mmddyy10.;
	length majcat 8.;

	if vsttype='E' then majcat=6;
	else if vsttype='O' then do;
		if service_desc='23H' then majcat=16;
		else if service_desc='23K' then majcat=13;
		else if service_desc='23P' then majcat=51;
		else if service_desc='2KP' then majcat=51;
		else if service_desc='AAC' then majcat=13;
		else if service_desc='ACC' then majcat=13;
		else if service_desc='ALI' then majcat=13;
		else if service_desc='ALL' then majcat=13;
		else if service_desc='AMB' then majcat=7;
		else if service_desc='AMS' then majcat=7;
		else if service_desc='ANE' then majcat=17;
		else if service_desc='ANE' then majcat=17;
		else if service_desc='APT' then majcat=8;
		else if service_desc='ASC' then majcat=7;
		else if service_desc='BIO' then majcat=13;
		else if service_desc='BIO' then majcat=13;
		else if service_desc='BLO' then majcat=13;
		else if service_desc='CAR' then majcat=13;
		else if service_desc='CAS' then majcat=13;
		else if service_desc='CCM' then majcat=13;
		else if service_desc='CCP' then majcat=51;
		else if service_desc='CCS' then majcat=16;
		else if service_desc='CDV' then majcat=13;
		else if service_desc='CHC' then majcat=13;
		else if service_desc='CHF' then majcat=13;
		else if service_desc='CRH' then majcat=11;
		else if service_desc='CTH' then majcat=13;
		else if service_desc='CTS' then majcat=13;
		else if service_desc='CTS' then majcat=16;
		else if service_desc='CVD' then majcat=13;
		else if service_desc='DBC' then majcat=13;
		else if service_desc='DER' then majcat=13;
		else if service_desc='DOS' then majcat=16;
		else if service_desc='ECF' then majcat=13;
		else if service_desc='EEG' then majcat=13;
		else if service_desc='EKG' then majcat=13;
		else if service_desc='EMG' then majcat=13;
		else if service_desc='EMR' then majcat=6;
		else if service_desc='END' then majcat=13;
		else if service_desc='END' then majcat=13;
		else if service_desc='ERS' then majcat=6;
		else if service_desc='ETW' then majcat=12;
		else if service_desc='EYE' then majcat=13;
		else if service_desc='FHC' then majcat=13;
		else if service_desc='FNS' then majcat=13;
		else if service_desc='FPC' then majcat=13;
		else if service_desc='FPR' then majcat=13;
		else if service_desc='FST' then majcat=13;
		else if service_desc='GRA' then majcat=10;
		else if service_desc='GRP' then majcat=51;
		else if service_desc='GRP' then majcat=51;
		else if service_desc='GSE' then majcat=13;
		else if service_desc='GSU' then majcat=16;
		else if service_desc='GYN' then majcat=13;
		else if service_desc='GYN' then majcat=13;
		else if service_desc='HBT' then majcat=12;
		else if service_desc='HEM' then majcat=13;
		else if service_desc='HMC' then majcat=13;
		else if service_desc='HON' then majcat=13;
		else if service_desc='HOS' then majcat=13;
		else if service_desc='HSP' then majcat=13;
		else if service_desc='INF' then majcat=13;
		else if service_desc='INF' then majcat=13;
		else if service_desc='INM' then majcat=13;
		else if service_desc='IOP' then majcat=51;
		else if service_desc='IRA' then majcat=10;
		else if service_desc='IVT' then majcat=12;
		else if service_desc='KMC' then majcat=16;
		else if service_desc='KPY' then majcat=51;
		else if service_desc='KSC' then majcat=7;
		else if service_desc='KSS' then majcat=16;
		else if service_desc='LAB' then majcat=9;
		else if service_desc='LUC' then majcat=13;
		else if service_desc='LUM' then majcat=13;
		else if service_desc='MCT' then majcat=13;
		else if service_desc='MDU' then majcat=51;
		else if service_desc='MED' then majcat=13;
		else if service_desc='MGE' then majcat=13;
		else if service_desc='MGN' then majcat=13;
		else if service_desc='MOL' then majcat=13;
		else if service_desc='MOM' then majcat=13;
		else if service_desc='MOP' then majcat=13;
		else if service_desc='MOR' then majcat=13;
		else if service_desc='MPD' then majcat=13;
		else if service_desc='MPL' then majcat=13;
		else if service_desc='MPV' then majcat=13;
		else if service_desc='MRT' then majcat=10;
		else if service_desc='MSE' then majcat=6;
		else if service_desc='MSG' then majcat=16;
		else if service_desc='MUR' then majcat=13;
		else if service_desc='NBL' then majcat=8;
		else if service_desc='NBL' then majcat=8;
		else if service_desc='NBO' then majcat=8;
		else if service_desc='NBO' then majcat=8;
		else if service_desc='NBU' then majcat=8;
		else if service_desc='NEP' then majcat=13;
		else if service_desc='NER' then majcat=13;
		else if service_desc='NER' then majcat=10;
		else if service_desc='NES' then majcat=16;
		else if service_desc='NEU' then majcat=13;
		else if service_desc='NRS' then majcat=16;
		else if service_desc='NUM' then majcat=13;
		else if service_desc='NUR' then majcat=8;
		else if service_desc='NUT' then majcat=13;
		else if service_desc='OBA' then majcat=8;
		else if service_desc='OBC' then majcat=8;
		else if service_desc='OBD' then majcat=8;
		else if service_desc='OBG' then majcat=8;
		else if service_desc='OBG' then majcat=13;
		else if service_desc='OBM' then majcat=8;
		else if service_desc='OBO' then majcat=8;
		else if service_desc='OBS' then majcat=8;
		else if service_desc='OBS' then majcat=13;
		else if service_desc='OBU' then majcat=8;
		else if service_desc='OCM' then majcat=13;
		else if service_desc='ONC' then majcat=13;
		else if service_desc='OPH' then majcat=13;
		else if service_desc='OPV' then majcat=13;
		else if service_desc='ORT' then majcat=13;
		else if service_desc='OTO' then majcat=13;
		else if service_desc='PAN' then majcat=13;
		else if service_desc='PAT' then majcat=9;
		else if service_desc='PAT' then majcat=13;
		else if service_desc='PDC' then majcat=13;
		else if service_desc='PDO' then majcat=13;
		else if service_desc='PED' then majcat=13;
		else if service_desc='PHM' then majcat=13;
		else if service_desc='PHY' then majcat=13;
		else if service_desc='PLA' then majcat=16;
		else if service_desc='PMC' then majcat=13;
		else if service_desc='POD' then majcat=13;
		else if service_desc='PPU' then majcat=51;
		else if service_desc='PSC' then majcat=51;
		else if service_desc='PSO' then majcat=51;
		else if service_desc='PSY' then majcat=51;
		else if service_desc='PTR' then majcat=11;
		else if service_desc='PTR' then majcat=13;
		else if service_desc='PTW' then majcat=11;
		else if service_desc='PTY' then majcat=11;
		else if service_desc='PUL' then majcat=13;
		else if service_desc='PUL' then majcat=13;
		else if service_desc='PVS' then majcat=16;
		else if service_desc='RAD' then majcat=10;
		else if service_desc='RAD' then majcat=10;
		else if service_desc='REH' then majcat=11;
		else if service_desc='REN' then majcat=13;
		else if service_desc='REO' then majcat=13;
		else if service_desc='RES' then majcat=13;
		else if service_desc='RHB' then majcat=11;
		else if service_desc='RHB' then majcat=11;
		else if service_desc='RHE' then majcat=13;
		else if service_desc='RHS' then majcat=11;
		else if service_desc='ROO' then majcat=13;
		else if service_desc='RSP' then majcat=12;
		else if service_desc='RUN' then majcat=30;
		else if service_desc='SCV' then majcat=16;
		else if service_desc='SDE' then majcat=16;
		else if service_desc='SDH' then majcat=9;
		else if service_desc='SDS' then majcat=9;
		else if service_desc='SGD' then majcat=16;
		else if service_desc='SGE' then majcat=16;
		else if service_desc='SGY' then majcat=16;
		else if service_desc='SHO' then majcat=16;
		else if service_desc='SNR' then majcat=16;
		else if service_desc='SNU' then majcat=13;
		else if service_desc='SOL' then majcat=13;
		else if service_desc='SOM' then majcat=16;
		else if service_desc='SOP' then majcat=16;
		else if service_desc='SOR' then majcat=16;
		else if service_desc='SPC' then majcat=9;
		else if service_desc='SPD' then majcat=13;
		else if service_desc='SPM' then majcat=13;
		else if service_desc='SPU' then majcat=16;
		else if service_desc='SPV' then majcat=16;
		else if service_desc='SRC' then majcat=13;
		else if service_desc='SRE' then majcat=16;
		else if service_desc='SRG' then majcat=16;
		else if service_desc='STB' then majcat=8;
		else if service_desc='SUR' then majcat=16;
		else if service_desc='SUR' then majcat=16;
		else if service_desc='THC' then majcat=13;
		else if service_desc='TRU' then majcat=13;
		else if service_desc='UNI' then majcat=13;
		else if service_desc='URO' then majcat=13;
		else if service_desc='VVC' then majcat=13;
		else if service_desc='WMC' then majcat=13;
		else if service_desc='WOM' then majcat=13;
		else if service_desc='XAB' then majcat=8;
		else if service_desc='XAN' then majcat=17;
		else if service_desc='XBA' then majcat=8;
		else if service_desc='XBI' then majcat=13;
		else if service_desc='XCC' then majcat=13;
		else if service_desc='XCL' then majcat=13;
		else if service_desc='XCP' then majcat=51;
		else if service_desc='XCR' then majcat=11;
		else if service_desc='XCT' then majcat=16;
		else if service_desc='XCV' then majcat=16;
		else if service_desc='XDE' then majcat=16;
		else if service_desc='XER' then majcat=6;
		else if service_desc='XFC' then majcat=13;
		else if service_desc='XGE' then majcat=16;
		else if service_desc='XGR' then majcat=13;
		else if service_desc='XGS' then majcat=16;
		else if service_desc='XGY' then majcat=16;
		else if service_desc='XHC' then majcat=13;
		else if service_desc='XHM' then majcat=13;
		else if service_desc='XHO' then majcat=16;
		else if service_desc='XHP' then majcat=13;
		else if service_desc='XIN' then majcat=13;
		else if service_desc='XLB' then majcat=9;
		else if service_desc='XMD' then majcat=51;
		else if service_desc='XND' then majcat=13;
		else if service_desc='XNL' then majcat=13;
		else if service_desc='XNR' then majcat=16;
		else if service_desc='XOA' then majcat=13;
		else if service_desc='XOB' then majcat=13;
		else if service_desc='XOC' then majcat=13;
		else if service_desc='XOM' then majcat=16;
		else if service_desc='XON' then majcat=13;
		else if service_desc='XOP' then majcat=16;
		else if service_desc='XOR' then majcat=16;
		else if service_desc='XOS' then majcat=7;
		else if service_desc='XOT' then majcat=16;
		else if service_desc='XOU' then majcat=13;
		else if service_desc='XOV' then majcat=13;
		else if service_desc='XPA' then majcat=13;
		else if service_desc='XPC' then majcat=16;
		else if service_desc='XPD' then majcat=13;
		else if service_desc='XPE' then majcat=13;
		else if service_desc='XPF' then majcat=13;
		else if service_desc='XPH' then majcat=9;
		else if service_desc='XPL' then majcat=16;
		else if service_desc='XPO' then majcat=16;
		else if service_desc='XPR' then majcat=13;
		else if service_desc='XPS' then majcat=51;
		else if service_desc='XPT' then majcat=11;
		else if service_desc='XPV' then majcat=16;
		else if service_desc='XPW' then majcat=13;
		else if service_desc='XRD' then majcat=13;
		else if service_desc='XRE' then majcat=13;
		else if service_desc='XRH' then majcat=13;
		else if service_desc='XRO' then majcat=13;
		else if service_desc='XRP' then majcat=13;
		else if service_desc='XRS' then majcat=13;
		else if service_desc='XSA' then majcat=13;
		else if service_desc='XSL' then majcat=13;
		else if service_desc='XSM' then majcat=13;
		else if service_desc='XSP' then majcat=9;
		else if service_desc='XSP' then majcat=9;
		else if service_desc='XTC' then majcat=13;
		else if service_desc='XUC' then majcat=13;
		else if service_desc='XUR' then majcat=16;
		else if service_desc='XWC' then majcat=13;
		else if service_desc='ZOT' then majcat=13;
		else if service_desc='ZZZ' then majcat=13;
		else majcat=13;
	end;
	else if vsttype='I' then do;
		if service_desc='23K' then majcat=1;
		else if service_desc='23P' then majcat=5;
		else if service_desc='2KP' then majcat=5;
		else if service_desc='AAC' then majcat=1;
		else if service_desc='ACC' then majcat=1;
		else if service_desc='ALI' then majcat=1;
		else if service_desc='ALL' then majcat=1;
		else if service_desc='ANE' then majcat=1;
		else if service_desc='ANE' then majcat=1;
		else if service_desc='APT' then majcat=2;
		else if service_desc='BIO' then majcat=1;
		else if service_desc='BIO' then majcat=1;
		else if service_desc='BLO' then majcat=1;
		else if service_desc='CAR' then majcat=1;
		else if service_desc='CAS' then majcat=1;
		else if service_desc='CCM' then majcat=1;
		else if service_desc='CCP' then majcat=5;
		else if service_desc='CCS' then majcat=14;
		else if service_desc='CDV' then majcat=1;
		else if service_desc='CHC' then majcat=1;
		else if service_desc='CHF' then majcat=1;
		else if service_desc='CRH' then majcat=4;
		else if service_desc='CTH' then majcat=1;
		else if service_desc='CTS' then majcat=1;
		else if service_desc='CTS' then majcat=14;
		else if service_desc='CVD' then majcat=1;
		else if service_desc='DBC' then majcat=1;
		else if service_desc='DER' then majcat=1;
		else if service_desc='DOS' then majcat=14;
		else if service_desc='ECF' then majcat=1;
		else if service_desc='EEG' then majcat=1;
		else if service_desc='EKG' then majcat=1;
		else if service_desc='EMG' then majcat=1;
		else if service_desc='EMR' then majcat=6;
		else if service_desc='END' then majcat=1;
		else if service_desc='END' then majcat=1;
		else if service_desc='ERS' then majcat=6;
		else if service_desc='ETW' then majcat=1;
		else if service_desc='EYE' then majcat=1;
		else if service_desc='FHC' then majcat=1;
		else if service_desc='FNS' then majcat=1;
		else if service_desc='FPC' then majcat=1;
		else if service_desc='FPR' then majcat=1;
		else if service_desc='FST' then majcat=1;
		else if service_desc='GRA' then majcat=1;
		else if service_desc='GRP' then majcat=5;
		else if service_desc='GRP' then majcat=5;
		else if service_desc='GSE' then majcat=1;
		else if service_desc='GSU' then majcat=14;
		else if service_desc='GYN' then majcat=1;
		else if service_desc='GYN' then majcat=1;
		else if service_desc='HBT' then majcat=1;
		else if service_desc='HEM' then majcat=1;
		else if service_desc='HMC' then majcat=1;
		else if service_desc='HON' then majcat=1;
		else if service_desc='HOS' then majcat=1;
		else if service_desc='HSP' then majcat=1;
		else if service_desc='INF' then majcat=1;
		else if service_desc='INF' then majcat=1;
		else if service_desc='INM' then majcat=1;
		else if service_desc='IRA' then majcat=1;
		else if service_desc='IRU' then majcat=4;
		else if service_desc='IVT' then majcat=1;
		else if service_desc='KMC' then majcat=14;
		else if service_desc='KPY' then majcat=5;
		else if service_desc='KSR' then majcat=1;
		else if service_desc='KSS' then majcat=14;
		else if service_desc='LAB' then majcat=1;
		else if service_desc='LUC' then majcat=1;
		else if service_desc='LUM' then majcat=1;
		else if service_desc='MCT' then majcat=1;
		else if service_desc='MDU' then majcat=5;
		else if service_desc='MED' then majcat=1;
		else if service_desc='MGE' then majcat=1;
		else if service_desc='MGN' then majcat=1;
		else if service_desc='MOL' then majcat=1;
		else if service_desc='MOM' then majcat=1;
		else if service_desc='MOP' then majcat=1;
		else if service_desc='MOR' then majcat=1;
		else if service_desc='MPD' then majcat=1;
		else if service_desc='MPL' then majcat=1;
		else if service_desc='MPV' then majcat=14;
		else if service_desc='MRT' then majcat=1;
		else if service_desc='MSE' then majcat=6;
		else if service_desc='MSG' then majcat=14;
		else if service_desc='MUR' then majcat=1;
		else if service_desc='NBL' then majcat=2;
		else if service_desc='NBL' then majcat=2;
		else if service_desc='NBO' then majcat=2;
		else if service_desc='NBO' then majcat=2;
		else if service_desc='NBT' then majcat=2;
		else if service_desc='NBU' then majcat=2;
		else if service_desc='NEP' then majcat=1;
		else if service_desc='NER' then majcat=1;
		else if service_desc='NER' then majcat=1;
		else if service_desc='NES' then majcat=14;
		else if service_desc='NEU' then majcat=1;
		else if service_desc='NRS' then majcat=14;
		else if service_desc='NUM' then majcat=1;
		else if service_desc='NUR' then majcat=2;
		else if service_desc='NUT' then majcat=1;
		else if service_desc='OBA' then majcat=2;
		else if service_desc='OBC' then majcat=2;
		else if service_desc='OBD' then majcat=2;
		else if service_desc='OBG' then majcat=2;
		else if service_desc='OBG' then majcat=2;
		else if service_desc='OBM' then majcat=2;
		else if service_desc='OBS' then majcat=2;
		else if service_desc='OBS' then majcat=2;
		else if service_desc='OBU' then majcat=2;
		else if service_desc='OCM' then majcat=1;
		else if service_desc='OOA' then majcat=1;
		else if service_desc='OPH' then majcat=1;
		else if service_desc='ORT' then majcat=1;
		else if service_desc='OTO' then majcat=1;
		else if service_desc='PAN' then majcat=1;
		else if service_desc='PAT' then majcat=1;
		else if service_desc='PAT' then majcat=1;
		else if service_desc='PDC' then majcat=1;
		else if service_desc='PED' then majcat=1;
		else if service_desc='PHM' then majcat=1;
		else if service_desc='PHY' then majcat=1;
		else if service_desc='PLA' then majcat=14;
		else if service_desc='PMC' then majcat=1;
		else if service_desc='POD' then majcat=1;
		else if service_desc='PPU' then majcat=5;
		else if service_desc='PSC' then majcat=5;
		else if service_desc='PSO' then majcat=5;
		else if service_desc='PSY' then majcat=5;
		else if service_desc='PSY' then majcat=5;
		else if service_desc='PTR' then majcat=4;
		else if service_desc='PTR' then majcat=1;
		else if service_desc='PTW' then majcat=4;
		else if service_desc='PTY' then majcat=4;
		else if service_desc='PUL' then majcat=1;
		else if service_desc='PUL' then majcat=1;
		else if service_desc='PVS' then majcat=14;
		else if service_desc='RAD' then majcat=1;
		else if service_desc='RAD' then majcat=1;
		else if service_desc='REH' then majcat=4;
		else if service_desc='REI' then majcat=1;
		else if service_desc='REN' then majcat=1;
		else if service_desc='RES' then majcat=1;
		else if service_desc='REY' then majcat=5;
		else if service_desc='RHB' then majcat=5;
		else if service_desc='RHB' then majcat=5;
		else if service_desc='RHE' then majcat=1;
		else if service_desc='RHS' then majcat=5;
		else if service_desc='ROO' then majcat=1;
		else if service_desc='RSP' then majcat=1;
		else if service_desc='RUN' then majcat=30;
		else if service_desc='SCV' then majcat=5;
		else if service_desc='SDE' then majcat=14;
		else if service_desc='SDH' then majcat=1;
		else if service_desc='SDS' then majcat=1;
		else if service_desc='SGD' then majcat=14;
		else if service_desc='SGE' then majcat=14;
		else if service_desc='SGY' then majcat=14;
		else if service_desc='SHO' then majcat=14;
		else if service_desc='SNF' then majcat=3;
		else if service_desc='SNF' then majcat=3;
		else if service_desc='SNR' then majcat=14;
		else if service_desc='SNU' then majcat=3;
		else if service_desc='SOL' then majcat=1;
		else if service_desc='SOM' then majcat=14;
		else if service_desc='SOP' then majcat=14;
		else if service_desc='SOR' then majcat=14;
		else if service_desc='SPC' then majcat=1;
		else if service_desc='SPD' then majcat=1;
		else if service_desc='SPM' then majcat=1;
		else if service_desc='SPU' then majcat=14;
		else if service_desc='SPV' then majcat=14;
		else if service_desc='SRC' then majcat=1;
		else if service_desc='SRE' then majcat=14;
		else if service_desc='SRG' then majcat=14;
		else if service_desc='STB' then majcat=2;
		else if service_desc='SUR' then majcat=14;
		else if service_desc='SUR' then majcat=14;
		else if service_desc='THC' then majcat=1;
		else if service_desc='TRU' then majcat=1;
		else if service_desc='UNI' then majcat=1;
		else if service_desc='URO' then majcat=1;
		else if service_desc='VVC' then majcat=1;
		else if service_desc='WMC' then majcat=1;
		else if service_desc='WOM' then majcat=1;
		else if service_desc='XCC' then majcat=1;
		else if service_desc='XCP' then majcat=5;
		else if service_desc='XFC' then majcat=1;
		else if service_desc='XGR' then majcat=1;
		else if service_desc='XOU' then majcat=4;
		else if service_desc='XPE' then majcat=6;
		else if service_desc='XRP' then majcat=1;
		else if service_desc='XSP' then majcat=1;
		else if service_desc='XSP' then majcat=1;
		else majcat=1;
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

%mend edw_hospital_west;


