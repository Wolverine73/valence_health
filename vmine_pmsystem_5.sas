
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_5
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the MedicalManager (Medman) pm system practice data   
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
| 26JAN2012 - Brian Stropich  - Clinical Integration  1.1.02
|             Added diagnosis cleansing logic - commas
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_5;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. ;
		  format dob svcdt createdt mmddyy10. submit dollar13.2;
		  length dob0 svcdt0 createdt0 $8. dx1 $6. mod1 $2. filename $40. source $1.;
		  set practice_&do_practice_id. ;	

	      filename=put(MaxProcessID, kprocessid.);
		  if tin in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then tin = '';
		  if memberid in ('0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = '';
		  if chrgcode="0" and _proccd NE "INTEREST";
		  if &do_practice_id. not in (408,468,103) then do;
		    patpatient = 'Y';
		  end;

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
		  dob0 = dob2;
		  svcdt0 = svcdt2;
		  createdt0 = createdt2;
		  dob = input(dob0,yymmdd10.);
		  if dob > today() then dob = dob - 36525;
		  svcdt = input(svcdt0,yymmdd10.);
		  createdt = input(createdt0,yymmdd10.);
		  submit = submit2;
		  system = "&system."; 

		%*SASDOC--------------------------------------------------------------------------
		| Diagnosis Code                                   
		------------------------------------------------------------------------SASDOC*;
		if &do_practice_id. in (367)  then do; 
			dx1=compress(cats(diag1),.);

			if length(dx1)=5 then do;
			  diag1=substr(dx1,1,3) || "." || substr(dx1,4,2) ;
			end;
			else if length(dx1)=4 then do;
			  diag1=substr(dx1,1,3) || "." || substr(dx1,4,1) ;
			end;
			else if length(dx1)le 3 then do;
			  diag1=substr(dx1,1,3);
			end;
		end;
		if length(dx1) > 5 then do;
		  diag1='';
		end;

		if &do_practice_id. in (680) then do;
			if index(diag1,'.') in (.,0) then do;
				dx1 = diag1;
				if substr(dx1,1,1) ne 'E' then do;
					if length(dx1) in (4,5) then diag1 = substr(dx1,1,3) || "." || substr(dx1,4,2);
					else if length(dx1) = 3 then diag1 = trim(dx1);
					else diag1 = trim(dx1);
				end;
				else if substr(dx1,1,1) in ('1','2','3','4','5','6','7','8','9','0','V') then do;
					if length(dx1) in (5) then diag1 = substr(dx1,1,4) || "." || substr(dx1,5,1);
					else if length (dx1) = 4 then diag1 = trim(dx1);
					else diag1 = trim(dx1);
				end;
				else do;
					diag1 = trim(dx1);
				end;	
			end;
		end;

		if &do_practice_id. in (964) then do;
			if index(diag1,',') not in (.,0) then do;
				dx1 = diag1;
				diag1 = trim(substr(dx1,1,index(diag1,',') - 1));
			end;
			else diag1 = diag1;
		end;


		%*SASDOC--------------------------------------------------------------------------
		| Proccd and mod values                               
		------------------------------------------------------------------------SASDOC*;
		mod1=compress(upcase(__mod1),'+'' ''/''\');
        if mod1 not in  ('','.') then do;
			if index(mod1,".") ge 1  then do;
				diag2=upcase(cats(mod1));
				mod1 = '';
			end;
/*			procmod1 = compress(procmod1,'.');*/
			else do;
					if substr(upcase(compress(__mod1,'+'' ''/''\')),3,1) ne '' then do;
					  mod2 = upcase(trim(substr(upcase(compress(__mod1,'+'' ''/''\')),3,2)));
					end;
					if substr(upcase(compress(__mod1,'+'' ''/''\')),5,1) ne '' then do;
					  mod3 = upcase(trim(substr(upcase(compress(__mod1,'+'' ''/''\')),5,2)));
					end;
				    mod1 = upcase(trim(substr(upcase(compress(__mod1,'+'' ''/''\')),1,2)));
			end;
	    end;
		mod1 = compress(mod1,'.');

	if substr(_proccd,6,1) ne '' and substr(_proccd,2,1) in ('1','2','3','4','5','6','7','8','9','0') then do;
/*		_procmod1 = compress(cats(substr(_proccd,6)),",- ");*/
		_procmod1 = cats(substr(_proccd,6));
		_mod1=scan(_procmod1,1,",- ");
		_mod2=scan(_procmod1,2,",- ");
		_mod3=scan(_procmod1,3,",- ");
		if _mod1 ne "" and _mod1 ne mod1 and _mod1 ne _mod2 and _mod1 ne mod3 then do;
			if mod1 = "" then mod1 = upcase(_mod1);
			else if _mod2 = "" then _mod2 = upcase(_mod1);
			else if mod3 = "" then mod3 = upcase(_mod1);
		end;
		if _mod2 ne "" and _mod2 ne mod1 and
		   _mod2 ne mod2 and _mod2 ne mod3 then do;
			if mod1 = "" then mod1 = upcase(_mod2);
			else if mod2 = "" then mod2 = upcase(_mod2);
			else if mod3 = "" then mod3 = upcase(_mod2);
		end;
		if _mod3 ne "" and _mod3 ne mod1 and
		   _mod3 ne mod2 and _mod3 ne mod3 then do;
			if mod1 = "" then mod1 = upcase(_mod3);
			else if mod2 = "" then mod2 = upcase(_mod3);
			else if mod3 = "" then mod3 = upcase(_mod3);
		end;

		mod1 = compress(mod1,'.');
		mod2 = compress(mod2,'.');
		mod3 = compress(mod3,'.');
	end;
	
		%*SASDOC--------------------------------------------------------------------------
		| POS                                    
		------------------------------------------------------------------------SASDOC*;
		if &do_practice_id. in (342,367) then do;
		  if length(_pos) = 2 and length(pos) ne 2 then pos=_pos;		  
		end;

		if pos = '' and length(_pos) = 2 and (11 <= (_pos * 1) <= 99) then pos = _pos;
       

		%*SASDOC--------------------------------------------------------------------------
		| Genders                            
		------------------------------------------------------------------------SASDOC*;
	      if upcase(sex) in ('F') then sex = 'F';
	      else if upcase(sex) in ('M') then sex = 'M';
	      else sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Final Clean-up                                 
		------------------------------------------------------------------------SASDOC*;
		
		if &do_practice_id. in (475) then do;
			if index(lname,'/') not in (.,0) then do;
				lname = trim(substr(lname,1,index(lname,'/') - 1));
			end;
			if index(fname,'/') not in (.,0) then do;
				fname = trim(substr(fname,1,index(fname,'/') - 1));
			end;
			lname = compress(lname,'*');
			fname = compress(fname,'*');
		end;

		if address1 = '.' then address1 = '';
		if address2 = '.' then address2 = '';
		state=compress(state,'.');
		state=substr(state,1,2);	
		if fname = '.' then fname = '';
		if payorid1='' then payorid1='0';
		phone = left(trim(phone));
		if mname = '.' then mname = '';
	  
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

	    drop casenum visitnum dob0 svcdt0 svcdt2 dob2 dx1 __mod1 _mod1 _mod2 _mod3 _procmod1 _pos submit2 moddt2 createdt2 createdt0;
	run;	


 

%mend vmine_pmsystem_5;
