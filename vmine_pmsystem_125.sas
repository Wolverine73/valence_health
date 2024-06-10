
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_125
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the PBSI pm system practice data   
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
| 01SEP2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_125;

	*SASDOC--------------------------------------------------------------------------
	| Diagnosis Function
	+------------------------------------------------------------------------SASDOC*;
	%if %sysfunc(exist(sasuser.userfuncs)) = 0 %then %do;
		proc fcmp outlib=sasuser.userfuncs.mymath;
			FUNCTION getdiagcd(dx1 $) $ 6;
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


	*SASDOC--------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	+--------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. (drop = createdt2) ;

	  format svcdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.  ;

	  set practice_&do_practice_id. (rename=(diag1=_diag1 diag2=_diag2 diag3=_diag3 diag4=_diag4 ));
											 

		*SASDOC--------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		+--------------------------------------------------------------------SASDOC*;
		svcdt=datepart(svcdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		submit=submit2;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);
		

		*SASDOC--------------------------------------------------------------------
		| Gender
		+--------------------------------------------------------------------SASDOC*; 
/*		sex = upcase(sex);*/
/*		if sex not in ('M','F') then sex = 'U';*/
    
		*SASDOC--------------------------------------------------------------------
		| Member ID
		+--------------------------------------------------------------------SASDOC*;

/*	    if memberid in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000')*/
/*	    then memberid='';*/

		*SASDOC--------------------------------------------------------------------
		| DIAGNOSIS CODES
		+--------------------------------------------------------------------SASDOC*;

		format diag1-diag4 $6.;

		diag1=getdiagcd(cats(_diag1));
		diag2=getdiagcd(cats(_diag2));
		diag3=getdiagcd(cats(_diag3));
		diag4=getdiagcd(cats(_diag4));

		*SASDOC--------------------------------------------------------------------
		| Client
		+--------------------------------------------------------------------SASDOC*;

		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

		
        drop svcdt2 moddt2 dob2 submit2 _diag1-_diag4;
	run;
 
%mend vmine_pmsystem_125;
