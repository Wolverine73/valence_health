
/*HEADER------------------------------------------------------------------------
|
| program:  pmsystem_dev_dq_create_dataset.sas
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
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro pmsystem_dev_dq_create_dataset;

 	%createvarloop(list=&assessvariables., prefix=validation_);
	%createvarloop(list=&assessvariables., prefix=issue_);

	*--------------------------------------------------------------------------------
	| data validations
	+------------------------------------------------------------------------------*;
	data pm_&practice. ;
	  length &validation_ $10 		 
		 &issue_      $20 ;
	  set  &datasetin.  ;

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
		else if put(cats(zip),$LatXwalk.) = . then do;
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
		else if substr(phone,1,3) not in ("205","251","256","334","907","480","520","602","623","928","479","501","870",
		"209","213","310","323","408","415","424","510","530","559","562","619","626","650","661","707","714","760","805","818","831","858","909","916","925","949",
		"303","719","720","970","203","475","860","959","302","239","305","321","352","386","407","561","727","754","772","786","813","850","863","904","941","954",
		"229","404","470","478","678","706","770","912","808","208","217","224","309","312","331","464","618","630","708","773","815","847","872",
		"219","260","317","574","765","812","319","515","563","641","712","316","620","785","913","270","502","606","859",
		"225","318","337","504","985","207","227","240","301","410","443","667","339","351","413","508","617","774","781","857","978",
		"231","248","269","313","517","586","616","734","810","906","947","989","218","320","507","612","651","763","952","228","601","662",
		"314","417","557","573","636","660","816","975","406","308","402","702","775","603","201","551","609","732","848","856","862","908","973","505",
		"212","315","347","516","518","585","607","631","646","716","718","845","914","917","252","336","704","828","910","919","980","984","701",
		"216","234","283","330","419","440","513","567","614","740","937","405","580","918","503","541","971",
		"215","267","412","445","484","570","610","717","724","814","835","878","401","803","843","864","605","423","615","731","865","901","931",
		"210","214","254","281","361","409","469","512","682","713","737","806","817","830","832","903","915","936","940","956","972","979",
		"435","801","802","276","434","540","571","703","757","804","206","253","360","425","509","564","202","304","262","414","608","715","920","307") then do;
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
	


%mend pmsystem_dev_dq_create_dataset;
