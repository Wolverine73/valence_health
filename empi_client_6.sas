
/*HEADER------------------------------------------------------------------------
|
| program:  empi_client_6.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Logic to extract Cleveland Clinic's EMPI data
|
| input:  	client_id - client number
|			filename - EMPI txt file
|                        
| output:  	Staging SAS datasets
|				cistage.empi_6_&wflow_exec_id. (empi & demographics)
|				cistage.empi_6_&wflow_exec_id._sysperid (empi & syspersid)
|				cistage.empi_6_&wflow_exec_id._xref (empi xref)
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 04JAN2011 - Abby Isaacs  - Clinical Integration
|       	  Original
| 28JAN2011 - Brandon Barber - Clinical Integration
|			  Production
| 27MAY2011 - Brandon Barber - Clinical Integration
|			  Revision for Member Merges
| 07NOV2011 - G Liu - Clinical Integration 2.0.01
|			  Added EDW processing codes.
|			  For EDW, minimal data scrubbing/standardizing, mostly data 
|				reformatting.
|			  Skipped Aaron's SSIS, merge field is read using SAS now.
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 01MAY2012 - G Liu - Clinical Integration 1.2.01
|			  Change to output 3 normalized datasets for faster processing
|			  Change target zip as $10. for Canadian zips
|			  Extend patient demographic fields length since EMPI can accommodate
|			  Move DQ report from load program to here so that we do not have to
|				unnecessarily read the dataset multiple times
| 10JUL2012 - G Liu - Clinical Integration 1.4.01
|			  Added missing logic to handle name that start with comma, to set
|				lname as null and fname from position 2 and on.
+-----------------------------------------------------------------------HEADER*/

