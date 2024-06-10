/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_31
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the ASPC system practice data   
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
| 19JAN2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

 %macro vmine_pmsystem_31;

	
	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.;
	length dob svcdt moddt 8.;
	format dob svcdt moddt mmddyy10. submit dollar13.2 system $30. filename $50. source $1.  ;
	set practice_&do_practice_id. ;	

	%*SASDOC--------------------------------------------------------------------------
	| Reformat dates and dollars and other                        
	------------------------------------------------------------------------SASDOC*;
	submit	 = submit2;
	dob 	 = datepart(dob2);
	svcdt 	 = datepart(svcdt2);
	moddt	 = datepart(moddt2);
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

	%*SASDOC--------------------------------------------------------------------------
	| Physicians
	----------------------------------------------------------------------------SASDOC*;

	%*SASDOC--------------------------------------------------------------------------
	| Member ID                                 
	------------------------------------------------------------------------SASDOC*;
	if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
	else memberid = ssn;

	%*SASDOC--------------------------------------------------------------------------
	| Claim and line number                               
	------------------------------------------------------------------------SASDOC*; 
	client_key		= &client_id.;
	practice_id		= &practice_id.; 
	source='P';

	drop svcdt2 dob2 moddt2 submit2 ;
	run;
 
%mend vmine_pmsystem_31;
