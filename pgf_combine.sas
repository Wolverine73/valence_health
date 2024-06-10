/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  pgf_combine.sas
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
| 25MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created PGF combine macro
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro pgf_combine(datapgf=);

 *SASDOC--------------------------------------------------------------------------
  | Combine all pgf datasets into one sas dataset
  ------------------------------------------------------------------------SASDOC*;

	data &datapgf.                              (compress=yes 
											   keep=system filed claimnum linenum 
											  	    tin npi upin provid provname provspec
												    memberid ssn lname fname mname dob sex phone address1 address2 city state zip
												    svcdt diag1-diag3 proccd mod1 majcat payorid1 payorname1
												    units submit pos);
	length claimnum $36. payorid1 $36. lname $25. units 8.  ;
	format dob svcdt mmddyy10.;
	set &pgfmem(obs=0);
	claimnum = '';
	payorid1 = '';
	units = .;
	lname = '';
	run;
	
	
	%do i = 1 %to &pgf_libname_total;
		proc append base=&datapgf force
					data=&&pgf_memname&i;
		run; 
	%end;
    

%mend pgf_combine;

 

