
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_7
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the app med pm system practice data   
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
| 19AUG2011 - Valence Health - Clinical Integration 2.0.01
|			1. convert datetimestamp into raw numeric value for sorting.
|
| 18APR2012 - Winnie Lee - Clinical Integration 2.0.01
|			1. Renamed PATPLINKID to PATID for Release 1.2 H02
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_7;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.  ;
	  format moddtclaim svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.;
	  set practice_&do_practice_id. ;
	  
	  **if claim_sequence = 1 ;/** left condition as if to view the log, not in sql because it runs too long **/

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
		svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		moddtclaim=datepart(moddtclaim2);
		submit=submit2;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);

		moddt_ts=compress(put(moddt2,25.));
        moddtclaim_ts=compress(put(moddtclaim2,25.));

		
		%*SASDOC--------------------------------------------------------------------------
		| ID clean up Brackets                                        
		------------------------------------------------------------------------SASDOC*;
	    linenum=upcase(cats(compress(linenum,'{}')));
	    claimnum=upcase(cats(compress(claimnum,'{}')));
/*	    patlinkid=upcase(cats(compress(patlinkid,'{}')));*/
		patid=upcase(cats(compress(patid,'{}')));
	    id=upcase(cats(compress(id,'{}')));

		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
		if upcase(sex) = 'F' then sex='F';
	    else if upcase(sex) = 'M' then sex='M';
	    else sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member                                    
		------------------------------------------------------------------------SASDOC*;
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";

		%*SASDOC--------------------------------------------------------------------------
		| Mod1 and Mod2                                    
		------------------------------------------------------------------------SASDOC*;
		_proccd   	 = compress(_proccd,"-");

		if substr(_proccd,6,1) ne "" then do;
			if mod1 = "" then mod1 = cats(substr(_proccd,6,2));
			else if mod2 = "" then mod2 = cats(substr(_proccd,6,2));
		end;


		%*SASDOC--------------------------------------------------------------------------
		| Diagnosis Codes                                    
		------------------------------------------------------------------------SASDOC*;
		l1=length(diag1);
		l2=length(diag2);
		l3=length(diag3);
		l4=length(diag4);

		if l1=4 then diag1=compress(diag1,".");
		if l2=4 then diag2=compress(diag2,".");
		if l3=4 then diag3=compress(diag3,".");
		if l4=4 then diag4=compress(diag4,".");

		if diag1 = "" then do;
			diag1 = diag2;
			diag2 = diag3;
			diag3 = diag4;
			diag4 = "";
		end;
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';
		
		drop svcdt2 createdt2 moddt2 moddtclaim2 dob2 submit2 trans_type l1 l2 l3 l4;
	run;
	

%mend vmine_pmsystem_7;


