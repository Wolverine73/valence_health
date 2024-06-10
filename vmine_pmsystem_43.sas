
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_43
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the eMDs system practice data   
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
| 19APR2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
|
+-----------------------------------------------------------------------HEADER*/
 %macro vmine_pmsystem_43;

	
	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.(drop = _diag1-_diag9);
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $50. source $1.  ;
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
		format diag1-diag9 $6.;
		%do k = 1 %to 9; 
			
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


		%*SASDOC--------------------------------------------------------------------------
		| Claim and line number (if all numeric)                               
		------------------------------------------------------------------------SASDOC*; 
	    
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

		
		drop svcdt2 createdt2 dob2 submit2;

	run;
	
%mend vmine_pmsystem_43;


