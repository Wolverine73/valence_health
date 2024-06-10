/*
%txt_mcp_execute(PHS, M:\PHS\sasdata\CIETL\member\, member, M:\PHS\sasdata\CIETL\dw\, labclme, 201109);
*/
%macro txt_mcp_execute(m_clientname, m_mem_folder, m_mem_setnm, m_clm_folder, m_clm_setnm, m_mcp_yrmo);
	libname oldclm "&m_clm_folder.";
	libname oldmem "&m_mem_folder.";

	libname newclm "&m_clm_folder.";
	libname newmem "&m_mem_folder.";
/*
	libname newclm "&m_clm_folder.memfix\";
	libname newmem "&m_mem_folder.memfix\";
*/
	%let m_clientname=%upcase(&m_clientname.);

  %IF %sysfunc(exist(newmem.member_key_xref_&m_mcp_yrmo.))=0 %THEN %DO;
	%macro get_client_mem;
	  data member(bufsize=128k bufno=1k drop=dob i ssntype fmtname rename=(newdob=dob)) 
		 memcrosswalk(keep=fmtname memberid member_key rename=(member_key=start memberid=label));
	   %if &m_clientname.=STLUKES or &m_clientname.=CCCPP or &m_clientname.=EXEMPLA %then %do;
		set oldmem.&m_mem_setnm.(keep=memberid fname lname sex dob address1 city state zip phone);
		where memberid ne '';
		format ssn $9.;
		if memberid not in: ('E','V') and length(memberid)=9 then ssn=memberid;
		else if memberid =: 'S' and length(memberid)=10 then ssn=substr(memberid,2);
	   %end;
	   %else %if &m_clientname.=PHS %then %do;
		set oldmem.&m_mem_setnm.(keep=memberid best_fname best_lname best_sex best_dob best_address1 best_city best_state best_zip best_phone
					  rename=(best_fname=fname best_lname=lname best_sex=sex best_dob=dob best_address1=address1 best_city=city best_state=state best_zip=zip best_phone=phone));
		where memberid ne '';
		format ssn $9.;
		if memberid ne: 'V' then ssn=memberid;
	   %end;
	   %else %if &m_clientname.=OHG %then %do;
		set oldmem.&m_mem_setnm.(keep=memberid fname lname sex dob address1 city state zip phone);
		where memberid ne '';
		format ssn $9.;
		if length(memberid)=9 and '0' le substr(memberid,1,1) le '9' and indexc(memberid,'*=/')=0 then ssn=memberid;
	   %end;
	   %else %do;
		set oldmem.&m_mem_setnm.(keep=memberid ssn fname lname sex dob address1 city state zip phone);
		where memberid ne '';
	   %end;
		format member_key 16. address1 $25. fname $20. city $20. zip $5. phone $10. sex_fname $21. newdob $8. zip3 $3. 
				addrscan $20. addrnum_zip $13. valid_ssn $9.;
		array fix(8) ssn fname lname sex address1 city zip phone;
		do i=1 to dim(fix); fix(i)=trim(upcase(fix(i))); end;
		sex_fname=substr(sex,1,1)||fname;
		lname_sound=soundex(lname);
		sex_fname_sound=substr(sex,1,1)||soundex(fname);
		if dob ne . then newdob=put(year(dob),4.)||put(month(dob),z2.)||put(day(dob),z2.);
		zip3=zip;
		if length(phone) lt 9 or substr(phone,4,6) in ('000000','111111','222222','333333','444444','555555','666666','777777','888888','999999') then phone='';
		/* if last digit is off, it is acceptable */
		if ssn='NOMTCH' then ssn='';
		%ssntest;
		if ssntype='VALID' then valid_ssn=ssn; else valid_ssn='';
		if '0' le substr(scan(address1,1),1,1) le '9' or 
			length(scan(address1,1)) gt 1 and '0' le substr(scan(address1,1),2,1) le '9' then do;
			if scan(address1,2) in ('N','S','E','W','NE','NW','SE','SW',
									'NORTH','SOUTH','EAST','WEST',
									'NORTHEAST','NORTHWEST','SOUTHEAST','SOUTHWEST') then addrscan=scan(address1,1)||' '||scan(address1,3);
			else addrscan=scan(address1,1)||' '||scan(address1,2);

			if length(zip)=5 then addrnum_zip=scan(address1,1)||' '||zip;
		end;
		client_key=0;
		wflow_exec_id=0;
		member_key=_n_;
	/*	if memberid=:'V' then member_key=999000000000+substr(memberid,2);
	   %if %scan(&m_mem_folder.,2,'\')=CCCPP %then %do;
		else if memberid=:'E' then member_key=888000000000+substr(memberid,2);
	   %end;
		else if compress(memberid) ne memberid then member_key=666000000000+tranwrd(substr(memberid,1,9),' ','0');
	   %if %scan(&m_mem_folder.,2,'\')=OHG %then %do;
	   %end
		else member_key=333000000000+memberid;*/
		fmtname='memxref';
	/*	else if 
	NEED PO BOX logic
		end;*/
	  run;

	  proc format cntlin=memcrosswalk;
	  run;
	%mend get_client_mem;
	%get_client_mem;

	%mcp_varcombo(1,5,7,valid_ssn sex_fname lname dob phone address1 zip);
	%mcp_varcombo(2,5,7,valid_ssn sex_fname_sound lname_sound dob phone address1 zip);
	%mcp_varcombo(3,5,7,valid_ssn sex_fname_sound lname_sound dob phone addrscan zip);
	%mcp_varcombo(4,4,6,valid_ssn sex_fname_sound lname_sound dob phone addrnum_zip);
	%mcp_varcombo(5,4,6,valid_ssn sex_fname lname dob phone zip3);
	%mcp_varcombo(6,3,3,sex_fname_sound lname_sound dob);

	%macro mcp_result;
		data member_key_dup_id_all(keep=client_key audit_result_str audit_numofvar audit_varstring);
			format audit_varstring $&max_varstring_length..;
			set member_key_dup_id1 member_key_dup_id2 member_key_dup_id3 member_key_dup_id4 member_key_dup_id5 member_key_dup_id6;
		run;

		proc sort data=member_key_dup_id_all nodup; 
			by client_key audit_result_str audit_numofvar audit_varstring;
		data member_key_dup_id_all(drop=i);
			set member_key_dup_id_all;
			by client_key audit_result_str audit_numofvar audit_varstring;
			format member_keyc $16.;
			if last.audit_result_str
		  %if perform_1group=Y %then %do;
				and (	scan(audit_result_str,1,'=') in: (&iden_group.) or index(audit_result_str,"=&iden_group.")	)
		  %end;
			then do i=1 to 6;
				member_keyc=cats(scan(audit_result_str,i,'='));
				if length(member_keyc) ge 15 then output;
			end;
		run;
		
		proc sql;
			create table interested_member as
			select	b.audit_result_str, a.*, b.audit_varstring, count(*) as dupcnt
			from	member a, member_key_dup_id_all b
			where	a.client_key=b.client_key
			and		put(a.member_key,z16.)=member_keyc
			group by b.client_key, b.audit_result_str
			order by client_key, audit_result_str;
		quit;

		/* Check for twins with same DOB, or parent & kid with same name */
		data interested_comment(keep=client_key audit_result_str audit_comment audit_varstring
									 ssndiff_ind dobdiff_ind phone_digit_diff fnamediff_ind);
			set interested_member;
			by client_key audit_result_str;
			format audit_comment $10.;
			lagfname=lag(fname); laglname=lag(lname); lagssn=lag(ssn); lagsex=lag(sex);
			dobyr=substr(dob,1,4); dobmo=substr(dob,5,2); dobdy=substr(dob,7,2);
			lagdob=lag(dob); lagdobyr=lag(dobyr); lagdobmo=lag(dobmo); lagdobdy=lag(dobdy); 
			phonenum=substr(phone,4);
			lagphone=lag(phone); lagphonenum=lag(phonenum);

			if dupcnt=2 and last.audit_result_str then do;
				%count_digit_diff(ssn,ssn,lagssn);
				%count_digit_diff(dobyr,dobyr,lagdobyr);
				%count_digit_diff(dobmo,dobmo,lagdobmo);
				%count_digit_diff(dobdy,dobdy,lagdobdy);
				if ssn='' or lagssn='' then ssndiff_ind=.;
				else if ssn_digit_diff le 3 then ssndiff_ind=0;
				else ssndiff_ind=1;
				if dob='' or lagdob='' then dobdiff_ind=.;
				else if sum(dobdy_digit_diff,dobmo_digit_diff,dobyr_digit_diff)=0 or
						dobyr_digit_diff=0 and dobmo=lagdobdy and dobdy=lagdobmo or
						dobdy_digit_diff=dobmo_digit_diff=0 and dobyr_digit_diff le 2 or
						dobdy_digit_diff=dobyr_digit_diff=0 or
						dobmo_digit_diff=dobyr_digit_diff=0 then dobdiff_ind=0;
				else dobdiff_ind=1;

				%count_digit_diff(phone,phone,lagphone);
				if index(upcase(audit_varstring),'PHONE')=0 then do;
					if phone ne '' and lagphone ne '' and
						(phone_digit_diff le 2 or phonenum=lagphonenum) then audit_varstring=trim(audit_varstring)||' '||'phone';
				end;

				%count_digit_diff(lname,lname,laglname);
				if index(upcase(audit_varstring),'LNAME')=0 then do;
					if (length(lname) ge 6 or length(laglname) ge 6) and 
						lname_digit_diffpct le .301 then audit_varstring=trim(audit_varstring)||' '||'lname';
					/* Maiden name in last name, or 2-word last name */
					else if lname ne '' and lname=scan(laglname,2,'-') or 
							laglname ne '' and laglname=scan(lname,2,'-') then audit_varstring=trim(audit_varstring)||' '||'lname';
					/* Last Name has Suffix */
					else if lname ne '' and lname=scan(laglname,1) and scan(laglname,2) in ('JR','SR','I','II','III','IV','V','VI') or 
							laglname ne '' and laglname=scan(lname,1) and scan(lname,2) in ('JR','SR','I','II','III','IV','V','VI') then audit_varstring=trim(audit_varstring)||' '||'lname';
				end;

				%count_digit_diff(fname,fname,lagfname);
				if index(upcase(audit_varstring),'FNAME')=0 then do;
					/* sex is different, but fname is exactly the same */
					if fname ne '' and fname=lagfname then audit_varstring=trim(audit_varstring)||' '||'fname';
					else if (length(fname) ge 6 or length(lagfname) ge 6) and 
						fname_digit_diffpct le .301 then audit_varstring=trim(audit_varstring)||' '||'fname';
					/* Nickname in first name with parentheses */
					else if fname ne '' and fname=scan(lagfname,2,'()') or 
							lagfname ne '' and lagfname=scan(fname,2,'()') then audit_varstring=trim(audit_varstring)||' '||'fname';
				end;
				if fname='' or lagfname='' then fnamediff_ind=.;
				else if index(upcase(audit_varstring),'FNAME') then fnamediff_ind=0;
				else fnamediff_ind=1;




				/* Check for parent & kid with same name */
				if index(upcase(audit_varstring),'DOB')=0 and
				   index(upcase(audit_varstring),'FNAME') and index(upcase(audit_varstring),'LNAME') and
				   dobdiff_ind then do;
					if abs(dobyr-lagdobyr) ge 12 then audit_comment='FAMILY'; 
					else audit_comment='MANCHECK';
					output;
				end;

				/* Check for twins with same DOB */
				else if index(upcase(audit_varstring),'FNAME')=0 and
				   index(upcase(audit_varstring),'DOB') and index(upcase(audit_varstring),'LNAME') and
				   fnamediff_ind and fname ne: trim(lagfname) and lagfname ne: trim(fname) then do;
					audit_comment='TWINS'; output;
				end;

				else if (index(upcase(audit_varstring),'ADDR') or index(upcase(audit_varstring),'PHONE')) and
				   index(upcase(audit_varstring),'FNAME') and index(upcase(audit_varstring),'LNAME') then do;
					if dobdiff_ind=0 and 
						(ssndiff_ind=0 or 
						 compress(fname," -'")=compress(lagfname," -'") and compress(lname," -'")=compress(laglname," -'")) then audit_comment='DUP';
					else if ssndiff_ind and dobdiff_ind then audit_comment='MANCHECK';
					else audit_comment='LIKELY';
					output;
				end;

				else if index(upcase(audit_varstring),'FNAME') and index(upcase(audit_varstring),'LNAME') and
				   index(upcase(audit_varstring),'DOB') then do;
					if ssndiff_ind=0 then audit_comment='DUP';
					else if ssndiff_ind=1 then audit_comment='MANCHECK';
					else audit_comment='';
					output;
				end;

				else do;
					audit_comment='???';
					output;
				end;
			end;
		run;

		proc sql;
			/* Start - This is different than EDW version */
			create table mem_clmcnt as
			select	memberid, count(*) as clmcnt
			from	oldclm.&m_clm_setnm.(keep=memberid)
			where	memberid ne ''
			group by 1;
			/* End difference */

			create table interested_member2a as
			select	a.*, b.clmcnt
			from	interested_member a left join mem_clmcnt b
						on put(a.member_key,memxref.)=b.memberid;
			create table interested_member2b(drop=audit_varstring rename=(audit_varstring_mod=audit_varstring)) as
			select	a.*, 
					case when a.dupcnt ge 3 then 'MULTI' when audit_comment ne '' then audit_comment else '' end as audit_comment,
					case when b.audit_varstring ne '' then b.audit_varstring else a.audit_varstring end as audit_varstring_mod,
					b.ssndiff_ind, b.dobdiff_ind, b.phone_digit_diff, b.fnamediff_ind
			from	interested_member2a a left join interested_comment b
						on a.client_key=b.client_key and a.audit_result_str=b.audit_result_str;

			create table throwout_multaudit as
			select	audit_result_str, length(audit_result_str) as string_l, member_key
			from	interested_member2b
		  %if perform_1group=Y %then %do;
			where	substr(put(member_key,z16.),1,8) in (&iden_group.)
		  %end;
			order by member_key, string_l, audit_result_str;
		quit;
		data throwout_multaudit(keep=audit_result_str);
			set throwout_multaudit;
			by member_key string_l audit_result_str;
			if last.member_key;
		run;
		proc sort data=throwout_multaudit nodup; by audit_result_str; run;

		proc sql;
			create table interested_member3 as
			select	a.*, sum(clmcnt) as totcnt, count(ssn) as ssncnt, count(distinct ssn) as ssnucnt, count(*) as linecnt
			from	interested_member2b a, throwout_multaudit b
			where	a.audit_result_str=b.audit_result_str
			group by a.audit_result_str
			order by client_key, audit_comment, audit_result_str, wflow_exec_id, clmcnt desc, lname, fname, dob, zip, member_key;
		quit;

		data interested_member3(drop=ssncnt ssnucnt linecnt) 
			 last_wflow(keep=client_key audit_comment audit_result_str wflow_exec_id rename=(wflow_exec_id=sort_wflow));
			set interested_member3;
			by client_key audit_comment audit_result_str;
			if last.audit_result_str then do;
				if ssnucnt gt 1 then ssntypo_cnt=1;
				else if 0 lt ssncnt lt linecnt and ssn ne '' then ss2nd_cnt=1;
				memcnt=1;
				output last_wflow;
			end;
			output interested_member3;
		run;
		data interested_member3;
			merge interested_member3 last_wflow;
			by client_key audit_comment audit_result_str;
		run;
	%mend mcp_result;

	%mcp_result;

	/* Autopush Dup and Likely categories */
	data push_to_xref;
		set interested_member3;
		where audit_comment in ('DUP','LIKELY');
		%ssntest;
		if ssntype='VALID' then rankssn=1; else rankssn=99;
		rankaddrph=sum(address1 ne '',city ne '',zip ne '',phone ne '');
	run;

	proc sort data=push_to_xref; by audit_result_str rankssn descending rankaddrph descending clmcnt;
	/* map member key from 2nd row to member key from 1st row */
	data xref_pushlist(keep=audit_result_str mk_from mk_to);
		set push_to_xref;
		by audit_result_str rankssn descending rankaddrph descending clmcnt;
		format mk_from mk_to rtmk 16.;
		retain rtmk ;
		if first.audit_result_str then rtmk=member_key;
		else do;
			if dupcnt=2 then do;
				mk_from=member_key; mk_to=rtmk;
				output xref_pushlist;
			end;
		end;
	run;

	%mcp_ite_xref;

	/* Output 1 - Member ID Crosswalk Table, from old member id (memberid_from) to new member id (member_to) */
	data newmem.member_key_xref_&m_mcp_yrmo.(keep=memberid_from memberid_to)
		 mktofmt(keep=fmtname memberid_from memberid_to rename=(memberid_from=start memberid_to=label));
		set xref_pushlist;
	  %if &m_clientname.=PHS %then %do;
		format memberid_from memberid_to $12.;
	  %end;
	  %else %if &m_clientname.=EXEMPLA %then %do;
		format memberid_from memberid_to $10.;
	  %end;
	  %else %do;
		format memberid_from memberid_to $12.;
	  %end;
		memberid_from=put(mk_from,memxref.);
		memberid_to=put(mk_to,memxref.);
		fmtname='$mkto';
	run;
	proc format cntlin=mktofmt; run;

	/* Output 2 - Complete listing of member records with consolidation potential */
	data newmem.falseneglist_&m_mcp_yrmo.(compress=no);
		set interested_member3;
	  %if &m_clientname.=PHS %then %do;
		format old_memberid new_memberid $12.;
	  %end;
	  %else %if &m_clientname.=EXEMPLA %then %do;
		format old_memberid new_memberid $10.;
	  %end;
	  %else %do;
		format old_memberid new_memberid $12.;
	  %end;
		old_memberid=put(member_key,memxref.);
		new_memberid=put(old_memberid,$mkto.);
	run;

	/* Output 3 - Listing of member records with crosswalk */
	options orientation=portrait pageno=1 ps=110 ls=196 missing=' ';
	proc sort data=newmem.falseneglist_&m_mcp_yrmo. out=display_autopush nodupkey; 
		where audit_comment in ('DUP','LIKELY');
		by new_memberid old_memberid;
	proc print data=display_autopush split='*';
		title "&m_clientname. &m_mcp_yrmo. False Negative autopush list";
		by new_memberid;
		id new_memberid;
		format lname $20. member_key memxref. clmcnt 6.;
		var member_key ssn fname lname sex dob address1 city zip phone clmcnt audit_comment;
		label member_key='old*memberid' new_memberid='new*memberid';
	run; title;
	
	/* Output 4 - New Member dataset without old member id that has been crosswalked */
	proc sql;
		create table newmem.&m_mem_setnm. as
		select	*
		from	oldmem.&m_mem_setnm.
		where	memberid not in (select memberid_from from newmem.member_key_xref_&m_mcp_yrmo.);
	quit;
  %END;
	/* Output 5 - New Labclme dataset with consolidated member id */
	%macro mapmemid(m2_input,m2_output);
		proc sql;
			create table &m2_output.(compress=no bufsize=128k bufno=1k drop=memberid rename=(newfix_memberid=memberid)) as
			select	coalesce(b.memberid_to,a.memberid) as newfix_memberid, a.*
			from	&m2_input. a left join newmem.member_key_xref_&m_mcp_yrmo. b on a.memberid=b.memberid_from;
		quit;
	%mend;
	%mapmemid(oldclm.&m_clm_setnm.,newclm.&m_clm_setnm.);

	proc sort data=newclm.&m_clm_setnm.; by memberid svcdt; run;
	proc datasets lib=newclm;
		modify &m_clm_setnm.;
			index create diag1;
			index create memberid;
			index create proccd;
			index create svcdt;
	quit;

	/* Output 5b - Other sources */
	/*%if &m_clientname.=EXEMPLA %then %do;
		libname mcp_v1 'M:\Exempla\SASTEMP\CIProcess\';
		%mapmemid(mcp_v1.matchedvmineandpgf,mcp_v1.matchedvmineandpgf);
		libname mcp_v1 clear;
		
		libname mcp_h1 'M:\Exempla\SASDATA\CIETL\hospital\';
		%mapmemid(mcp_h1.exempla_hospital_cases,mcp_h1.exempla_hospital_cases);
		libname mcp_h1 clear;

		libname mcp_l1 'M:\Exempla\SASDATA\CIETL\lab\';
		%mapmemid(mcp_l1.matchedelhp_hl7,mcp_l1.matchedelhp_hl7);
		libname mcp_l1 clear;
	%end;*/

	/* Output 6 - New member formats tie to the new member dataset */
	data newmem.member_lname(keep=fmtname type start lname	  rename=(lname=label))
		 newmem.member_fname(keep=fmtname type start fname	  rename=(fname=label))
		 newmem.member_dob	(keep=fmtname type start dob	  rename=(dob=label))
	%if &m_clientname.=PHS %then %do;
		 newmem.memberYN	(keep=fmtname type start memberYN rename=(memberYN=label))
	%end;
	%else %if &m_clientname.=EXEMPLA %then %do;
		 newmem.member_yn	(keep=fmtname type start memberYN rename=(memberYN=label))
	%end;
	%else %do;
		 newmem.memberYN	(keep=fmtname type start memberYN rename=(memberYN=label))
	%end;
		 newmem.member_sex	(keep=fmtname type start sex	  rename=(sex=label));
		set newmem.member end=lstobs;
		format fmtname $10.;
		type='C'; 
		memberYN='Y';
	  %macro memfmt_output;
		fmtname='lname'; output newmem.member_lname;
		fmtname='fname'; output newmem.member_fname;
		fmtname='dob'; output newmem.member_dob;
		fmtname='memberYN'; 
			%if &m_clientname.=PHS %then %do;
				output newmem.memberYN;
			%end;
			%else %if &m_clientname.=EXEMPLA %then %do;
				output newmem.member_yn;
			%end;
			%else %do;
				output newmem.memberYN;
			%end;			
		fmtname='member_sex'; output newmem.member_sex;
	  %mend memfmt_output;

		%memfmt_output;
		if lstobs then do;
			memberid='other'; lname='N'; fname='N'; dob=.; memberYN='N'; sex='';
			%memfmt_output;
		end;
		rename memberid=start;
	run;
%mend txt_mcp_execute;
