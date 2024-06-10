
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_13
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the eclinical system practice data   
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
| 26AUG2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
|             
+-----------------------------------------------------------------------HEADER*/
 %macro vmine_pmsystem_13;

	
	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.( rename=(claimnum2 = claimnum linenum2=linenum encounterid2=encounterid));
	  length dob svcdt 8.;
	  format dob svcdt mmddyy10. submit dollar13.2 system $30. filename $50. source $1.  ;
	  set practice_&do_practice_id. ;	
      where proccd ne '';	

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
 		submit	 = submit2;
		dob 	 = input(dob2,mmddyy10.);
		svcdt 	 = datepart(svcdt2);
		system	 = "&system.";
		filename = put(MaxProcessID, kprocessid.);
		
		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
	    if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Diags       
		----------------------------------------------------------------------------SASDOC*;

		%*SASDOC--------------------------------------------------------------------------
		| Procedure Codes & Modifiers 
		----------------------------------------------------------------------------SASDOC*;

		%*SASDOC--------------------------------------------------------------------------
		| Place of Service
		----------------------------------------------------------------------------SASDOC*;
		if pos = '0' then pos = '';

		%*SASDOC--------------------------------------------------------------------------
		| Physicians
		----------------------------------------------------------------------------SASDOC*;
		if upin = 'N/A' then upin = '';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
	    if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
	    else memberid = ssn;

	
		%*SASDOC--------------------------------------------------------------------------
		| Claim and line number                               
		------------------------------------------------------------------------SASDOC*; 
	    claim_number	= claimnum*1;
        claimnum2 		= compress(claimnum,'{''}');
		line_number		= linenum * 1;
	    linenum2		= left(linenum); 
		encounter_id  	= encounterid * 1;
		encounterid2	= left(encounterid);
		client_key		= &client_id.;
		practice_id		= &practice_id.; 
		source='P';

		drop svcdt2 dob2 submit2 linenum claimnum encounterid;
	
		run;

 
%mend vmine_pmsystem_13;
