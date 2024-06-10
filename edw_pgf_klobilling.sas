
/*HEADER------------------------------------------------------------------------
|
| program:  edw_pgf_klobilling.sas
|
| location: M:\ci\programs\standardmacros
|
| purpose:  load nsap pgf data - klobilling           
|
| input:    text files  
|
| output:   claims2 and cistage datasets
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 20JAN2011 - Robyn Stellman  - Clinical Integration  1.0.01
|             Initiated
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
+-----------------------------------------------------------------------HEADER*/

%macro edw_pgf_klobilling;

%put NOTE: GROUP ID = &vlink_id.;
%put NOTE: PRACTICE ID = &practice_id.;
%put NOTE: filename = &filename.;

%global DirectoryPath;

*SASDOC--------------------------------------------------------------------------
| Create libnames based on client value and assigned formats
------------------------------------------------------------------------SASDOC*;	
%if "&filename." eq "" %then %do ;
		
	data _null_;
		call symput('klobil_dir'," dir \\fs\&client_name.\Data\CI\PGF\Auto\&practice_id.\*.*/b");
		call symput('klobil_fil2',"\\fs\&client_name.\Data\CI\PGF\Auto\&practice_id.\");
		call symput('DirectoryPath',"\\fs\&client_name.\Data\CI\PGF\Auto\&practice_id.\");
	run;		

%end;
%else %do;

	data _null_;
		call symput('klobil_dir',"dir %trim(&pmdir.)\*.* /b");
		call symput('klobil_fil2',"%trim(&pmdir.)\");
		call symput('DirectoryPath',"%trim(&pmdir.)\");
	run;    

     data _null_;
          format filedate mmddyy10.;
          file1="&filename";
	    fdate1 = substr(file1,5,8);
	    filedate = input(fdate1,yymmdd8.);
	    chkdate='01MAR2011'd;                      
          call symput('filedate',filedate);
	    call symput('chkdate',chkdate);
    run;        
            
%end;	

	%put NOTE: klobil_dir = &klobil_dir.;
	%put NOTE: klobil_fil2 = &klobil_fil2.;
	%put NOTE: directorypath = &directorypath.;
      %put NOTE: filedate = &filedate.; 

*SASDOC--------------------------------------------------------------------------
	| Read in text files and output raw files to sas dataset
	------------------------------------------------------------------------SASDOC*;	

	filename filelist pipe "&klobil_dir";

	data claimsraw_&do_practice_id.(compress=yes);
		length claimfilename $100 filed $8 npi $10.; 

		infile filelist truncover;
		input claimfilename $100.;

		filed= substr((compress(claimfilename,'_')),4,8);
		filedate=input(filed,mmddyy8.);
		filename=compress(substr(claimfilename,1,26));

		claimfilename="&klobil_fil2"||trim(claimfilename);

		
	  %if "&filename." ne ""  %then %do; 
        if claimfilename = "&klobil_fil2"||"&filename.";
	  %end;		

		infile dummy
	  %if filedate < &chkdate. %then %do;
		filevar=claimfilename truncover dsd firstobs=1 lrecl=700 end=lastrec;
		do until (lastrec);
		   
		format 	patdob svcdt filedate mmddyy10. billamt 10.2 npi $upcase10. upin $upcase6. 
				procmod $upcase2. payorname1 $upcase50.;
		length 	upin $6. provname $42.;

		input
		claimnum: $5.
		itemnum: $1.
		_provid: $15.
		npi: $10.
		provtaxid: $9.
		provlast: $25.
		provfirst: $15.
		payorid1: $9.							
		payorname1: $35.
		payorEDI1: $5.	
		instype1: $2.
		patrel1: $2.
		patid1: $19.
		payorid2: $9.
		payorname2: $35.
		payorEDI2: $5.
		instype2: $2.
		patrel2: $2.							
		patid2: $19.
		payorid3: $9.							
		payorname3: $35.
		payorEDI3: $5.
		instype3: $2.
		patrel3: $2.
		patid3: $19.
		patssn: $9.
		patlast: $35.
		patfirst: $15.							
		patmid: $1.
		patdob : mmddyy10.						
		patsex: $1.
		tos: $1. 
		svcdt:  mmddyy10.
		proccd: $5.
		procmod: $2.
		quantity: 3.  
		billamt: 10.
		_diag1: $6.	
		_diag2: $6.
		_diag3: $6.
		_diag4: $6.
		_diag5: $6.
		pos: $2.;

		upin = '';

	%end;
	  %else %do;
		filevar=claimfilename truncover dsd delimiter="09"x firstobs=1 lrecl=500 end=lastrec;	
			do until (lastrec);
		   
		format  patdob svcdt filedate mmddyy10. billamt 10.2 npi $upcase10. upin $upcase6. 
				procmod $upcase2. payorname1 $upcase50.;
		length 	upin $6. provname $42. claimnum $5.;

		input 
		
	claimnum: $5.
		itemnum: $1.
		_provid: $15.
		npi: $10.
		provtaxid: $9.
		provlast: $25.
		provfirst: $15.
		payorid1: $9.							
		payorname1: $35.
		payorEDI1: $5.	
		instype1: $2.
		patrel1: $2.
		patid1: $19.
		payorid2: $9.
		payorname2: $35.
		payorEDI2: $5.
		instype2: $2.
		patrel2: $2.							
		patid2: $19.
		payorid3: $9.							
		payorname3: $35.
		payorEDI3: $5.
		instype3: $2.
		patrel3: $2.
		patid3: $19.
		patssn: $9.
		patlast: $35.
		patfirst: $15.							
		patmid: $1.
		patdob : mmddyy10.						
		patsex: $1.
		tos: $1. 
		svcdt:  mmddyy10.
		proccd: $5.
		procmod: $2.
		quantity: 3.  
		billamt: 10.
		_diag1: $6.	
		_diag2: $6.
		_diag3: $6.
		_diag4: $6.
		_diag5: $6.
		pos: $2.;
		upin = '';
      %end; 

		if index(_diag1,'.') = 4 then diag1=_diag1;
		else if trim(substr(_diag1,1,1)) in ('0','1','2','3','4','5','6','7','8','9','E','V') then do;
			_diag1=compress(_diag1,' ');
			if length(_diag1)>3 then do;
				d1=trim(substr(_diag1,1,3));
				d2=trim(substr(_diag1,4));
			end;
			else if length(_diag1)<=3 then diag1=_diag1;
			if d1 ne "" and d2 ne "" then diag1=trim(d1)||"."||trim(d2);
			else diag1=compress(_diag1,' ');
		end;	
		else do;
			diag1=compress(_diag1,' ');
		end;

		if index(_diag2,'.') = 4 then diag2=_diag2;
		else if trim(substr(_diag2,1,1)) in ('0','1','2','3','4','5','6','7','8','9','E','V') then do;
			_diag2=compress(_diag2,' ');
			if length(_diag2)>3 then do;
				d1=trim(substr(_diag2,1,3));
				d2=trim(substr(_diag2,4));
			end;
			else if length(_diag2)<=3 then diag2=_diag2;
			if d1 ne "" and d2 ne "" then diag2=trim(d1)||"."||trim(d2);
			else diag2=compress(_diag2,' ');
		end;	
		else do;
			diag2=compress(_diag2,' ');
		end;

		if index(_diag3,'.') = 4 then diag3=_diag3;
		else if trim(substr(_diag3,1,1)) in ('0','1','2','3','4','5','6','7','8','9','E','V') then do;
			_diag3=compress(_diag3,' ');
			if length(_diag3)>3 then do;
				d1=trim(substr(_diag3,1,3));
				d2=trim(substr(_diag3,4));
			end;
			else if length(_diag3)<=3 then diag3=_diag3;
			if d1 ne "" and d2 ne "" then diag3=trim(d1)||"."||trim(d2);
			else diag3=compress(_diag3,' ');
		end;	
		else do;
			diag3=compress(_diag3,' ');
		end;

		if index(_diag4,'.') = 4 then diag4=_diag4;
		else if trim(substr(_diag4,1,1)) in ('0','1','2','3','4','5','6','7','8','9','E','V') then do;
			_diag4=compress(_diag4,' ');
			if length(_diag4)>3 then do;
				d1=trim(substr(_diag4,1,3));
				d2=trim(substr(_diag4,4));
			end;
			else if length(_diag4)<=3 then diag4=_diag4;
			if d1 ne "" and d2 ne "" then diag4=trim(d1)||"."||trim(d2);
			else diag4=compress(_diag4,' ');
		end;	
		else do;
			diag4=compress(_diag4,' ');
		end;

		if index(_diag5,'.') = 4 then diag5=_diag5;
		else if trim(substr(_diag5,1,1)) in ('0','1','2','3','4','5','6','7','8','9','E','V') then do;
			_diag5=compress(_diag5,' ');
			if length(_diag5)>3 then do;
				d1=trim(substr(_diag5,1,3));
				d2=trim(substr(_diag5,4));
			end;
			else if length(_diag5)<=3 then diag5=_diag5;
			if d1 ne "" and d2 ne "" then diag5=trim(d1)||"."||trim(d2);
			else diag5=compress(_diag5,' ');
		end;	
		else do;
			diag5=compress(_diag5,' ');
		end;

		provlast = compress(provlast,',');
		provname = trim(provlast)||","||trim(provfirst);

		if _ERROR_=1 then error_message=1;

		drop d1 d2;

		output;
		end;
	run;
/*
	data ci_start_date;
	  format start_date mmddyy10.  ;
	  set ciedw.client (where = (client_key=&client_id. ));
		  start_date=datepart(ci_start_date);	  
		  keep start_date;
	run;

	data claimsraw_&do_practice_id.;
	  if _n_ = 1 then set ci_start_date ;
         set claimsraw_&do_practice_id;
		          practice_id = &do_practice_id;
			  client_key = &client_id;
			  if svcdt >= start_date ;
			  %edw_npi_cleansing_rules;
    run;
*/

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data claims2 (keep=	system filed claimnum itemnum filedate filename practice_id
					   	upin npi tin provid provlast provfirst provname 
					   	memberid ssn lname fname mname mi sex dob 
					   	diag1 diag2 diag3 diag4 _proccd proccd mod1 mod2 units
					   	svcdt incmonthid 
		 			   	submit tos pos 
						payorname1-payorname3 payorid1-payorid3 patid1-patid3
		     			loaddt address1 address2 city state phone zip client_key source );
		set claimsraw_&do_practice_id;
		format  proccd $5. memberid ssn $9. svcdt dob loaddt mmddyy10. submit 10.2 tin $9. upin $6. _proccd $10.; 
		length units 8. upin $6. filed $8. mod2 source $1. _proccd $10. loaddt 4. provid npi $10. lname $25. fname $15. 
                 address1 $50. address2 $50. city $50. state $2. zip $12. phone $20. mname $1.; 
		
	/*	npi_n = npi+0;
		if npi_n in (&provider_list.); */

	      system="KLOBILLING";
		claimnum=claimnum;
		itemnum=itemnum;
		lname=patlast;
		fname=patfirst;
		mi=patmid;
		sex=patsex;
		dob=patdob;
		ssn=compress(patssn,"-");
		memberid=ssn;
		if memberid in ("","0","00","000","0000","00000","000000","0000000","00000000","000000000") then memberid="";
		submit = billamt; 
		svcdt=svcdt;
		incmonthid=incmonthid;
		diag1=diag1;
		diag2=diag2;
		diag3=diag3;
		diag4=diag4;
                client_key=&client_id.;

		_proccd=proccd;
		proccd=proccd;
		l_proccd=length(proccd);
		if l_proccd ne 3 then do; 
		mname = mi;

		end;
		else procdesc=proccd;
		mod1=procmod;
		tos=tos;
		units=quantity;
		provlast = compress(provlast,',');
		provid = _provid;
		UPIN=UPIN; 
		pos=pos;
		rel=patrel1;
		filed=filed;
		loaddt = today();
		address1 = '';
		address2 = '';
		city = '';
		state = '';
		phone = '';
		zip = '';
		source = 'P';
		mod2 = ''; 
		if provname = "," then provname = '';
		client_key = &client_id.;
		practice_id = &do_practice_id.;
		practice_key = &vlink_id.;
	run;
	

	*SASDOC-------------------------------------------------------------------------
	|  Remove duplicates and output final dataset                         
	|------------------------------------------------------------------------SASDOC*;
	proc sort data= claims2 ;
		by &byvars0;
	run;

	data practice_&do_practice_id. ;
	  format provid $10.;
		set claims2;
		by &byvars0;
		if first.mod2 then duplicate='N';
		else do;
			duplicate='Y';
			billamt=0;
			quantity=0;
		end;
		incmonthid=put(svcdt,yymmn6.)*1;
		provid=npi; 
	run;
	
	proc sort data=practice_&do_practice_id.;
	  by &byvars0;
	run;


%mend edw_pgf_klobilling;
