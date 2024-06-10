
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_19
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Aprima(formerly Imedica) system practice data   
|
| logic:                   
|
| input:         
|                        
| output:    
|
| usage:    
|
|c
+--------------------------------------------------------------------------------
| history:  
|
| 24AUG2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 23MAR2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Modified diagnosis code clean up logic
|			2. Modified modifier code clean up logic
|			3. Modified proccd clean up logic
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
|             
+-----------------------------------------------------------------------HEADER*/
 %macro vmine_pmsystem_19;

	
	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.(drop =   rename=(claimnum2 = claimnum linenum2=linenum));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $50. source $1. diag1-diag9 $6.;
	  set practice_&do_practice_id. (rename=(diag1=_diag1 diag2=_diag2 diag3=_diag3 diag4=_diag4 diag5=_diag5 
											 diag6=_diag6 diag7=_diag7 diag8=_diag8 diag9=_diag9));		  	

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
		| Diags       
		------------------------------------------------------------------------SASDOC*;
/*		if diag1="     ." then diag1 = "";*/
/*		if diag2="     ." then diag2 = "";*/
/*		if diag3="     ." then diag3 = "";*/
/*		if diag4="     ." then diag4 = "";*/
/*		if diag1="000000" then diag1 = "";*/
/*		if diag2="000000" then diag2 = "";*/
/*		if diag3="000000" then diag3 = "";*/
/*		if diag4="000000" then diag4 = "";*/
/*		if index(diag1,'.')=4 and substr(diag1,5,2)="" then diag1=compress(diag1,'.');*/
/*		if index(diag2,'.')=4 and substr(diag2,5,2)="" then diag2=compress(diag2,'.');*/
/*		if index(diag3,'.')=4 and substr(diag3,5,2)="" then diag3=compress(diag3,'.');*/
/*		if index(diag4,'.')=4 and substr(diag4,5,2)="" then diag4=compress(diag4,'.');	*/

		%do k = 1 %to 9; /*23MAR2011 - WLee - Modify diagnosis code clean up logic*/
			
			if index(_diag&k.,'.') in (.,0) then do;
			if substr(_diag&k.,1,1) ne 'E' then do;
				if length(_diag&k.) > 3 then diag&k. = substr(_diag&k.,1,3) || "." || substr(_diag&k.,4);
				else diag&k. = _diag&k.;
			end;
			else do;
				if length(_diag&k.) > 4 then diag&k. = substr(_diag&k.,1,4) || "." || substr(_diag&k.,5);
				else diag&k. = _diag&k.;
			end;
			end;
			else diag&k. = _diag&k.;

		%end;

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
		| CPT and Modifiers                             
		------------------------------------------------------------------------SASDOC*;	
		if index(_proccd,'-') > 0 and index(_proccd,'-') ne . and mod1 = '' then mod1 = cats(substr(_proccd,index(_proccd,'-') + 1,2)); /*23MAR2011 - WLee - Modify modifier code clean up logic*/
		else if index(_proccd,'-') > 0 and index(_proccd,'-') ne . and mod1 ne '' then mod2 = cats(substr(_proccd,index(_proccd,'-') + 1,2));
		else if length(_proccd) > 5 and mod1 = '' then mod1 = cats(substr(_proccd,6,2));
		else if length(_proccd) > 5 and mod1 ne '' then mod2 = cats(substr(_proccd,6,2));

		if index(proccd,'-') > 0 then proccd = cats(substr(_proccd,1,index(_proccd,'-') - 1)); /*23MAR2011 - WLee - Modify proccd clean up logic*/

		%*SASDOC--------------------------------------------------------------------------
		| Claim and line number                               
		------------------------------------------------------------------------SASDOC*; 
	    claim_number=claimnum;
        claimnum2 = compress(claimnum,'{''}');
		line_number=linenum;
	    linenum2=compress(linenum,'{''}');
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

		
		drop visitnum svcdt2 createdt2 dob2 submit2 moddt2 linenum claimnum _diag1-_diag9;

	run;
	
/*	proc sort data= practice_&do_practice_id.;*/
/*	by claimnum memberid svcdt lname fname dob diag1 diag2 diag3 proccd mod1 descending maxprocessid descending moddt2 descending submit descending units ;*/
/*	run;*/
/*	*/
/*	data practice_&do_practice_id.;*/
/*	set practice_&do_practice_id.;*/
/*	by claimnum memberid svcdt lname fname dob diag1 diag2 diag3 proccd mod1 descending processid descending moddt2 descending submit descending units ;*/
/**/
/*	if first.proccd;*/
/*	run;*/ 

%mend vmine_pmsystem_19;


