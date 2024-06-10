
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_1
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the medisoft pm system practice data   
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
|   \
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 26JAN2012 - Brian Stropich  - Clinical Integration  1.1.02
|             Adding 628 diagnosis cleansing logic - missing decimals
|
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_1;

	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. (rename=(claimnum2=claimnum linenum2=linenum));
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40. source $1.;
	  set practice_&do_practice_id. ;		  	

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
		| Missing values for variables                                
		------------------------------------------------------------------------SASDOC*;
		if memberid='.' then memberid="";
		if ssn='.' then ssn="";
		if mname='.' then mname="";
		if pos='.' then pos="";
		if address1='.' then address1="";
		if address2='.' then address2="";
		if state='.' then state="";

		%*SASDOC--------------------------------------------------------------------------
		| Fname                                                       
		------------------------------------------------------------------------SASDOC*;
		fname=left(compress(fname,'+'));

		%*SASDOC--------------------------------------------------------------------------
		| Practice reformat - proccd diags payorname      
		------------------------------------------------------------------------SASDOC*;
		if kpracticeid = 256 then do;
			if length(_proccd) = 6 then do;
			  proccd = upcase(compress(trim(substr(_proccd,2,5)),'.'));
			end;
		    else do;
			  proccd = upcase(compress(trim(substr(_proccd,1,5)),'.'));
			end;
		end;
		else do;
		  proccd = upcase(compress(trim(substr(_proccd,1,5)),'.'));
		end; 		

		if kpracticeid in (274,1229) then do;

			%do diag = 1 %to 4; /*07JUN2011 - WLee - logic for diag cleanup with 274 and 270 changed in Medisoft 16*/
				if substr(diag&diag.,1,1) ne 'E' and diag&diag. ne '' then do;
					if length(diag&diag.)=5 then do;
						diag&diag.=substr(diag&diag.,1,3) || "." || substr(diag&diag.,4,2) ;
					end;
					else if length(diag&diag.)=4 then do;
						diag&diag.=substr(diag&diag.,1,3) || "." || substr(diag&diag.,4,1) ;
					end;
					else if length(diag&diag.)le 3 then do;
						diag&diag.=substr(diag&diag.,1,3);
					end;
				end;
				else if substr(diag&diag.,1,1) = 'E' and diag&diag. ne '' then do;
					if length(diag&diag.)=5 then do;
						diag&diag.=substr(diag&diag.,1,4) || "." || substr(diag&diag.,5,1) ;
					end;
					else if length(diag&diag.)<=4 then do;
						diag&diag.=substr(diag&diag.,1,4);
					end;
				end;
				else diag&diag. = diag&diag.;
			%end;
		end; 
		else if kpracticeid in (628,1009) then do; 
		   	   
		   array diag  {*} diag1-diag4 ;
		   array indx  {*} i1-i4 ;
		   array lngth {*} l1-l4 ;
		   array subt  {*} $1 sub1-sub4 ;
		   
		   do j = 1 to dim(diag) ;
		     indx{j}=indexc(diag{j},".");
		     lngth{j}=length(diag{j});
			 subt{j} =substr(diag{j},1,1);
			 if subt{j} ne 'E' then do;
		       if lngth{j} > 3 and indx{j} = 0 then do;  /*** performed if diagnosis is missing **/
		         diag{j}=substr(diag{j},1,3)||"."||substr(diag{j},4);
		       end; 
			 end;
			 else do;  
		       if lngth{j} > 4 and indx{j} = 0 then do;
		         diag{j}=substr(diag{j},1,4)||"."||substr(diag{j},5);
		       end; 
			 end;
		   end;

		   drop i1-i4 l1-l4 sub1-sub4 j;
   		end;
		else if kpracticeid = 295 then do;
		    if diag1 = 'V0381' then diag1 = 'V03.81';
		    if diag2 = 'V0381' then diag2 = 'V03.81';
		    if diag3 = 'V0381' then diag3 = 'V03.81';
			if diag4 = 'V0381' then diag4 = 'V03.81';
		end;
		else if kpracticeid = 31 then do;
			if tin in ('','.') then tin='364032157';
		end;
		else if kpracticeid =37 then do;
			if tin in ('','.') then tin='200587989';
		end;
