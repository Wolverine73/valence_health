
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_8
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Mosaiq pm system practice data   
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
| 18AUG2011 - G Liu - Clinical Integration 2.0.01
|			1. Added compress . for mname
|			2. Added compress QWERTY and left function for phone
|				We didn't build custom function to compress QWERTY in SQL yet,
|				so, bring all 25 char from SQL to scrub here.
| 
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_8;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.(drop=claimnum linenum phone rename=(claimnum2=claimnum linenum2=linenum phone2=phone));
	set practice_&do_practice_id.;
	format svcdt createdt moddt dob eff_dt1 exp_dt1 mmddyy10. submit dollar13.2 system $30. filename $40. phone2 $10.;	
  
		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
        if linenum ne 0 and payer_priority = 1;

        svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		eff_dt1 = datepart(eff_dt);
		exp_dt1 = datepart(exp_dt);
		submit=submit2;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);
		if eff_dt1 = . then eff_dt1 = '01jan1900'd;
		if exp_dt1 = . then exp_dt1 = '31dec3000'd;
		if mod1 = '.' then mod1 = '';
		mod1 = upcase(mod1);
		mod2 = upcase(mod2);
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
		mname=compress(mname,'.');
		if sex not in ('F','M') then sex='U';
		phone2 = left(compress(upcase(phone),"'-(). \/#ABCDEFGHIJKLMNOPQRSTUVWXYZ"));

		if proccd = "" and length(revcd)=5 then do;
			proccd = revcd;
			revcd = "";
		end;
		if proccd = revcd then revcd = "";

		if eff_dt1 <=svcdt and svcdt<= exp_dt1 then valid=1;
		  else valid=0;

		if valid=1;
		
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

	  drop eff_dt1 exp_dt1 valid eff_dt exp_dt svcdt2 submit2 createdt2 moddt2 payer_priority dob2;
	run;	


     

%mend vmine_pmsystem_8;
