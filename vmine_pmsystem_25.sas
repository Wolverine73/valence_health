
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_25
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the advancedmd pm system practice data   
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
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_25;

	*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	+------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.  (rename=(claimnum2=claimnum linenum2=linenum));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.;
	  set practice_&do_practice_id. (rename=(npi2=_npi2));
	  
	  **if claim_sequence = 1 ;/** left condition as if to view the log, not in sql because it runs too long **/

		*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		+------------------------------------------------------------------------SASDOC*;
		svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		submit=submit2;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);
		claim_number=claimnumbr;
		line_number=linenumbr;
		
		*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		+------------------------------------------------------------------------SASDOC*;
		if upcase(sex) = 'F' then sex='F';
	    else if upcase(sex) = 'M' then sex='M';
	    else sex = 'U';

		*SASDOC--------------------------------------------------------------------------
		| Member                                    
		+------------------------------------------------------------------------SASDOC*;
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
		
		%*SASDOC--------------------------------------------------------------------------
		| Provider                                 
		------------------------------------------------------------------------SASDOC*;		
		format npi2 $10.;
		npi2=cats(put(_npi2,10.));

		*SASDOC--------------------------------------------------------------------------
		| POS - Logic
		|  1.  Reset POS to missing since POS is facility_uid and format of 2
		|  2.  Each practice needs to manually interpret 
		|  3.  Conditions need to be created for each practice for AdvancedMD
		+------------------------------------------------------------------------SASDOC*;
		pos="";
		%if &do_practice_id = 617 %then %do;
			if posshortname in ('OF') then pos = '11';
			else pos = '';
		%end;
		%else %if &do_practice_id = 667 %then %do;
			if posshortname = 'OFF' then pos = '11';
			else if posshortname in ('ARBOR','EECC') then pos = '31';
			else if posshortname = 'GLEN' then pos = '22';
			else if posshortname = 'ELNHU' then pos = '24';
			else if posshortname in ('CONH','COIL','AHCC') then pos = '32';
			else if posshortname = '' then pos = '';
		%end;
		%else %if &do_practice_id = 668 %then %do;
			if posshortname = 'PRACT' then pos = '11';
			else if posshortname = 'AHH' then pos = '22';
			else if posshortname = 'PER' then pos = '34';
			else if posshortname = '' then pos = '';
		%end;
		%else %if &do_practice_id = 674 %then %do;
			if posshortname = 'IFHA' then pos = '11';
			else if posshortname = '' then pos = '';
		%end;
		%else %if &do_practice_id = 713 %then %do;
			if posshortname = 'OFF' then pos = '11';
			else if posshortname IN ('M IN','H IN') then pos = '21';
			else if posshortname IN ('M OUT','WCC') then pos = '22';
			else if posshortname = 'HASC' then pos = '24';
			else if posshortname IN ('H ER','M ER') then pos = '23';
			else if posshortname = '' then pos = '';
		%end;
		%else %if &do_practice_id = 714 %then %do;
			if posshortname = 'OFF' then pos = '11';
			else if posshortname IN ('M IN','H IN') then pos = '21';
			else if posshortname IN ('M OUT','WCC') then pos = '22';
			else if posshortname = '' then pos = '';
		%end;
		%else %do;
			pos = '';
			%put ERROR: POS variables missing adjust code for this practice &do_practice_id. to map data.;
		%end;

	
		*SASDOC--------------------------------------------------------------------------
		| Client                          
		+------------------------------------------------------------------------SASDOC*;
		claim_number=claimnum;
        	line_number=linenum;
		claimnum2=left(put(claimnum,8.));
        	linenum2=left(put(linenum,8.));
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';
		
		drop _npi2 svcdt2 createdt2 moddt2 dob2 submit2 claimnum linenum;
	run;
	

%mend vmine_pmsystem_25;


