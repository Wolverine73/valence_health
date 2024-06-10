
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_6
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the practice point manager pm system practice data   
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
| 23AUG2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
| 18AUG2011 - G Liu - Clinical Integration 2.0.01
|			  1. Added pos smart logic to handle all practices including new ones
|					a. If practice has no records in dept table, default pos to 11
|					b. If has known junk records only, also default to 11
|					c. Otherwise, we do practice-specific mapping
|			  2. Added compress +- for diag
|             
+-----------------------------------------------------------------------HEADER*/
 %macro vmine_pmsystem_6;

	%*SASDOC--------------------------------------------------------------------------
	| Perform department table audit to decide pos default of 11 or not
	------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
		connect to oledb(init_string=&emine.);
		select 	deptcnt
		into	:m_deptcnt
		from connection to oledb
		(	
			select	count(*) as deptcnt	               
			from    dbo.PracticePointManager_department
			where	kpracticeid = &do_practice_id.
		  %if &do_practice_id.=170 %then %do;
			and 	departmentid <> '784.2'
		  %end;
		  %else %if &do_practice_id.=660 %then %do;
			and 	departmentid not in ('BRA','LATT')
		  %end;
		);
	quit;
	%put Practice &do_practice_id. has &m_deptcnt. "valid" records in department table.;
 	
	
	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id.(drop=_pos  rename=(claimnum2=claimnum linenum2=linenum));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $50. pos $2.;
	  set practice_&do_practice_id.(rename=(diag1=_diag1 diag2=_diag2 diag3=_diag3 diag4=_diag4));

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
		| POS     
		------------------------------------------------------------------------SASDOC*;
		%if &m_deptcnt.=0 %then %do;
            pos = '11';	
		%end;
		%else %if &do_practice_id. = 172 %then %do;
		   if _pos = 'OP' then pos = '11';
			else if _pos = 'IP' then pos = '21';
			else if _pos = 'XRAY' then pos = '99';
			else if _pos = 'DXA' then pos = '99';
			else if _pos = 'CT/MRI' then pos = '99';
			else if _pos = 'EMG' then pos = '23';
			else if _pos = 'LBIN' then pos = '99';
			else if _pos = 'LBSO' then pos = '99';
			else if _pos = 'PT' then pos = '62';
		%end;

		%*SASDOC--------------------------------------------------------------------------
		| Diags       
		------------------------------------------------------------------------SASDOC*;

		format diag1-diag4 $6.;
		%do k = 1 %to 4;
			_diag&k.=compress(_diag&k.,'+-');
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
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
	    if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
	    if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
	    else memberid = ssn;
		
		%*SASDOC--------------------------------------------------------------------------
		| Claim and line number                               
		------------------------------------------------------------------------SASDOC*; 
	    claim_number=claimnum*1;
        claimnum2 = left(put(claimnum,8.));
		line_number=linenum;
	    linenum2=left(put(linenum,8.));

		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

		
		drop casenum visitnum svcdt2 createdt2 moddt2 dob2 submit2 linenum claimnum _diag1-_diag4;



	run;	
	
	%*SASDOC--------------------------------------------------------------------------
	| Remove duplicate claims - include maximum process ID to keep the latest  
	| claims for the practice data
	------------------------------------------------------------------------SASDOC*;	
	proc sort data=practice_&do_practice_id.;
	  by claimnum descending linenum descending moddt descending maxprocessid ;
	run;
	
	data practice_&do_practice_id.;
     set practice_&do_practice_id.;
	 by claimnum descending linenum descending moddt descending maxprocessid ;
	 if first.linenum;
	run;
	

%mend vmine_pmsystem_6;
