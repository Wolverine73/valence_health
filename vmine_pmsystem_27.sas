
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_27
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the altapoint pm system practice data   
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
| 20JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Commented out code_type because its no longer passed from vmine_view_27
|				since the filter logic is now in the standardized store procedure
|			2. Commented out claimnum and linenum type conversions since it's handled
|				in the standardized store procedure
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_27;

	*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	+------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.  /*(rename=(claimnum2=claimnum linenum2=linenum))*/;
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.;
	  set practice_&do_practice_id. ;
	  
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
		| Diagnosis code clean ups                        
		+------------------------------------------------------------------------SASDOC*;
		if diag4 in ("") and diag5 not in ("") then do;
			diag4= diag5;
			diag5= "";
		end;
		if diag3 in ("") and diag4 not in ("") then do;
			diag3= diag4;
			diag4= "";
		end;
		else if diag2 in ("") and diag3 not in ("") then do;
			diag2 = diag3;
			diag3 = "";
		end;
		else if diag1 in ("") and diag2 not in ("") then do;
			diag1 = diag2;
			diag2 = "";
		end;
	

		*SASDOC--------------------------------------------------------------------------
		| Modifier clean ups                         
		+------------------------------------------------------------------------SASDOC*;
		if mod3 in ("") and mod4 not in ("") then do;
			mod3= mod4;
			mod4= "";
		end;
		else if mod2 in ("") and mod3 not in ("") then do;
			mod2 = mod3;
			mod3 = "";
		end;
		else if mod1 in ("") and mod2 not in ("") then do;
			mod1 = mod2;
			mod2 = "";
		end;

		if length(_proccd) > 5 and index(_proccd,'-') in (.,0) then do;
			if mod1 = '' and mod2 = '' then mod1 = substr(_proccd,6,2);
			else if mod1 ne '' and mod2 = '' then mod2 = substr(_proccd,6,2);
		end;
		else if length(_proccd) > 5 and index(_proccd,'-') not in (.,0) then do;
			if mod1 = '' and mod2 = '' then mod1 = substr(_proccd,index(_proccd,'-') + 1,2);
			else if mod1 ne '' and mod2 = '' then mod2 = substr(_proccd,index(_proccd,'-') + 1,2);
		end;
		
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
	
		*SASDOC--------------------------------------------------------------------------
		| Client                          
		+------------------------------------------------------------------------SASDOC*;
/*		claim_number=claimnum;*/
/*        line_number=linenum;*/
/*		claimnum2=left(put(claimnum,8.));*/
/*        linenum2=left(put(linenum,8.));		*/
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';
		
		drop svcdt2 createdt2 moddt2 dob2 submit2 code_type /*claimnum linenum*/;
	run;
	

%mend vmine_pmsystem_27;


