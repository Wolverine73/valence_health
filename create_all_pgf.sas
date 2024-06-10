/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_all_pgf.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:  To combine pgf data 
|
| INPUT:    pgf sas datasets 
|
| OUTPUT:   temporary pgf sas dataset
|           
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 02JUN2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created PGF combine macro
|
|             
+-----------------------------------------------------------------------HEADER*/


%macro create_all_pgf;

*SASDOC--------------------------------------------------------------------------
 | Create Combined Uploader Data Set
 ------------------------------------------------------------------------SASDOC*; 

	libname uploader 'M:\NSAP\SASDATA\CI\CIETL\claims\PGF\uploader';
	
	%let byvars = %str(memberid svcdt lname fname dob proccd mod1  
                       descending filename units 
                        diag1-diag3  );
	proc sql noprint;
	  create table vtable as 
	  select *
	  from sashelp.vtable; 
	quit;

	
	data list (keep=libname memname); 
		set vtable;
		if (upcase(libname) in ("UPLOADER") and substr(upcase(memname),1,2) = "PM") or (upcase(libname) in ("LOADED")  and substr(upcase(memname),1,7) = "CLAIMS_");
/*		call execute("proc append base=pgf_uploader force data="||libname||"."||memname||";run;");  */
		call symput('template', MemName);
	run;

	data pgf_uploader;
	length 	   NPI: $10.   NPI2: $10.	TIN:	$9.  Provname:	    $40. memberid:		$9.  Phone: $11.	  DOB: 4.  Sex: $1.	  Lname: $35. Fname: $25. Address1:$50.  Address2:   $50.City:	$30.
   		State: $2.  Zip: $10. svcdt: 4.	diag1: $6.	 diag2: $6.	diag3: $6.	proccd: $5.	 mod1: $5. pos:  $2.	units:  $5. ;
		set uploader.&template. (obs=0);
	run;

	data list (keep=libname memname); 
		set sashelp.vtable;
		if (upcase(libname) in ("UPLOADER") and substr(upcase(memname),1,2) = "PM") or (upcase(libname) in ("LOADED")  and substr(upcase(memname),1,7) = "CLAIMS_");
		call execute("proc append base=pgf_uploader force data="||libname||"."||memname||";run;");  
		call symput('template', MemName);
	run;

	%let byvars = %str(memberid svcdt lname fname dob proccd mod1  
                       descending filename units 
                        diag1-diag3  );
	
	proc sort data=pgf_uploader;
		by &byvars.;
	run;


	%*SASDOC--------------------------------------------------------------------------
	| Create the final output dataset of the practice data and remove any
	| duplicates which may exist
	------------------------------------------------------------------------SASDOC*;
	data uploader.claims_uploader ( drop= visitnum claim_number line_number ) 
		 dups1;
		set pgf_uploader;
		by  &byvars. ;
		practiceid=1*scan(filename, 1, "-");
		if first.mod1 and last.mod1 then dupcount=.;
		else if first.mod1 then dupcount =0 ;
		else dupcount = 1;

		if upcase(units)='UNITS'  then units='';
		units_A=units*1;
		drop units;
		rename units_a=units;

		if first.mod1 then output uploader.claims_uploader;
		if dupcount ne . then output dups1;
	run;



*SASDOC--------------------------------------------------------------------------
 | Get All PGF Data
 ------------------------------------------------------------------------SASDOC*; 

	proc sql;
	  create table pgflist AS SELECT b.libname, b.memname
      from pgf_libnames AS a left join sashelp.vtable as b on a.libname = b.libname;
	  quit;
	
      data pgflist;
	  set pgflist;
	  where substr(memname,1,7) = 'CLAIMS_';
   run;	

   data _null_;
  		set pgflist end=eof;
  		i+1;
        ii=left(put(i,4.));
  	    call symput('allpgf'||ii,compress(libname||"."||memname));
		if eof then do;
			call symput('pgf_libname_total',ii);
			call symput('templatepgf',compress(libname||"."||memname));
		end;
	run;
	
 *SASDOC--------------------------------------------------------------------------
  | Combine all pgf datasets into one sas dataset
  ------------------------------------------------------------------------SASDOC*;

	data pgfall (compress=yes  keep=system filed claimnum linenum 
										   tin npi upin provid provname provspec
												    memberid ssn lname fname mname dob sex phone address1 address2 city state zip
												    svcdt diag1-diag3 proccd mod1 majcat payorid1 payorname1
												    units submit pos);
          set &templatepgf. (obs=0);
		  length claimnum $36. lname $25. units 8.  ;
		  format dob svcdt mmddyy10.;
		  claimnum = '';
		  payorid1 = '';
		  units = .;
		  lname = '';
	 run;

	 %do k = 1 %to &pgf_libname_total. ;
          %put NOTE: PGF_LIBNAME_TOTAL = &pgf_libname_total;
		  %put NOTE: TEMPLATEPGF = &templatepgf;
		  %put NOTE: ALLPGF = &allpgf&k;
              		 

	      
    	  Proc datasets  ;
			Append base= pgfall force
			Data= &&allpgf&k;
			
			Quit;	


    %end;

%mend create_all_pgf;

