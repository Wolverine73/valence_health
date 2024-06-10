
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_54
|
| location: \\Sas2\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the idx pm system practice data   
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

%macro vmine_pmsystem_54;


	*SASDOC--------------------------------------------------------------------------
	| Diagnosis Function
	+------------------------------------------------------------------------SASDOC*;
		proc fcmp outlib=sasuser.userfuncs.mymath;
			FUNCTION getdiagcd(dx1 $) $ 6;
			diag='';
			if index(dx1,'.') in (4,5) then diag=dx1;
			else if trim(substr(dx1,1,1)) in ('0','1','2','3','4','5','6','7','8','9','V') then do;
				dx1=compress(dx1,' ');
				if length(dx1)>3 then do;
					d1=trim(substr(dx1,1,3));
					d2=trim(substr(dx1,4));
				end;
				else if length(dx1)<=3 then diag=dx1;
				if d1 ne "" and d2 ne "" then diag=trim(d1)||"."||trim(d2);
				else diag=dx1;
			end;
			else if trim(substr(dx1,1,1)) in ('E') then do;
				dx1=compress(dx1,' ');
				if length(dx1) > 4 then do;
					d1 = trim(substr(dx1,1,4));
					d2 = trim(substr(dx1,5));
				end;
				else if length(dx1) <= 4 then diag = dx1;
				if d1 ne '' and d2 ne '' then diag = trim(d1) || '.' || trim(d2);
				else diag=dx1;
			end;
			else do;
				diag=compress(dx1,' ');
			end;
			return(diag);
			endsub;
			run;

	*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	+------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. (rename=(claimnum2=claimnum linenum2=linenum));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.
	         memberid ssn $9. ;
	  set practice_&do_practice_id. (rename=(ssn=ssn2 memberid=memberid2 phone=phone2 upin=upin2
	                                         diag1=d1 diag2=d2 diag3=d3 diag4=d4));
	  
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
		
		*SASDOC--------------------------------------------------------------------------
		| DX                                  
		+------------------------------------------------------------------------SASDOC*;		
		diag1=getdiagcd(cats(d1));
		diag2=getdiagcd(cats(d2));
		diag3=getdiagcd(cats(d3));
		diag4=getdiagcd(cats(d4));
		
		*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		+------------------------------------------------------------------------SASDOC*;
		if upcase(sex) = 'F' then sex='F';
	    else if upcase(sex) = 'M' then sex='M';
	    else sex = 'U';
	    
		*SASDOC--------------------------------------------------------------------------
		| Provider                                    
		+------------------------------------------------------------------------SASDOC*;
		format upin $6.;
		upin=cats(upin2);

		*SASDOC--------------------------------------------------------------------------
		| Member                                    
		+------------------------------------------------------------------------SASDOC*;
		mname=compress(mname,'.');
		memberid=put(left(memberid2),9.);
		ssn=put(left(ssn2),9.);
		if ssn ='.' then ssn='';
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";

		*SASDOC--------------------------------------------------------------------------
		| Phone                                    
		+------------------------------------------------------------------------SASDOC*;
		format phone $10.;
		phone=cats(phone2);

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
		
		drop casenum visitnum patid phone2 upin2 svcdt2 createdt2 moddt2 dob2 submit2 memberid2 ssn2 d1-d4 claimnum linenum;
	run;
	

%mend vmine_pmsystem_54;
