
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_2
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the lytec pm system practice data   
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
| 10AUG2011 - Valence Health - Clinical Integration 2.0.01
|			1. Add logic to clean up diag E codes from SQL. 
|
| 22SEP2011 - Valence Health - G Liu 2.0.01
|			1. Added logic to scrub last name for practice 119
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_2;
	*SASDOC--------------------------------------------------------------------
	| Create user function for diagnosis code clean up.
	+--------------------------------------------------------------------SASDOC*;
	%if %sysfunc(exist(sasuser.userfuncs)) = 0 %then %do;
		proc fcmp outlib=sasuser.userfuncs.mymath;
			FUNCTION getdiagcd(dx1 $) $ 7;
			diag='';
			if index(dx1,'.') in (4,5) then diag=dx1;
			else if trim(substr(dx1,1,1)) in ('0','1','2','3','4','5','6','7','8','9','V') then do;
				dx1=compress(dx1,' ');
				if length(dx1)>3 then do;
					d1=trim(substr(dx1,1,3));
					d2=trim(substr(dx1,4));
				end;
				else if length(dx1)<=3 then diag=dx1;
				if d1 ne "" and d2 ne "" then diag=trim(d1)||"."||trim(d2);
				else diag=dx1;
			end;
			else if trim(substr(dx1,1,1)) in ('E') then do;
				dx1=compress(dx1,' ');
				if length(dx1) > 4 then do;
					d11 = trim(substr(dx1,1,4));
					d12 = trim(substr(dx1,5));
				end;
				else if length(dx1) <= 4 then diag = dx1;
				if d11 ne '' and d12 ne '' then diag = trim(d11) || '.' || trim(d12);
				else diag=dx1;
			end;
			else do;
				diag=compress(dx1,' ');
			end;
			return(diag);
			endsub;
			run;
	%end;
	options cmplib=sasuser.userfuncs;


	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. (rename=(claimnum2=claimnum linenum2=linenum upin2=upin));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.;
	  set practice_&do_practice_id.  ;	


		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                       
		------------------------------------------------------------------------SASDOC*;	
		svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		submit=submit2 * units ;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);
		if address2="." then address2="";

		%*SASDOC--------------------------------------------------------------------------
		| Diagnosis codes                                    
		------------------------------------------------------------------------SASDOC*;
		%do k = 1 %to 5;
            dx&k.=compress(diag&k.,'. ');
        	diag&k.=getdiagcd(dx&k.);			
			if substr(diag&k.,1,3) in ('MIS','NIG') then diag&k.=''; 
            drop dx&k. ;
		%end;
		

		%*SASDOC--------------------------------------------------------------------------
		| Procmod values                          
		------------------------------------------------------------------------SASDOC*;
		%do j = 1 %to 4;
			if length(cats(procmod&j.)) ge 3 then mod&j.="";
			if mod&j. in ("\","+","]",".") then mod&j.=""; 
		%end;

		%*SASDOC--------------------------------------------------------------------------
		| Genders                                 
		------------------------------------------------------------------------SASDOC*;
		if sex='1' then sex="F";
		else if sex='0' then sex="M";
		else sex="U";
		
		
		%*SASDOC--------------------------------------------------------------------------
		| Provider                                 
		------------------------------------------------------------------------SASDOC*;		
		provid=npi;
		format upin2 $6.;
		upin2=cats(upin);

		%*SASDOC--------------------------------------------------------------------------
		| Payor                                 
		------------------------------------------------------------------------SASDOC*;		
		payorname1=left(payorname1);

		%*SASDOC--------------------------------------------------------------------------
		| Payor                                 
		------------------------------------------------------------------------SASDOC*;		
		if units < 1 then units=0;

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';
		
		%*SASDOC--------------------------------------------------------------------------
		| Last name                                
		------------------------------------------------------------------------SASDOC*;
		%if &do_practice_id.=119 %then %do;
			if indexc(lname,'0123456789$') then do;
				lname=scan(lname,1);
			end;
		%end;

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

		drop /*patid*/ upin procmod1-procmod4 svcdt2 moddt2 dob2 submit2 claimnum linenum;
	run;
	
	
%mend vmine_pmsystem_2;
