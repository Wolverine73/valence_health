/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  vmine_combine.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:  To combine vmine data 
|           
|
| INPUT:    vmine practice sas datasets 
|
| OUTPUT:   combined vmine temporary sas dataset
|           combined practice data for each pm system
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 24MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created Vmine combine macro
|
|             
+-----------------------------------------------------------------------HEADER*/
%macro vmine_combine(datavm=);


	*SASDOC--------------------------------------------------------------------------
    | Combine vmine practice data for each pm system
    +------------------------------------------------------------------------SASDOC*;
	%do i = 1 %to &libname_total. ;
	    data &&libname&i...vmine_&&system&i.._all_&logdate(compress=yes 
											        keep=system filename claimnum linenum
											   		ssn memberid lname fname dob sex address1 address2 city state zip phone
													provid upin npi tin provname 
													svcdt diag1-diag3 _proccd proccd mod1 pos units
													submit payorname1 payorid1);
		set &&libname&i...&&memname&i(obs=0);
       			
		%do j = 1 %to &&clmname_total&i;
		 	%put &&clmname&i&j;	
			%put &&clmname_total&i;

			proc append base=&&libname&i...vmine_&&system&i.._all_&logdate force 
				data=&&libname&i...&&clmname&i&j;
				run; 
			 

		%end;
		run;
	%end;

    *SASDOC--------------------------------------------------------------------------
    | Combine all vmine systems into one dataset
    +------------------------------------------------------------------------SASDOC*;

	data &datavm (compress=yes drop = _filed);
		length system $10.   _filed filed $8. practiceID 3. ;
		set
		%do i = 1 %to &libname_total;
			&&libname&i...vmine_&&system&i.._all_&logdate(in=&&system&i)
		%end;
		;
		%do i = 1 %to &libname_total;
			if &&system&i then system = "&system&i";
		%end;
		_filed = cats(cats(substr(filename,index(filename,'-')+1,8)));
		filed = cats(substr(_filed,5,2) || substr(_filed,7,2) || substr(_filed,1,4));
		practiceID = cats(substr(filename,1,index(filename,'-') - 1)) * 1;
	    
	run;

%mend vmine_combine;


