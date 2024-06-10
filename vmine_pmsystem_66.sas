
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_66
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Medevolve pm system practice data   
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
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_66;


		%*SASDOC--------------------------------------------------------------------------
		| Perform cleaning and edits to the practice data
		------------------------------------------------------------------------SASDOC*;
		data practice_&do_practice_id. (rename=(claimnum2 = claimnum linenum2=linenum pos2=pos));
		  format svcdt dob mmddyy10. submit dollar13.2 system $30. ; 
		  length npi provid $10.;
		  length claimnum2 linenum2 npi2 payorid1-payorid3 $10 filename $50 npayorid1-npayorid3 $10 x1 pos2 $2;
		  set practice_&do_practice_id. ;	

		  where pt_drtype = 'C'; 

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                       
		------------------------------------------------------------------------SASDOC*;	
	      dob = datepart(dob2);
		  svcdt = datepart(svcdt2);
		  submit = submit2;

		  system = "&system.";
		  filename=put(MaxProcessID, kprocessid.);

		%*SASDOC--------------------------------------------------------------------------
		| Diagnosis codes                                    
		------------------------------------------------------------------------SASDOC*;
			if index(diag1,'.') in (.,0) then do;
			if substr(diag1,1,1) ne 'E' then do;
				if length(diag1) > 3 then diag1 = trim(substr(diag1,1,3)) || "." || trim(substr(diag1,4));
					else diag1 = trim(diag1);
				end;
					else do;
				if length(diag1) > 4 then diag1 = trim(substr(diag1,1,4)) || "." || trim(substr(diag1,5));
					else diag1 = trim(diag1);
					end;
				end;
			else do;
				diag1 = trim(diag1);
			end;

			if index(diag2,'.') in (.,0) then do;
			if substr(diag2,1,1) ne 'E' then do;
				if length(diag2) > 3 then diag2 = trim(substr(diag2,1,3)) || "." || trim(substr(diag2,4));
					else diag2 = trim(diag2);
				end;
					else do;
				if length(diag2) > 4 then diag2 = trim(substr(diag2,1,4)) || "." || trim(substr(diag2,5));
					else diag2 = trim(diag2);
					end;
				end;
			else do;
				diag2 = trim(diag2);
			end;

			if index(diag3,'.') in (.,0) then do;
			if substr(diag3,1,1) ne 'E' then do;
				if length(diag3) > 3 then diag3 = trim(substr(diag3,1,3)) || "." || trim(substr(diag3,4));
					else diag3 = trim(diag3);
				end;
					else do;
						if length(diag3) > 4 then diag3 = trim(substr(diag3,1,4)) || "." || trim(substr(diag3,5));
						else diag3 = trim(diag3);
					end;
				end;
			else do;
				diag3 = trim(diag3);
			end;

			if index(diag4,'.') in (.,0) then do;
			if substr(diag4,1,1) ne 'E' then do;
				if length(diag4) > 3 then diag4 = trim(substr(diag4,1,3)) || "." || trim(substr(diag4,4));
					else diag4 = trim(diag4);
				end;
				else do;
					if length(diag4) > 4 then diag4 = trim(substr(diag4,1,4)) || "." || trim(substr(diag4,5));
					else diag4 = trim(diag4);
				end;
			end;
				else do;
					diag4 = trim(diag4);
			end;

			%*SASDOC--------------------------------------------------------------------------
			| Other values                          
			------------------------------------------------------------------------SASDOC*;
			claimnum2=put(left(claimnum),10.); 
			linenum2=put(left(linenum),10.); 

			x1=put(pos,8.);
		    pos2=substr(x1,1,2);
			pos2=put(pos,2.);
   

			%*SASDOC--------------------------------------------------------------------------
			| Genders                                 
			------------------------------------------------------------------------SASDOC*;
	             if sex in ("F","f") then sex = "F";
	             else if sex in ("M","m") then sex = "M";
                   else sex = "U";

			%*SASDOC--------------------------------------------------------------------------
			| Member ID                                 
			------------------------------------------------------------------------SASDOC*;
			if memberid *1 = 0 then memberid = "";
			memberid = compress(memberid);
			ssn = compress(ssn);
			
			%*SASDOC--------------------------------------------------------------------------
			| Client                          
			------------------------------------------------------------------------SASDOC*;
			client_key=&client_id. ;
			practice_id=&practice_id.; 
			source='P';


			drop dob2 svcdt2 moddt2 createdt2 pt_drtype casenum visitnum submit2 claimnum linenum pos x1;
		run;
		
%mend vmine_pmsystem_66;













