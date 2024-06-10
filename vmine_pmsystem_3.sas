
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_3
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the Centricity system practice data   
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
|			  Migrating from text files to SQL
|      
| 17AUG2011 - G Liu - Clinical Integration 2.0.01
|			  Delete claims with all null on svcdt, proc, mod, and diag
|    
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 03MAY2012 - G Liu - Clinical Integration 1.2.01
|			  Add PATID for dedupping
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_3;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. ;
	  format svcdt svcdtto createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.;
	  set practice_&do_practice_id. ;		  	

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
		svcdt=datepart(svcdt2);
		svcdtto=datepart(svcdtto2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		submit=submit2;
		system="&system.";
		filename=put(MaxProcessID, kprocessid.);

		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
	    if upcase(sex) in ('F') then sex = 'F';
	    else if upcase(sex) in ('M') then sex = 'M';
	    else sex = 'U';


	    if &do_practice_id. in (146,228) then do;
			_proccd = proccd;
			proccd = proccd ; *mod 9/2/09 by KG;
		end;
	    else proccd = code;  		                         *mod 9/2/09 by KG;

		%*SASDOC--------------------------------------------------------------------------
		| Provider ID                                 
		------------------------------------------------------------------------SASDOC*;
	    %if %upcase(&client_id) = 1 %then %do; /** adventist **/
		  provid = cats(upin);
		  if upin = '' then provid = cats(npi);
	    %end;
	    %else %do;
	      provid=cats(npi);
	    %end;

		%*SASDOC--------------------------------------------------------------------------
		| Address and Name                             
		------------------------------------------------------------------------SASDOC*;
		if address1='.' then address1='';
		if city='.' then city='';
		if state='.' then state=''; 
		if mname='.' then mname=''; 
		fname=compress(fname,'"');

		
		%*SASDOC--------------------------------------------------------------------------
		| mod                              
		------------------------------------------------------------------------SASDOC*;		
		if length(_mod1) > 2 then do;
			if length(_mod1) = 6 then do;
				if _mod2 = "" and _mod3 = "" then do;
					mod1 = cats(substr(_mod1,1,2));
					mod2 = cats(substr(_mod1,3,2));
					mod3 = cats(substr(_mod1,5,2));
				end;
				else if _mod2 ne '' and _mod3 = '' then do;
					mod4 = cats(substr(_mod2,1,2));
					mod3 = cats(substr(_mod1,5,2));
					mod2 = cats(substr(_mod1,3,2));	
					mod1 = cats(substr(_mod1,1,2));	
				end;
				else do;
					mod1 = cats(substr(_mod1,1,2));
					mod2 = cats(substr(_mod2,1,2));
					mod3 = cats(substr(_mod3,1,2));
					mod4 = cats(substr(_mod4,1,2));
				end;
			end;
			else if length(_mod1) = 4 then do;
				if _mod2 = '' and _mod3 = '' then do;
					mod1 = cats(substr(_mod1,1,2));
					mod2 = cats(substr(_mod1,3,2));
				end;
				else if _mod2 ne '' and mod3 = '' then do;
					mod1 = cats(substr(_mod1,1,2));
					mod2 = cats(substr(_mod1,3,2));
					mod3 = cats(substr(_mod2,1,2));
				end;
				else do;
					mod1 = cats(substr(_mod1,1,2));
					mod2 = cats(substr(_mod2,1,2));
					mod3 = cats(substr(_mod3,1,2));
					mod4 = cats(substr(_mod4,1,2));
				end;
			end;
			else do;
					mod1 = '';
					mod2 = '';
					mod3 = '';
					mod4 = ''; 
			end;
		end;
		else do;
			mod1 = cats(substr(_mod1,1,2));
			mod2 = cats(substr(_mod2,1,2));
			mod3 = cats(substr(_mod3,1,2));
			mod4 = cats(substr(_mod4,1,2));	
		end;		

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if memberid in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';

		%*SASDOC--------------------------------------------------------------------------
		| Payor                                 
		------------------------------------------------------------------------SASDOC*;
		payorname1=left(payorname1);
		provname=upcase(provname);
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

		%*SASDOC--------------------------------------------------------------------------
		| If claim line has no pertinent info, delete
		------------------------------------------------------------------------SASDOC*;
		if svcdt=. and proccd='' and mod1=''  and mod2=''  and mod3='' 
                 and diag1='' and diag2='' and diag3='' then delete;

	  drop svcdt2 svcdtto2 createdt2 moddt2 dob2 submit2 code _mod1 _mod2 _mod3 _mod4;
	run;	

	%*SASDOC--------------------------------------------------------------------------
	| Remove duplicate claims - include maximum process ID to keep the latest  
	| claims for the practice data
	------------------------------------------------------------------------SASDOC*;	
	proc sort data=practice_&do_practice_id. ;
	  by claimnum proccd mod1 mod2 mod3 mod4 svcdt svcdtto units submit 
	     descending linenum descending kProcessID_Procs descending kProcessID_PatVisit descending maxprocessid;
	run;
	
	proc sort data=practice_&do_practice_id.  nodupkey;
	  by claimnum proccd mod1 mod2 mod3 mod4 svcdt svcdtto units submit;
	run;
	
	proc summary data=practice_&do_practice_id. nway missing;
	  class PATID ssn memberid lname fname mname dob svcdt _proccd proccd mod1-mod4 client_key practice_id source;
	  id sex phone system filename claimnum linenum upin npi npi2 provid tin provname diag1-diag9 createdt moddt 
	  payorname1 payorid1 instype1 npayorid1 payorname2 payorid2 instype2 npayorid2 payorname3 payorid3 instype3 npayorid3
	  pos address1 address2 city state zip maxprocessid 
      kProcessID_Procs kProcessID_PatVisit kProcessID_Pat kProcessID_MedLists
      kProcessID_Prov kProcessID_Insurance kProcessID_PatientDiags;
	  var submit units;
	  output out=practice_&do_practice_id. (compress=yes drop=_type_ _freq_) sum=;
	run;

	data practice_&do_practice_id.;
	 set practice_&do_practice_id.;
     patientmax=max(kProcessID_Procs, kProcessID_PatVisit, kProcessID_PatientDiags);
	run;
	


%mend vmine_pmsystem_3;
