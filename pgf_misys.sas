
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  pgf_misys.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load PGF data - Misys         
|
| INPUT:    Misys CSV files
|
| OUTPUT:   claims_&group dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 19MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created Misys macro 
+-----------------------------------------------------------------------HEADER*/

%macro pgf_misys(group= );
	
	*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	--------------------------------------------------------------------------SASDOC*;	
	data _null_;
		call symput('misys_dir',"dir \\fs\&clientname.\Data\CI\PGF\Misys\&group.\*.* /b");
		call symput('misys_fil2',"\\fs\&clientname.\Data\CI\PGF\Misys\&group.\");
	run;

	filename indata pipe "&misys_dir";

	*SASDOC-------------------------------------------------------------------------
	| Read in CSV files                          
	|------------------------------------------------------------------------SASDOC*;
	data claimraw(compress = yes);
	infile indata lrecl=300 truncover  DSD lrecl=2500 ;
	input multread $100.;
	length source $11.  filed $8.;

	fil2read="&misys_fil2" ||multread;
	infile dummy filevar = fil2read missover dsd lrecl=2500 end=lastrec firstobs = 2;
	do until (lastrec);

		input
	 
	   claimnum: $36.	
	   linenum: $36.	
	   npi:	$10.
	   provlast: $35.	
	   provfirst: $25.	
	   practiceid: $15.	
	   practicename: $25.	
	   ssn: $9.
	   phone:$10.
	   _dob: $10.
	   sex:	$1.
	   lname: $25.	
	   fname: $15.	
	   mname: $1.
	   address1: $50.
	   address2: $50.
	   city: $20.
	   state: $2.
	   zip: $10.	
	   _svcdt: $10.	
	   _diag1: $10.	
	   _diag2: $10.	
	   _diag3: $10.	
	   _proccd: $10.	
	   mod1:  $2.	
	   _pos:  $2.	
	  ;

		source=scan(multread,-3,'. _ \');
		filed =scan(multread,-2,'. _');
		filename=multread;




	output;
	end;

	run;

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data claims (compress=yes rename = _filed = filed
				  keep = system claimnum linenum _filed
						 ssn memberid lname fname mname dob _dob _svcdt sex phone address1 address2 city state zip
						 provname npi upin tin svcdt diag1 diag2 diag3 proccd _proccd mod1 pos units submit payorid1 payorname1);
		set claimraw;

		length 	system $10. 
				ssn memberid $9. lname $25. fname $15. mname $1.   sex $1. phone $10. 
				provname $42. npi $10. upin $6. tin $9. 
				 diag1-diag3 $6. _proccd $10. proccd $5. mod1 $2. units submit 8. pos $2. 
				payorid1 $36. payorname1 $50. dob svcdt 8. _filed filed  $8.;

			
		format dob svcdt mmddyy10. submit dollar13.2;

		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
		else memberid = ssn;

		proccd	 = upcase(trim(substr(_proccd,1,5)));

		provname = trim(provlast)||","||trim(provfirst);

		if index(_svcdt,'/') = 0 then svcdt = input(_svcdt, yymmdd10.);
	   	else svcdt = input(cats(substr(_svcdt,1,index(_svcdt," ") - 1)),mmddyy10.);

		if index(_dob,'/') =0 then dob =  input(_dob,yymmdd10.);
	   	else dob = input(cats(substr(_dob,1,index(_dob," ") - 1)),mmddyy10.);


		if sex in ("F","f") then sex = "F";
		else if sex in ("M","m") then sex = "M";
		else sex = "U";

		diag1 =  _diag1;	
		diag2 =  _diag2;	
		diag3 =  _diag3;	
		pos = _pos;
			
		system = 'MISYS';

		upin = '';
		tin = '';
		units = .;
		submit = .;
		payorid1 = '';
		payorname1 = '';

		_filed = substr(filed,1,2)||"01"||substr(filed,3,4);

	run;
	
	*SASDOC-------------------------------------------------------------------------
	| Validation of npi and tin numbers                          
	|------------------------------------------------------------------------SASDOC*;

	proc sort data=prov.provider nodupkey out=prov (keep=upin tin npi provname practice);
	*where prvtermdt > today();
		by npi tin;
	run;

	proc print data=prov;
	run;

	proc summary data=claims nway missing;
		class provname upin npi tin ;
		output out = clmprovcheck (drop=_type_ rename=_freq_=cnt);
		proc print data=clmprovcheck;
	run;


	data claims2 (compress=yes);
		set claims;
		length provspec $2. provid $10.;
		if provname = "," then provname = '';

		if tin ne '364117454' then tin = '364117454';
		if provname in ('GIDRON,ADI') then do;
			if upin ne 'I74156' then upin = 'I74156';
		end;
		if provname in ('MURRAY LAW MD,TERESA') then do;
			if upin ne 'E98940' then upin = 'E98940';
		end;
		if provname in ('GILMAN MD,ALAN') then do;
			if upin ne 'C44179' then upin = 'C44179';
		end;
		if provname in ('MALHOTRA MD,RAJAT') then do;
			if upin ne 'H50838' then upin = 'H50838';
		end;

		provspec = put(npi,$provspec.);
		provid = npi;
	run;

	proc summary data=claims2 nway missing;
		class  provname provspec tin npi upin ;
		output out=provcheck (drop=_type_ rename=_freq_=cnt compress=yes);
		proc print data=provcheck;
		title 'Check Provider Formats';
	run;

	*SASDOC-------------------------------------------------------------------------
	|  Remove duplicates and output final dataset                         
	|------------------------------------------------------------------------SASDOC*;

	proc sort data = claims2;
		by memberid svcdt lname fname dob proccd mod1;
	run;

	data misys.claims_&group. (compress=yes) 
		 dups (compress=yes);
		set claims2;
		by memberid svcdt lname fname dob proccd mod1;

		if first.mod1 and last.mod1 then dupcount=.;
		else if first.mod1 then dupcount =0 ;
		else dupcount = 1;

		if first.mod1 then output  misys.claims_&group.;
		if dupcount ne . then output dups;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Call SAS Macros - Create Data Quality Report                           
	|------------------------------------------------------------------------SASDOC*;

	%dq_report(client=&vmine_client_id., pgf_practice= misys.claims_&group.);

%mend pgf_misys;
