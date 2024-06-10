/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_consolidation.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Find false negatives (1 patient with multiple member keys) from MLA
|
| logic:    Logic 1: PATID constraint, if same PATID, must collapse
|			Logic 2: Same patient(see algorithm) with address or phone to confirm identity
|
| input:    Macro parameters and /or SQL server practices
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|                        
| output:   1. Populate cihold.member_key_xref
|			2. cistage.false_negative_&wflow_exec_id. (all potential fixes)
|			3. Listing of autopush list
|
| usage:    reprocessing_xref will reprocess all claims based on member_key_xref
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 25APR2011 - G Liu - Clinical Integration 1.0.01
|			  Original
| 08NOV2011 - G Liu - Clinical Integration 1.0.02
|			  Added logic to prevent fixing member keys tie to EMPI.
|				1. If both member keys are EMPI member keys, do not collapse.
|				2. If 1 member key is not EMPI, collapse to the EMPI member key.
|				3. If member keys are not tied to EMPI, collapse as normal.
|			  Changed logic to use created_on field for sorting instead of wflow_exec_id
|				It doesn't matter right now, because for ciedw.member table, we do not
|				update wflow_exec_id for now. But in case we change the methodology,
|				created_on should be static. We will collapse member key to the one that
|				is created first, according to created_on.
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 25FEB2012 - G Liu - Clinical Integration 1.1.02
|			  Added codes to handle MULTI category. Randomly pick a pair to go through
|				logic to attempt autopush.
| 02MAY2012 - G Liu - Clinical Integration 1.2.01 H02
|			  Load mapping to VH_EMPI.PATIENT_FALSE_NEGATIVE
| 16MAY2012 - G Liu - Clinical Integration 1.2.02
|			  Changed to source from VH_EMPI
| 08JUN2012 - G Liu - Clinical Integration 1.3.01
|			  Add join to ciedw.person_member_map to get MEMBER_KEY
| 31JUL2012 - G Liu - Clinical Integration 1.5.01
|			  Fix bug in source query by adding pdm.delete_flag=0
| 01AUG2012 - G Liu - Clinical Integration 1.5.02 M03
|			  Run the "long" version of member fix by looking at all variations
|				of demographics in the person_ tables
|			  Implement the PATID constraint
|				- same PATID will be collapsed regardless of other fields
|				- different PATID will not be eligible for collapsing (long version only)
| 12SEP2012 - G Liu - Clinical Integration 1.5.03 M03
|			  For payer PATIDs, we will strictly adhere to 1 PATID = 1 member key. This
|				is due to downstream portal codes needing absolutely 1 member local id to
|				1 member key, otherwise, downstream codes will not work properly.
|			  So, in the original logic (logic 2) that looks at demographics only, since
|				person keys are not taken into account (not in the short version anyway),
|				we will identify whether the pair that we are about to collapse, if they 
|				have different PATIDs. If so, even though other datasources might want
|				this collapsing to happen, we just can't quite do it here. We don't create
|				new member keys in false negative, unless we want to add significantly
|				to this code.
|			  Ex.
|				Member key A - Person key 1 (from DSID 123 - CI with patid 001)
|				Member key A - Person key 2 (from DSID 456 - 456 is payer with PATID xxx)
|				Member key A - Person key 3 (from DSID 789)
|				Member key B - Person key 4 (from DSID 123 - CI with patid 002)
|				Member key B - Person key 5 (from DSID 456 - 456 is payer with PATID yyy)
|			    False negative says collapse B to A
|				Since A and B have 2 different PATIDs from dsid 456, we will no longer
|					collapse this pair.
|				Ideally, what needs to happen is most likely:
|				NEW Member key C - Person key 1
|				NEW Member key C - Person key 2
|				NEW Member key C - Person key 3
|				NEW Member key C - Person key 4
|				NEW Member key D - Person key 5 - leave this all by itself since payer made the mistake
|			  This way, this patient's claims from the CI side are all consolidated to 1
|				single member key.
|			  Note, CI dsid will still consolidate, just not payer dsid.
+-----------------------------------------------------------------------HEADER*/

