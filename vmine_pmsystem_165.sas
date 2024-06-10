/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_165
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the PPMISAV system practice data   
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
| 25MAY2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

 %macro vmine_pmsystem_165;

	
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
	| Missing values for variables                                
	------------------------------------------------------------------------SASDOC*;

	%*SASDOC--------------------------------------------------------------------------
	| Gender                                    
	------------------------------------------------------------------------SASDOC*;

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

	%*SASDOC--------------------------------------------------------------------------
	| Claim and line number                               
	------------------------------------------------------------------------SASDOC*; 
	client_key		= &client_id.;
	practice_id		= &practice_id.; 
	source='P';

	drop svcdt2 dob2 moddt2 submit2 ;

	run;
 
%mend vmine_pmsystem_165;
