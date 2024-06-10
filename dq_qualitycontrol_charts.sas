
/*HEADER------------------------------------------------------------------------
|
| program:  dq_qualitycontrol_charts.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create quality control charts for practice data 
|
| logic:    
|
| input:         
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01MAY2010 - Brandon Barber  - Clinical Integration  1.0.01
|             Original
|
| 01NOV2010 - Brian Stropich
|             Fixed the indicators for the MRCC to 0-good, 1-too few, 2-too many          
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_qualitycontrol_charts;

	%*SASDOC----------------------------------------------------------------------
	| Individual Value and Moving Range Control Charts 
	|
	| Total observations within monthly files are compared to the monthly history 
	| of all files by practice.  Control limits are established based on statistical 
	| significance departures away from the mean number of file records per month.  
	| Thus, any observation outside of these control limits, whether too high or 
	| too low, is considered an observational extreme based on the previous file 
	| history and is flagged for further review.  
	|
	+---------------------------------------------------------------------SASDOC*;
	data vMine (drop = filename dateday);
	  length filedt $6 system $35 ; 
	  set &datasetin. (keep = filename svcdt npi );
	  system="&systemname.";
	  filedt = substr(filename,index(filename,"-")+1,6);
	  pracID = substr(filename,1,index(filename,"-")-1);
	  dateday = put(svcdt,weekdatx3.);
	  if put(npi,$provyn.) = "Y";
	  if upcase(dateday) in ("SAT","SUN") then delete;
	run;

	%*SASDOC----------------------------------------------------------------------
	| claim counts by npi and file reception month  
	+---------------------------------------------------------------------SASDOC*;
	proc sort data=vMine;
	  by npi filedt;
	run;

	data vMine_File (drop = svcdt);
	  set vMine;
	  retain clmcount;
	  by npi filedt;
	  if first.filedt then clmcount = 1;
	  else clmcount = clmcount + 1;
	  if last.filedt;
	run;

	data vMineFile_Num1 (keep = npi filecount);
	  set vMine_File;
	  by npi;
	  retain filecount;
	  if first.npi then filecount = 1;
	  else filecount = filecount + 1;
	  if last.npi;
	run;

	data vMineFile_prov;
	  set vMine_File;
	  by npi;
	  if first.npi then delete; *remove full historical data;
/*	  if filedt ge put(intnx('month',today(),-11),yymmn6.);*/
	run;

	data vMineFile_prov1a (drop = preprov preclms);
	  set vMineFile_prov;
	  preprov = lag(npi);
	  preclms = lag(clmcount);
	  if npi = preprov then MR = abs(clmcount - preclms);
	  count = 1;
	run;

	proc summary data=vMineFile_prov1a;
	  class npi;
	  vars count MR clmcount;
	  output out=vMineFile_prov1X (drop = _type_ _freq_) sum=;
	run;

	data vMineFile_prov1X (drop = MR count clmcount);
	  set vMineFile_prov1X;
	  MRbar = MR / count;
	  clmcountbar = clmcount / count;
	  I_UCL = clmcountbar + 3*(MRbar / 1.128);
	  I_LCL = clmcountbar - 3*(MRbar / 1.128);
	  R_UCL = 3.267*MRbar;
	  R_LCL = 0;
	  if npi ne "";
	  if I_LCL lt 0 then I_LCL = 0;
	run;


	%*SASDOC----------------------------------------------------------------------
	| Individual Value and Moving Range QC by ProvID and File Reception Month  
	+---------------------------------------------------------------------SASDOC*;
	data qc_movingrange_filedt_provider (keep =  pracID npi system filedt MR_flag clm_flag flag_reason);
	  length flag_reason $8.;
	  merge vMineFile_prov1X (in=a) 
	        vMineFile_prov1a (in=b drop = count) 
	        vMineFile_Num1   (in=c);
	  by npi;
	  if clmcount gt I_UCL then do;
		clm_flag = 2;
		flag_reason = "Too Many";
	  end;
	  else if clmcount lt I_LCL then do;
		clm_flag = 1;
		flag_reason = "Too Few";
	  end;
	  else clm_flag = 0;
	  if MR gt R_UCL then MR_flag = 1;
	  else if MR lt R_LCL then MR_flag = 1;
	  else MR_flag = 0;
	run;

	proc sort data = qc_movingrange_filedt_provider;
	by descending filedt;
	run;

	proc sql noprint;
	 select filedt into: filedt
	 from qc_movingrange_filedt_provider (obs=1);
	quit;

	data qc_movingrange_filedt_provider;
	 set qc_movingrange_filedt_provider  ;
	 where filedt = "&filedt."; 
	run;


	%*SASDOC----------------------------------------------------------------------
	| Claim counts by practice and file reception months.  
	+---------------------------------------------------------------------SASDOC*;
	proc summary data=vMineFile_prov;
	  class pracid filedt;
	  vars clmcount;
	  id system;
	  output out=vMineFile_prac (drop = _type_ _freq_) sum=;
	run;

	data vMineFile_prac (drop = pregroup preclms);
	  set vMineFile_prac;
	  where pracid ne "" and filedt ne "";
	  pregroup = lag(pracid);
	  preclms = lag(clmcount);
	  if pracid = pregroup then MR = abs(clmcount - preclms);
	  count = 1;
	run;

	data vMineFile_Num2 (keep = pracid filecount pracid);
	  retain filecount;
	  set vMineFile_prac;
	  by pracid;
	  if first.pracid then filecount = 1;
	  else filecount = filecount + 1;
	  if last.pracid;
	run;

	proc summary data=vMineFile_prac;
	  class pracid;
	  vars count MR clmcount;
	  output out=vMineFile_prac1X (drop = _type_ _freq_) sum=;
	run;

	data vMineFile_prac1X (drop = MR count clmcount);
	  set vMineFile_prac1X;
	  if pracid ne "";
	  MRbar = MR / count;
	  clmcountbar = clmcount / count;
	  I_UCL = clmcountbar + 3*(MRbar / 1.128);
	  I_LCL = clmcountbar - 3*(MRbar / 1.128);
	  if I_LCL lt 0 then I_LCL = 0;
	  R_UCL = 3.267*MRbar;
	  R_LCL = 0;
	run;


	%*SASDOC----------------------------------------------------------------------
	| Individual Value and Moving Range QC by Practice and File Reception Month  
	+---------------------------------------------------------------------SASDOC*;
	data qc_movingrange_filedt_practice (keep = pracid system filedt MR_flag clm_flag flag_reason);
	  length flag_reason $8.;
	  merge vMineFile_prac1X (in=a) 
	        vMineFile_prac   (in=b drop = count) 
	        vMineFile_Num2   (in=c);
	  by pracid;
	  if clmcount gt I_UCL then do;
		clm_flag = 2;
		flag_reason = "Too Many";
	  end;
	  else if clmcount lt I_LCL then do;
		clm_flag = 1;
		flag_reason = "Too Few";
	  end;
	  else clm_flag = 0;
	  if MR gt R_UCL then MR_flag = 1;
	  else if MR lt R_LCL then MR_flag = 1;
	  else MR_flag = 0;
	run;

	proc sort data = qc_movingrange_filedt_practice;
	by descending filedt;
	run;

	proc sql noprint;
	 select filedt into: filedt
	 from qc_movingrange_filedt_practice (obs=1);
	quit;

	data qc_movingrange_filedt_practice;
	 set qc_movingrange_filedt_practice  ;
	 where filedt = "&filedt."; 
	run;
	
	
	data qc_movingrange_filedt;
	 length level $15 ;
	 set qc_movingrange_filedt_practice (in=a)
	     qc_movingrange_filedt_provider (in=b);
	 if a then level='Practice Level';
	 else if b then level='Provider Level';
	run;


	%*SASDOC----------------------------------------------------------------------
	| Fraction Nonconforming Control Charts 
	|
	| The rate of invalid or missing (nonconforming) records within monthly files 
	| are compared within respective fields to the monthly history of all files by 
	| practice.  An upper control limit is established based on statistical 
	| significance departure above the mean rate of nonconforming records per month.  
	| Thus, any observation above the upper control limit represents an observational 
	| extreme based on the previous file history and is flagged for further review.   
	|
	+---------------------------------------------------------------------SASDOC*;
	%put NOTE: qc_&practice - created in the dq_create_dataset macro;
	
	data _null_;
	  cur_month = put(today(),yymmn.);
	  call symputx('cur_month',cur_month);
	run;

	%put NOTE:  Current Month: &cur_month.;


	%*SASDOC----------------------------------------------------------------------
	| File date 
	| Remove history file from data set if more then 1 file exists since it will
	| offset values for validation
	+---------------------------------------------------------------------SASDOC*;
	proc sql noprint;
	 select min(filedt) into: filedtmin
	 from qc_&practice. 
	 where filedt ne '' and pracid ne '';
	quit;
	
	proc sql noprint;
	 select count(*) into: filedtcnt
	 from qc_&practice.  
	 where filedt ne '' and pracid ne '';
	quit;	
	
	%put NOTE: filedtmin = &filedtmin. ;
	%put NOTE: filedtcnt = &filedtcnt. ;	
	
	proc summary data=qc_&practice. %if &filedtcnt. ne 1 %then %do; 
	                                  (where = (filedt ne "&filedtmin"))
	                                %end;;
	  class pracid filedt;
	  var memberid_fg dob_fg lname_fg fname_fg address1_fg zip_fg phone_fg proccd_fg diag1_fg npi_fg count;
	  output out=vMine2filedt_fgsum (drop = _type_ _freq_) sum=;
	run;

	data temp001;
	  set vMine2filedt_fgsum;
	  where pracid = "" and filedt = "";
		pbar_memberid = memberid_fg / count;
		pbar_dob = dob_fg / count;
		pbar_lname = lname_fg / count;
		pbar_fname = fname_fg / count;
		pbar_address1 = address1_fg / count;
		pbar_zip = zip_fg / count;
		pbar_phone = phone_fg / count;
		pbar_proccd = proccd_fg / count;
		pbar_diag1 = diag1_fg / count;
		pbar_npi = npi_fg / count;
		if pbar_memberid = . then pbar_memberid = 0;
		if pbar_dob = . then pbar_dob = 0;
		if pbar_lname = . then pbar_lname = 0;
		if pbar_fname = . then pbar_fname = 0;
		if pbar_address1 = . then pbar_address1 = 0;
		if pbar_zip = . then pbar_zip = 0;
		if pbar_phone = . then pbar_phone = 0;
		if pbar_proccd = . then pbar_proccd = 0;
		if pbar_diag1 = . then pbar_diag1 = 0;
		if pbar_npi = . then pbar_npi = 0;
		call symputx('pbar_memberid',pbar_memberid);
		call symputx('pbar_dob',pbar_dob);
		call symputx('pbar_lname',pbar_lname);
		call symputx('pbar_fname',pbar_fname);
		call symputx('pbar_address1',pbar_address1);
		call symputx('pbar_zip',pbar_zip);
		call symputx('pbar_phone',pbar_phone);
		call symputx('pbar_proccd',pbar_proccd);
		call symputx('pbar_diag1',pbar_diag1);
		call symputx('pbar_npi',pbar_npi);
	run;
	
	%let temp001_cnt=0;
	
	proc sql noprint;
	  select count(*) into: temp001_cnt
	  from temp001;
	quit;
	
	%if &temp001_cnt ne 0 %then %do;


	data vMine2filedt_fgsum (keep = pracid filedt memberid dob lname fname 
	                                address1 zip phone proccd diag1 npi);
	  set vMine2filedt_fgsum;
	  where pracid ne "" and filedt ne "";
		phat_memberid = memberid_fg / count;
		phat_dob = dob_fg / count;
		phat_lname = lname_fg / count;
		phat_fname = fname_fg / count;
		phat_address1 = address1_fg / count;
		phat_zip = zip_fg / count;
		phat_phone = phone_fg / count;
		phat_proccd = proccd_fg / count;
		phat_diag1 = diag1_fg / count;
		phat_npi = npi_fg / count;
		if phat_memberid = . then phat_memberid = 0;
		if phat_dob = . then phat_dob = 0;
		if phat_lname = . then phat_lname = 0;
		if phat_fname = . then phat_fname = 0;
		if phat_address1 = . then phat_address1 = 0;
		if phat_zip = . then phat_zip = 0;
		if phat_phone = . then phat_phone = 0;
		if phat_proccd = . then phat_proccd = 0;
		if phat_diag1 = . then phat_diag1 = 0;
		if phat_npi = . then phat_npi = 0;

		LCL_memberid = &pbar_memberid. - 3*sqrt((&pbar_memberid.*(1-&pbar_memberid.))/count);
		LCL_dob = &pbar_dob. - 3*sqrt((&pbar_dob.*(1-&pbar_dob.))/count);
		LCL_lname = &pbar_lname. - 3*sqrt((&pbar_lname.*(1-&pbar_lname.))/count);
		LCL_fname = &pbar_fname. - 3*sqrt((&pbar_fname.*(1-&pbar_fname.))/count);
		LCL_address1 = &pbar_address1. - 3*sqrt((&pbar_address1.*(1-&pbar_address1.))/count);
		LCL_zip = &pbar_zip. - 3*sqrt((&pbar_zip.*(1-&pbar_zip.))/count);
		LCL_phone = &pbar_phone. - 3*sqrt((&pbar_phone.*(1-&pbar_phone.))/count);
		LCL_proccd = &pbar_proccd. - 3*sqrt((&pbar_proccd.*(1-&pbar_proccd.))/count);
		LCL_diag1 = &pbar_diag1. - 3*sqrt((&pbar_diag1.*(1-&pbar_diag1.))/count);
		LCL_npi = &pbar_npi. - 3*sqrt((&pbar_npi.*(1-&pbar_npi.))/count);

		if LCL_memberid lt 0 then LCL_memberid = 0;
		if LCL_dob lt 0 then LCL_dob = 0;
		if LCL_lname lt 0 then LCL_lname = 0;
		if LCL_fname lt 0 then LCL_fname = 0;
		if LCL_address1 lt 0 then LCL_address1 = 0;
		if LCL_zip lt 0 then LCL_zip = 0;
		if LCL_phone lt 0 then LCL_phone = 0;
		if LCL_proccd lt 0 then LCL_proccd = 0;
		if LCL_diag1 lt 0 then LCL_diag1 = 0;
		if LCL_npi lt 0 then LCL_npi = 0;

		UCL_memberid = &pbar_memberid. + 3*sqrt((&pbar_memberid.*(1-&pbar_memberid.))/count);
		UCL_dob = &pbar_dob. + 3*sqrt((&pbar_dob.*(1-&pbar_dob.))/count);
		UCL_lname = &pbar_lname. + 3*sqrt((&pbar_lname.*(1-&pbar_lname.))/count);
		UCL_fname = &pbar_fname. + 3*sqrt((&pbar_fname.*(1-&pbar_fname.))/count);
		UCL_address1 = &pbar_address1. + 3*sqrt((&pbar_address1.*(1-&pbar_address1.))/count);
		UCL_zip = &pbar_zip. + 3*sqrt((&pbar_zip.*(1-&pbar_zip.))/count);
		UCL_phone = &pbar_phone. + 3*sqrt((&pbar_phone.*(1-&pbar_phone.))/count);
		UCL_proccd = &pbar_proccd. + 3*sqrt((&pbar_proccd.*(1-&pbar_proccd.))/count);
		UCL_diag1 = &pbar_diag1. + 3*sqrt((&pbar_diag1.*(1-&pbar_diag1.))/count);
		UCL_npi = &pbar_npi. + 3*sqrt((&pbar_npi.*(1-&pbar_npi.))/count);

		if UCL_memberid gt 1 then UCL_memberid = 1;
		if UCL_dob gt 1 then UCL_dob = 1;
		if UCL_lname gt 1 then UCL_lname = 1;
		if UCL_fname gt 1 then UCL_fname = 1;
		if UCL_address1 gt 1 then UCL_address1 = 1;
		if UCL_zip gt 1 then UCL_zip = 1;
		if UCL_phone gt 1 then UCL_phone = 1;
		if UCL_proccd gt 1 then UCL_proccd = 1;
		if UCL_diag1 gt 1 then UCL_diag1 = 1;
		if UCL_npi gt 1 then UCL_npi = 1;

		if phat_memberid lt LCL_memberid then do;
		  memberid = 1;
		end;
		else if phat_memberid gt UCL_memberid then do;
		  memberid = 2;
		end;
		else do;
		  memberid = 0;
		end;
		
		if phat_dob lt LCL_dob then do;
		  dob = 1;
		end;
		else if phat_dob gt UCL_dob then do;
		  dob = 2;
		end;
		else do;
		  dob = 0;
		end;		
		
		if phat_lname lt LCL_lname then do;
		  lname = 1;
		end;
		else if phat_lname gt UCL_lname then do;
		  lname = 2;
		end;
		else do;
		  lname = 0;
		end;
		
		if phat_fname lt LCL_fname then do;
		  fname = 1;
		end;
		else if phat_fname gt UCL_fname then do;
		  fname = 2;
		end;
		else do;
		  fname = 0;
		end;
		
		if phat_address1 lt LCL_address1 then do;
		  address1 = 1;
		end;
		else if phat_address1 gt UCL_address1 then do;
		  address1 = 2;
		end;
		else do;
		  address1 = 0;
		end;
		
		if phat_zip lt LCL_zip then do;
		  zip = 1;
		end;
		else if phat_zip gt UCL_zip then do;
		  zip = 2;
		end;
		else do;
		  zip = 0;
		end;		
		
		if phat_phone lt LCL_phone then do;
		  phone = 1;
		end;
		else if phat_phone gt UCL_phone then do;
		  phone = 2;
		end;
		else do;
		  phone = 0;
		end;
		
		if phat_proccd lt LCL_proccd then do;
		  proccd = 1;
		end;
		else if phat_proccd gt UCL_proccd then do;
		  proccd = 2;
		end;
		else do;
		  proccd = 0;
		end;		

		if phat_diag1 lt LCL_diag1 then do;
		  diag1 = 1;
		end;
		else if phat_diag1 gt UCL_diag1 then do;
		  diag1 = 2;
		end;
		else do;
		  diag1 = 0;
		end;
		
		if phat_npi lt LCL_npi then do;
		  npi = 1;
		end;
		else if phat_npi gt UCL_npi then do;
		  npi = 2;
		end;
		else do;
		  npi = 0;
		end;
		
	run;
	
	%end;

	data vMine2filedt_fgsumX (keep = filecount pracid);
	  set vMine2filedt_fgsum;
	  by pracid;
	  retain filecount;
	  if first.pracid then filecount = 1;
	  else filecount = filecount + 1;
	  if last.pracid;
	run;

	data fn_controlcharts_filedt;
	  merge vMine2filedt_fgsum  (in=a) 
	        vMine2filedt_fgsumX (in=b);
	  by pracid;
	run;

	proc sort data = fn_controlcharts_filedt;
	by descending filedt;
	run;

	data fn_controlcharts_filedt;
	 set fn_controlcharts_filedt (obs=1);
	 drop filecount;
	run;

	proc sort data = fn_controlcharts_filedt;
	  by pracid;
	run;

	proc transpose data =  fn_controlcharts_filedt 
                   out  = fn_controlcharts_filedt (rename=(pracid=practiceid _name_=data_element col1=fncc_indicator));
	  by pracid;
	run;
	
	data fn_controlcharts_filedt;
	 length flag_reason $20 ;
	 set fn_controlcharts_filedt;
	 if fncc_indicator = 1 then flag_reason='Lower Limit Issue';
	 else if fncc_indicator = 2 then flag_reason='Upper Limit Issue';
	run;

%mend dq_qualitycontrol_charts;