%macro edw_member_consolidation;
	options bufsize=128k bufno=1k compress=yes;

	/******************
	* Logic 1 - Start *
	*******************/

	/* PATID constraint 1 - each PATID should have only 1 member key */
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		/* we will also use this dataset at the bottom of program to do one last check of PATID */
		create table patk_and_persk as
		select	datasourceid, system_person_id, patient_key,
				ssn, fname, lname, sex, input(dob,yymmdd10.) as dob, address1, city, zip, phone, created_on, wflow_exec_id,
				rand('uniform') as random_sort
				/* random sort so that we don't always pick the same pair in every single member fix */
		from	connection to oledb
				(	select	distinct coalesce(pdg.datasourceid_group,ps.datasourceid) as datasourceid, ps.system_person_id, ppm.patient_key,
							ssn, fname, lname, sex, dob, address1, city, zip, phone, pdm.created_on, pdm.created_wflow_exec_id as wflow_exec_id
					from	vh_empi.dbo.person_workflow_detail(nolock) 	pwd inner join
							vh_empi.dbo.person_patient_map(nolock) 	ppm on pwd.client_key=ppm.client_key and pwd.person_key=ppm.person_key and ppm.delete_flag=0 inner join
							vh_empi.dbo.person(nolock) 				p on ppm.client_key=p.client_key and ppm.person_key=p.person_key inner join
							vh_empi.dbo.patient_detail_map(nolock)	pdm on ppm.client_key=pdm.client_key and ppm.patient_key=pdm.patient_key and pdm.delete_flag=0 inner join
							vh_empi.dbo.patient_detail(nolock) 		patd on pdm.client_key=patd.client_key and pdm.patient_detail_key=patd.patient_detail_key inner join 
							vh_empi.dbo.person_system(nolock) 		ps on p.client_key=ps.client_key and p.person_system_key=ps.person_system_key left join
							vh_empi.dbo.pl_datasource_group(nolock) pdg on ps.datasourceid=pdg.datasourceid
					where	ppm.client_key=&client_id.
				);
	quit;

	proc sql;
		create view v_patid_constraint1 as
		select	*
		from	patk_and_persk
		group by datasourceid, system_person_id
		having	count(distinct patient_key) gt 1
		order by datasourceid, system_person_id, random_sort;
	quit;

	/* output vars here are to match logic 2 output which was written first */
	data patid_constraint1(drop=audit_comment origdob rename=(patient_key=member_key)) 
		 patid_comment1(keep=client_key audit_result_str audit_varstring audit_comment)
		 bad_patid
		 overwrite_patid_constraint1(keep=audit_result_str audit_comment);
		set v_patid_constraint1(rename=(dob=origdob));
		by datasourceid system_person_id random_sort;
		if first.system_person_id then combocnt=1;
		else combocnt+1;

		client_key=&client_id.;
		audit_numofvar=1;
		format dob $8.;
		if origdob ne . then dob=put(year(origdob),4.)||put(month(origdob),z2.)||put(day(origdob),z2.);
		lagfname_sound=soundex(lag(fname)); laglname_sound=soundex(lag(lname)); lagdob=lag(dob);

		format audit_comment $10.;
		if system_person_id=:'SYS[' and index(system_person_id,'ID[]') then do; 
			/* Prior to 8/2/12, we erroneously created the composite PATID for Cleveland's 837s and self-pay when the MRN is null.
				All these PATIDs (ex. SYS[050]ID[], SYS[310]ID[]) should have been null values. Currently we have thousands of patients
				all tie to these same bad PATIDs. G 8/7/12 */
			output bad_patid;
			if combocnt=1 then do;
				put datasourceid= system_person_id=;
			end;
		end;
		else do;
			format audit_result_str $101.; /* match logic 2 variable initialized in mcp_varcombo.sas */
			audit_result_str=cats(put(datasourceid,6.))||' '||system_person_id; /* it is important for dsid to be the first word. this is
																					later used for finding empi dsid */
			audit_comment='PATID';
			audit_varstring='datasourceid_group system_person_id';

			if combocnt le 2 then do; /* false negative only knows how to handle pairs. if there are 3 member keys
											with same PATIDs, it'll need 2 false negative runs to fix everything */
				dupcnt=2;
				output patid_constraint1;
				output patid_comment1;
				if combocnt=2 and 
					fname ne '' and lagfname_sound ne '' and soundex(fname) ne lagfname_sound and
					lname ne '' and laglname_sound ne '' and soundex(lname) ne laglname_sound and dob ne lagdob 
				then do;
					audit_comment='NOFIXPATID';
					output overwrite_patid_constraint1;
				end;
			end;
		end;
		drop combocnt;
	run;
	%set_error_flag
	%on_error(ACTION=ABORT)

	proc sql undo_policy=none;
		create table patid_comment1 as
		select	distinct a.client_key, a.audit_result_str, a.audit_varstring, coalesce(b.audit_comment,a.audit_comment) as audit_comment
		from	patid_comment1 a left join
				overwrite_patid_constraint1 b on a.audit_result_str=b.audit_result_str
		order by audit_result_str, audit_comment;
	quit;
	/****************
	* Logic 1 - End *
	*****************/

	/******************
	* Logic 2 - Start *
	*******************/
	data _null_;
		random=rand('uniform');
		if &client_id. in (6) then runperweek=3; /* 3 member fix runs per week */
		else runperweek=1; /* 1 member fix run per week */
		/* we want to run the long member fix version roughly once a month */
		if random lt 12/(runperweek*52) then call symput('emc_run_longmemfix',1);
		else call symput('emc_run_longmemfix',0);
	run;

	%let emc_run_longmemfix=0; /* don't implement long version yet */
	%if &emc_run_longmemfix. %then %do;
		/* this looks at the person_ tables, which means the source has all demographic variations that tie to a member key */
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			create view view_member as
			select	client_key, patient_key as member_key,
					case when system_person_id='' then '' else put(datasourceid_group,z6.)||system_person_id end as patid,
					ssn, fname, mname, lname, sex, input(dob,yymmdd10.) as dob, address1, city, state, zip, phone,
					min(created_on) as created_on, min(wflow_exec_id) as wflow_exec_id
			from	connection to oledb
					(	select	p.client_key, ppm.patient_key, pdg.datasourceid_group, ps.system_person_id,
								ssn, fname, mname, lname, sex, dob, address1, city, state, zip, phone,
								ppm.created_on, ppm.created_wflow_exec_id as wflow_exec_id
						from	vh_empi.dbo.person(nolock)				p inner join
								vh_empi.dbo.person_patient_map(nolock) 	ppm on p.client_key=ppm.client_key and p.person_key=ppm.person_key and ppm.delete_flag=0 inner join
								vh_empi.dbo.patient(nolock)				pat on ppm.client_key=pat.client_key and ppm.patient_key=pat.patient_key and pat.delete_flag=0 inner join
								vh_empi.dbo.person_detail(nolock)		pd on p.client_key=pd.client_key and p.person_detail_key=pd.person_detail_key left join
								vh_empi.dbo.person_system(nolock)		ps on p.client_key=ps.client_key and p.person_system_key=ps.person_system_key left join
								vh_empi.dbo.pl_datasource_group(nolock) pdg on ps.datasourceid=pdg.datasourceid
						where	p.client_key=&client_id.
					)
			group by 1,2,3,
					 4,5,6,7,8,9,10,11,12,13,14
			order by patient_key;
		quit;
		/* long version not completed. mcp_varcombo needs to be modified to account for the new member_key_num variable
			so that when we assign buckets, we know which demographics to grab instead of just randomly picking 1 from the pool of 
			person keys belonging to the member key */
	%end;
	%else %do;
		/* this looks at the patient_ tables, which means the source is the member table with 1 demographic variation per member key */
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			create view view_member as
			select	client_key, patient_key as member_key,
					ssn, fname, mname, lname, sex, input(dob,yymmdd10.) as dob, address1, city, state, zip, phone,
					created_on, wflow_exec_id
			from	connection to oledb
					(	select	p.client_key, p.patient_key,
								ssn, fname, mname, lname, sex, dob, address1, city, state, zip, phone,
								pdm.created_on, pdm.created_wflow_exec_id as wflow_exec_id
						from	vh_empi.dbo.patient(nolock)				p inner join
								vh_empi.dbo.patient_detail_map(nolock) 	pdm on p.client_key=pdm.client_key and p.patient_key=pdm.patient_key and p.delete_flag=0 and pdm.delete_flag=0 inner join
								vh_empi.dbo.patient_detail(nolock)		pd on pdm.client_key=pd.client_key and pdm.patient_detail_key=pd.patient_detail_key
						where	p.client_key=&client_id.
					)
			group by patient_key
			having	count(*)=1;
		quit;
	%end;

	data member(compress=yes bufsize=128k bufno=1k drop=dob i ssntype t0_addr1 t1_addr1 t2_addr1 rename=(newdob=dob));
		set view_member;
	  %if &emc_run_longmemfix. %then %do;
		by member_key;
		if first.member_key then member_key_num=1;
		else member_key_num+1;
	  %end;
		format 	member_key 16. address1 $25. fname $20. city $20. zip $5. phone $10. sex_fname $21. newdob $8. zip3 $3. 
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

		%ssntest
		if ssntype='VALID' then valid_ssn=ssn; else valid_ssn='';

		format t0_addr1 t1_addr1 t2_addr1 $100.;
		t0_addr1=tranwrd(address1,'POBOX','PO BOX ');
		t0_addr1=tranwrd(address1,'C/O ','');
		if '0' le substr(scan(address1,1),1,1) le '9' or 
			length(scan(address1,1)) gt 1 and '0' le substr(scan(address1,1),2,1) le '9' then do;
			if scan(address1,2) in ('N','S','E','W','NE','NW','SE','SW',
									'NORTH','SOUTH','EAST','WEST',
									'NORTHEAST','NORTHWEST','SOUTHEAST','SOUTHWEST') then addrscan=scan(address1,1)||' '||scan(address1,3);
			else addrscan=scan(address1,1)||' '||scan(address1,2);

			if length(zip)=5 then addrnum_zip=scan(address1,1)||' '||zip;
		end;
		else if index(' '||t0_addr1||' ',' BOX ') then do;
			addrscan=scan(substr(' '||t0_addr1||' ',index(' '||t0_addr1||' ',' BOX ')+5),1);
			addrnum_zip=trim(addrscan)||' '||zip;
		end;
		else if t0_addr1 ne '' then do;
			t1_addr1=compress(t0_addr1,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ','k');
			addrscan=scan(t1_addr1,1)||' '||scan(t1_addr1,2);
			t2_addr1=compress(t1_addr1,'0123456789','k');
			if t2_addr1 ne '' then addrnum_zip=scan(t2_addr1,1)||' '||zip;
		end;
	run;
	%set_error_flag
	%on_error(ACTION=ABORT)

	options mprint nomlogic nosymbolgen;

	/* If there is a derivative variable based on fname, dob or ssn, that original word has to be somewhere in that derivative variable name too.
		The macro checks to make sure all the combination that we are auditing at least have 1 of the 3 in there. If it's fname_sound, then the
		macro will know that this variable is also a fname variable, and that combo will go through for auditing.
	*/
	sasfile member load;
	%mcp_varcombo(1,5,7,valid_ssn sex_fname lname dob phone address1 zip)

	%mcp_varcombo(2,5,7,valid_ssn sex_fname_sound lname_sound dob phone address1 zip)

	%mcp_varcombo(3,5,7,valid_ssn sex_fname_sound lname_sound dob phone addrscan zip)

	%mcp_varcombo(4,4,6,valid_ssn sex_fname_sound lname_sound dob phone addrnum_zip)

	%mcp_varcombo(5,4,6,valid_ssn sex_fname lname dob phone zip3)

	%mcp_varcombo(6,3,3,sex_fname_sound lname_sound dob)
	sasfile member close;

	/* Check whether client has EMPI file. If so, keep data integrity of client's EMPI file.
	   Collapse the non-EMPI member key to EMPI member key if one of them is tie to EMPI. if both are 
		EMPI, keep as is. */
	%client_empi_check(&client_id.)
	%set_error_flag
	%on_error(ACTION=ABORT)

	%macro mcp_result;
		data member_key_dup_id_all(keep=client_key audit_result_str audit_numofvar audit_varstring);
			format audit_varstring $&max_varstring_length..;
			set member_key_dup_id1 member_key_dup_id2 member_key_dup_id3 member_key_dup_id4 member_key_dup_id5 member_key_dup_id6;
		run;

		proc sort data=member_key_dup_id_all nodup; by client_key audit_result_str audit_numofvar audit_varstring;
		/* split to pairs vs. multiple (more than 2) member keys. when we have more than 2, the later section
			doesn't know what to do with it, and none of them gets automatically pushed to get fixed. 
			the dataset with more than 2 member keys, we sort member within each group randomly and pick the first 2 member 
			keys to form a new pair, and attempt to autopush that pair, if confidence is high enough. this means that
			3 member keys that can be collapsed into 1, we handle 2 of them first, and if those 2 are successful, leaving 1, the 
			next round of member fix will handle this 1 and that remaining one, theoretically, if they get identified again.
			The randon pick is because, if we have A,B,C that potentially can be collapsed, but A and B will never get autopushed,
			if we constantly pick A and B, C will never get a chance to be collapsed to A or B. Doing the pairing randomly, eventually
			each pairs get looked at eventually.
		*/
		data member_key_dup_id_all_le2(drop=random_sort)
			 member_key_dup_id_all_gt2;
			set member_key_dup_id_all;
			by client_key audit_result_str audit_numofvar audit_varstring;
			format member_keyc $16. member_key 16.;
			countequal=countc(audit_result_str,'=');
            if last.audit_result_str
            then do i=1 to min(countequal+1,6);
				member_keyc=cats(scan(audit_result_str,i,'='));
				if length(member_keyc) ge 15 then do;
					member_key=input(member_keyc,16.);
					if countequal=1 then output member_key_dup_id_all_le2;
					else do;
						random_sort=rand('uniform');
						output member_key_dup_id_all_gt2;
					end;
				end;
			end;
			drop i countequal member_keyc;
		run;
		
		proc sort data=member_key_dup_id_all_gt2; by client_key audit_result_str random_sort;
		data member_key_dup_id_all_gt2_first2(drop=random_sort mkc);
			set member_key_dup_id_all_gt2;
			by client_key audit_result_str random_sort;
			if first.audit_result_str then mkc=1;
			else mkc+1;
			if mkc le 2 then output;
		run;

		data member_key_dup_id_pair(index=(tablekey=(client_key member_key)));
			set member_key_dup_id_all_le2 member_key_dup_id_all_gt2_first2;
		run;

		proc datasets lib=work nolist;
			modify member;
				index create tablekey=(client_key member_key);
		quit;

		proc sql;
			create table interested_member as
			select	b.audit_result_str, a.*, b.audit_varstring, count(*) as dupcnt
			from	member a, member_key_dup_id_pair b
			where	a.client_key=b.client_key
			and		a.member_key=b.member_key
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
				%count_digit_diff(ssn,ssn,lagssn)
				%count_digit_diff(dobyr,dobyr,lagdobyr)
				%count_digit_diff(dobmo,dobmo,lagdobmo)
				%count_digit_diff(dobdy,dobdy,lagdobdy)
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

				%count_digit_diff(phone,phone,lagphone)
				if index(upcase(audit_varstring),'PHONE')=0 then do;
					if phone ne '' and lagphone ne '' and
						(phone_digit_diff le 2 or phonenum=lagphonenum) then audit_varstring=trim(audit_varstring)||' '||'phone';
				end;

				%count_digit_diff(lname,lname,laglname)
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

				%count_digit_diff(fname,fname,lagfname)
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
		/****************
		* Logic 2 - End *
		*****************/

		/* Combine output from logic 1 and 2 - list logic 2 output first to inherit table attribute */
		data interested_member_combined / view=interested_member_combined;
			set interested_member patid_constraint1;
		run;
		data interested_comment_combined / view=interested_comment_combined;
			set interested_comment patid_comment1;
		run;

		/* claim count not that important. we just want to show some count in edw. so, do header count because the query returns much faster */
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			create table mem_clmcnt as
			select	*
			from	connection to oledb
					(	select	pmm.member_key, count(*) as clmcnt
						from	ciedw.dbo.encounter_header(nolock) eh, ciedw.dbo.person_member_map(nolock) pmm
						where	eh.client_key=pmm.client_key and eh.person_key=pmm.person_key
						and		eh.client_key=&client_id.
						group by pmm.member_key
					);
		quit;
		%set_error_flag
		%on_error(ACTION=ABORT)

		proc sql;
			create view interested_member2a as
			select	a.*, b.clmcnt
			from	interested_member_combined a left join 
					mem_clmcnt b on a.member_key=b.member_key;

			create table interested_member2b(drop=audit_varstring rename=(audit_varstring_mod=audit_varstring)) as
			select	a.*, 
					case when countc(a.audit_result_str,'=')+1 ge 3 and audit_comment in ('DUP','LIKELY') then trim(audit_comment)||' SBS'
						 when countc(a.audit_result_str,'=')+1 ge 3 then 'MULTI' 
						 when audit_comment ne '' then audit_comment 
						 else '' 
					end as audit_comment,
					case when b.audit_varstring ne '' then b.audit_varstring else a.audit_varstring end as audit_varstring_mod,
					b.ssndiff_ind, b.dobdiff_ind, b.phone_digit_diff, b.fnamediff_ind
			from	interested_member2a a left join 
					interested_comment_combined b on a.client_key=b.client_key and a.audit_result_str=b.audit_result_str;

			create table throwout_multaudit as
			select	audit_result_str, length(audit_result_str) as string_l, member_key,
					case when audit_comment='PATID' then 1 
						 when scan(audit_comment,1) in ('DUP','LIKELY') then 2
						 else 3
					end as sortrank
			from	interested_member2b
			order by member_key, sortrank, string_l, audit_result_str;
		quit;

		/* This step can use a lot more scrutiny. 1 member key can show up in multiple groupings. Ideally, we want to pick the pair
			that we can fix first, and if not, then we just display as potential. However, after each member key is looked at,
			we could still end up with multiple groupings for the same member key, because the other member key in the pairing 
			"selected" that pairing. This is working now, but maybe there's a way to make it even slicker? */
		data throwout_multaudit(keep=audit_result_str);
			set throwout_multaudit;
			by member_key sortrank string_l audit_result_str;
			if first.member_key;
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
			if substr(put(member_key,z16.),3,6)=put(&empi_datasource_id.,z6.) then empirank=1; else empirank=99;
			if last.audit_result_str then do;
				if ssnucnt gt 1 then ssntypo_cnt=1;
				else if 0 lt ssncnt lt linecnt and ssn ne '' then ss2nd_cnt=1;
				memcnt=1;
				output last_wflow;
			end;
			output interested_member3;
		run;
		data interested_member3(index=(tablekey=(audit_result_str empirank)))
			 cistage.false_negative_&wflow_exec_id.;
			merge interested_member3 last_wflow;
			by client_key audit_comment audit_result_str;
		run;

		data pair_is_empi(keep=audit_result_str);
			set interested_member3;
			by audit_result_str empirank;
			if last.audit_result_str then do;
				/* If same PATID from EMPI datasourceid, i.e. client's EMPI, but different member key, then something didn't get updated properly.
					Each client's EMPI should only map to 1 member key. So, we will collapse the member keys tie to 1 client's EMPI. G 8/12 */
				if audit_comment='PATID' and scan(audit_result_str,1)="&empi_datasource_id." then; 
				else if empirank=1 then output pair_is_empi;
			end;
		run;

		proc sql;
			create table push_to_xref(index=(member_key)) as
			select	a.*
			from	interested_member3 a left join
					pair_is_empi b on a.audit_result_str=b.audit_result_str
			where	scan(a.audit_comment,1) in ('DUP','LIKELY','PATID') 
			and 	b.audit_result_str=''
			order by audit_result_str, empirank, created_on, member_key;
		quit;

		/* Start - R1.5.03 Perform one last check to make sure we do not collapse payer PATIDs 
					EMPI is no different. Even though we checked it above for pair_is_empi, this check is
					by person key and dsid check. Won't hurt to have it here too. 
		*/
		%global emc_payer_dsid_list;
		%let emc_payer_dsid_list=0;
		proc sql noprint;
			select	b.datasourceid
			into	:emc_payer_dsid_list separated by ','
			from	ids.datasource a, ids.datasource_payer b
			where	a.datasourceid=b.datasourceid
			and		a.clientid=&client_id.;
		quit;
		%put NOTE: Client &client_id. has payer datasource id(s) &emc_payer_dsid_list.;

		%if %str(&emc_payer_dsid_list.)=0 and &empi_datasource_id.=0 %then %do;
			proc sql;
				create table push_to_xref_checked(index=(tablekey=(audit_comment audit_result_str))) as
				select	*
				from	push_to_xref
				order by audit_result_str, empirank, created_on, member_key;
			quit;
		%end;
		%else %do;
			proc sort data=patk_and_persk(where=(datasourceid in (&emc_payer_dsid_list.,&empi_datasource_id.)) keep=patient_key datasourceid system_person_id) 
					   out=patk_and_persk2(rename=(patient_key=member_key)) nodups;
				by patient_key datasourceid system_person_id;
			run;

			proc sql;
				create table push_to_xref_diff_payer_patid as
				select	audit_result_str, datasourceid, count(distinct system_person_id) as patidcnt
				from	push_to_xref(keep=member_key audit_result_str) a, patk_and_persk2 b
				where	a.member_key=b.member_key
				group by audit_result_str, datasourceid
				having	patidcnt gt 1;
			quit;

			proc sql;
				create table push_to_xref_checked(index=(tablekey=(audit_comment audit_result_str))) as
				select	*
				from	push_to_xref
				where	audit_result_str not in (select	distinct audit_result_str from push_to_xref_diff_payer_patid)
				order by audit_result_str, empirank, created_on, member_key;
			quit;
		%end;
		/* End - R1.5.03 Perform one last check to make sure we do not collapse payer PATIDs */

		proc sql noprint;
			select	ClientName, scan(SASLogFileLocation,1,'\'), scan(SASLogFileLocation,2,'\')
			into	:ids_client_name, :ids_client_path1, :ids_client_path2
			from	ids.client
			where	ClientID=&client_id.;
		quit;
		%global xl;
		%let ids_client_name=&ids_client_name;
		%let ids_client_path1=&ids_client_path1;
		%let ids_client_path2=&ids_client_path2;
		%if %symexist(sas_mode) and %upcase(&sas_mode.)=PROD %then %let xl=\\&ids_client_path1.\&ids_client_path2.\reports\Data_Quality_Reports\Member_False_Negative_Autopush_List_&ids_client_name._&wflow_exec_id..txt;
		%else %let xl=\\&ids_client_path1.\&ids_client_path2.\reports\Data_Quality_Reports\test\Member_False_Negative_Autopush_List_&ids_client_name._&wflow_exec_id..txt;

		options orientation=landscape pageno=1 ls=256 ps=83 missing=' ';
		proc printto file="&xl." new;

		proc print data=push_to_xref_checked;
			title "False Negative Autopush List for client &ids_client_name.";
			where scan(audit_comment,1) in ('DUP','LIKELY','PATID');
			by audit_comment audit_result_str notsorted;
			id audit_comment audit_result_str;
			pageby audit_comment;
			format audit_result_str $30. lname $20.;
			var member_key clmcnt ssn fname lname sex dob address1 city zip phone wflow_exec_id;
		run; title;

		proc printto; run;
	%mend mcp_result;
	%mcp_result

	/* map member key from 2nd row to member key from 1st row */
	data t_xref_pushlist(keep=mk_from mk_to);
		set push_to_xref_checked;
		by audit_result_str empirank created_on member_key;
		format mk_from mk_to rtmk 16.;
		retain rtmk ;
		if first.audit_result_str then rtmk=member_key;
		else do;
			if dupcnt=2 then do;
				mk_from=member_key; mk_to=rtmk;
				output t_xref_pushlist;
			end;
		end;
	run;

	/* If the new xref from field is already in existing table to field, we don't want to keep remapping the same 
		member every time. We swap the new xref from and to fields. 
	   The only exception is, if there is now an EMPI member key, we will remap it again, to the EMPI member key.
	*/
	proc sql;
		create table xref_pushlist as
		select	case when substr(put(mk_to,z16.),3,6)=put(&empi_datasource_id.,z6.) then mk_from
					 when patient_key_xref=. then mk_from 
					 else mk_to 
				end as mk_from,
				case when substr(put(mk_to,z16.),3,6)=put(&empi_datasource_id.,z6.) then mk_to
					 when patient_key_xref=. then mk_to 
					 else mk_from 
				end as mk_to
		from	t_xref_pushlist a left join vh_empi.patient_false_negative(keep=patient_key patient_key_xref updated_on where=(updated_on ne .)) b
				on a.mk_from=b.patient_key_xref;

		drop table t_xref_pushlist;
	quit;

	%mcp_ite_xref

	/* after mcp_ite_xref, empi might became from.... for now, don't map it and exclude.
		we need to change mcp_ite_xref so that it ranks empi higher when iterating 
	   looks like it's working, and only "screws up" when there is 1 non-empi and 2 empi, 
		and logic caught the same 1 non-empi mapping to each empi, then we loop through ite
		we end up with 1 of the empi mapping to the other empi.
	*/
	data xref_pushlist(rename=(mk_from=patient_key mk_to=patient_key_xref));
		set xref_pushlist;
		client_key=&client_id.;
		created_on=datetime();
		created_by='false - negative';
		created_wflow_exec_id=&wflow_exec_id.;
		format mk_from mk_to 16.;
		if substr(put(mk_from,z16.),3,6)=put(&empi_datasource_id.,z6.) then do;
			put mk_from= mk_to=;
			delete;
		end;
		else output;
	run;

	/* Start - R1.5.03 Recheck to make sure we do not collapse payer PATIDs 
				Sometimes we have Payer mk A to CI mk 123, then CI mk 123 to payer mk B. After ite macro,
				we know better to do Payer mk A to payer mk B, and CI mk 123 to payer mk B. The first pair
				will violate payer PATID rule.
				There are also cases of Payer mk A to EMPI mk 123, then Payer mk B to EMPI mk 123, and if
				we let this happen, then we would violate payer PATID rule. 
	*/
	%if %str(&emc_payer_dsid_list.)=0 and &empi_datasource_id.=0 %then %do;
		data cistage.fn_pushlist_&client_id._&wflow_exec_id.;
			set xref_pushlist;
		run;
	%end;
	%else %do;
		data xref_pushlist_vertical(index=(member_key));
			set xref_pushlist;
			member_key=patient_key; output;
			member_key=patient_key_xref; output;
		run;

		proc sql;
			create table xref_pushlist_diff_payer_patid as
			select	patient_key_xref, datasourceid, count(distinct system_person_id) as patidcnt
			from	xref_pushlist_vertical(keep=patient_key_xref member_key) a, patk_and_persk2 b
			where	a.member_key=b.member_key
			group by patient_key_xref, datasourceid
			having	patidcnt gt 1;
		quit;

		proc sql;
			create table cistage.fn_pushlist_&client_id._&wflow_exec_id. as
			select	*
			from	xref_pushlist
			where	patient_key_xref not in
					(	select	distinct patient_key_xref
						from	xref_pushlist_diff_payer_patid
					);
		quit;
	%end;
	/* End - R1.5.03 Recheck to make sure we do not collapse payer PATIDs */

	%bulkload_to_cio(&wflow_exec_id.,cistage.fn_pushlist_&client_id._&wflow_exec_id.,
					m_desttable=vh_empi.dbo.patient_false_negative,
					m_keepvar=client_key patient_key patient_key_xref created_on created_by created_wflow_exec_id,
					m_isdatetime=created_on)

	/* quick summary - start */
	proc sql;
		create view false_negative_notempi as
		select	distinct audit_result_str, 1 as pairhasnonempi
		from	cistage.false_negative_&wflow_exec_id.
		where	empirank ne 1;
		create view false_negative_mkcnt as
		select	audit_result_str, count(*) as numof_mk
		from	cistage.false_negative_&wflow_exec_id.
		group by 1
		order by 1;
	quit;
 
	proc sql;
		create table fs_summary as
		select	case when pairhasnonempi=1 then 'NON EMPI' else 'EMPI' end as pair_category, audit_comment, 
				max(numof_mk) as max_numof_mk,
				count(*) format comma8. as mkcnt
		from	cistage.false_negative_&wflow_exec_id. a left join
				false_negative_notempi b on a.audit_result_str=b.audit_result_str left join
				false_negative_mkcnt c on a.audit_result_str=c.audit_result_str
		group by 1,2
		order by 1,2;
	quit;

	data _null_;
		set fs_summary;
		by pair_category;
		if first.pair_category then put ' ';
		put pair_category= audit_comment= max_numof_mk= mkcnt=;
	run;
	/* quick summary - end */

	proc sql noprint;
		select	count(*)
		into	:tgt_record_cnt
		from	xref_pushlist;
	quit;

	proc sql;
		drop table push_to_xref, push_to_xref_checked, inconsistent_xref, swap_xref, temp_xref, double_xref, xref_pushlist;
	quit;

	proc sql noprint;
		  update vbpm.sk_process_control a
		  set EXT_OUTPUT_LOG = "&xl."
		  where a.wflow_exec_id=&wflow_exec_id.
		    and a.client_id=&client_id.
			and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
	quit;
%mend edw_member_consolidation;
%edw_member_consolidation
