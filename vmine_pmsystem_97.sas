
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_97
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Medinformatix pm system practice data   
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
| 31AUG2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
|             
+-----------------------------------------------------------------------HEADER*/


%macro vmine_pmsystem_97;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.(rename=(claimnum2=claimnum linenum2=linenum ));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. claimnum2 linenum2 $8. ssn memberid $9.;
	  set practice_&do_practice_id. ;	 

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
		svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		submit=submit2;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);

		%*SASDOC--------------------------------------------------------------------------
		| Missing values for variables                                
		------------------------------------------------------------------------SASDOC*;
		if memberid='.' then memberid="";
		if ssn='.' then ssn="";
		if mname='.' then mname="";
		if pos='.' then pos="";
		if address1='.' then address1="";
		if address2='.' then address2="";
		if state='.' then state="";

		%*SASDOC--------------------------------------------------------------------------
		| Diags       
		------------------------------------------------------------------------SASDOC*;
		if diag1="     ." then diag1 = "";
		if diag2="     ." then diag2 = "";
		if diag3="     ." then diag3 = "";
		if diag4="     ." then diag4 = "";
		if diag1="000000" then diag1 = "";
		if diag2="000000" then diag2 = "";
		if diag3="000000" then diag3 = "";
		if diag4="000000" then diag4 = "";
		if index(diag1,'.')=4 and substr(diag1,5,2)="" then diag1=compress(diag1,'.');
		if index(diag2,'.')=4 and substr(diag2,5,2)="" then diag2=compress(diag2,'.');
		if index(diag3,'.')=4 and substr(diag3,5,2)="" then diag3=compress(diag3,'.');
		if index(diag4,'.')=4 and substr(diag4,5,2)="" then diag4=compress(diag4,'.');	

		%*SASDOC--------------------------------------------------------------------------
		| Proccd, Pos and Mod       
		------------------------------------------------------------------------SASDOC*;

		pos	=  compress(pos,"'""+""`""[""]");
		
		if substr(_proccd,1,2) = 'LV' and (length(_proccd) > 5) then do;
			proccd = cats(substr(_proccd,2,5));
		end; else 
		if substr(_proccd,1,1) = 'S' and (length(_proccd) > 5) then do;
			proccd = cats(substr(_proccd,2,5));
		end; else do;
			proccd = cats(substr(_proccd,1,5));
			if mod1 = '' and (length(_proccd) > 6) then mod1 = substr(_proccd,6,2);
			if mod2 = '' and (length(_proccd) > 8) then mod2 = substr(_proccd,8,2);
		end;


		mod1 = compress(cats(mod1),"'""+""`""[""]");
		mod2 = compress(cats(mod2),"'""+""`""[""]");
		if compress(mod1)='.' then mod1 = '';
		if compress(mod2)='.' then mod2 = ''; 


			
		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
		if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID and SSN                                
		------------------------------------------------------------------------SASDOC*;
		if kpracticeid = 378 then do; *Adventist practice;
			if pssn ne '' then ssn = pssn;
			else if pssn = '' and gssn ne '' and lname = glname and fname = gfname then ssn = gssn;
			else ssn = '';
		end;

		else if kpracticeid in (366,393,449,493) then do; *PHS practices;
			if gssn ne '' then ssn = gssn;

			else if pssn ne '' then ssn = pssn;
			else ssn = '';
		end;
	

        if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
	    else memberid = ssn;

		%*SASDOC--------------------------------------------------------------------------
		| Payor                                    
		------------------------------------------------------------------------SASDOC*;
		
		if payorname1='.' then payorname1='';

		
		%*SASDOC--------------------------------------------------------------------------
		| claim and line number                          
		------------------------------------------------------------------------SASDOC*;       
		claimnum2=left(put(claimnum,8.));
        linenum2=left(put(linenum,8.));
		claim_number=claimnum;
        line_number=linenum;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';
		
		
		if substr(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9') then output;

		drop casenum visitnum svcdt2 createdt2 moddt2 dob2 submit2 claimnum linenum gssn pssn  ;
	run;




%mend vmine_pmsystem_97;

