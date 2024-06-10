
/*HEADER------------------------------------------------------------------------
|
| program:  dq_create_dataset.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create the data quality data set with all the validations
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
| 01APR2010 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
| 04MAY2011 - Nick Williams   - Clinical Integration  1.0.02
|             Create vMine Load Report datasets here.
|
| 03JAN2011 - Nick Williams - Clinical Integration  1.0.02
|             Add data validation for NPI CI participation variable.
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_create_dataset;

 	%createvarloop(list=&assessvariables., prefix=validation_);
	%createvarloop(list=&assessvariables., prefix=issue_);

	*--------------------------------------------------------------------------------
	| data validations
	+------------------------------------------------------------------------------*;
	proc contents data = &datasetin. out = contents_npi;
	run;
	
	proc sql noprint;
	  select count(*) into: contents_npi
	  from contents_npi
	  where upcase(name) = 'PROVNAME';
	quit;	
	
	data pm_&practice. ;
	  length &validation_ $10 		 
		 &issue_      $40 ;
	  set  &datasetin. &filename_where. ;

		count=1;

		*--------------------------------------------------------------------------------
		| fname validation
		+------------------------------------------------------------------------------*;
		%if &FNAMEIND=YES %then %do;		
		fnameindex=indexc(upcase(fname),'0123456789!@#$%^&*()+_=:<>?/\');

		if missing(fname) then do;
		  validation_fname = 'Invalid';
		  issue_fname = 'Missing Values';
		end;
		else if fnameindex gt 0 then do;
		  validation_fname = 'Invalid';
		  issue_fname = 'Invalid Values';
		end;
		else do;
		  validation_fname = 'Valid';
		  issue_fname = ' ';
		end;
		%end;
		%else %do;
		  validation_fname = 'DNE';
		  issue_fname = 'Does Not Exist';	
		%end;	


		*--------------------------------------------------------------------------------
		| lname validation
		+------------------------------------------------------------------------------*;
		%if &LNAMEIND=YES %then %do;	
		lnameindex=indexc(upcase(lname),'0123456789!@#$%^&*()+_=:<>?/\');


		if missing(lname) then do;
		  validation_lname = 'Invalid';
		  issue_lname = 'Missing Values';
		end;
		else if lnameindex gt 0 then do;
		  validation_lname = 'Invalid';
		  issue_lname = 'Invalid Values';
		end;
		else do;
		  validation_lname = 'Valid';
		  issue_lname = ' ';
		end;
		%end;
		%else %do;
		  validation_lname = 'DNE';
		  issue_lname = 'Does Not Exist';	
		%end;	

		*--------------------------------------------------------------------------------
		| address1 validation
		+------------------------------------------------------------------------------*;
		%if &ADDRESS1IND=YES %then %do;
		if missing(address1) then do;
		  validation_address1 = 'Invalid';
		  issue_address1 = 'Missing Values';
		end;
		else do;
		  validation_address1 = 'Valid';
		  issue_address1 = ' ';
		end;
		%end;
		%else %do;
		  validation_address1 = 'DNE';
		  issue_address1 = 'Does Not Exist';	
		%end;

		*--------------------------------------------------------------------------------
		| city validation
		+------------------------------------------------------------------------------*;
		%if &CITYIND=YES %then %do;
		if missing(city) then do;
		  validation_city = 'Invalid';
		  issue_city = 'Missing Values';
		end;
		else do;
		  validation_city = 'Valid';
		  issue_city = ' ';
		end;
		%end;
		%else %do;
		  validation_city = 'DNE';
		  issue_city = 'Does Not Exist';	
		%end;	

		*--------------------------------------------------------------------------------
		| state validation
		+------------------------------------------------------------------------------*;
		%if &STATEIND=YES %then %do;	
		if missing(state) then do;
		  validation_state = 'Invalid';
		  issue_state = 'Missing Values';
		end;
		else do;
		  validation_state = 'Valid';
		  issue_state = ' ';
		end;
		%end;
		%else %do;
		  validation_state= 'DNE';
		  issue_state = 'Does Not Exist';	
		%end;	


		*--------------------------------------------------------------------------------
		| zipcode validation
		+------------------------------------------------------------------------------*;
		%if &ZIPIND=YES %then %do;	
		if missing(zip) then do;
		  validation_zip = 'Invalid';
		  issue_zip = 'Missing Values';
		end;
		else if put(cats(zip),$LatXwalk.) = "" then do;
		  validation_zip = 'Invalid';
		  issue_zip = 'DNE Values';
		end;
		else do;
		  validation_zip = 'Valid';
		  issue_zip = ' ';
		end;
		%end;
		%else %do;
		  validation_zip = 'DNE';
		  issue_zip = 'Does Not Exist';	
		%end;	

		*--------------------------------------------------------------------------------
		| pos validation
		+------------------------------------------------------------------------------*;
		%if &POSIND=YES %then %do;	
		if missing(pos) then do;
		  validation_pos = 'Invalid';
		  issue_pos = 'Missing Values';
		end;
		else do;
		  validation_pos = 'Valid';
		  issue_pos = ' ';
		end;
		%end;
		%else %do;
		  validation_pos = 'DNE';
		  issue_pos = 'Does Not Exist';	
		%end;		


		*--------------------------------------------------------------------------------
		| dob validation
		+------------------------------------------------------------------------------*;
		%if &DOBIND=YES %then %do;
		dobindex=indexc(upcase(dob),'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
		dobnumberindex=indexc(dob,'0123456789');	

		if dobnumberindex > 0  and missing(dob) then do;
		   validation_dob='Invalid';
		   issue_dob='Invalid Formats';
		end;
		else if dobindex > 0 then do;
		   validation_dob='Invalid';
		   issue_dob='Invalid Values - Characters';
		end;
		else if missing(dob) then do;
		  validation_dob = 'Invalid';
		  issue_dob = 'Missing Values';
		end;
		else if dob > today() or dobindex gt 0 then do;
		  validation_dob = 'Invalid';
		  issue_dob = 'Invalid Values';
		end;
		else do;
		  validation_dob = 'Valid';
		  issue_dob = ' ';
		end;
		%end;
		%else %do;
		  validation_dob = 'DNE';
		  issue_dob = 'Does Not Exist';	
		%end;	


		*--------------------------------------------------------------------------------
		| phone validation
		+------------------------------------------------------------------------------*;
		%if &PHONEIND=YES %then %do;
		phone=compress(phone,"()- ");
		phonelength=length(phone);
		phoneindex=indexc(upcase(phone),'ABCDEFGHIJKLMNOPQRSTUVWXYZ');	

		if missing(phone) then do;
		  validation_phone = 'Invalid';
		  issue_phone = 'Missing Values';
		end;
		else if phoneindex gt 0 then do;
		  validation_phone = 'Invalid';
		  issue_phone = 'Invalid Values';
		end;
		else if substr(phone,4,1) in ("0","1") or substr(phone,4,3) = "555" then do;
		  validation_phone = 'Invalid';
		  issue_phone = 'Invalid Number';
		end;
		else if substr(phone,1,3) not in (
				"201","202","203","204","205","206","207","208","209","210","212","213","214","215","216","217","218","219","224",
				"225","226","228","229","231","234","236","239","240","242","246","248",
				"250","251","252","253","254","256","260","262","264","267","268","269","270",
				"276","278","281","283","284","289",
				"301","302","303","304","305","306","307","308","309","310","312","313","314","315","316","317","318","319","320","321","323",
				"325","330","331","334","336","337","339","340","341","345","347",
				"351","352","360","361","369",
				"380","385","386",
				"401","402","403","404","405","406","407","408","409","410","412","413","414","415","416","417","418","419","423","424",
				"425","430","432","434","435","438","440","441","442","443",
				"450","464","469","470","473",
				"475","478","479","480","484",
				"501","502","503","504","505","506","507","508","509","510","512","513","514","515","516","517","518","519","520",
				"530","540","541",
				"551","557","559","561","562","563","564","567","570","571","573","574",
				"575","580","585","586",
				"600","601","602","603","604","605","606","607","608","609","610","612","613","614","615","616","617","618","619","620","623",
				"626","627","628","630","631","636","641","646","647","649",
				"650","651","660","661","662","664","669","670","671",
				"678","679","682","684","689",
				"700","701","702","703","704","705","706","707","708","709","710","711","712","713","714","715","716","717","718","719","720","724",
				"727","731","732","734","737","740","747",
				"754","757","758","760","762","763","764","765","767","769","770","772","773","774",
				"775","778","779","780","781","784","785","786","787",
				"800","801","802","803","804","805","806","807","808","809","810","812","813","814","815","816","817","818","819",
				"828","829","830","831","832","835","843","845","847","848",
				"850","856","857","858","859","860","862","863","864","865","866","867","868","869","870","872",
				"876","878",
				"901","902","903","904","905","906","907","908","909","910","911","912","913","914","915","916","917","918","919","920",
				"925","927","928","931","935","936","937","939","940","941","947","949",
				"951","952","954","956","957","959","970","971","972","973",
				"975","978","979","980","984","985","989"

		 ) then do;
		  validation_phone = 'Invalid';
		  issue_phone = 'Invalid Area Code';
		end;
		else if phonelength ne 10 then do;
		  validation_phone = 'Invalid';
		  issue_phone = 'Invalid Lengths';
		end;
		else do;
		  validation_phone = 'Valid';
		  issue_phone = ' ';
		end;
		%end;
		%else %do;
		  validation_phone = 'DNE';
		  issue_phone = 'Does Not Exist';	
		%end;	


		*--------------------------------------------------------------------------------
		| member ID validation
		+------------------------------------------------------------------------------*;
		%if &MEMBERIDIND=YES %then %do;	
		memberid = compress(memberid,"-");
		memlength=length(memberid);
		memindex=indexc(upcase(memberid),'ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()+-_=:<>,.?/\');	

		if missing(memberid) then do;
		  validation_memberid = 'Invalid'; 
		  issue_memberid = 'Missing Values';
		end;
		else if upcase(memberid) in ('000000000','111111111','222222222','333333333','444444444','555555555',
								     '666666666','777777777','888888888','999999999','123456789','MISSING')  
			or memindex  gt 0 then do;
		  validation_memberid = 'Invalid'; 
		  issue_memberid = 'Invalid Values';
		end;
		else if memlength ne 9 then do;
		  validation_memberid = 'Invalid'; 
		  issue_memberid = 'Invalid Lengths';
		end;
		else do;
		  validation_memberid = 'Valid';
		  issue_memberid = '';
		end;
		%end;
		%else %do;
		  validation_memberid = 'DNE';
		  issue_memberid = 'Does Not Exist';	
		%end;	


		*--------------------------------------------------------------------------------
		| sex validation
		+------------------------------------------------------------------------------*;
		%if &SEXIND=YES %then %do;
		if upcase(sex) in ('M','F') then do;
		  validation_sex = 'Valid';
		  issue_sex = '';
		end;
		else if missing(sex) then do;
		  validation_sex = 'Invalid'; 
		  issue_sex = 'Missing Values';
		end;
		else do;
		  validation_sex = 'Invalid';
		  issue_sex = 'Invalid Values';
		end;
		%end;
		%else %do;
		  validation_address1 = 'DNE';
		  issue_address1 = 'Does Not Exist';	
		%end;	 


		*--------------------------------------------------------------------------------
		| npi validation
		+------------------------------------------------------------------------------*;
		%if &NPIIND=YES %then %do;
		temp_npi=put(npi, $ProvYN. );
		length provid_luhn $15.  luhnsum_mod10 $6 npi_provname $75;
		%if &contents_npi. ne 0 %then %do;
		  npi_provname=trim(npi)||" - "||trim(provname);
		%end;
		%else %do;
		  npi_provname=trim(npi);
		%end;
		provid_luhn = "80840" || npi;
		
		luhn_num1 = substr(provid_luhn,1,1)*1;
		luhn_num2 = substr(provid_luhn,2,1)*1*2;
		luhn_num3 = substr(provid_luhn,3,1)*1;
		luhn_num4 = substr(provid_luhn,4,1)*1*2;
		luhn_num5 = substr(provid_luhn,5,1)*1;
		luhn_num6 = substr(provid_luhn,6,1)*1*2;
		luhn_num7 = substr(provid_luhn,7,1)*1;
		luhn_num8 = substr(provid_luhn,8,1)*1*2;
		luhn_num9 = substr(provid_luhn,9,1)*1;
		luhn_num10 = substr(provid_luhn,10,1)*1*2;
		luhn_num11 = substr(provid_luhn,11,1)*1;
		luhn_num12 = substr(provid_luhn,12,1)*1*2;
		luhn_num13 = substr(provid_luhn,13,1)*1;
		luhn_num14 = substr(provid_luhn,14,1)*1*2;
		luhn_num15 = substr(provid_luhn,15,1)*1;

		luhn_char2 = put(luhn_num2,z2.);
		luhn_char4 = put(luhn_num4,z2.);
		luhn_char6 = put(luhn_num6,z2.);
		luhn_char8 = put(luhn_num8,z2.);
		luhn_char10 = put(luhn_num10,z2.);
		luhn_char12 = put(luhn_num12,z2.);
		luhn_char14 = put(luhn_num14,z2.);

		luhn_num2_1 = substr(luhn_char2,1,1)*1;
		luhn_num2_2 = substr(luhn_char2,2,1)*1;
		luhn_num4_1 = substr(luhn_char4,1,1)*1;
		luhn_num4_2 = substr(luhn_char4,2,1)*1;
		luhn_num6_1 = substr(luhn_char6,1,1)*1;
		luhn_num6_2 = substr(luhn_char6,2,1)*1;
		luhn_num8_1 = substr(luhn_char8,1,1)*1;
		luhn_num8_2 = substr(luhn_char8,2,1)*1;
		luhn_num10_1 = substr(luhn_char10,1,1)*1;
		luhn_num10_2 = substr(luhn_char10,2,1)*1;
		luhn_num12_1 = substr(luhn_char12,1,1)*1;
		luhn_num12_2 = substr(luhn_char12,2,1)*1;
		luhn_num14_1 = substr(luhn_char14,1,1)*1;
		luhn_num14_2 = substr(luhn_char14,2,1)*1;
		luhnsum_mod10 = sum(luhn_num1,luhn_num3,luhn_num5,luhn_num7,luhn_num9,luhn_num11,luhn_num13,luhn_num15,
				luhn_num2_1,luhn_num2_2,luhn_num4_1,luhn_num4_2,luhn_num6_1,luhn_num6_2,luhn_num8_1,
				luhn_num8_2,luhn_num10_1,luhn_num10_2,luhn_num12_1,luhn_num12_2,luhn_num14_1,luhn_num14_2) / 10;

		if upcase(temp_npi)='Y' then do;
		   validation_npi='Valid';
		   issue_npi=' ';
		end;
		else if missing(npi) then do;
		   validation_npi='Invalid';
		   issue_npi='Missing Values';
		end;
		else do;
		   validation_npi='Invalid'; 
		   issue_npi='Invalid Values';
		end;
		if not missing(npi) and 
		   (index(luhnsum_mod10,".") ge 1 or
		   length(cats(provid_luhn)) lt 15 or
		   indexc(provid_luhn,"QWERTYUIOPASDFGHJKLZXCVBNM") ge 1) then do;
		   validation_npi='Invalid'; 
		   issue_npi='Invalid Values - Luhn';		
		end;		
		%end;
		%else %do;
		  validation_npi = 'DNE';
		  issue_npi = 'Does Not Exist';	
		%end;	

		*--------------------------------------------------------------------------------
		| npicipar validation
		| ncw added
		+------------------------------------------------------------------------------*;
		%if &NPICIPARIND=YES %then %do;			
			validation_npicipar = ifc(npicipar=1, 'Valid', 'Invalid');
			issue_npicipar = ifc(npicipar=1, 'Partcipating', 'Not Partcipating');
		%end;
		%else %do;
		  validation_npicipar = 'DNE';
		  issue_npicipar = 'Does Not Exist';	
		%end;	

		*--------------------------------------------------------------------------------
		| procedure validation
		+------------------------------------------------------------------------------*;
		%if &PROCCDIND=YES %then %do;
		if missing(proccd) then do;
		   validation_proccd='Invalid';
		   issue_proccd='Missing Values';
		end;		
		else if put(proccd,$cpt.)=proccd then do;
		   validation_proccd='Invalid';
		   issue_proccd='Invalid Values';
		end;
		else if put(proccd,$cpt.)='' then do;
		   validation_proccd='Invalid';
		   issue_proccd='Invalid Values';
		end;
		else do;
		   validation_proccd='Valid';
		   issue_proccd=' ';
		end;
		%end;
		%else %do;
		  validation_address1 = 'DNE';
		  issue_address1 = 'Does Not Exist';	
		%end;	


		*--------------------------------------------------------------------------------
		| diagnosis validation
		+------------------------------------------------------------------------------*;
		%if &DIAG1IND=YES %then %do;
		diag1length=length(diag1);
		diag2length=length(diag2);
		diag3length=length(diag3);

		if missing(diag1) then do;
		   validation_diag1='Invalid';
		   issue_diag1='Missing Values';
		end;
		else if put(diag1,$diag5cd.)=diag1 then do;
		   validation_diag1='Invalid';
		   issue_diag1='Invalid Values';
		end;
		else do;
		   validation_diag1='Valid';
		   issue_diag1=' ';
		end;
		%end;
		%else %do;
		  validation_address1 = 'DNE';
		  issue_address1 = 'Does Not Exist';	
		%end;	


		*--------------------------------------------------------------------------------
		| service dates validation
		+------------------------------------------------------------------------------*;
		%if &SVCDTIND=YES %then %do;
		svcdtindex=indexc(upcase(svcdt),'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
		svcdtnumberindex=indexc(svcdt,'0123456789');

		/***if &timestart. <= svcdt <= &timeend. then do;***/
		if missing(svcdt) then do;
		  validation_svcdt = 'Invalid';
		  issue_svcdt = 'Missing Values';
		end;
		else if svcdt <= today() then do;
		   validation_svcdt="Valid";
		   issue_svcdt='';
		end;
		else if svcdt > &timeend. then do;
		   validation_svcdt="Invalid";
		   issue_svcdt='Invalid Values - Future';
		end;		
		else if svcdtindex > 0 then do;
		   validation_svcdt='Invalid';
		   issue_svcdt='Invalid Values - Characters';
		end;
		else do;
		   validation_svcdt='Invalid';
		   issue_svcdt='Invalid Values';
		end;
		%end;
		%else %do;
		  validation_address1 = 'DNE';
		  issue_address1 = 'Does Not Exist';	
		%end;	


	run;
	
	%if &practice. ne 0 %then %do;  /** only vmine practices **/

	  *--------------------------------------------------------------------------------
	  | service dates validation - part 2
	  +------------------------------------------------------------------------------*;	
	  proc sql noprint;
	    select count(*) into: svcdt_check 
	    from pm_&practice.
	    where svcdt > intnx('month',today(),-1) 
	      and svcdt < intnx('month',today(),-0) ; 
	  quit;

	  %put NOTE: svcdt_check=&svcdt_check. ;
	
	  data pm_&practice. ;
	    set pm_&practice. ; 
	    
		flast="&filename_last.";
		fnow="&filename." ; 
		if trim(flast)=trim(fnow) then do;
		end;
		else do; 
		   validation_svcdt="Invalid";
		   issue_svcdt='Service dates DNE within latest file';
		end;  
		
		svcdt_check=&svcdt_check. ;
		if svcdt_check = 0 then do;
		   validation_svcdt="Invalid";
		   issue_svcdt='Service date cutoff';
		end;		
	  run;
	
	%end;
	
	
	*--------------------------------------------------------------------------------
	| quality control - data validations
	+------------------------------------------------------------------------------*;
	
	%if &practice. ne 0 %then %do;  /** only vmine practices **/

		data qc_&practice. ; 	  
		  length filedt $6. lname $25. fname $15.;
		  set  &datasetin. (keep = filename &keepvariables. );

		  pracID = substr(filename,1,index(filename,"-")-1);
		  filedt = substr(filename,index(filename,"-")+1,6);
		  provgroup2 = put(cats(pracID),$PracWalk.);						
		  if provgroup2 ne "";	

		  dateday = put(svcdt,weekdatx3.);
		  if upcase(dateday) in ("SAT","SUN") then delete;	  

		  count=1;

			*--------------------------------------------------------------------------------
			| fname validation
			+------------------------------------------------------------------------------*;
			%if &FNAMEIND=YES %then %do;		
			fnameindex=indexc(upcase(fname),'0123456789!@#$%^&*()+_=:<>?/\');

			if missing(fname) then do;
			  fname_fg=1;
			end;
			else if fnameindex gt 0 then do;
			  fname_fg=1;
			end;
			else do;
			  fname_fg=.;
			end;		
			%end;
			%else %do;
			  fname_fg=.;	
			%end;	


			*--------------------------------------------------------------------------------
			| lname validation
			+------------------------------------------------------------------------------*;
			%if &LNAMEIND=YES %then %do;	
			lnameindex=indexc(upcase(lname),'0123456789!@#$%^&*()+_=:<>?/\');


			if missing(lname) then do;
			  lname_fg=1;
			end;
			else if lnameindex gt 0 then do;
			  lname_fg=1;
			end;
			else do;
			  lname_fg=.;
			end;
			%end;
			%else %do;
			  lname_fg=.;	
			%end;	

			*--------------------------------------------------------------------------------
			| address1 validation
			+------------------------------------------------------------------------------*;
			%if &ADDRESS1IND=YES %then %do;
			if missing(address1) then do;
			  address1_fg=1;
			end;
			else do;
			  address1_fg=.;
			end;
			%end;
			%else %do;
			  address1_fg=.;	
			%end;

			*--------------------------------------------------------------------------------
			| city validation
			+------------------------------------------------------------------------------*;
			%if &CITYIND=YES %then %do;
			if missing(city) then do;
			  city_fg=1;
			end;
			else do;
			  city_fg=.;
			end;
			%end;
			%else %do;
			  city_fg=.;	
			%end;	

			*--------------------------------------------------------------------------------
			| state validation
			+------------------------------------------------------------------------------*;
			%if &STATEIND=YES %then %do;	
			if missing(state) then do;
			  state_fg=1;
			end;
			else do;
			  state_fg=.;
			end;
			%end;
			%else %do;
			  state_fg=.;	
			%end;	


			*--------------------------------------------------------------------------------
			| zipcode validation
			+------------------------------------------------------------------------------*;
			%if &ZIPIND=YES %then %do;	
			if missing(zip) then do;
			  zip_fg=1;
			end;
			else if put(cats(zip),$LatXwalk.) = "" then do;
			  zip_fg=1;
			end;
			else do;
			  zip_fg=.;
			end;
			%end;
			%else %do;
			  zip_fg=.;
			%end;	

			*--------------------------------------------------------------------------------
			| pos validation
			+------------------------------------------------------------------------------*;
			%if &POSIND=YES %then %do;	
			if missing(pos) then do;
			  pos_fg=1;
			end;
			else do;
			  pos_fg=.;
			end;
			%end;
			%else %do;
			  pos_fg=.;
			%end;		


			*--------------------------------------------------------------------------------
			| dob validation
			+------------------------------------------------------------------------------*;
			%if &DOBIND=YES %then %do;
			dobindex=indexc(upcase(dob),'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
			dobnumberindex=indexc(dob,'0123456789');	

			if dobnumberindex > 0  and missing(dob) then do;
			   dob_fg=1;
			end;
			else if dobindex > 0 then do;
			   dob_fg=1;
			end;
			else if missing(dob) then do;
			  dob_fg=1;
			end;
			else if dob > today() or dobindex gt 0 then do;
			  dob_fg=1;
			end;
			else do;
			  dob_fg=.;
			end;
			%end;
			%else %do;
			  dob_fg=.;
			%end;	


			*--------------------------------------------------------------------------------
			| phone validation
			+------------------------------------------------------------------------------*;
			%if &PHONEIND=YES %then %do;
			phone=compress(phone,"()- ");
			phonelength=length(phone);
			phoneindex=indexc(upcase(phone),'ABCDEFGHIJKLMNOPQRSTUVWXYZ');	

			if missing(phone) then do;
			  phone_fg=1;
			end;
			else if phoneindex gt 0 then do;
			  phone_fg=1;
			end;
			else if substr(phone,4,1) in ("0","1") or substr(phone,4,3) = "555" then do;
			  phone_fg=1;
			end;
			else if substr(phone,1,3) not in (
				"201","202","203","204","205","206","207","208","209","210","212","213","214","215","216","217","218","219","224",
				"225","226","228","229","231","234","236","239","240","242","246","248",
				"250","251","252","253","254","256","260","262","264","267","268","269","270",
				"276","278","281","283","284","289",
				"301","302","303","304","305","306","307","308","309","310","312","313","314","315","316","317","318","319","320","321","323",
				"325","330","331","334","336","337","339","340","341","345","347",
				"351","352","360","361","369",
				"380","385","386",
				"401","402","403","404","405","406","407","408","409","410","412","413","414","415","416","417","418","419","423","424",
				"425","430","432","434","435","438","440","441","442","443",
				"450","464","469","470","473",
				"475","478","479","480","484",
				"501","502","503","504","505","506","507","508","509","510","512","513","514","515","516","517","518","519","520",
				"530","540","541",
				"551","557","559","561","562","563","564","567","570","571","573","574",
				"575","580","585","586",
				"600","601","602","603","604","605","606","607","608","609","610","612","613","614","615","616","617","618","619","620","623",
				"626","627","628","630","631","636","641","646","647","649",
				"650","651","660","661","662","664","669","670","671",
				"678","679","682","684","689",
				"700","701","702","703","704","705","706","707","708","709","710","711","712","713","714","715","716","717","718","719","720","724",
				"727","731","732","734","737","740","747",
				"754","757","758","760","762","763","764","765","767","769","770","772","773","774",
				"775","778","779","780","781","784","785","786","787",
				"800","801","802","803","804","805","806","807","808","809","810","812","813","814","815","816","817","818","819",
				"828","829","830","831","832","835","843","845","847","848",
				"850","856","857","858","859","860","862","863","864","865","866","867","868","869","870","872",
				"876","878",
				"901","902","903","904","905","906","907","908","909","910","911","912","913","914","915","916","917","918","919","920",
				"925","927","928","931","935","936","937","939","940","941","947","949",
				"951","952","954","956","957","959","970","971","972","973",
				"975","978","979","980","984","985","989"
			) then do;
			  phone_fg=1;
			end;
			else if phonelength ne 10 then do;
			  phone_fg=1;
			end;
			else do;
			  phone_fg=.;
			end;
			%end;
			%else %do;
			  phone_fg=.;	
			%end;	


			*--------------------------------------------------------------------------------
			| member ID validation
			+------------------------------------------------------------------------------*;
			%if &MEMBERIDIND=YES %then %do;	
			memberid = compress(memberid,"-");
			memlength=length(memberid);
			memindex=indexc(upcase(memberid),'ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()+-_=:<>,.?/\');	

			if missing(memberid) then do;
			  memberid_fg=1;
			end;
			else if upcase(memberid) in ('000000000','111111111','222222222','333333333','444444444','555555555',
									     '666666666','777777777','888888888','999999999','123456789','MISSING')  
				or memindex  gt 0 then do;
			  memberid_fg=1;
			end;
			else if memlength ne 9 then do;
			  memberid_fg=1;
			end;
			else do;
			  memberid_fg=.;
			end;
			%end;
			%else %do;
			  memberid_fg=.;	
			%end;	


			*--------------------------------------------------------------------------------
			| sex validation
			+------------------------------------------------------------------------------*;
			%if &SEXIND=YES %then %do;
			if upcase(sex) in ('M','F') then do;
			  sex_fg=1;
			end;
			else if missing(sex) then do;
			  sex_fg=1;
			end;
			else do;
			  sex_fg=.;
			end;
			%end;
			%else %do;
			  sex_fg=.;	
			%end;	 


			*--------------------------------------------------------------------------------
			| npi validation
			+------------------------------------------------------------------------------*;
			%if &NPIIND=YES %then %do;
			temp_npi=put(npi, $ProvYN. );
			length provid_luhn $15.  luhnsum_mod10 $6;
			provid_luhn = "80840" || npi;

			luhn_num1 = substr(provid_luhn,1,1)*1;
			luhn_num2 = substr(provid_luhn,2,1)*1*2;
			luhn_num3 = substr(provid_luhn,3,1)*1;
			luhn_num4 = substr(provid_luhn,4,1)*1*2;
			luhn_num5 = substr(provid_luhn,5,1)*1;
			luhn_num6 = substr(provid_luhn,6,1)*1*2;
			luhn_num7 = substr(provid_luhn,7,1)*1;
			luhn_num8 = substr(provid_luhn,8,1)*1*2;
			luhn_num9 = substr(provid_luhn,9,1)*1;
			luhn_num10 = substr(provid_luhn,10,1)*1*2;
			luhn_num11 = substr(provid_luhn,11,1)*1;
			luhn_num12 = substr(provid_luhn,12,1)*1*2;
			luhn_num13 = substr(provid_luhn,13,1)*1;
			luhn_num14 = substr(provid_luhn,14,1)*1*2;
			luhn_num15 = substr(provid_luhn,15,1)*1;

			luhn_char2 = put(luhn_num2,z2.);
			luhn_char4 = put(luhn_num4,z2.);
			luhn_char6 = put(luhn_num6,z2.);
			luhn_char8 = put(luhn_num8,z2.);
			luhn_char10 = put(luhn_num10,z2.);
			luhn_char12 = put(luhn_num12,z2.);
			luhn_char14 = put(luhn_num14,z2.);

			luhn_num2_1 = substr(luhn_char2,1,1)*1;
			luhn_num2_2 = substr(luhn_char2,2,1)*1;
			luhn_num4_1 = substr(luhn_char4,1,1)*1;
			luhn_num4_2 = substr(luhn_char4,2,1)*1;
			luhn_num6_1 = substr(luhn_char6,1,1)*1;
			luhn_num6_2 = substr(luhn_char6,2,1)*1;
			luhn_num8_1 = substr(luhn_char8,1,1)*1;
			luhn_num8_2 = substr(luhn_char8,2,1)*1;
			luhn_num10_1 = substr(luhn_char10,1,1)*1;
			luhn_num10_2 = substr(luhn_char10,2,1)*1;
			luhn_num12_1 = substr(luhn_char12,1,1)*1;
			luhn_num12_2 = substr(luhn_char12,2,1)*1;
			luhn_num14_1 = substr(luhn_char14,1,1)*1;
			luhn_num14_2 = substr(luhn_char14,2,1)*1;
			luhnsum_mod10 = sum(luhn_num1,luhn_num3,luhn_num5,luhn_num7,luhn_num9,luhn_num11,luhn_num13,luhn_num15,
					luhn_num2_1,luhn_num2_2,luhn_num4_1,luhn_num4_2,luhn_num6_1,luhn_num6_2,luhn_num8_1,
					luhn_num8_2,luhn_num10_1,luhn_num10_2,luhn_num12_1,luhn_num12_2,luhn_num14_1,luhn_num14_2) / 10;

			if upcase(temp_npi)='Y' then do;
			   npi_fg=.;
			end;
			else if missing(npi) then do;
			   npi_fg=1;
			end;
			else do;
			   npi_fg=1;
			end;
			if not missing(npi) and 
			   (index(luhnsum_mod10,".") ge 1 or
			   length(cats(provid_luhn)) lt 15 or
			   indexc(provid_luhn,"QWERTYUIOPASDFGHJKLZXCVBNM") ge 1) then do;
			   npi_fg=1;		
			end;		
			%end;
			%else %do;
			  npi_fg=.;	
			%end;	


			*--------------------------------------------------------------------------------
			| procedure validation
			+------------------------------------------------------------------------------*;
			%if &PROCCDIND=YES %then %do;
			if missing(proccd) then do;
			   proccd_fg=1;
			end;		
			else if put(proccd,$cpt.)=proccd then do;
			   proccd_fg=1;
			end;
			else if put(proccd,$cpt.)='' then do;
			   proccd_fg=1;
			end;
			else do;
			   proccd_fg=.;
			end;
			%end;
			%else %do;
			  proccd_fg=.;	
			%end;	


			*--------------------------------------------------------------------------------
			| diagnosis validation
			+------------------------------------------------------------------------------*;
			%if &DIAG1IND=YES %then %do;
			diag1length=length(diag1); 

			if missing(diag1) then do;
			   diag1_fg=1;
			end;
			else if put(diag1,$diag5cd.)=diag1 then do;
			   diag1_fg=1;
			end;
			else do;
			   diag1_fg=.;
			end;
			%end;
			%else %do;
			  diag1_fg=.;	
			%end;	


			*--------------------------------------------------------------------------------
			| service dates validation
			+------------------------------------------------------------------------------*;
			%if &SVCDTIND=YES %then %do;
			svcdtindex=indexc(upcase(svcdt),'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
			svcdtnumberindex=indexc(svcdt,'0123456789');

			/***if &timestart. <= svcdt <= &timeend. then do;***/
			if missing(svcdt) then do;
			  svcdt_fg=1;
			end;		
			else if svcdt <= today() then do;
			   svcdt_fg=.;
			end;
			else if svcdt > &timeend. then do;
			   svcdt_fg=1;
			end;		
			else if svcdtindex > 0 then do;
			   svcdt_fg=1;
			end;
			else do;
			   svcdt_fg=1;
			end;
			%end;
			%else %do;
			  svcdt_fg=.;	
			%end;	

		*--------------------------------------------------------------------------------
		| npicipar validation
		| ncw added
		+------------------------------------------------------------------------------*;
		%if &NPICIPARIND=YES %then %do;			
			validation_npicipar = ifc(npicipar=1, 'Valid', 'Invalid');
			issue_npicipar = ifc(npicipar=1, 'Partcipating', 'Not Partcipating');
		%end;
		run;
	%end;

	*SASDOC--------------------------------------------------------------------
	| Create vmine dq dataset
	+--------------------------------------------------------------------SASDOC*;
	%DQ_VARLISTCHK(DATA=&datasetin.,varchk=%str(PROVNAME NPI NPI2 UPIN TIN));
    %global dqprov_vars;
    %let dqprov_vars=&VARLIST2.;

    proc summary data=&datasetin. nway missing;
    class &dqprov_vars.;
    output out=dqprov (drop=_type_ rename=_freq_=count);
    run;

    proc sql noprint;
	  select sum(count) into: dqprov_sumtotal
	  from dqprov;
	quit;

	data dqprov ;
      length percent 8.;
      format percent 8.2;
	  set dqprov ;
      percent = divide(count,&dqprov_sumtotal.);
	  totalrecs = &dqprov_sumtotal. ;
	run;

	proc datasets lib=work memtype=data;
	   modify dqprov; 
	     attrib _all_ label='';      
	run; 
	  contents data=dqprov;
	run;
	quit; 

	proc summary data=&datasetin. nway missing;
	format svcdt yymmn6.;
	class svcdt;
	output out=dqclmsum (drop=_type_ rename=_freq_=count);
	run;

	proc sort data=dqclmsum; by descending svcdt; run;

	*SASDOC--------------------------------------------------------------------
	| Split dataset by nth observations
	+--------------------------------------------------------------------SASDOC*;
	%macro splitdsnbyobs(dsn=,splitby=,macvar=);
	%global &macvar ;
    %countobs(dsn=&dsn,macvar=no_obs);
	%let no_obs=&no_obs; 	
	%do i=1 %to %sysfunc(ceil(&no_obs/&splitby));
		data &dsn.&i.;
		set &dsn (firstobs=%sysfunc(floor(%eval((&i.-1)*&splitby.+1))) obs=%sysfunc(ceil(%eval(&i * &splitby.))));        
		run;		
		%let &macvar=&i.; 
		%put Note: Macro variable &macvar. contains this no# of observations &&&macvar.;
	%end;
	%mend splitdsnbyobs;

	%splitdsnbyobs(dsn=dqclmsum,splitby=24,macvar=dqclmsumcols);	
	%splitdsnbyobs(dsn=dqprov,splitby=30,macvar=dqprovcols);


%mend dq_create_dataset;
