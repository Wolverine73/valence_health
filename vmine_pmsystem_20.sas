
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_20
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

%macro vmine_pmsystem_20;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. ;
	  format svcdt createdt moddt dob dateentered datemodified mmddyy10. submit dollar13.2 system $30. filename $40. source $1.  ;
	  set practice_&do_practice_id. (rename=(claimnum=_claimnum linenum=_linenum diag1=_diag1 diag2=_diag2 diag3=_diag3 diag4=_diag4));	

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                       
		------------------------------------------------------------------------SASDOC*;	
		svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		dateentered=datepart(dateentered2);
		datemodified=datepart(datemodified2);
		submit=submit2;
		
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);
		if address1="." then address1="";
		if address2="." then address2="";

		%*SASDOC--------------------------------------------------------------------------
		| Diagnosis codes                                    
		------------------------------------------------------------------------SASDOC*;	
		length diag1-diag4 $6.;

		%do k = 1 %to 4; /*09JUN2011 - WLee - Added diagnosis code clean up logic*/
			if substr(_diag&k.,2,1) in ('0','1','2','3','4','5','6','7','8','9') and _diag&k. ne '' then do;
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
				else if index(_diag&k.,'.')=4 and length(_diag&k.) = 4 then do;
					diag&k. = compress(_diag&k.,'.');
				end;
				else if index(_diag&k.,'.')=5 and length(_diag&k.) = 5 and substr(_diag&k.,1,1) = 'E' then do;
					diag&k. = compress(_diag&k.,'.');
				end;
				else diag&k. = _diag&k.;
			end;
			else diag&k. = _diag&k.;
		%end;	

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
	

		%*SASDOC--------------------------------------------------------------------------
		| Payor                                 
		------------------------------------------------------------------------SASDOC*;		
		

		%*SASDOC--------------------------------------------------------------------------
		| Removal of invalid claims                                 
		------------------------------------------------------------------------SASDOC*;		
		translate_value=translate(_proccd,"                             ","-/\QWERTYUIOPASDFGHJKLZXCVBNM");
		translate_length=length(_proccd);
		if translate_value='' and  translate_length ne 2 then delete;

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';
		
		%*SASDOC--------------------------------------------------------------------------
		| Number Conversion                          
		------------------------------------------------------------------------SASDOC*;
		claim_number=_claimnum*1;
        line_number=_linenum*1;
		format claimnum linenum $8.;
		claimnum=cats(put(_claimnum,8.));
		linenum=cats(put(_linenum,8.));
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

		drop _claimnum _linenum svcdt2 moddt2 dob2 dateentered2 createdt2 datemodified2 submit2 _diag1-_diag4;
	run;
	

%mend vmine_pmsystem_20;
