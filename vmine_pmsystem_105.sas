
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_105
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Misys PM system practice data   
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
| 11MAR2011 - Winnie Lee - Clinical Integration 1.0.01
|			1. Update to current production MEMBERID assignement logic
|			2. Update to current production POS assignement logic
|			3. Include diagnosis code clean up logic
|           4. Update to current production exclusion logic
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
| 05AUG2011 - G Liu - Clinical Integration 2.0.01
| 			1. Added upcase for provname
|			2. Added compress * for diag
|			3. Made diag shifting for all practices
|			4. Set provid=npi for all clients
|
| 
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_105;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.;
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.  ;
	  set practice_&do_practice_id. (rename=(diag1=_diag1 diag2=_diag2 diag3=_diag3 diag4=_diag4 diag5=_diag5 
											 diag6=_diag6 diag7=_diag7 diag8=_diag8 diag9=_diag9));
	  
	  **if claim_sequence = 1 ;/** left condition as if to view the log, not in sql because it runs too long **/

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
		| where condition - exclusion logic to remove bad encounters                                    
		------------------------------------------------------------------------SASDOC*;
		if (proccd not in ('','ADX','DNKA')) or  
		       (proccd in ('','ADX','DNKA') and submit2 > 0) ;


		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
		if upcase(sex) = 'F' then sex='F';
        else if upcase(sex) = 'M' then sex='M';
        else sex = 'U';
    
    
		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                    
		------------------------------------------------------------------------SASDOC*;    
/*	    if memberid in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000')*/
/*	    then memberid='';*/

		/*11MAR2011 - WLee: update to current production MEMBERID assignement logic*/
		if ssn * 1 not in (.,0) then memberid = trim(ssn);
		else memberid = '';
	    
		%*SASDOC--------------------------------------------------------------------------
		| POS                                   
		------------------------------------------------------------------------SASDOC*; 	      
		/*11MAR2011 - WLee: update to current production POS assignement logic*/
		%if &do_practice_id. = 290 or &do_practice_id. = 316 or &do_practice_id. = 376 or &do_practice_id. = 567 or &do_practice_id. = 626 or &do_practice_id. = 627 %then %do;
			pos = pos1;
		%end;
		%else %if &do_practice_id. = 310 or &do_practice_id. = 313 or &do_practice_id. = 314 or &do_practice_id. = 315 or &do_practice_id. = 369 %then %do;
			pos = pos2;
		%end;
		%else %do;
			pos = pos4;
		%end;


		%*SASDOC--------------------------------------------------------------------------
		| DIAGNOSIS CODES                                  
		------------------------------------------------------------------------SASDOC*; 
/*		%if &do_practice_id.=316 %then %do;*/
			array tdx(9) _diag1-_diag9;
			do loopdx=1 to 8;
				if tdx(loopdx)='' then do; 
					tdx(loopdx)=tdx(loopdx+1);
					tdx(loopdx+1)='';	
				end;
			end;
/*		%end; */

		format diag1-diag9 $6.;
		%do k = 1 %to 9;
			_diag&k.=compress(_diag&k.,'*');
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

/*			if diag&k. in ('000','000.0','000.00') then diag&k. = '';*/

		%end;

		
	   
		%*SASDOC--------------------------------------------------------------------------
		| Provider ID                                    
		------------------------------------------------------------------------SASDOC*;  	   
	    provid=npi;
		provname=upcase(provname);	
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';


		%*SASDOC--------------------------------------------------------------------------
		| Number Conversion                          
		------------------------------------------------------------------------SASDOC*;
		claimnum2 = claimnum * 1;
		linenum2  = linenum * 1;
		
        drop casenum visitnum svcdt2 createdt2 moddt2 dob2 submit2 pos1 pos2 pos4 _diag1-_diag9;
	run;
 
%mend vmine_pmsystem_105;
