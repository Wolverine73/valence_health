
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_9
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the american medical software pm system practice data   
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

%macro vmine_pmsystem_9;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. ;
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1. ;
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
		| Reformat missing values                                     
		------------------------------------------------------------------------SASDOC*;		
		if mname='.' then mname="";
		if pos='.' then pos="";
		if mod1='.' then mod1='';
		if mod2='.' then mod2='';
		if mod3='.' then mod3='';
		if mod4='.' then mod4='';
		if diag1='.' then diag1='';
		if diag2='.' then diag2='';
		if diag3='.' then diag3='';
		if diag4='.' then diag4='';
		if address1='.' then address1='';
		if address2='.' then address2='';


		%*SASDOC--------------------------------------------------------------------------
		| Mod       
		------------------------------------------------------------------------SASDOC*;
		if mod3 = "" and mod4 ne "" then do;
			mod3 = mod4;
			mod4 = "";
		end;
		if mod2 = "" and mod3 ne "" then do;
			mod2 = mod3;
			mod3 = "";
		end;
	    if mod1="" and mod2 ne "" then do;
		  mod1 = mod2;
		  mod2 = "";
	    end;


		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
	    if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
	    if ssn='.' then ssn='';
	    if ssn in ('.','','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";

	    
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;	    
		claim_number=claimnum*1;
        line_number=linenum*1;  
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';


		drop svcdt2 createdt2 moddt2 dob2 submit2;
	run;
	

%mend vmine_pmsystem_9;
