
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_111
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the CompulinkOA pm system practice data   
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

%macro vmine_pmsystem_111;

	%*SASDOC--------------------------------------------------------------------------
	| Figure out which column the practice populates SSNs with
	------------------------------------------------------------------------SASDOC*;
	data ssncheck (keep=valid_ssn_1-valid_ssn_5);
	set practice_&do_practice_id. (keep=user1-user5);
	%do k=1 %to 5;
		if (length(user&k.) = 9) and 
		   ((user&k. * 1) > 0) and
		   (substr(user&k.,1,1) in ('0','1','2','3','4','5','6','7','8','9')) and
		   (substr(user&k.,9,1) in ('0','1','2','3','4','5','6','7','8','9')) and
		   (indexc(upcase(user&k.),'ABCDEFGHIJKLMNOPQRSTUVWXYZ') = 0) then valid_ssn_&k. = 1;
		else valid_ssn_&k. = 0;
	%end;
	run;

	proc summary data=ssncheck nway missing;
	var valid_ssn_1-valid_ssn_5;
	output out=ssncheck2 (drop=_type_ _freq_) sum=;
	run;

	data ssncheck3;
	set ssncheck2;
	length maxcol 8.;
	maxcol = max(valid_ssn_1, valid_ssn_2, valid_ssn_3, valid_ssn_4, valid_ssn_5);
	if maxcol = valid_ssn_1 then call symput('ssn_column', 'user1');
	else if maxcol = valid_ssn_2 then call symput('ssn_column', 'user2');
	else if maxcol = valid_ssn_3 then call symput('ssn_column', 'user3');
	else if maxcol = valid_ssn_4 then call symput('ssn_column', 'user4');
	else if maxcol = valid_ssn_5 then call symput('ssn_column', 'user5');
	run;

	%put NOTE: Patient SSN is in &ssn_column. field;


	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. ;
	set practice_&do_practice_id. (rename = (claimnum = _claimnum linenum = _linenum));
	length svcdt createdt moddt moddt_ldgr dob submit claim_number line_number 8. claimnum linenum $36. filename $40.;
	format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40.;	
  
    svcdt=datepart(svcdt2);
	createdt=datepart(createdt2);
	moddt=datepart(moddt2);
	moddt_ldgr = datepart(moddt2ldgr);
	dob=datepart(dob2);
	submit=submit2;
	system="&system.";
	filename=put(MaxProcessID, kprocessid.);

	
	ssn = &ssn_column.;
	if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000','999999999') or 
	   length(ssn) < 9 then memberid = '';
	else memberid = ssn;

	sex = upcase(sex);
	if sex in ('M','F') then sex = sex;
	else sex = 'U';

	if diag1 = '.' then diag1 = '';
	if diag2 = '.' then diag2 = '';
	if diag3 = '.' then diag3 = '';
	if diag4 = '.' then diag4 = '';

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

	%*SASDOC--------------------------------------------------------------------------
	| Client                          
	------------------------------------------------------------------------SASDOC*;
	client_key=&client_id. ;
	practice_id=&practice_id.; 
	source='P';
	claim_number = _claimnum * 1;
	line_number  = _linenum * 1;
	claimnum = cats(_claimnum);
	linenum  = cats(_linenum);

	if substr(proccd,2,1) not in ('1','2','3','4','5','6','7','8','9','0') then delete;

  	drop svcdt2 submit2 createdt2 moddt2 moddt2ldgr dob2 visitnum user1-user5 createdt _claimnum _linenum;
	run;	

%mend vmine_pmsystem_111;
