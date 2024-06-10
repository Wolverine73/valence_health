
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  pgf_hnautica.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load PGF data - HealthNautica           
|
| INPUT:    Health Nautica text file(historical)
|
| OUTPUT:   claims_&group dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 19MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created HealthNautica macro 
|
+-----------------------------------------------------------------------HEADER*/

%macro pgf_hnautica(group= );

	*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	--------------------------------------------------------------------------SASDOC*;	
	%macro lib;
	%if %upcase(&clientname) = NSAP %then %do;
		data _null_;
			call symput('hnautica_dir',"dir \\Fs\&clientname.\data\CI\PGF\HealthNautica\&group\Current_Extract\*.* /b");
			call symput('hnautica_fil2',"\\Fs\&clientname.\data\CI\PGF\HealthNautica\&group\Current_Extract\");
		run;
	%end;
	%else %do;
		data _null_;
			call symput('hnautica_dir',"dir \\fs\&clientname.\data\PGF\HealthNautica\&group\Current_Extract\*.* /b");
			call symput('hnautica_fil2',"\\fs\&clientname.\data\PGF\HealthNautica\&group\Current_Extract");
		run;
	%end;
	%mend;
	%lib;

    *SASDOC-------------------------------------------------------------------------
	| Read in text file                          
	|------------------------------------------------------------------------SASDOC*;
	filename indata pipe "&hnautica_dir";

	data raw(compress=yes drop=File_Extract filedate filedatefrom filedateto cnt);
		length fil2read $100. filename $22. filedate $12. filed $8. filedt filedtfrom filedtto 4. 
				system filedatefrom filedateto $10. pcpid $6.;
		format filedt filedtfrom filedtto mmddyy10.;
		infile indata truncover ;
		input File_Extract $100.;
		fil2read="&hnautica_fil2" || File_Extract;
		infile dummy filevar=fil2read truncover delimiter='|' dsd lrecl=1000 end=lastrec;
		do until (lastrec);
		Input
		cnt: 8.
		table :$upcase100.
		var1: $50.
		var2: $50.
		var3: $50.
		var4: $50.
		var5: $50.
		var6: $50.
		var7: $50.
		var8: $50.
		var9: $50.
		var10: $50.
		var11: $50.
		var12: $50.
		var13: $50.
		var14: $50.
		var15: $50.
		;
		retain filedate system pcpid;
			if index(table,"IPA DATA CAPTURE START") not in (.,0) then do;
				filedate=cats(substr(table,28,2)) || cats(substr(table,24,3)) || cats(substr(table,31,5));
				filedt = input(filedate,eurdfde9.);
				filedatefrom = cats(substr(table,49,10));
				filedtfrom = input(filedatefrom,mmddyy10.);
				filedateto = cats(substr(table,63,10));
				filedtto = input(filedateto,mmddyy10.);
				filename = cats(substr(file_extract,1,22));
				filed = cats(substr(filename,8,8));
			end;
			if index(table,"IPA DATA CAPTURE END") not in (.,0) then delete;
			system = 'HNAUTICA';
			pcpid = upcase(cats(substr(filename,1,6)));
		output;
		end;
	run;

	data header (drop= var1-var15);
		set raw;
		where  index(table,"IPA DATA CAPTURE START") not in (.,0);
	run;

	proc sort data=header nodupkey;
		by filename;
	run;

	data _null_;
		set header;
		by filedtto;
		if last.filedtto then do;
			call symput('filename_last',filename);
			call symput('practice',pcpid);
			call symput('system',system);
		end;
	run;

	%put &filename_last &practice &system ;

	title " Practice Name: &practice ";
	title2 " System: &system ";

	*SASDOC-------------------------------------------------------------------------
	| Create claims table                         
	|------------------------------------------------------------------------SASDOC*;
	data clms (compress=yes
				 keep = filename filed filedt filedtfrom filedtto system 
						claimnum patlinkid npi provlast provfirst tin
						svcdt _proccd proccd mod1 units pos diag1-diag4 submit);
		set raw;
		where table="SRVCDETAIL";
		 
		length 	claimnum npi $10. provlast $25. provfirst $15. tin $9. 
				svcdate $10. svcdt 4. diag1-diag4 $6. _proccd $10. proccd $5. mod1 $2.
				units 8. submit 8.  pos $2.; *unitstypeind $5. tos $2.;
		format svcdt mmddyy10. submit dollar20.2;

		claimnum 	 = upcase(cats(var1));
		patlinkid 	 = upcase(cats(var2));
		svcdate 	 = cats(var3);
		_proccd 	 = upcase(cats(var4));
		proccd  	 = upcase(substr(_proccd,1,5));
		*provlinkid  = upcase(cats(var5));
		npi			 = var5;
		provlast	 = upcase(cats(var6));
		provfirst	 = upcase(cats(var7));
		tin			 = compress(var8,'-');
		units 	 	 = var9;
		pos 		 = upcase(cats(var10));
		diag1 		 = upcase(cats(var11));
		diag2 		 = upcase(cats(var12));
		diag3 		 = upcase(cats(var13));
		diag4 		 = upcase(cats(var14));
		submit 		 = var15;

		svcdt = input(svcdate,mmddyy10.);
		if index(_proccd,'-') not in (.,0) then do;
			mod1 = cats(substr(_proccd,index(_proccd,'-') + 1,2));
		end;
	run;

	proc sort data=clms;
		by patlinkid;
	run;
	*SASDOC-------------------------------------------------------------------------
	| Create patient table                       
	|------------------------------------------------------------------------SASDOC*;
	data pat (compress = yes
			  keep = filename patlinkid ssn lname fname mname dob sex /*phone*/);
		set raw;
		where table = 'PATIENT';
		length patlinkid $10. ssn $9. lname $25. fname $15. mname $1. dob 4. sex $1.;
			   
		format dob mmddyy10.;

		patlinkid = upcase(cats(var1));
		ssn 	  = compress(cats(var2),'-');
		lname 	  = upcase(cats(var3));
		fname 	  = upcase(cats(var4));
		mname 	  = upcase(cats(var5));
		dob 	  = input(var6,mmddyy10.);
		sex 	  = upcase(cats(var7));
	run;


	proc sort data=pat nodupkey;
		by patlinkid;
	run;
	*SASDOC-------------------------------------------------------------------------
	| Create payor table                        
	|------------------------------------------------------------------------SASDOC*;
	data ins (compress = yes
			  keep = filename patlinkid payorname1 guarantortype payor_effdt payor_termdt);
	set raw;
		where table = 'PATSUBINS';
		length patlinkid $10. guarantortype $1. payorname1 $50.;
		format payor_effdt payor_termdt mmddyy10.; 
		patlinkid     = upcase(cats(var1));
		guarantortype = upcase(cats(var2));
		payorname1 	  = upcase(cats(var3));
		payor_effdt   = input(var4,mmddyy10.) ;
		payor_termdt  = input(var5,mmddyy10.) ;
	run;

	proc sort data=ins nodupkey out=ins2 (compress=yes);
		where guarantortype = 'P'; * SELECT PRIMARY INSURANCE ONLY;
		by patlinkid guarantortype payorname1 payor_effdt payor_termdt ;
	run;

	proc summary data=ins2 nway missing;
		class patlinkid payorname1 payor_effdt payor_termdt;
		output out=payorcheck (drop=_type_);
		proc print data=payorcheck (obs=1000);
	run;

	data ins2B ;
		set ins2;
		%let firstp = 200401;
		call symput('lastp',put(today(),yymmn6.));
	run;

	*create record for each member month;
	data ins3 (drop=effmonth termmonth i j);
		set ins2B;

		if payor_termdt = . then payor_termdt = today() + 365;

		effmonth=input(put(payor_effdt, yymmn6.), 6.);
		termmonth=input(put(payor_termdt+1, yymmn6.), 6.); *many termdts are the last day of the month;

		do i  = &firstp to &lastp;
		if i = &firstp then j=0;
		j=j+1;
		if mod(i,100)=13 then i = i+88;
		monthid = i ;

		if effmonth <= monthid < termmonth then output ins3;

		end;
	run;

	*SASDOC-------------------------------------------------------------------------
	| Merge claims and patient tables and validate npi and tin numbers                          
	|------------------------------------------------------------------------SASDOC*;
	data clms2A (compress=yes) patonly (compress=yes);
		merge clms (in=a)
			  pat  (in=b drop=filename);
		by patlinkid;
		length memberid $9. provlast $25. provfirst $15. provname $42. upin $6. npi provid $10. tin $9.;
		monthid = input(put(svcdt, yymmn6.), 6.);
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = '';
		else memberid = ssn;
		provname = cats(provlast) || ", " || cats(provfirst);

		if upcase("&clientname") = "Adventist" then do;
			if "&group" = "DILSHA" then upin = 'D14500';
			else if "&group" = "PERRAS" then upin = 'C42038';
			else if "&group" = "RIVPSY" then upin = 'D12786';
		end; else 
		if upcase("&clientname") = "NSAP" then do;
			if tin ne '364341856' then tin = '364341856';
			if provname = 'SONDHEIMER, STUART' then npi = '1164433785';
			provid = npi;
		end;

		if a then output clms2A;
		else if b and not a then output patonly;
	run;
	
	*SASDOC-------------------------------------------------------------------------
	| Merge claims and payor table                         
	|------------------------------------------------------------------------SASDOC*;
	proc sort data=clms2A out=clms2B;
		by patlinkid monthid;
	run;

	proc sort data=ins3 out=ins4;
		by patlinkid monthid;
	run;

	data clms2 (compress=yes);
		merge clms2B (in=a)
			  ins4  (in=b keep= patlinkid monthid payorname1);
		by patlinkid monthid;
		if a then output clms2;
	run;
	
	*SASDOC-------------------------------------------------------------------------
	|  Remove duplicates and output final dataset                         
	|------------------------------------------------------------------------SASDOC*;
	proc sort data=clms2;
		by memberid lname fname dob svcdt proccd mod1;
	run;

	data dups (compress=yes);
		set clms2;
		by memberid lname fname dob svcdt proccd mod1;
		if first.mod1 and last.mod1 then delete;
		else output;
	run;

	proc sort data=clms2 nodupkey out=hlthntc.claims_&group (drop=patlinkid);
		by memberid lname fname dob svcdt proccd mod1;
	run;

    *SASDOC--------------------------------------------------------------------------
	| Call SAS Macros - Create Data Quality Report                           
	|------------------------------------------------------------------------SASDOC*;

	%dq_report(client=&vmine_client_id., pgf_practice= hlthntc.claims_&group.);

%mend pgf_hnautica;
