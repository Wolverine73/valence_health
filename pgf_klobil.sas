
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  pgf_klobil.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load NSAP PGF data - klobilling           
|
| INPUT:    Text Files  
|
| OUTPUT:   claims_&group dataset 
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 20MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created KLOBil macro - NSAP only
+-----------------------------------------------------------------------HEADER*/

%macro pgf_klobil(group= );

*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	------------------------------------------------------------------------SASDOC*;	
	data _null_;
		call symput('klobil_dir'," dir \\fs\&clientname.\Data\CI\PGF\klobilling\Claims\*.*/b");
		call symput('klobil_fil',"\\fs\&clientname.\Data\CI\PGF\klobilling\Claims\");
	run;
	
*SASDOC--------------------------------------------------------------------------
	| Read in text files and output raw files to sas dataset
	------------------------------------------------------------------------SASDOC*;	

	filename filelist pipe "&klobil_dir";

	data klbllng.claimsraw_&group(compress=yes);
		length claimfilename $100 filed $8 source $8 npi $10.; 
		format source $upcase8.;

		infile filelist truncover;
		input claimfilename $100.;

		source = scan(claimfilename,2,'_');
		filed= substr((compress(claimfilename,'_')),14,8);
		filedate=input(filed,mmddyy8.);
		filename=compress(substr(claimfilename,1,26));

		claimfilename="&klobil_fil"||trim(claimfilename);

		infile dummy
		filevar=claimfilename truncover dsd firstobs=1 lrecl=700 end=lastrec;
		do until (lastrec);
		   
		format 	patdob svcdt filedate mmddyy10. billamt 10.2 npi $upcase10. upin $upcase6. 
				procmod $upcase2. payorname1 $upcase50.;
		length 	upin $6.;

		input
		claimnum: $5.
		itemnum: $1.
		_provid: $15.
		/*upin: $6.*/
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

		if _ERROR_=1 then error_message=1;

		drop d1 d2;

		output;
		end;
	run;

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data claims1 (keep=	system source filed claimnum itemnum filedate filename
					   	upin npi tin provid provlast provfirst provname 
					   	memberid ssn lname fname mi sex dob 
					   	diag1 diag1desc diag2 diag3 diag4 _proccd proccd procdesc mod1 units
					   	svcdt incmonthid 
		 			   	submit tos pos 
						payorname1-payorname3 payorid1-payorid3 patid1-patid3
		     			loaddt
				  compress=yes);
		set klbllng.claimsraw_&group;
		format  proccd $5. memberid ssn $9. svcdt dob loaddt mmddyy10. submit 10.2 tin $9. upin $6. _proccd $10.; 
		length units 8. upin $6. filed $8. source $8. _proccd $10. loaddt 4. provname $42. provid npi $10. lname $25. fname $15. claimnum payorid1 $36.; 
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
		diag1desc=put(diag1,$diag5cd.);
		_proccd=proccd;
		proccd=proccd;
		l_proccd=length(proccd);
		if l_proccd ne 3 then do; 
		procdesc=put(proccd,$cpt.);
		end;
		else procdesc=proccd;
		mod1=procmod;
		tos=tos;
		units=quantity;
		provlast = compress(provlast,',');
		provname = trim(provlast)||","||trim(provfirst);
		provid = _provid;
		UPIN=UPIN; 
		tin = provtaxid;
		pos=pos;
		source="&group";
		rel=patrel1;
		filed=filed;
		loaddt = today();
	run;
	
	*SASDOC-------------------------------------------------------------------------
	| Validation of npi and tin numbers                          
	|------------------------------------------------------------------------SASDOC*;

	proc sort data=prov.provider nodupkey out=prov (keep=upin tin npi provname practice);
	*where prvtermdt > today();
		by npi tin;
	run;

	proc print data=prov;
		title 'NSAP Provider Table';
	run;

	proc summary data=claims1 nway missing;
		class provname upin npi tin ;
		output out = clmprovcheck (drop=_type_ rename=_freq_=cnt);
		proc print data=clmprovcheck;
	run;

	data claims2 (compress=yes);
		set claims1;
		length provspec $2. provid $10.;
		if provname = "," then provname = '';

		if provtaxid ne '203621835' then provtaxid ='203621835';
		if tin ne '203621835' then tin ='203621835';

		if provname in ('CRETICOS,CATHERINE') then do;
			npi = '1356370233';
			if upin ne 'C38884' then upin = 'C38884';
		end;
		if provname in ('KULKA,MANDAVI')  then do;
			npi = '1770512659';
			if upin ne 'H96305' then upin='H96305';
		end;

		if npi = "" and upin not = " " then npi = put(upin,$upin_npi.);
		if provname = "" and npi ne " " then provname = put(npi,$ProvName.);

		provspec = put(npi,$provspec.);
		provid = npi;
	run;


	proc summary data=claims2 nway missing;
		class provname provspec upin npi tin ;
		output out = clmprovcheck2 (drop=_type_ rename=_freq_=cnt);
		proc print data=clmprovcheck2;
	run;

	*SASDOC-------------------------------------------------------------------------
	|  Remove duplicates and output final dataset                         
	|------------------------------------------------------------------------SASDOC*;

	proc sort data= claims2 out=clms (compress=yes);
		by memberid svcdt lname fname dob proccd mod1;
	run;

	data dups2 (compress=yes);
		set clms;
		by memberid svcdt lname fname dob proccd mod1;
		if first.mod1 and last.mod1 then delete;
	run;

	data claims3 (compress=yes);
		set clms;
		by memberid svcdt lname fname dob proccd mod1;
		if first.mod1 then duplicate='N';
		else do;
			duplicate='Y';
			billamt=0;
			quantity=0;
		end;
		incmonthid=put(svcdt,yymmn6.)*1;
	run;

	proc sort data=claims3(compress=yes);
		by memberid lname fname dob svcdt proccd mod1;
	run;

	data klbllng.claims_&group (compress=yes); 
		set claims3;
	run;

*SASDOC--------------------------------------------------------------------------
	| Call SAS Macros - Create Data Quality Report                           
	|------------------------------------------------------------------------SASDOC*;

	%dq_report(client=&vmine_client_id., pgf_practice= klbllng.claims_&group.);

%mend pgf_klobil;
