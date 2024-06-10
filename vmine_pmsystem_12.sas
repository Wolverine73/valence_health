
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_12
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the medware pm system practice data   
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

%macro vmine_pmsystem_12;

	%*SASDOC--------------------------------------------------------------------------
	| Create format of alphabet mapping
	---------------------------------------------------------------------------SASDOC*;
	
	%include "M:\ci\programs\StandardMacros\vmine_pmsystem_12_num2charfmt.sas";

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. (rename=(claimnum2=claimnum linenum2=linenum));
	format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40.;
	set practice_&do_practice_id. (rename=(sex=_sex mname=_mname npi2=_npi2));			 

	%*SASDOC--------------------------------------------------------------------------
	| Reformat dates and dollars and other                       
	------------------------------------------------------------------------SASDOC*;	
	svcdt	 = (svcdt2 * 1)    - 18261 - ('01jan1960'd - '30dec1899'd); *18261 converts Practice Partners number into long integer;
	createdt = (createdt2 * 1) - 18261 - ('01jan1960'd - '30dec1899'd); *18261 converts Practice Partners number into long integer;
	moddt	 = (moddt2 * 1)    - 18261 - ('01jan1960'd - '30dec1899'd); *18261 converts Practice Partners number into long integer;
	dob		 = (dob2 * 1)      - 18261 - ('01jan1960'd - '30dec1899'd); *18261 converts Practice Partners number into long integer;
	submit	 = submit2;

	system 	 = "&system.";
	filename = put(MaxProcessID, kprocessid.);


	if (_sex * 1) > 0 and (32 <= (_sex   * 1) < 91) and put(_sex,$num2char.)   ne _sex   then sex   = put(_sex,$num2char.); *Some practices does not have the number codes for sex and mname;
	else sex = _sex;
	if (32 <= (_mname * 1) < 91) and put(_mname,$num2char.) ne _mname then mname = put(_mname,$num2char.); *Some practices does not have the number codes for sex and mname;
	else mname = _mname;

	if mname = "," then mname = "";

	%*SASDOC--------------------------------------------------------------------------
	| Diagnosis codes                                    
	------------------------------------------------------------------------SASDOC*;	

	%*SASDOC--------------------------------------------------------------------------
	| Procedure and Modifier codes                                    
	------------------------------------------------------------------------SASDOC*;		

	%*SASDOC--------------------------------------------------------------------------
	| Phone                          
	------------------------------------------------------------------------SASDOC*;
	if length(phone) ne 10 then phone=""; 

	%*SASDOC--------------------------------------------------------------------------
	| Genders                                 
	------------------------------------------------------------------------SASDOC*;
	if sex not in ("F","M") then sex="U";


	%*SASDOC--------------------------------------------------------------------------
	| Provider                                 
	------------------------------------------------------------------------SASDOC*;		
	format npi2 $10.;
	npi2=compress(_npi2);

	%*SASDOC--------------------------------------------------------------------------
	| Payor                                 
	------------------------------------------------------------------------SASDOC*;		


	%*SASDOC--------------------------------------------------------------------------
	| Removal of invalid claims                                 
	------------------------------------------------------------------------SASDOC*;		


	%*SASDOC--------------------------------------------------------------------------
	| Member ID                                 
	------------------------------------------------------------------------SASDOC*;
	if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';

	%*SASDOC--------------------------------------------------------------------------
	| Client                          
	------------------------------------------------------------------------SASDOC*;
	claim_number=claimnum;
        line_number=linenum;
	claimnum2=left(put(claimnum,8.));
        linenum2=left(put(linenum,8.));
	client_key		= &client_id.;
	practice_id		= &practice_id.; 
	source='P';

	drop _npi2 svcdt2 moddt2 dob2 submit2 createdt2 claimnum linenum _sex _mname;
	run;


%mend vmine_pmsystem_12;
