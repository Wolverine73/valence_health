
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_99
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Office Practicum pm system practice data   
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_99;


	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. (rename=(claimnum2=claimnum linenum2=linenum));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40.;
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
		if mname='.' then mname="";
		if pos='.' then pos="";
		upin="";

		%*SASDOC--------------------------------------------------------------------------
		| Mod                                    
		------------------------------------------------------------------------SASDOC*;
		mod1 = compress(cats(mod1),"'""+""`""[""]");
		mod2 = compress(cats(mod2),"'""+""`""[""]");

		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
		if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if memberid in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		claim_number=claimnum;
        line_number=linenum;
		claimnum2=left(put(claimnum,8.));
        linenum2=left(put(linenum,8.));		
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';   


		drop svcdt2 createdt2 moddt2 dob2 submit2 claimnum linenum; 
	run;

	
    

%mend vmine_pmsystem_99;