%macro empi_client_6(incoming,m_force_filegen=);
	options compress=yes bufsize=128k bufno=1k;
	%let folderloc=\\fs\cccpp\data\crosswalk\EMPI\;

	%if %symexist(filename) %then %do; /* begin - skelta passes filename, for ongoing new files */
		%let txtfile1=&folderloc.&filename.;
		%let filedate=%substr(%scan(&filename.,2,'-'),1,8);
		%let filehour=%substr(%scan(&filename.,2,'-'),10,2);
		%let fileminute=%substr(%scan(&filename.,2,'-'),12,2);
		%let filesecond=%substr(%scan(&filename.,2,'-'),14,4);
		data _null_;
			if "&filedate." in ('20110430','20110531','20110630','20110731') then call symput('empi_oldformat','1');
			else call symput('empi_oldformat','0');
		run;
	%end; /* end - skelta filename */
	%else %do; /* begin - onboarding process of historical files using SAS Script instead of Skelta */
		filename pipefold pipe %unquote(%str(%'dir %")&folderloc.%str(\%" /b%'));
		data ec6_pipefolder;
			length filename $200.;
			infile pipefold truncover;
			input;
			filename=_infile_;
			format date $8.;
			if length(scan(filename,1,'._ '))=8 and verify(substr(scan(filename,1,'._ '),1,8),'0123456789')=0 then date=scan(filename,1,'._ ');
			else if length(scan(filename,-2,'._ '))=8 and verify(substr(scan(filename,-2,'._ '),1,8),'0123456789')=0 then date=scan(filename,-2,'._ ');
			else if length(scan(filename,-3,'._ '))=8 and verify(substr(scan(filename,-3,'._ '),1,8),'0123456789')=0 then date=scan(filename,-3,'._ ');
			if date ne: '20' then date=substr(date,5,4)||substr(date,1,4);
		run;

		proc sql noprint;
			select	max(date)
			into	:filedate
			from	ec6_pipefolder
		quit;

		%if &m_force_filegen. ne %then %let filedate=&m_force_filegen.;;
		%let filedate=&filedate.;
		%let filehour=0;
		%let fileminute=0;
		%let filesecond=0;

		data _null_;
			set ec6_pipefolder;
			where date="&filedate.";
			if index(upcase(filename),'UNPIVOT') then call symput('txtfile2',"&folderloc."||trim(filename));
			else call symput('txtfile1',"&folderloc."||trim(filename));
		run;
		%if %symexist(txtfile2)=0 %then %do;
			%if &filedate. ge 20111201 %then %do;
				%let empi_oldformat=0;
			%end;
			%else %do;
				%let empi_oldformat=1;
			%end;
		%end;
	%end; /* end - onboarding outside of skelta */

	options nosymbolgen;
	%put NOTE: Processing EMPI file with received date &filedate.;
	%put NOTE: EMPI file 1 is &txtfile1.;
	%if %symexist(txtfile2) %then %do;
	%put NOTE: EMPI file 2 is &txtfile2.;
	%end;

	%let interfacenum=50 200 210 230 240 250 300 310 320 330 340 400;
	%let interfacename=CCID CCHS_WR_EAD CCHS_WR_FVH_LUTH CCHS_WR_LKWH CCHS_WR_MMH MEDINA CCHS_ER_EAD CCHS_ER_HCH CCHS_ER_EUH CCHS_ER_HRH CCHS_ER_SPH CCF_FLORIDA;

	/* File path for DQ report */
	proc sql noprint;
		select	ClientName, scan(SASLogFileLocation,1,'\'), scan(SASLogFileLocation,2,'\')
		into	:ids_client_name, :ids_client_path1, :ids_client_path2
		from	ids.client
		where	ClientID=&client_id.;
	quit;
	%let ids_client_name=&ids_client_name;
	%let ids_client_path1=&ids_client_path1;
	%let ids_client_path2=&ids_client_path2;
	%if %symexist(sas_mode) and %upcase(&sas_mode.)=PROD %then %let xl=\\&ids_client_path1.\&ids_client_path2.\reports\Data_Quality_Reports\DataQuality_EMPI_&ids_client_name._&wflow_exec_id..txt;
	%else %let xl=\\&ids_client_path1.\&ids_client_path2.\reports\Data_Quality_Reports\test\DataQuality_EMPI_&ids_client_name._&wflow_exec_id..txt;

	options orientation=landscape pageno=1 ls=256 ps=83 missing=' ';
	proc printto file="&xl." new;

	/* Read text file */
	data 	&incoming.		(keep=EID newssn fname mname lname sex dob address1 address2 city newstate newzip newphone
					 		rename=(EID=enterprise_member_id newssn=ssn newstate=state newzip=zip newphone=phone))
			ec6_null_eid	(keep=EID ssn name dob gender address1 address2 city state zip phone)
			ec6_mrn			(keep=current EID Interface MRN)
	 		&incoming._xref	(keep=eid mrn rename=(eid=parent_enterprise_member_id mrn=enterprise_member_id));
		infile "&txtfile1." truncover delimiter='|' dsd lrecl=32767 firstobs=2;
		format MRN $50. interface 8. lname fname $50. mname $30. sex $1. newssn $9. newphone $10. newstate $2. newzip $10.;
		input @; 
		_infile_ = tranwrd(_infile_,"|'|","||"); 
		_infile_ = tranwrd(_infile_,'|"|','||'); 
		_infile_ = tranwrd(_infile_,'STOP|,','STOP,'); 
		input	EID: 				$50.
				CCID: 				$50.
				CCHS_WR_EAD: 		$60.
				CCHS_WR_FVH_LUTH: 	$20.
				CCHS_WR_LKWH: 		$10.
				CCHS_WR_MMH: 		$10.
				MEDINA: 			$50.
				CCHS_ER_EAD: 		$10.
				CCHS_ER_HCH: 		$10.
				CCHS_ER_EUH: 		$10.
				CCHS_ER_HRH: 		$10.
				CCHS_ER_SPH: 		$60.
				CCF_FLORIDA: 		$50.
				NAME: 				$100.
				DOB: 				MMDDYY10.
				GENDER: 			$7.
				ADDRESS1: 			$100.
			  %if &empi_oldformat. ne 1 %then %do;
				ADDRESS2:			$100.
			  %end;
				CITY: 				$50.
				STATE: 				$15.
				ZIP: 				$10.
				RACE: 				$20.
				PHONE: 				$25.
				STATUS: 			$20.
				SSN: 				$11.
				REPLACEMENTS:		$32767.
			;
		%if &empi_oldformat. %then %do;
		format address2 $1.;
		call missing(address2);
		%end;
		src_record_cnt+1;
		call symput('src_record_cnt',cats(src_record_cnt));

		array fix(*) name gender address1 address2 city state zip;
		do i=1 to dim(fix); fix(i)=upcase(fix(i)); end;

		if name ne '' then do;
			if index(name,',') gt 1 then do;
				lname=substr(name, 1, index(name, ',')-1);
				if length(name) gt index(name,',') then fname= substr(name, (index(name, ',')+ 1), (length(name)-index(name, ',')));
			end;
			else do;
				lname=''; 
				fname=substr(name,2);
			end;
		end;
		if scan(fname,1) ne scan(fname,-1) and length(scan(fname,-1))=1 then do;
			mname=scan(fname,-1);
			fname=substr(fname,1,length(fname)-length(mname));
		end;
		sex = gender;
		newssn = compress(ssn,"-");
		if address2='' and index(address1,'^') then do;
			address2=substr(address1,index(address1,'^')+1);
			address1=substr(address1,1,index(address1,'^')-1);
		end;
		if cats(state) = upcase("Alaska") then state = "AK";
		else if cats(state) = upcase("Alabama") then state = "AL";
		else if cats(state) = upcase("Arkansas") then state = "AR";
		else if cats(state) = upcase("American Samoa") then state = "AS";
		else if cats(state) = upcase("Arizona") then state = "AZ";
		else if cats(state) = upcase("California") then state = "CA";
		else if cats(state) = upcase("Colorado") then state = "CO";
		else if cats(state) = upcase("Connecticut") then state = "CT";
		else if cats(state) = upcase("District of Columbia") then state = "DC";
		else if cats(state) = upcase("Delaware") then state = "DE";
		else if cats(state) = upcase("Florida") then state = "FL";
		else if cats(state) = upcase("Federated States of Micronesia") then state = "FM";
		else if cats(state) = upcase("Georgia") then state = "GA";
		else if cats(state) = upcase("Guam") then state = "GU";
		else if cats(state) = upcase("Hawaii") then state = "HI";
		else if cats(state) = upcase("Iowa") then state = "IA";
		else if cats(state) = upcase("Idaho") then state = "ID";
		else if cats(state) = upcase("Illinois") then state = "IL";
		else if cats(state) = upcase("Indiana") then state = "IN";
		else if cats(state) = upcase("Kansas") then state = "KS";
		else if cats(state) = upcase("Kentucky") then state = "KY";
		else if cats(state) = upcase("Louisiana") then state = "LA";
		else if cats(state) = upcase("Massachusetts") then state = "MA";
		else if cats(state) = upcase("Maine") then state = "ME";
		else if cats(state) = upcase("Maryland") then state = "MD";
		else if cats(state) = upcase("Marshall Islands") then state = "MH";
		else if cats(state) = upcase("Michigan") then state = "MI";
		else if cats(state) = upcase("Minnesota") then state = "MN";
		else if cats(state) = upcase("Missouri") then state = "MO";
		else if cats(state) = upcase("Northern Mariana Islands") then state = "MP";
		else if cats(state) = upcase("Mississippi") then state = "MS";
		else if cats(state) = upcase("Montana") then state = "MT";
		else if cats(state) = upcase("North Carolina") then state = "NC";
		else if cats(state) = upcase("North Dakota") then state = "ND";
		else if cats(state) = upcase("Nebraska") then state = "NE";
		else if cats(state) = upcase("New Hampshire") then state = "NH";
		else if cats(state) = upcase("New Jersey") then state = "NJ";
		else if cats(state) = upcase("New Mexico") then state = "NM";
		else if cats(state) = upcase("Nevada") then state = "NV";
		else if cats(state) = upcase("New York") then state = "NY";
		else if cats(state) = upcase("Ohio") then state = "OH";
		else if cats(state) = upcase("Oklahoma") then state = "OK";
		else if cats(state) = upcase("Oregon") then state = "OR";
		else if cats(state) = upcase("Pennsylvania") then state = "PA";
		else if cats(state) = upcase("Puerto Rico") then state = "PR";
		else if cats(state) = upcase("Palau") then state = "PW";
		else if cats(state) = upcase("Rhode Island") then state = "RI";
		else if cats(state) = upcase("South Carolina") then state = "SC";
		else if cats(state) = upcase("South Dakota") then state = "SD";
		else if cats(state) = upcase("Tennessee") then state = "TN";
		else if cats(state) = upcase("Texas") then state = "TX";
		else if cats(state) = upcase("Utah") then state = "UT";
		else if cats(state) = upcase("Virgin Islands") then state = "VI";
		else if cats(state) = upcase("Vermont") then state = "VT";
		else if cats(state) = upcase("Virginia") then state = "VA";
		else if cats(state) = upcase("Washington") then state = "WA";
		else if cats(state) = upcase("Wisconsin") then state = "WI";
		else if cats(state) = upcase("West Virginia") then state = "WV";
		else if cats(state) = upcase("Wyoming") then state = "WY";
		newstate=state;
		newzip=compress(zip);
		newphone=compress(phone,'0123456789','k');
		if upcase(eid) not in ('END OF FILE') then do;
			if eid='' then output ec6_null_eid;
			else output &incoming.;

			array x(12) &interfacename.;
			do i=1 to dim(x);
				if x(i) ne '' then do;
					current=1;
					MRN=compress(x(i),'<>');
					interface=scan("&interfacenum.",i);
					if substr(MRN,1,1) ne "Z" then output ec6_mrn;
				end;
			end;
		end;

		z=1;
		lastmerge=1;
		do while (lastmerge);
			current=0;
			mrn=compress(scan(replacements,z,'^'),'<>');
			interface=scan(replacements,z+1,'^');
			if interface ne . then do;
				if interface in (&interfacenum.) and substr(MRN,1,1) ne "Z" then output ec6_mrn;
				else if interface=0 and mrn ne substr(eid,2) and mrn ne eid then output &incoming._xref;
			end;
			else lastmerge=0;
			z+2;
		end;
	run;
	%put NOTE: Source Record Count = &src_record_cnt.;

	options pageno=1;
	proc print data=ec6_null_eid n;
		title "Client &ids_client_name. EMPI file &filename.";
		title2 "Records with null enterprise_member_id";
		var EID ssn name dob gender address1 address2 city state zip phone;
		format ssn $11. name $40. dob mmddyy10. gender $1. address1 $15. address2 $5. city $15. state $2. zip $5. phone $10.;
	run; title;

	/* We expect incoming EMPI file to have 1 set of demographic information per EMPI. If that's not the case, we will not use
		the record, because we won't know which set of demographic information to load to patient table as the gold standard. */
	proc sql;
		create table ec6_eid_dup as
		select	*
		from	&incoming.
		group by enterprise_member_id
		having	count(*) ne 1;
	quit;

	%let ec6_dsid=%sysfunc(open(ec6_eid_dup));
	%let ec6_nobs=%sysfunc(attrn(&ec6_dsid.,nobs));
	%let ec6_dsrc=%sysfunc(close(&ec6_dsid.));
	%if &ec6_nobs. %then %do;
		options pageno=1;
		proc print data=ec6_eid_dup n;
			title "Client &ids_client_name. EMPI file &filename.";
			title2 "EID with multiple records";
			var enterprise_member_id ssn name dob gender address1 address2 city state zip phone;
			format ssn $11. name $40. dob mmddyy10. gender $1. address1 $15. address2 $5. city $15. state $2. zip $5. phone $10.;
		run; title;

		proc sql;
			create table &incoming. as
			select	*
			from	&incoming.
			where	enterprise_member_id not in (select distinct enterprise_member_id from ec6_eid_dup);
		quit;
	%end;

	proc sort data=&incoming._xref nodup; by parent_enterprise_member_id enterprise_member_id; run;
	proc sql;
		create view ec6_view_xref as
		select	distinct enterprise_member_id, parent_enterprise_member_id, count(distinct parent_enterprise_member_id) as dupcnt
		from	&incoming._xref
		group by enterprise_member_id;
	quit;
	data &incoming._xref(drop=dupcnt) ec6_xref_dup ec6_xref_null_eid;
		set ec6_view_xref;
		if dupcnt ne 1 then output ec6_xref_dup;
		else if parent_enterprise_member_id='' then output ec6_xref_null_eid;
		else output &incoming._xref;
	run;

	options pageno=1;
	proc print data=ec6_xref_null_eid n;
		title "Client &ids_client_name. EMPI file &filename.";
		title2 "Records with child EID but null parent EID";
	run; title;

	options pageno=1;
	proc print data=ec6_xref_dup n;
		title "Client &ids_client_name. EMPI file &filename.";
		title2 "Records with child EID but more than 1 parent EID";
	run; title;

	proc sort data=ec6_mrn nodup; by current eid mrn interface;
	data ec6_region_empi_current(keep=interface eid mrn localinterface);
		set ec6_mrn(keep=current mrn eid interface);
		where current;
		if interface=200 then do;
			localinterface=210; output;
			localinterface=230; output;
			localinterface=240; output;
		end;
		else if interface=300 then do;
			localinterface=310; output;
			localinterface=320; output;
			localinterface=330; output;
			localinterface=340; output;
		end;
	run;

	proc sql;
		create view ec6_view_syspersid as
		select  distinct dhms(input("&filedate.",yymmdd8.),&filehour.,&fileminute.,&filesecond.) format datetime. as file_received_date, 
				a.eid as enterprise_member_id, 
				left(put(a.interface,z3.)) length 3 format $3. as source_system_id, 
				a.mrn as system_member_id,
		        case when b.interface=. then '' else left(put(b.interface,z3.)) end length 3 format $3. as parent_source_system_id,
		        b.mrn as parent_system_member_id, count(distinct a.eid) as dupcnt
		from    ec6_mrn a left join
		        ec6_region_empi_current b on a.interface=b.localinterface and a.eid=b.eid
		where	a.mrn ne '' and UPCASE(a.mrn) not like '%TEST%' /* invalid records */
		group by 3,4
		order by 3,4;
	quit;

	data &incoming._syspersid(drop=dupcnt) ec6_mrn_mult_mapping ec6_mrn_w_null_eid(drop=dupcnt);
		set ec6_view_syspersid;
		if dupcnt ne 1 then output ec6_mrn_mult_mapping; 
		else if enterprise_member_id='' then output ec6_mrn_w_null_eid;
		else output &incoming._syspersid;
	run;

	options pageno=1;
	proc print data=ec6_mrn_w_null_eid n;
		title "Client &ids_client_name. EMPI file &filename.";
		title2 "System_member_id records with null enterprise_member_id";
	run; title;

	options pageno=1;
	proc print data=ec6_mrn_mult_mapping;
		title "Client &ids_client_name. EMPI file &filename.";
		title2 "System_member_id with multiple mapping to enterprise_member_id";
		by source_system_id system_member_id;
		id source_system_id system_member_id;
	run; title;

	proc printto; run;

	proc datasets lib=work nolist; delete ec6_:; quit;

	%let dsn_id=%sysfunc(open(&incoming.));
	%let dsn_obs=%sysfunc(attrn(&dsn_id.,nobs));
	%let dsn_rc=%sysfunc(close(&dsn_id.));

	%let tgt_record_cnt=&dsn_obs.;
	%put NOTE: Target Record Count = &tgt_record_cnt.;

	proc sql noprint;
		update 	vbpm.sk_process_control a
		set 	EXT_OUTPUT_LOG = "&xl."
		where 	a.wflow_exec_id=&wflow_exec_id.
		and 	a.client_id=&client_id.
		and 	a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
	quit;
%mend empi_client_6;
