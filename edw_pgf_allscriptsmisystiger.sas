
/*HEADER------------------------------------------------------------------------
|
| program:  edw_pgf_allscriptsmisystiger.sas
|
| location: M:\ci\programs\standardmacros
|
| purpose:  load pgf data - misys         
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
+-----------------------------------------------------------------------HEADER*/

%macro edw_pgf_allscriptsmisystiger;

%global DirectoryPath;
	
	*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	--------------------------------------------------------------------------SASDOC*;	
	data _null_;
		call symput('misys_dir',"dir \\fs\&client_name.\Data\CI\PGF\Auto\&group_id.\*.* /b");
		call symput('misys_fil2',"\\fs\&client_name.\Data\CI\PGF\Auto\&group_id.\");
		call symput('DirectoryPath',"\\fs\&client_name.\Data\CI\PGF\Auto\&group_id.\");
	run;

    %set_error_flag;
    %on_error(ACTION=ABORT);

	filename indata pipe "&misys_dir";

	*SASDOC-------------------------------------------------------------------------
	| Read in CSV files                          
	|------------------------------------------------------------------------SASDOC*;
	data claimraw(compress = yes);
	infile indata lrecl=300 truncover  DSD lrecl=2500 ;
	input multread $100.;
	length source $11.  filed $8. filename $10.;
	format svcdt mmddyy10.;

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
	   lname: $50.	
	   fname: $50.	
	   mname: $1.
	   address1: $50.
	   address2: $50.
	   city: $50.
	   state: $2.
	   zip: $12.	
	   _svcdt: $10.	
	   _diag1: $6.	
	   _diag2: $6.	
	   _diag3: $6.	
	   _proccd: $10.	
	   mod1:  $2.	
	   _pos:  $2.	
	  ;

	 provname = trim(provlast)||","||trim(provfirst);

	 source=scan(multread,-3,'. _ \');
	 filed =scan(multread,-2,'. _');
	 filename = multread;

       if index(_svcdt,'/') = 0 then
           svcdt = input(_svcdt,yymmdd10.);
       else svcdt = input(cats(substr(_svcdt,1,index(_svcdt," ") - 1)),mmddyy10.);

	output;
	end;

	run;

	data ci_start_date;
	  format start_date mmddyy10.  ;
	  set ciedw.client (where = (client_key=&client_id. ));
		  start_date=datepart(ci_start_date);	  
		  keep start_date;
	run;

	data claimraw;
	  if _n_ = 1 then set ci_start_date ;
         set claimraw;
		          practice_id = &practice_id.;
			  client_key = &client_id.;
			  if svcdt >= start_date ;
			  %edw_npi_cleansing_rules;
    run;

	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;
	data claims2 (compress=yes rename = _filed = filed
				  keep = system claimnum linenum _filed practice_id
						 ssn memberid lname fname mname dob sex phone address1 address2 city state zip client_key filename
						 provname npi upin tin svcdt diag1 diag2 diag3 proccd _proccd mod1 pos units submit payorid1 payorname1);
		set claimraw;

		length 	system $10. 
				ssn memberid $9. lname $50. fname $50. mname $1.   sex $1. phone $10. 
				provname $42. npi $10. upin $6. tin $9. 
				 diag1-diag3 $6. _proccd $10. proccd $5. mod1 $2. units submit 8. pos $2. 
				payorid1 $36. payorname1 $50. dob 8. _filed filed  $8. ;

			
		format  submit dollar13.2;
            format dob dob2 mmddyy10.;

		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
		else memberid = ssn;

	/*	npi_n = npi + 0;
		if npi_n in (&provider_list.); */

		proccd	 = upcase(trim(substr(_proccd,1,5)));

		if index(_dob,'/') = 0 then
                        dob2 = input(_dob,yymmdd10.);
            else dob2 = input(cats(substr(_dob,1,index(_dob," ") - 1)),mmddyy10.);


		*dob = input(cats(substr(_dob,1,index(_dob," ") - 1)),mmddyy10.);

		 
		*dob =  input(compress(_dob,'-'),yymmdd8.);
		*svcdt =  input(compress(_svcdt,'-'),yymmdd8.);


		*dob = dhms(dob2,0,0,0);
		dob = dob2;

		if sex in ("F","f") then sex = "F";
		else if sex in ("M","m") then sex = "M";
		else sex = "U";

		diag1 =  _diag1;	
		diag2 =  _diag2;	
		diag3 =  _diag3;	
		pos = _pos;
			
		system = 'MISYS';

		upin = '';

		units = .;
		submit = .;
		payorid1 = '';
		payorname1 = '';

		_filed = substr(filed,1,2)||"01"||substr(filed,3,4);

	run;
	
	data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id. ;
		set claims2;
		format provid $10.;
		length source mod2 $1. ;
		if provname = "," then provname = '';
		
		source = 'P';
            mod2 = '';
            provid=npi;

	run;

%mend edw_pgf_allscriptsmisystiger;
