
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_4
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the nextgen pm system practice data   
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

%macro vmine_pmsystem_4;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. ;
	  format svcdt0 $8. svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $50. source $1.;
	  set practice_&do_practice_id. ;
      where linenum ne ''; 	  

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
			svcdt0 = svcdt2;
			svcdt = input( svcdt0, yymmdd10.);
			moddt=input(moddt2, yymmdd10.);
			dob= input( dob2, yymmdd10.);
			createdt = datepart(createdt2);
			/*submit=submit2 * units ;*/
			submit = submit2;
			system="&system.";
			if address2="." then address2="";
			mname = substr(mname,1,1);
			filename=put(MaxProcessID, kprocessid.);
/*            createdt_ts =input(createdt2,anydtdtm25.);            */
/*            svcdt_ts    =input(svcdt2,anydtdtm25.);*/

		%*SASDOC--------------------------------------------------------------------------
		| Diagnosis Code                                   
		------------------------------------------------------------------------SASDOC*;
           dx1=diag1;
           dx2=diag2;
		   dx3=diag3;
		   dx4=diag4;
		  
			%do k = 1 %to 4;
			if index(dx&k,'.') in (4,5) then diag&k=dx&k;
			else if trim(substr(dx&k,1,1)) in ('0','1','2','3','4','5','6','7','8','9','V') then do;
				dx&k=compress(dx&k,' ');
				if length(dx&k)>3 then do;
					d1_&k=trim(substr(dx&k,1,3));
					d2_&k=trim(substr(dx&k,4));
				end;
				else if length(dx1)<=3 then diag1=dx1;
				if d1_&k ne "" and d2_&k ne "" then diag&k=trim(d1_&k)||"."||trim(d2_&k);
				else diag&k=compress(dx&k,' ');
			end;
			else if trim(substr(dx&k,1,1)) in ('E') then do;
				dx&k=compress(dx&k,' ');
				if length(dx&k) > 4 then do;
					d1_&k = trim(substr(dx&k,1,4));
					d2_&k = trim(substr(dx&k,5));
				end;
				else if length(dx&k) <= 4 then diag&k = dx&k;
				if d1_&k ne '' and d2_&k ne '' then diag&k = trim(d1_&k) || '.' || trim(d2_&k);
				else diag&k = compress(dx&k,' ');
			end;	
			else do;
				diag&k=compress(dx&k,' ');
			end;
		%end;

		%*SASDOC--------------------------------------------------------------------------
		| Proccd values                               
		------------------------------------------------------------------------SASDOC*;
	        if &do_practice_id. = 164 then do;
		       if substr(_proccd,1,3) = "EPI" then proccd = cats(substr(_proccd,4,5));
	        end;

		%*SASDOC--------------------------------------------------------------------------
		| Genders                            
		------------------------------------------------------------------------SASDOC*;
			sex = upcase(sex);
			if sex not in ('M','F') then sex = 'U';

		
		%*SASDOC--------------------------------------------------------------------------
		| Member ID                            
		------------------------------------------------------------------------SASDOC*;		
		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		provid=npi;
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';
		
		%*SASDOC--------------------------------------------------------------------------
		| Service Date Filter vs. Create Date                          
		------------------------------------------------------------------------SASDOC*;
		if svcdt > createdt then delete;
		
		
		drop casenum visitnum svcdt0 svcdt2 moddt2 dob2 submit2 d1_: d1_4 dx: d2_:;
	run;	


%mend vmine_pmsystem_4;
