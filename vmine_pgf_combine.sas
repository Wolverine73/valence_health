/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  vmine_pgf_combine.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:  To combine vmine and pgf data 
|           
|
| INPUT:    combined vmine and combined pgf sas datasets 
|
| OUTPUT:   allclaims dataset
|           
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 24MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created Vmine and pgf combine macro
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pgf_combine(datapgf=,datavm=);
	
   *SASDOC--------------------------------------------------------------------------
   |  combine vmine and pgf data and remove manual and non-ipa providers 
   +------------------------------------------------------------------------SASDOC*;

	data all1(drop = filed);
		length filedt 8. practice $50. provid $10.;
		format filedt mmddyy8.;
		set &datavm. 
		    &datapgf.;
		filedt = input(filed,mmddyy8.);
		practice = put(npi,$provprac.);
		provid = npi;
		provtype = put(npi,$provtype.) ;
		if put(npi,$provyn.) = "Y";
		*if provtype in ('V','P');
	run;

	proc sort data=all1 out= dw.&allclaims_dataset(compress=yes);
		by memberid lname fname dob svcdt proccd mod1;
	run;
	
   *SASDOC--------------------------------------------------------------------------
   |  rename dataset for linking algorithim
   +------------------------------------------------------------------------SASDOC*;
	data dw.allclaims_&clientname. (compress=yes);
		set dw.&allclaims_dataset;
	run;

%mend vmine_pgf_combine;



