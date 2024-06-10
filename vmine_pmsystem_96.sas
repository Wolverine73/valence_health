
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_96
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the greenway pm system practice data   
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


%macro vmine_pmsystem_96;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.(rename=(claimnum2=claimnum linenum2=linenum phone2 = phone));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. claimnum2 linenum2 $8. phone2 $10.;
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
		phone2 = substr(compress(phone,'.'),1,10);


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
		| PROCCD       
		------------------------------------------------------------------------SASDOC*;

		%if &do_practice_id. = 386 %then %do;
			if proccd = 'BALFD' then delete;
		%end;

		%*SASDOC--------------------------------------------------------------------------
		| Mod       
		------------------------------------------------------------------------SASDOC*;
		mod1 = compress(cats(mod1),"'""+""`""[""]");
		mod2 = compress(cats(mod2),"'""+""`""[""]");
		if compress(mod1)='.' then mod1 = '';
		if compress(mod2)='.' then mod2 = ''; 
		pos	=  compress(pos,"'""+""`""[""]");


		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
		if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
	    else memberid = ssn;

		%*SASDOC--------------------------------------------------------------------------
		| Payor                                    
		------------------------------------------------------------------------SASDOC*;
		payorid1=compress(payorid1,' ');
		if payorname1='.' then payorname1='';

		%*SASDOC--------------------------------------------------------------------------
		| claim and line number                          
		------------------------------------------------------------------------SASDOC*;       
		claimnum2=compress(left(put(claimnum,8.)),'.');
        linenum2=compress(left(put(linenum,8.)),'.');
		claim_number=claimnum;
        line_number=linenum;
		
		client_key	= &client_id.;
		practice_id	= &practice_id.; 
		source='P';

		drop casenum phone svcdt2 createdt2 moddt2 dob2 submit2 claimnum linenum VoidServiceDetailID;
	run;


/*	%*SASDOC--------------------------------------------------------------------------*/
/*	| Remove duplicate claims - include maximum process ID to keep the latest  */
/*	| claims for the practice data*/
/*	------------------------------------------------------------------------SASDOC*;	*/
/*	proc sort data=practice_&do_practice_id.;*/
/*	   by claimnum linenum descending visitnum descending kprocessid_ServiceDetail descending moddt descending maxprocessid ;*/
/*	run;*/
/*	*/
/*	data practice_&do_practice_id.;*/
/*     set practice_&do_practice_id.;*/
/*	  by claimnum linenum descending visitnum descending kprocessid_ServiceDetail descending moddt descending maxprocessid  ;*/
/*	 if first.visitnum;*/
/*	run;*/
/*	*/
	


%mend vmine_pmsystem_96;

