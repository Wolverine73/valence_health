
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_11
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Ntierprise pm system practice data   
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

%macro vmine_pmsystem_11;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.;
	set practice_&do_practice_id. (rename=(claimnum=_claimnum linenum=_linenum));
	length svcdt moddt dob createdt 8. system $30. units submit 8. claimnum linenum $10. filename $40.;
	format svcdt moddt dob createdt mmddyy10. submit dollar13.2;	

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
		svcdt = datepart(svcdt2);
		moddt=datepart(moddt2);
		dob= datepart(dob2);
		createdt = datepart(createdt2);
		system="&system.";
		filename = put(MaxProcessID, kprocessid.);
		if address2="." then address2="";
		submit = submit2;

		upin = compress(upin,'.');

		%*SASDOC--------------------------------------------------------------------------
		| Diagnosis codes                                    
		------------------------------------------------------------------------SASDOC*;


		%*SASDOC--------------------------------------------------------------------------
		| Genders                                 
		------------------------------------------------------------------------SASDOC*; 
		if sex not in ('M','F') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';

		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		claimnum = cats(_claimnum);
        linenum  = cats(_linenum);
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';        
 

		drop svcdt2 moddt2 dob2 createdt2 _mod submit2;

	run;			     

%mend vmine_pmsystem_11;
