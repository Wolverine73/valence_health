
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_16
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the micromd pm system practice data   
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
|		1. Migrating from text files to SQL
| 
| 11AUG2011 - G Liu - Clinical Integration 2.0.01
|		1. Added dx scrubbing logic due to additional trailing junk digit 
|  
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 26JAN2012 - Brian Stropich  - Clinical Integration  1.1.02
|             Update diagnosis cleansing logic - trailing zeros
|
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_16;

	*SASDOC--------------------------------------------------------------------------
	| For performing cleansing logic on diagnosis trailing zero issue for micro MD
	| Practices known with this issue - 740 798 805 841 896 1043
	+------------------------------------------------------------------------SASDOC*;
	data diag5cd;
	  set ciedw.diagnosis  (where=(lowcase(diagnosis_cd) ne 'other')) end=end; 
	  length fmtname $10  type $1 label $50;
	  retain fmtname 'Diag5cd'  type 'C';		  	
	  start = diagnosis_cd;
	  label = diagnosis_description;
	  output; 
	  keep start label type fmtname;
	run;
	
	%proc_format(datain=work.diag5cd);

	*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	+------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.;
	set practice_&do_practice_id. (rename = (claimnum=_claimnum linenum=_linenum 
											 diag1=_diag1 diag2=_diag2 diag3=_diag3 diag4=_diag4 diag5=_diag5));
	format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1. claimnum linenum $10.
		   dx1-dx5 diag1-diag5 $6.;
	  
	  **if claim_sequence = 1 ;/** left condition as if to view the log, not in sql because it runs too long **/

		*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		+------------------------------------------------------------------------SASDOC*;
		svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		submit=submit2;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);
		
		*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		+------------------------------------------------------------------------SASDOC*;
		if upcase(sex) not in ('F','M') then sex = 'U';

		*SASDOC--------------------------------------------------------------------------
		| Member                                    
		+------------------------------------------------------------------------SASDOC*;
		if put(ssn,$ssn.) = 'VALID' then memberid = ssn;
		else memberid = '';

		
		*SASDOC--------------------------------------------------------------------------
		| Diagnosis Codes                                  
		+------------------------------------------------------------------------SASDOC*;
		%do k = 1 %to 5;		 
			if index(_diag&k.,'.') in (.,0) then do;
				if substr(_diag&k.,1,1) ne 'E' then do;
					if length(_diag&k.) > 3 then dx&k. = substr(_diag&k.,1,3) || "." || substr(_diag&k.,4);
					else dx&k. = _diag&k.;
				end;
				else do;
					if length(_diag&k.) > 4 then dx&k. = substr(_diag&k.,1,4) || "." || substr(_diag&k.,5);
					else dx&k. = _diag&k.;
				end;
			end;
			else dx&k. = _diag&k.;
			_diag&k=dx&k. ;
			/* These practices have additional trailing 0 junk digit. */
			if left(put(_diag&k. ,$diag5cd.)) = left(_diag&k.) then do; 
				if _diag&k. ne '' and substr(_diag&k.,length(_diag&k.),1)='0' then do; 
                    _diag&k.=substr(_diag&k.,1,length(_diag&k.)-1);
					if _diag&k.=:'E' and substr(_diag&k.,5)='.' then _diag&k.=substr(_diag&k.,1,4);
					else if _diag&k. ne: 'E' and substr(_diag&k.,4)='.' then _diag&k.=substr(_diag&k.,1,3);
				end;
			end; 
			diag&k. = _diag&k.;

			if substr(diag&k.,1,1)="E" and length(diag&k.)=5 and substr(diag&k,5,1)="." then diag&k.=substr(diag&k.,1,4);
			else if length(diag&k.)=4 and substr(diag&k.,4,1)="." then diag&k.=substr(diag&k.,1,3);
			else diag&k. = diag&k.;
		%end;	

		*SASDOC--------------------------------------------------------------------------
		| Modifiers                                   
		+------------------------------------------------------------------------SASDOC*;
		if length(_proccd) > 5 and _proccd not in ('FRAMES') then do;
			 if mod1 ne '' and mod2 ne '' and mod3 ne '' and mod4 = '' then mod4 = trim(substr(_proccd,6,2));
		else if mod1 ne '' and mod2 ne '' and mod3 = '' and mod4 = '' then mod3 = trim(substr(_proccd,6,2));
		else if mod1 ne '' and mod2 = '' and mod3 = '' and mod4 = '' then mod2 = trim(substr(_proccd,6,2));
		else if mod1='' and mod2='' and mod3='' and mod4='' then mod1 = trim(substr(_proccd,6,2));
		end;

		*SASDOC--------------------------------------------------------------------------
		| Client                          
		+------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';
		claim_number=_claimnum*1;
        	line_number=_linenum*1; 
		claimnum = cats(_claimnum);
		linenum  = cats(_linenum);
	
		
		drop svcdt2 createdt2 moddt2 dob2 submit2 dx1-dx5 _diag1-_diag5;

		if length(_proccd) ge 5 and proccd not in ('CANCE','COINS','COPAY','COPPA','DEDUC','NOSHO') then output;

	run;
	

%mend vmine_pmsystem_16;