/*		else if kpracticeid = 42 then do;*/
/*			 if payorid1='CCN'   then payorname1='CCN';*/
/*			else if payorid1='HCI'   then payorname1='HCI';*/
/*			else if payorid1='IAC'   then payorname1='IAC';*/
/*			else if payorid1='SAMBA' then payorname1='SAMBA';*/
/*			else if payorid1='UMR'   then payorname1='UMR';*/
/*		end;*/
/*		else if kpracticeid = 62 then do;*/
/*		    if payorid1='CCMSI' then payorname1='CCMSI';*/
/*		end;*/
/*		else if kpracticeid = 92 then do;*/
/*			if payorid1='MMSI' then payorname1='MMSI';*/
/*		    else if payorid1='PAI'  then payorname1='PAI';*/
/*		end;*/
		else if kpracticeid = 295 then do;
			%do diag = 1 %to 4 ;
				if diag&diag. = 'V0381' then diag&diag. = 'V03.81';
			%end; 
		end;


		%do diag = 1 %to 4;
			if diag&diag.="     ." then diag&diag. = "";
			if index(diag&diag.,'.')=4 and substr(diag&diag.,5,2)="" then diag&diag.=compress(diag&diag.,'.');
		%end;   

		%*SASDOC--------------------------------------------------------------------------
		| Diags       
		------------------------------------------------------------------------SASDOC*;
		if diag1="     ." then diag1 = "";
		if diag2="     ." then diag2 = "";
		if diag3="     ." then diag3 = "";
		if diag4="     ." then diag4 = "";
		if diag1="000000" then diag1 = "";
		if diag2="000000" then diag2 = "";
		if diag3="000000" then diag3 = "";
		if diag4="000000" then diag4 = "";
		if index(diag1,'.')=4 and substr(diag1,5,2)="" then diag1=compress(diag1,'.');
		if index(diag2,'.')=4 and substr(diag2,5,2)="" then diag2=compress(diag2,'.');
		if index(diag3,'.')=4 and substr(diag3,5,2)="" then diag3=compress(diag3,'.');
		if index(diag4,'.')=4 and substr(diag4,5,2)="" then diag4=compress(diag4,'.');	

		/*Clean up logic from Medisoft16*/
		if diag8 not in ("") and diag7 in ("") then do;
			diag7 = diag8;
			diag8= "";
		end;
		if diag7 not in ("") and diag6 in ("") then do;
			diag6 = diag7;
			diag7= "";
		end;
		if diag6 not in ("") and diag5 in ("") then do;
			diag5 = diag6;
			diag6= "";
		end;
		if diag5 not in ("") and diag4 in ("") then do;
			diag4 = diag5;
			diag5= "";
		end;
		if diag4 not in ("") and diag3 in ("") then do;
			diag3 = diag4;
			diag4= "";
		end;
		if diag3 not in ("") and diag2 in ("") then do;
			diag2 = diag3;
			diag3= "";
		end;
		if diag2 not in ("") and diag1 in ("") then do;
			diag1 = diag2;
			diag2= "";
		end; 

		%*SASDOC--------------------------------------------------------------------------
		| Mod       
		------------------------------------------------------------------------SASDOC*;
		mod1 = compress(cats(mod1),"'""+""`""[""]");
		mod2 = compress(cats(mod2),"'""+""`""[""]");
		if left(compress(mod1))='.' then mod1 = '';
		if left(compress(mod2))='.' then mod2 = ''; 

		if mod1 in ("") and mod2 not in ("") then do;
			mod1=mod2;
			mod2="";
		end;

		pos	= compress(pos,"'""+""`""[""]");

		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;
		if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if trim(ssn) in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') or
		   trim(ssn) in ('111111111', '222222222', '333333333', '444444444', '555555555', '666666666', '888888888', '999999999',
						'99999999 ', '123456789') or
		   indexc(ssn, 'abcdefghijklmnopqrtsuvwxyz') not in (0, .) then memberid='';

		%*SASDOC--------------------------------------------------------------------------
		| Payor                                    
		------------------------------------------------------------------------SASDOC*;
		**payorid1=compress(upcase(payorid1),' ');
		**payorid1=upcase(payorid1);
		payorname1=left(payorname1);
		if payorname1='.' then payorname1='';

		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
/*		%if &client_id. = 1 %then %do;*/
	    /*  provid=upin;*/ /** Adventist Only **/
/*		%end;*/
/*		%else %do;*/
		  provid=npi; /** All other CI Clients **/
/*		%end;*/

		%if &practice_id. = 706 %then %do;
			if npi = '1962490052' and cats(provname) = 'BERBERIAN, ESTEBAN' then npi = '1750545901';
		%end;

		%if &practice_id. = 289 %then %do;
			if length(proccd) < 5 then delete;
		%end;

		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
		claim_number=claimnum;
        line_number=linenum;
		claimnum2=left(put(claimnum,8.));
        linenum2=left(put(linenum,8.));
		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';

		drop /*patid*/ svcdt2 createdt2 moddt2 dob2 submit2 claimnum linenum;
	run;

%mend vmine_pmsystem_1;
