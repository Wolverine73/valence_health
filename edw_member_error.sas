
/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_error.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Find false positive (1 member key with multiple patients) from MLA
|
| logic:    see program
|
| input:    Macro parameters and /or SQL server practices
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|                        
| output:   1. Populate vh_empi.person_patient_false_positive with autopush list
|			2. cistage.false_positive_&client_id._&wflow_exec_id. (all potential fixes)
|			3. Listing of autopush list
|
| usage:    reprocess_error will reprocess all claims based on member_key_error
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 25APR2011 - G Liu - Clinical Integration 1.0.01
|             Original
| 08NOV2011 - G Liu - Clinical Integration 1.0.02
|			  Added logic to prevent fixing member keys tie to EMPI
|			  Added EMPI demographic information from member table for iden
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 10MAR2012 - G Liu - Clinical Integration 1.1.02
|			  Temporary bypass of HL7 lab table. If member key in HL7 lab table, mk not eligible to be fixed.
| 12MAR2012 - G Liu - Clinical Integration 1.1.03
|			  If we have (>5 fname or >5 lname) AND >5 DOB in a single mk, then we automatically split all 
|				patients by DOB. If there is at least 1 null DOB in the mk, we don't apply this logic for now.
| 17MAY2012 - G Liu - Clinical Integration 1.2.01
|			  Change to source from VH_EMPI database
|			  Add pre-screen subset clm1aa so program runs on a much smaller subset that is eligible for fixing
| 12JUL2012 - G Liu - Clinical Integration 1.4.01
|			  Relax the rule for MULTPAT-OVERFIX to fix more false positives groups that are outrageously
| 12AUG2012 - G Liu - Clinical Integration 1.5.01
|			  Relax the rule for MULTPAT-OVERFIX to fix more false positives groups that are outrageously
|
| 09AUG2012 - B Fletcher - Clinical Integration 1.5
| 			  Modified the initial 2 datasets to combine into a single query
|
| 09AUG2012 - B Fletcher - Clinical Integration 1.5
|			  Added logic to split member keys if patids and demographics are different within a set (member key and datasourceid)
|			  Do NOT split up member_keys when person combination of (fname,lname,dob,sex) or (ssn,fname,dob) plus zip or phone match. 
|			  If one of the patids are NULL with 2 other populated patids all 3 patids will get new member keys  
|  
| 			M03 Business Rule: within a set of member_keys and datasourceids
|			1.	EMPI records will not be broken up (regardless of demo or patids)
|			2.	For sets of 2 - populated system_member_id – new member_keys
|			3.	For sets of 3 - all populated system_member_id – new member_keys
|			4.	For sets of 3 - at least 2 system_member_Id – all new member_keys
|			5.	For sets of 4 or more - at least 2 system_member_Id – all populated system_member_id with get new member_keys and 1 key for all unpopulated system_member_ids
+-----------------------------------------------------------------------HEADER*/


%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment; 


%client_empi_check(&client_id.);

proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table cistage_allfiles as
	select  *
		from    connection to oledb
   (    SELECT person.person_key
							, coalesce(ds_grp.DATASOURCEID_GROUP, pwd.DATASOURCEID) as practice_id
							, pwd.created_wflow_exec_id as wflow_exec_id
							, ps.system_person_id as system_member_id
							, ssn
							, upper(fname) as fname
							, upper(mname) as mname
							, upper(lname) as lname
							, upper(sex) as sex
							, upper(address1) as address1
							, upper(address2) as address2
							, upper(city) as city
							, upper(state) as state
							, substring(zip,1,5) as zip
							, phone
							, ppm.patient_key as member_key
							, pwd.client_key
							, convert(char(11),dob,112) as dob
							, right('00' + (convert(varchar,pwd.client_key)),2) + right('000000' + (convert(varchar,pwd.datasourceid)),6) as client_group_key
							from  vh_empi.dbo.person_patient_map(nolock) ppm

					INNER JOIN vh_empi.dbo.person(nolock)   person
						  on person.client_key=ppm.client_key
						  and person.person_key=ppm.person_key
						  and ppm.delete_flag=0
							and ppm.person_patient_map_key = (  select  min(d0.person_patient_map_key)
															from    vh_empi.dbo.person_patient_map(nolock) d0
															where   d0.client_key=&client_id.
															and     d0.delete_flag=0
															and     d0.person_key=ppm.person_key    )
					INNER JOIN vh_empi.dbo.person_workflow_detail(nolock)   pwd
						  on pwd.client_key=person.client_key and pwd.person_key=person.person_key
					inner join vh_empi.dbo.person_detail(nolock) pd
						  on person.client_key=pd.client_key
						  and person.person_detail_key=pd.person_detail_key
					left join vh_empi.dbo.person_system(nolock) ps
							on person.client_key=ps.client_key
							and person.person_system_key=ps.person_system_key
					left join vh_empi.dbo.pl_datasource_group(nolock)  ds_grp
						 on pwd.DATASOURCEID = ds_grp.DATASOURCEID
						 where pwd.client_key=&client_id.  		 
				  order by member_key 
			);quit;

%let keepvar=wflow_exec_id client_key practice_id member_key ssn fname mname lname sex dob address1 address2 city state zip phone 
			 system_member_id person_key;

data fname_nickname;
	format sex_fname_nickname sex_fname $17.;
	input sex_fname_nickname sex_fname;
	cards;
	F_ABBY F_ABIGAIL
	F_ANGIE F_ANGELA
	F_ANGIE F_ANGELINA
	F_ANGIE F_ANGELINE
	F_ANN F_ANNA
	F_ANN F_ANNIE
	F_ANNE F_ANNIE
	F_BARB F_BARBARA
	F_BECKY F_REBECCA
	F_BETH F_BETHANY
	F_BETH F_ELIZABETH
	F_BETSY F_ELIZABETH
	F_BETTY F_ELIZABETH
	F_BETTY F_BETTE
	F_CAROL F_CAROLINE
	F_CAROL F_CAROLYN
	F_CATH F_CATHERINE
	F_CATH F_CATHLEEN
	F_CATH F_CATHY
	F_CATHY F_CATHERINE
	F_CATHY F_CATHLEEN
	F_CHRIS F_CHRISTINA
	F_CHRIS F_CHRISTINE
	F_CHRISTIE F_CHRISTINA
	F_CHRISTIE F_CHRISTINE
	F_CHRISTINE F_CHRISTINA
	F_CHRISTY F_CHRISTINA
	F_CHRISTY F_CHRISTINE
	F_CINDY F_CYNTHIA
	F_CONNIE F_CONSTANCE
	F_CYNDI F_CYNTHIA
	F_DANNY F_DENISE
	F_DEB F_DEBORAH
	F_DEBBIE F_DEBORAH
	F_DEBBY F_DEBORAH
	F_DEBBIE F_DEBORA
	F_DEBBIE F_DEBRA
	F_DEBRA F_DEBORAH
	F_DI F_DIANA
	F_DOTTIE F_DOROTHY
	F_FRAN F_FRANCES
	F_GERI F_GERALDINE
	F_GERT F_GERTRUDE
	F_GWEN F_GWENDOLYN
	F_HELEN F_HELENE
	F_HELEN F_HELENA
	F_ISABEL F_ISABELLA
	F_JACKIE F_JACQUELINE
	F_JACKIE F_JACQUELYN
	F_JAN F_JANET
	F_JAN F_JANICE
	F_JEN F_JENNIFER
	F_JEN F_JENNY
	F_JENNY F_JENNIFER
	F_JILL F_JILLIAN
	F_JO F_JOANN
	F_JO F_JOANNE
	F_JO F_JOSEPHINE
	F_JOY F_JOYCE
	F_JUDI F_JUDITH
	F_JUDY F_JUDITH
	F_JULES F_JULIA
	F_JULIE F_JULIA
	F_KATE F_KATHERINE
	F_KATE F_KATHLEEN
	F_KATHY F_KATHLEEN
	F_KATHY F_KATHRYN
	F_KATHY F_KATHERINE
	F_KATIE F_KATHERINE
	F_KATIE F_KATHLEEN
	F_KATIE F_KATHRYN
	F_KIM F_KIMBERLY
	F_KIM F_KIMBERLEY
	F_KIM F_KIMBERLEE
	F_KRIS F_KRISTINE
	F_LIZ F_ELIZABETH
	F_LORI F_LORRAINE
	F_LUCY F_LUCILLE
	F_MAGGIE F_MARGARET
	F_MANDY F_AMANDA
	F_MARGE F_MARGARET
	F_MARGE F_MARJORIE
	F_MARGIE F_MARGARET
	F_MARGIE F_MARJORIE
	F_MILLIE F_MILDRED
	F_PAM F_PAMELA
	F_PAT F_PATRICIA
	F_PAT F_PATSY
	F_PATSY F_PATRICIA
	F_PATTI F_PATRICIA
	F_PATTY F_PATRICIA
	F_PENNY F_PENELOPE
	F_SAM F_SAMANTHA
	F_SANDI F_SANDRA
	F_SANDY F_SANDRA
	F_SHARI F_SHARON
	F_STEPH F_STEPHANIE
	F_SUE F_SUSAN
	F_SUE F_SUZANNE
	F_SUSIE F_SUSAN
	F_TAMMY F_TAMARA
	F_TERRI F_TERESA
	F_TERRI F_THERESA
	F_TERRI F_THERESE
	F_TERRY F_TERESA
	F_TINA F_CHRISTINA
	F_TRACY F_THERESA
	F_TRICIA F_PATRICIA
	F_TRISH F_TRICIA
	F_VIC F_VICTORIA
	F_VICKI F_VICTORIA
	F_VICKIE F_VICTORIA
	F_VICKY F_VICTORIA
	M_AL M_ALAN
	M_AL M_ALBERT
	M_AL M_ALFRED
	M_ALBERT M_ALBERTO
	M_ALEC M_ALEXANDER
	M_ALEX M_ALEXANDER
	M_ANDY M_ANDREW
	M_ARNIE M_ARNOLD
	M_ART M_ARTEM
	M_ART M_ARTHUR
	M_BEN M_BENJAMIN
	M_BENNY M_BENJAMIN
	M_BERNIE M_BERNARD
	M_BILL M_WILLIAM
	M_BILL M_BILLY
	M_BILLY M_WILLIAM
	M_BOB M_ROBERT
	M_BOB M_BOBBY
	M_BOBBY M_ROBERT
	M_BRAD M_BRADLEY
	M_BRAD M_BRADFORD
	M_CHARLIE M_CHARLES
	M_CHRIS M_CHRISTOPHER
	M_CHRIS M_CHRISTIAN
	M_CHUCK M_CHARLES
	M_CLAY M_CLAYTON
	M_CLIFF M_CLIFFORD
	M_CLINT M_CLINTON
	M_CURT M_CURTIS
	M_DAN M_DANIEL
	M_DAN M_DANNY
	M_DANNY M_DANIEL
	M_DAVE M_DAVID
	M_DICK M_RICHARD
	M_DICKY M_RICHARD
	M_DON M_DONALD
	M_DONNIE M_DONALD
	M_DOUG M_DOUGLAS
	M_ED M_EDDIE
	M_ED M_EDWARD
	M_EDDIE M_EDWARD
	M_EMIL M_EMILIANO
	M_ERNIE M_ERNEST
	M_FRANK M_FRANCIS
	M_FRANK M_FRANKLIN
	M_FRANKIE M_FRANK
	M_FRED M_ALFRED
	M_FRED M_FREDERICK
	M_FRED M_FREDRICK
	M_FRED M_FREDDIE
	M_GEOFF M_GEOFFREY
	M_GREG M_GREGORY
	M_GREGG M_GREGORY
	M_GUS M_GUSTAVO
	M_HARRY M_HAROLD
	M_HERB M_HERBERT
	M_JACKIE M_JACK
	M_JAKE M_JACOB
	M_JEFF M_JEFFREY
	M_JERRY M_GERALD
	M_JERRY M_JEROME
	M_JIM M_JAMES
	M_JIM M_JIMMY
	M_JIMMY M_JAMES
	M_JOE M_JOSEPH
	M_JOE M_JOSE
	M_JOE M_JOEY
	M_JOEY M_JOSEPH
	M_JACK M_JOHN
	M_JOHN M_JOHNNY
	M_JOHN M_JONATHAN
	M_JOHN M_JOHNATHAN
	M_JOHNNY M_JONATHAN
	M_JON M_JONATHAN
	M_JOSE M_JOSEPH
	M_JOSH M_JOSHUA
	M_KEN M_KENNETH
	M_KEN M_KENNY
	M_KENNY M_KENNETH
	M_KURT M_CURTIS
	M_LARRY M_LAWRENCE
	M_LARRY M_LAURENCE
	M_LENNY M_LEONARDO
	M_LEO M_LEONARDO
	M_LOU M_LOUIS
	M_LUKE M_LUCAS
	M_MARC M_MARCUS
	M_MARTY M_MARTIN
	M_MATT M_MATTHEW
	M_MAX M_MAXWELL
	M_MEL M_MELVIN
	M_MICK M_MICHAEL
	M_MICK M_MICKEY
	M_MICKEY M_MICHAEL
	M_MIKE M_MICHAEL
	M_MIKEY M_MICHAEL
	M_MITCH M_MITCHELL
	M_NATE M_NATHAN
	M_NATE M_NATHANIEL
	M_NATHAN M_NATHANIEL
	M_NICK M_NICHOLAS
	M_NICKY M_NICHOLAS
	M_NORM M_NORMAN
	M_PAT M_PATRICK
	M_PETE M_PETER
	M_PHIL M_PHILIP
	M_PHIL M_PHILLIP
	M_RANDY M_RANDALL
	M_RANDY M_RANDOLPH
	M_RAY M_RAYMOND
	M_RICH M_RICHARD
	M_RICK M_RICHARD
	M_RICK M_RICKY
	M_RICK M_RICKEY
	M_ROB M_ROBERT
	M_ROBERT M_ROBERTO
	M_ROD M_RODNEY
	M_RON M_RONALD
	M_RON M_RONNIE
	M_RONNIE M_RONALD
	M_RUDY M_RUDOLPH
	M_RUSS M_RUSSELL
	M_SAM M_SAMUEL
	M_SAM M_SAMMY
	M_SAMMY M_SAMUEL
	M_SID M_SIDNEY
	M_STAN M_STANLEY
	M_STEVE M_STEVEN
	M_STEVE M_STEPHEN
	M_STEVIE M_STEVEN
	M_TED M_THEODORE
	M_TED M_TEDDY
	M_TEDDY M_THEODORE
	M_TERRY M_TERRENCE
	M_TERRY M_TERRANCE
	M_TIM M_TIMOTHY
	M_TOM M_THOMAS
	M_TOM M_TOMMY
	M_TOMMY M_THOMAS
	M_TONY M_ANTHONY
	M_VERN M_VERNON
	M_VIC M_VICTOR
	M_VINCE M_VINCENT
	M_WILL M_WILLIAM
	M_WILLIE M_WILLIAM
	M_ZACH M_ZACHARY
;
run;

%let mep_autopush_category='DIFF-AUTO','FAMILY-AUTO','MULTBIRTH-AUTO','MULTPAT-AUTO','NAMEDIFF-AUTO','SAMENAME-AUTO','SOUNDPROB-AUTO';

%macro mep_iden_fp;
	/* Collaspe all records by demographic columns plus check for multi patids within a member_key and practice_id recordset */
	proc sql;
	create view meminfo_from_clm1a as
		 select all.member_key
			  , strip(ssn)   as ssn   , strip(fname)    as fname
			  , strip(mname) as mname , strip(lname)    as lname    , strip(sex)      as sex
			  , strip(dob)   as dob   , strip(address1) as address1 , strip(address2) as address2
			  , strip(city)  as city  , strip(zip)      as zip      , strip(phone)    as phone
			  , count(*)     as clmcnt 
			  , coalesce(multipatids.uniqueperson, 0) as uniqueperson
		from    cistage_allfiles all
		left join (  select distinct member_key, practice_id, count(distinct coalesce(system_member_id, '0')) as uniqueperson
					   from cistage_allfiles
					   where practice_id NE coalesce(&empi_datasource_id.,0)
					  group by member_key, practice_id
					 having count(distinct system_member_id) > 1) multipatids
		on all.member_key = multipatids.member_key
		and all.practice_id = multipatids.practice_id
		group by all.member_key,2,3,4,5,6,7,8,9,10,11,12 
	;
	quit;
	
	/* 1) eliminate recordsets where all demographics are identical except for below scenarios -- no false positive can exist 
	   2) retain member_key where multiple patids exist in member_key and practiced id set to perform an additional check later in the program
	 */
    proc sql;   
	create view meminfo_from_clm1aa as
        select  *
        from    meminfo_from_clm1a
        group by member_key
        having  count(distinct ssn||fname||mname||lname||sex||dob) ne 1
             or uniqueperson > 1;
    quit;


	data meminfo_from_clm1b(drop=i);
		set meminfo_from_clm1aa;
		origssn=ssn; origfname=fname; origmname=mname; origlname=lname; origsex=sex; origdob=dob; 
		origaddr1=address1; origaddr2=address2; origcity=city; origzip=zip; origphone=phone;
		%ssntest;
		if ssnTYPE='INVALID' then ssn='';
		if 	&client_id.=4 and dob in ('18001228','19010101') or 
			&client_id.=6 and dob in ('18991230','19000101','19010101','19200101') or
			&client_id. not in (4,6) and dob='19010101' or
			not ('1890' le substr(dob,1,4) le year("&sysdate."d)) then dob='';

		fname=compbl(cats(upcase(fname)));
		fname=tranwrd(fname,'- ','-');
		fname=tranwrd(fname,' -','-');
		fname=tranwrd(fname,'SR.','SR');
		fname=tranwrd(fname,'JR.','JR');
		if fname='BABY' or index(fname,'BABY') and (index(fname,'BOY') or index(fname,'GIRL') or index(fname,'TWIN')) then fname='';
		if fname ne '' and substr(fname,length(fname),1)='.' then fname=substr(fname,1,length(fname)-1);
		if length(scan(fname,2))=1 and scan(fname,3)='' and mname='' then do; fname=scan(fname,1); mname=scan(fname,2); end;

		lname=compbl(cats(upcase(lname)));
		lname=tranwrd(lname,'- ','-');
		lname=tranwrd(lname,' -','-');
		lname=tranwrd(lname,'SR.','SR');
		lname=tranwrd(lname,'JR.','JR');
		lname=tranwrd(lname,'M.D.','MD');
		lname=tranwrd(lname,'(EXPIRED)','');
		if lname ne '' and substr(lname,length(lname),1)='.' then lname=substr(lname,1,length(lname)-1);

		if fname=lname='REUSE' then do; fname=''; lname=''; end;

		format addrscan $20. addrscan_zip $25. addrscan_city $35. addrnum_zip $13. zip3 $3.;
		/* if add address or phone fields here, make sure to add in step 1b */

		zip3=zip;
		if length(phone) lt 9 or substr(phone,4,6) in ('000000','111111','222222','333333','444444','555555','666666','777777','888888','999999') then phone='';
		/* if last digit is off, it is acceptable */

		address1=compbl(cats(upcase(address1)));
		do i=2 to min(length(address1),7);
			if '0' le substr(address1,i-1,1) le '9' and 'A' le substr(address1,i,1) le 'Z' or
			   'A' le substr(address1,i-1,1) le 'Z' and '0' le substr(address1,i,1) le '9' then address1=substr(address1,1,i-1)||' '||substr(address1,i);
		end;
		if '0' le substr(scan(address1,1),1,1) le '9' or 
			length(scan(address1,1)) gt 1 and '0' le substr(scan(address1,1),2,1) le '9' then do;
			if scan(address1,2) in ('N','S','E','W','NE','NW','SE','SW',
									'NORTH','SOUTH','EAST','WEST',
									'NORTHEAST','NORTHWEST','SOUTHEAST','SOUTHWEST') then addrscan=scan(address1,1)||' '||scan(address1,3);
			else addrscan=scan(address1,1)||' '||scan(address1,2);

			if length(zip)=5 then do; 
				addrscan_zip=trim(addrscan)||' '||zip;
				addrnum_zip=scan(address1,1)||' '||zip;
			end;

			if city ne '' then addrscan_city=trim(addrscan)||' '||city;
		end;
	run;

	proc sql;
		create view v_meminfo_from_clm1b as
		select	*, count(*) as dupcnt, count(distinct fname) as fname_cnt, count(distinct lname) as lname_cnt,
				count(fname) as fname_nn, count(lname) as lname_nn
		from	meminfo_from_clm1b
		group by member_key;
	quit;
	data meminfo_from_clm1b meminfo_from_clm1b_nameok;
		set v_meminfo_from_clm1b;
		if fname_nn=lname_nn=dupcnt and fname_cnt=lname_cnt=1 then output meminfo_from_clm1b_nameok;
		else output meminfo_from_clm1b;
		drop dupcnt fname_cnt lname_cnt fname_nn lname_nn;
	run;
	/* Pick (more correct) long version of 2-word names */
	%macro pick_long_name(m_name);
		proc sql;
			create table pln_summname as
			select	distinct member_key, &m_name.
			from	meminfo_from_clm1b;

			create table pln_scrubname as
			select	distinct a.member_key, a.&m_name. as longname, b.&m_name. as name_compress,
					case when 0 lt index(a.&m_name.,"'") lt length(a.&m_name.) then 1
						 when 0 lt index(a.&m_name.,"-") lt length(a.&m_name.) then 2
						 when 0 lt index(a.&m_name.,'(') lt length(a.&m_name.) then 3
						 when 0 lt index(a.&m_name.,'"') lt length(a.&m_name.) then 4
						 when 0 lt index(a.&m_name.,',') lt length(a.&m_name.) then 5
						 when 0 lt index(a.&m_name.,';') lt length(a.&m_name.) then 6
						 when 0 lt index(a.&m_name.,' ') lt length(a.&m_name.) then 7
						 else 99
					end as longname_rank, 
					length(a.&m_name.) as longname_length
			from	pln_summname a, pln_summname b
			where	a.member_key=b.member_key
			and	(	scan(a.&m_name.,2,'-"(),; ') ne '' and compress(a.&m_name.,'-"(),; ')=b.&m_name. 
				 or scan(a.&m_name.,2,"-'(),; ") ne '' and compress(a.&m_name.,"-'(),; ")=b.&m_name.	)
			and		a.&m_name. ne b.&m_name.
			order by member_key, longname_rank, longname_length desc, longname;
		quit;

		data pln_best_longname(keep=member_key longname name_compress);
			set pln_scrubname;
			by member_key longname_rank descending longname_length longname;
			if first.member_key;
		run;

		proc sql;
			create table pln_remapname as
			select	a.member_key, a.longname as &m_name., b.longname as maptoname
			from	pln_scrubname a, pln_best_longname b
			where	a.member_key=b.member_key and a.name_compress=b.name_compress
			and		a.longname ne b.longname
		  union
			select	member_key, name_compress as &m_name., longname as maptoname
			from	pln_best_longname
			order by 1,2,3;
		quit;

		data meminfo_from_clm1b(drop=maptoname);
			if _n_=0 then set pln_remapname;
			declare hash h_pln(dataset:'pln_remapname');
			h_pln.defineKey('member_key',"&m_name.");
			h_pln.defineData('maptoname');
			h_pln.defineDone();
			call missing(member_key,&m_name.,maptoname);

			do while (not lstobs);
				maptoname='';
				set meminfo_from_clm1b end=lstobs;
				if h_pln.find()=0 then &m_name.=maptoname;
				output;
			end;
			stop;
		run;
		proc datasets lib=work nolist; delete pln_:; quit;
	%mend pick_long_name;
	%pick_long_name(lname);
	%pick_long_name(fname);
	proc append base=meminfo_from_clm1b data=meminfo_from_clm1b_nameok; run;

	/* Substitute first name nickname to long name */
	proc sql;
		create table sfn_summname as
		select	distinct member_key, sex, fname, substr(sex,1,1)||"_"||fname as sex_fname
		from	meminfo_from_clm1b;

		create table scrub_fname_nickname(rename=(longname=maptoname)) as
		select	distinct a.member_key, a.fname as longname, b.sex, b.fname
		from	sfn_summname a, sfn_summname b, fname_nickname x
		where	a.member_key=b.member_key
		and	(	a.sex_fname=x.sex_fname_nickname and b.sex_fname=x.sex_fname
			 or b.sex_fname=x.sex_fname_nickname and a.sex_fname=x.sex_fname)
		and	(	length(a.fname) gt length(b.fname)
			 or length(a.fname) eq length(b.fname) and a.fname gt b.fname)
		group by 1,3
		having	longname=max(longname)
		order by 1,2,3;
	quit;

	data meminfo_from_clm1b(drop=maptoname);
		if _n_=0 then set scrub_fname_nickname;
		declare hash h_sfn(dataset:'scrub_fname_nickname');
		h_sfn.defineKey('member_key','sex','fname');
		h_sfn.defineData('maptoname');
		h_sfn.defineDone();
		call missing(member_key,sex,fname,maptoname);

		do while (not lstobs);
			maptoname='';
			set meminfo_from_clm1b end=lstobs;
			if h_sfn.find()=0 then fname=maptoname;
			output;
		end;
		stop;
	run;
	proc sql; drop table sfn_summname, scrub_fname_nickname; quit;

	/* If names are flipped, even if they are different patient who happens to have names flipped, you would still wonder if it's
		possible that they should have the same name. Meaning, as far as true comparison purpose, they won't do us any good anyway,
		which means we'll have to depend on other fields. That's why we scrub the names, and flip them so that in SAS logic they
		would look the same for comparison.
	*/
	proc sql;
		create table flipnm_summname as
		select	member_key, fname, lname, sum(clmcnt) as cnt
		from	meminfo_from_clm1b
		group by 1,2,3;

		create table flipnm_scrubname as
		select	a.member_key, a.fname, a.lname, b.fname as maptofname, b.lname as maptolname
		from	flipnm_summname a, flipnm_summname b
		where	a.member_key=b.member_key
		and		a.fname ne '' and a.fname=b.lname 
		and 	a.lname ne '' and a.lname=b.fname
		and		a.fname ne a.lname
		and		a.cnt le b.cnt
		group by a.member_key
		having	fname||lname=min(fname||lname);
	quit;

	data meminfo_from_clm1b(drop=maptofname maptolname);
		if _n_=0 then set flipnm_scrubname;
		declare hash h_fs(dataset:'flipnm_scrubname');
		h_fs.defineKey('member_key','fname','lname');
		h_fs.defineData('maptofname','maptolname');
		h_fs.defineDone();
		call missing(member_key,fname,lname,maptofname,maptolname);

		do while (not lstobs);
			maptofname=''; maptolname='';
			set meminfo_from_clm1b end=lstobs;
			if h_fs.find()=0 then do;
				fname=maptofname;
				lname=maptolname;
			end;
			output;
		end;
		stop;
	run;
	proc sql; drop table flipnm_summname, flipnm_scrubname; quit;

	proc sort data=meminfo_from_clm1b out=meminfo_from_clm1c; by member_key ssn fname lname sex dob descending address1 city zip descending phone;
	data meminfo_from_clm1c(drop=lag: index=(member_key));
		set meminfo_from_clm1c;
		by member_key ssn fname lname sex dob descending address1 city zip descending phone;
		lagaddress1=lag(address1); lagaddrscan_city=lag(addrscan_city); lagaddrscan_zip=lag(addrscan_zip); lagaddrnum_zip=lag(addrnum_zip);
		lagcity=lag(city); lagzip=lag(zip); lagzip3=lag(zip3); lagphone=lag(phone);
		if ssn ne '' and not first.dob then do;
			/* filling in missing addr and/or phone only if SSN, fname, lname, sex, DOB all match within the same member_key */
			if address1='' and city='' and zip='' and (lagaddress1 ne '' or lagcity ne '' or lagzip ne '') then do;
				address1=lagaddress1; addrscan_city=lagaddrscan_city; addrscan_zip=lagaddrscan_zip; addrnum_zip=lagaddrnum_zip;
				city=lagcity; zip=lagzip; zip3=lagzip3;
			end;
			if phone='' and lagphone ne '' then phone=lagphone;
		end;
	run;

	proc sql;
		create view meminfo_from_clm1d as
		select	*, count(*) as dupcnt,
				count(distinct ssn) as ssncnt, count(ssn) as ssncnt_nn,
				count(distinct soundex(fname)) as fnamescnt, count(distinct fname) as fnamecnt, 
				count(distinct substr(fname,1,2)) as fname12cnt, count(fname) as fnamecnt_nn,
				count(distinct soundex(lname)) as lnamescnt, count(distinct lname) as lnamecnt, 
				count(distinct dob) as dobcnt, count(dob) as dobcnt_nn, 
				count(distinct sex) as sexcnt,
				count(distinct addrscan_city) as addrscancitycnt, count(addrscan_city) as addrscancitycnt_nn,
				count(distinct addrscan_zip) as addrscanzipcnt, count(addrscan_zip) as addrscanzipcnt_nn, 
				count(distinct phone) as phonecnt, count(phone) as phonecnt_nn
		from	meminfo_from_clm1c
		group by member_key
		order by member_key, clmcnt desc, fname, lname;
	quit;

	data meminfo_from_clm2 meminfo_from_clm2_dobok;
		set meminfo_from_clm1d;
		RID=_n_;
		if dobcnt_nn=dupcnt and dobcnt=1 then output meminfo_from_clm2_dobok;
		else output meminfo_from_clm2;
	run;

  %macro loop_find_dobtypo(dobsortorder=1);
	/* sort order is used so that if A,B,B,B,C, then we sort A one time and see if we can find A in any of the 3 Bs, and if not, 
  		the 2nd iteration, we want to try to find C in the 3 Bs. If we keep the sort order the same, we'll always try A and never 
  		try C */
	proc datasets nolist;
		modify meminfo_from_clm2;
			index create tablekey1=(member_key dob);
	quit;
	
	%let lfd_dsid=%sysfunc(open(meminfo_from_clm2));
	%let lfd_varind=%sysfunc(varnum(&lfd_dsid.,dob_valpct));
	%let lfd_dsrc=%sysfunc(close(&lfd_dsid.));
	proc sql;
		create table meminfo_from_clm3 as
		select	*, count(*)/dupcnt as dob_valpct
		from	meminfo_from_clm2 %if &lfd_varind. %then %do; (drop=dob_valpct) %end;
		group by member_key, dob
		order by member_key, dob_valpct desc, dob %if &dobsortorder.=2 %then %do; desc %end;;
	quit;

	data minority_dob;
		set meminfo_from_clm3;
		by member_key descending dob_valpct %if &dobsortorder.=2 %then %do; descending %end; dob;
		if last.member_key and dob_valpct lt .50001;
		/* if 1 vs 1 (i.e. pct=.5), as long as within 16 years, probably same person, with weird DOB typo */
	run;

	proc datasets nolist;
		modify meminfo_from_clm3;
			index create tablekey2=(member_key fname lname);
		modify minority_dob;
			index create tablekey2=(member_key fname lname);
	quit;
	proc sql;
		create table minority_dob_probablytypo(drop=addrscan_city addrscan_zip) as
		select	distinct a.*, b.dob as dob_typo, 
				case when a.dob='' then 99999999 
					/* .5 is to break tie in case the "typo" dob is midpoint of 2 other DOBs with same dob_valpct weight */
					 when a.dob gt b.dob then abs(mdy(input(substr(a.dob,5,2),2.),input(substr(a.dob,7,2),2.),input(substr(a.dob,1,4),4.)) - 
												  mdy(input(substr(b.dob,5,2),2.),input(substr(b.dob,7,2),2.),input(substr(b.dob,1,4),4.))) + .5
					 else abs(mdy(input(substr(a.dob,5,2),2.),input(substr(a.dob,7,2),2.),input(substr(a.dob,1,4),4.)) - 
							  mdy(input(substr(b.dob,5,2),2.),input(substr(b.dob,7,2),2.),input(substr(b.dob,1,4),4.))) 
				end as dob_typodiff
		from	minority_dob a, meminfo_from_clm3 b
		where	a.member_key=b.member_key
		and		a.fname=b.fname and a.lname=b.lname
		and		b.dobcnt ne 1
		and		a.dob ne b.dob
		and	(	a.addrscan_city ne '' and a.addrscan_city=b.addrscan_city 
			 or a.addrscan_zip ne '' and a.addrscan_zip=b.addrscan_zip
			 or a.phone ne '' and a.phone=b.phone)
		group by a.member_key
		/* if greater than 16 years apart, it could be family members with same name */
		having	dob_valpct=max(dob_valpct) and dob_typodiff=min(dob_typodiff) and dob_typodiff lt 365.25*16;
	quit;

	%let eme_dsid=%sysfunc(open(minority_dob_probablytypo));
	%let eme_nobs=%sysfunc(attrn(&eme_dsid.,nobs));
	%let eme_dsrc=%sysfunc(close(&eme_dsid.));
	%if &eme_nobs. %then %do;
		data meminfo_from_clm3(drop=dob_typo);
			if _n_=0 then set minority_dob_probablytypo(keep=RID dob_typo);
			declare hash h_mdp(dataset:'minority_dob_probablytypo(keep=RID dob_typo)');
			h_mdp.defineKey('RID');
			h_mdp.defineData('dob_typo');
			h_mdp.defineDone();
			call missing(RID,dob_typo);

			do while (not lstobs);
				dob_typo=.;
				set meminfo_from_clm3(drop=dob_valpct) end=lstobs;
				if h_mdp.find()=0 then dob=dob_typo;
				output;
			end;
			stop;
		run;
	%end;

	proc datasets nolist;
		delete meminfo_from_clm2;
		change meminfo_from_clm3=meminfo_from_clm2;
	quit;
  %mend loop_find_dobtypo;
	%loop_find_dobtypo;
	%loop_find_dobtypo(dobsortorder=2);
	%loop_find_dobtypo;
	%loop_find_dobtypo(dobsortorder=2);
	%loop_find_dobtypo;
	%loop_find_dobtypo(dobsortorder=2);

	%let eme_dsid=%sysfunc(open(meminfo_from_clm2));
	%let eme_varind=%sysfunc(varnum(&eme_dsid.,dob_valpct));
	%let eme_dsrc=%sysfunc(close(&eme_dsid.));
	data meminfo_from_clm3(index=(member_key));
		set meminfo_from_clm2_dobok meminfo_from_clm2 %if &eme_varind. %then %do; (drop=dob_valpct) %end;;
	run;

	/* If fname and lname are flipped, don't count them as different patients */
	proc sql;
		create table perform_flname as
		select	distinct a.member_key, 
				soundex(a.fname) as f1sound, soundex(a.lname) as l1sound,
				soundex(b.fname) as f2sound, soundex(b.lname) as l2sound
		from	meminfo_from_clm3 a, meminfo_from_clm3 b
		where	a.member_key=b.member_key
		and		a.fnamescnt=b.lnamescnt=2
		group by a.member_key
		having	f1sound=l2sound and f2sound=l1sound
		and		f1sound ne f2sound
		and		f1sound=min(soundex(a.fname))
		and		f2sound=max(soundex(b.fname))
		order by member_key;
	quit;
	data meminfo_from_clm3;
		merge meminfo_from_clm3 perform_flname(in=b keep=member_key);
		by member_key;
		if b then do;
			fnamescnt=1; lnamescnt=1;
		end;
	run;

	%macro eme_create_perform(m_var);
	  /* recount dob since we changed DOB above using the minority logic */
	  proc sql;
		create table perform_&m_var. as
		select	distinct member_key, count(distinct &m_var.) as &m_var.cnt, &m_var.
		from	meminfo_from_clm3
		group by member_key
		order by member_key;
	  quit;
	%mend eme_create_perform;
	%eme_create_perform(dob);

	%macro eme_create_perform_nm(m_var);
	  proc sql;
		create table perform_&m_var. as
		select	distinct member_key, &m_var.scnt, soundex(&m_var.) as &m_var._sound, &m_var., length(&m_var.) as &m_var._length
		from	meminfo_from_clm3
		order by member_key, &m_var._sound, &m_var._length;
	  quit;
	  data perform_&m_var.(drop=&m_var._:);
		set perform_&m_var.;
		by member_key &m_var._sound &m_var._length;
		/* if sound is same, keep the longest name for comparison later. */
		if last.&m_var._sound;
	  run;
	%mend eme_create_perform_nm;
	%eme_create_perform_nm(fname);
	%eme_create_perform_nm(lname);

	data mod_dob(keep=member_key dobcnt dob6_digit_diff dob_value_diff rename=(dobcnt=mod_dobcnt));
		set perform_dob;
		by member_key;
		dobyr=substr(dob,1,4); dobmo=substr(dob,5,2); dobdy=substr(dob,7,2); dob6=substr(dob,3,6);
		lagdob=lag(dob); lagdobyr=lag(dobyr); lagdobmo=lag(dobmo); lagdobdy=lag(dobdy); 
		if dob ne '' then dob_n=mdy(input(substr(dob,5,2),2.),input(substr(dob,7,2),2.),input(substr(dob,1,4),4.));
		lagdob6=lag(dob6); lagdob_n=lag(dob_n);
		if dobcnt ne 2 then output;
		else if dobcnt=2 and last.member_key then do;
					%count_digit_diff(dobyr,dobyr,lagdobyr);
					%count_digit_diff(dobmo,dobmo,lagdobmo);
					%count_digit_diff(dobdy,dobdy,lagdobdy);
					if dob='' and lagdob ne '' or dob ne '' and lagdob='' then dobcnt=2;
					else if dob='' and lagdob='' then dobcnt=1;
					else if sum(dobdy_digit_diff,dobmo_digit_diff,dobyr_digit_diff)=0 or
							dobyr_digit_diff=0 and dobmo=lagdobdy and dobdy=lagdobmo or
							dobdy_digit_diff=dobmo_digit_diff=0 and dobyr_digit_diff le 2 or
							dobdy_digit_diff=dobyr_digit_diff=0 or
							dobmo_digit_diff=dobyr_digit_diff=0 then dobcnt=1;
					else dobcnt=2;
					%count_digit_diff(dob6,dob6,lagdob6);
					if dob_n ne . and lagdob_n ne . then dob_value_diff=abs(dob_n-lagdob_n);
			output;
		end;
	run;
	data mod_fname(keep=member_key fnamescnt rename=(fnamescnt=mod_fnamescnt));
		set perform_fname;
		by member_key;
		lagfname=lag(fname); 
		if fnamescnt ne 2 then output;
		else if fnamescnt=2 and last.member_key then do;
					%count_digit_diff(fname,fname,lagfname);
					if fname='' and lagfname ne '' or fname ne '' and lagfname='' then fnamescnt=2;
					else if fname='' and lagfname='' then fnamescnt=1;
					else do;
						if (length(fname) ge 6 or length(lagfname) ge 6) and 
							fname_digit_diffpct le .301 then fnamescnt=1;
						/* Nickname in first name with parentheses */
						else if fname ne '' and fname=scan(lagfname,2,'()') or 
								lagfname ne '' and lagfname=scan(fname,2,'()') then fnamescnt=1;
						*else fnamescnt=2;
					end;
			output;
		end;
	run;
	data mod_lname(keep=member_key lnamescnt rename=(lnamescnt=mod_lnamescnt));
		set perform_lname;
		by member_key;
		laglname=lag(lname);
		if lnamescnt ne 2 then output;
		else if lnamescnt=2 and last.member_key then do;
					%count_digit_diff(lname,lname,laglname);
					if lname='' and laglname ne '' or lname ne '' and laglname='' then lnamescnt=2;
					else if lname='' and laglname='' then lnamescnt=1;
					else do;
						if (length(lname) ge 6 or length(laglname) ge 6) and 
							lname_digit_diffpct le .301 then lnamescnt=1;
						/* Maiden name in last name, or 2-word last name */
						else if lname ne '' and lname=scan(laglname,2,'-') or 
								laglname ne '' and laglname=scan(lname,2,'-') then lnamescnt=1;
						/* Last Name has Suffix */
						else if lname ne '' and lname=scan(laglname,1) and scan(laglname,2) in ('JR','SR','I','II','III','IV','V','VI') or 
								laglname ne '' and laglname=scan(lname,1) and scan(lname,2) in ('JR','SR','I','II','III','IV','V','VI') then lnamescnt=1;
						*else lnamescnt=2;
					end;
			output;
		end;
	run;

	proc sort data=mod_dob nodup; by member_key mod_dobcnt;
	proc sort data=mod_fname nodup; by member_key mod_fnamescnt;
	proc sort data=mod_lname nodup; by member_key mod_lnamescnt;
	proc sort data=meminfo_from_clm3 out=meminfo_from_clm4; by member_key;
	data meminfo_from_clm4;
		merge meminfo_from_clm4(drop=RID) mod_dob mod_fname mod_lname;
		by member_key;
		sortparm1=soundex(fname);
		sortparm2=soundex(lname);
	run;

	/* BUCKET POTENTIAL RECORDS TO BE SPLIT */ 
	proc sort data=meminfo_from_clm4; by member_key sortparm1 dob sortparm2 fname lname phone address1 city zip;
	data meminfo_from_clm4(drop=lag: sortparm:) audit_falseposlist(keep=member_key audit_comment);
		set meminfo_from_clm4;
		by member_key sortparm1 dob sortparm2 fname lname phone address1 city zip;
		lagfname=lag(fname); laglname=lag(lname); lagdob=lag(dob); 
		lagaddrscan_city=lag(addrscan_city); lagaddrscan_zip=lag(addrscan_zip);
		lagphone=lag(phone);
		retain patnum;
		if first.member_key then patnum=0;

		/* if name is same but sex is diff, then don't count sex being diff */
		mod_sexcnt=sexcnt;
		if mod_fnamescnt=1 and mod_sexcnt ne 1 then mod_sexcnt=1;

		format audit_comment $15.;
		if sum(mod_fnamescnt ne 1, mod_lnamescnt ne 1, mod_dobcnt ne 1, mod_sexcnt ne 1) ge 2 and dupcnt gt 1 then do;
			if mod_fnamescnt gt 2 and mod_fnamescnt=mod_lnamescnt=mod_dobcnt then do;
				audit_comment='MULTPAT-AUTO';
				if first.member_key then patnum=1;
				else patnum+1;
				if last.member_key and patnum ne mod_fnamescnt then audit_comment='MULTPAT-CHECK';
			end;
			else if mod_fnamescnt gt 2 and fname12cnt=mod_fnamescnt and mod_lnamescnt=mod_dobcnt=1 then do;
				audit_comment='MULTBIRTH-AUTO';
				if first.member_key then patnum=1;
				else patnum+1;
				if last.member_key and patnum ne mod_fnamescnt then audit_comment='MULTPAT-CHECK';
			end;
			else if mod_fnamescnt gt 2 and fname12cnt=mod_fnamescnt=mod_dobcnt and mod_lnamescnt=1 then do;
				audit_comment='FAMILY-AUTO';
				if first.member_key then patnum=1;
				else patnum+1;
				if last.member_key and patnum ne mod_fnamescnt then audit_comment='MULTPAT-CHECK';
			end;
			else if mod_fnamescnt gt 2 or mod_lnamescnt gt 2 or mod_dobcnt gt 2 or mod_sexcnt gt 2 then audit_comment='MULTI';
			else if mod_fnamescnt=2 and mod_dobcnt=2 then do;
				audit_comment='DIFF-AUTO';
				if first.member_key then patnum=1;
				else if soundex(lagfname) ne soundex(fname) or lagdob ne dob then patnum+1;
				if last.member_key and patnum ne mod_fnamescnt then audit_comment='DIFF-CHECK';
			end;
			else if mod_dobcnt=1 then do;
				if first.member_key then patnum=1;
				else if fname ne '' and lagfname ne fname and index(lagfname||laglname,scan(fname,1))=0 and
						lname ne '' and laglname ne lname and index(lagfname||laglname,scan(lname,1))=0 then patnum+1;
				if last.member_key then do;
					if patnum=fnamecnt then do;
						if addrscancitycnt_nn=addrscanzipcnt_nn=dupcnt and addrscancitycnt=fnamecnt and addrscanzipcnt=fnamecnt and
							phonecnt_nn=dupcnt and phonecnt=fnamecnt then do;
							if fnamecnt=dupcnt then audit_comment='NAMEDIFF-AUTO';
							else audit_comment='NAMEDIFF-AUTO';
							/* if fnamecnt ne dupcnt, these count comparisons are not perfect. there is a small chance that A and B have 
								different name, but has same address, and B has different addresses which contributed to the addrcnt. So, 
								addr different not because A and B addresses are different, but 1 patient has multiple addresses. That 
								said, I haven't come across bad identification of false positives yet */
						end;
						else audit_comment='NAMEDIFF-CHECK1';
					end;
					else audit_comment='NAMEDIFF-CHECK2';
				end;
			end;
			else audit_comment='???';
		end;
		/* For patients with same name and different DOB, we need to use address/phone to further identify the patients. 
			(It could be that DOB has typo, but the typo logic is too strict).
			Different address/phone might not mean anything, but same address/phone could mean that patient is the same person. 
			The only exception is parent and kid, but year has to be different by more than 16 years.*/
		else if mod_fnamescnt=mod_lnamescnt=1 and mod_dobcnt gt 1 then do;
			if fnamecnt=lnamescnt=1 then do;
				/* if change comment name or add categories, please make sure it is captured in the additional patnum data step below */
				if dob6_digit_diff ge 5 and dob_value_diff gt 365.25*16 then audit_comment='SAMENAME-AUTO';
				else if dob_value_diff gt 365.25*16 then audit_comment='SAMENAME-FAMILY';
				else audit_comment='SAMENAME-CHECK';
				
				if first.member_key then patnum=1;
				else if lagdob ne dob then patnum+1;
			end;
			else if fnamecnt ne 1 then do;
				if first.member_key then patnum=1;
				else if lagfname=fname and lagdob=dob and 
						(lagaddrscan_city=addrscan_city or lagaddrscan_city='' or addrscan_city='' or 
						 lagaddrscan_zip=addrscan_zip or lagaddrscan_zip='' or addrscan_zip='' or
						 lagphone=phone or lagphone='' or phone='') then;
				else patnum+1;
				if last.member_key then do;
					if patnum=2 then do;
						if ssncnt=1 and ssncnt_nn=dupcnt then audit_comment='SOUNDPROB-CHECK';
						else if (addrscanzipcnt=1 and addrscanzipcnt_nn=dupcnt or addrscancitycnt=1 and addrscancitycnt_nn=dupcnt) and 
								phonecnt=1 and phonecnt_nn=dupcnt and
								dob_value_diff le 365.25*16 then audit_comment='SOUNDPROB-CHECK';
						else audit_comment='SOUNDPROB-AUTO';
					end;
					else if patnum ne mod_dobcnt then audit_comment='SOUNDPROB-NOFIX';
					else audit_comment='SOUNDPROB-MULTI';
				end;
			end;
			else audit_comment='OTHER';
		end;
		else if mod_dobcnt=1 and mod_fnamescnt gt 1 and fname12cnt gt 2 then do;
			audit_comment='FAMILY-CHECK';
		end;
		else if dupcnt gt 1 then do;
			if dobcnt_nn ne dupcnt then do;
				if fnamecnt=1 then ;
				else do;
					audit_comment='MULTPAT-CHECK';
					if first.member_key then patnum=1;
					else if lagfname=fname then;
					else patnum+1;
				end;
			end;
			else if fnamecnt_nn ne dupcnt then do;
				if dobcnt=1 then ;
				else do;
					audit_comment='MULTPAT-CHECK';
					if first.member_key then patnum=1;
					else if lagdob=dob then;
					else patnum+1;
				end;
			end;
			/* this is for male only since male should not have different last name */
			else if sex='M' and mod_lnamescnt gt 1 and addrscanzipcnt gt 1 and phonecnt gt 1 and ssncnt_nn ne dupcnt then do;
				audit_comment='SOUNDPROB-CHECK';
			end;
		end;

		output meminfo_from_clm4;
			/* dataset to check patids */
		if last.member_key and (audit_comment ne '' or uniqueperson > 1) then output audit_falseposlist; 
	run;

	proc sql;
		create table audit_falseposlist_info_auto as
		select	a.member_key, patnum, origssn as ssn, origfname as fname, origmname as mname, origlname as lname, origsex as sex, origdob as dob,
				origaddr1 as address1, origaddr2 as address2, origcity as city, origzip as zip, origphone as phone, b.audit_comment, a.uniqueperson
		from	meminfo_from_clm4(drop=audit_comment) a, audit_falseposlist b
		where	a.member_key=b.member_key
		and		b.audit_comment in (&mep_autopush_category.) 
		order by audit_comment, member_key, patnum, fname, lname, dob, phone, address1;

		create table audit_falseposlist_info_manual1 as
		select	a.*, b.audit_comment
		from	meminfo_from_clm4(drop=audit_comment) a, audit_falseposlist b
		where	a.member_key=b.member_key
		and		b.audit_comment not in (&mep_autopush_category.)
		order by member_key, dob, fname, lname;
	quit;

	/* If member key has too many patients, just fix by DOB. There might still be 2 patients with same DOB, and 
		we'll have to rely on the 2nd round of false positive to fix those. Some could have DOB typo, and now 
		they'll get 2 different member keys. We'll rely on false negative to fix those.
	   By splitting these up front, we prevent linking algorithm to permutate to way too many combinations
		when the member key is a match.
	*/
	data audit_falseposlist_info_manual2;
		set audit_falseposlist_info_manual1(rename=(patnum=patnum_orig));
		by member_key dob fname lname;
		lagfname=lag(fname); laglname=lag(lname); lagdob=lag(dob);
		retain patnum;
		if dobcnt ge 3 and (fnamecnt ge 5 or lnamecnt ge 4) or
		   dobcnt ge 7 or fnamecnt ge 7 or lnamecnt ge 7 then do;
			audit_comment='MULTPAT-OVERFIX';
			if first.member_key then patnum=1;
			else if dob=. and fname ne lagfname or dob ne lagdob then patnum+1;
		end;
		else patnum=patnum_orig;
		keep 	member_key patnum origssn origfname origmname origlname origsex origdob
				origaddr1 origaddr2 origcity origzip origphone audit_comment uniqueperson;
		rename 	origssn=ssn origfname=fname origmname=mname origlname=lname origsex=sex origdob=dob
				origaddr1=address1 origaddr2=address2 origcity=city origzip=zip origphone=phone;
	run;
	
	/* APPEND ALL RECORDS */
	data audit_falseposlist_info;
		set audit_falseposlist_info_auto audit_falseposlist_info_manual2;
	run;

	data cistage.false_positive_&client_id._&wflow_exec_id.;
		set audit_falseposlist_info;
	run;
	proc sort data=cistage.false_positive_&client_id._&wflow_exec_id.;
		by audit_comment member_key patnum fname lname dob phone address1;
	run;
%mend mep_iden_fp;
%mep_iden_fp;

%macro mep_auto_push;
	proc sql;
		create table push_to_falsepos_t as
		select	*
		from	audit_falseposlist_info
		where 	audit_comment in (&mep_autopush_category.,'MULTPAT-OVERFIX') or uniqueperson > 1
		order by member_key, ssn, fname, mname, lname, sex, dob, address1, address2, city, zip, phone;

		create table client_group_data as
		select	distinct member_key, person_key,
				ssn, fname, mname, lname, sex, dob, address1, address2, city, state, zip, phone, 
				client_group_key, client_key,  practice_id,  
				strip(system_member_id) as system_member_id,  /*source,*/ /*enterprise_member_id,*/
				case when practice_id=&empi_datasource_id. then 1 else 99 end as empirank
		from	cistage_allfiles
		where	member_key in (select distinct member_key from push_to_falsepos_t) 
		order by member_key, ssn, fname, mname, lname, sex, dob, address1, address2, city, zip, phone;
	quit;

	/* Pull original demographics back in */
	data push_to_falsepos_t2;
		merge push_to_falsepos_t client_group_data;
		by member_key ssn fname mname lname sex dob address1 address2 city zip phone;
		if missing(patnum) then patnum=0;
	run;

	/* 
	   3 step process to check records that have not been split apart from the previous false postive code
	   above due to differnt system member ids aka patids for a given member_key and dsid set.
	   If the record has not been split and the fname lname sex dob demographics are different then
	   check system_member_id per member_key record set. 
       If a record set is split apart any null patids will get there own member key. 
	   For example, 3 identical member keys with patids 111, 222, and null will get their own member_key
	   
	   Step 1: ID different system_member_id per set of member_key, practice_id and patnum for step 3
	*/		
	  PROC SQL undo_policy=none;
            CREATE TABLE push_to_falsepos_t2 as
            SELECT *, count(distinct system_member_id) as multisysmemid, count(*) as total_cnt
            FROM push_to_falsepos_t2
            GROUP BY member_key,practice_id,  patnum;
        QUIT;
    /* Step 2: Capture the MAX patnum for step 3 */
        PROC SQL undo_policy=none;
            CREATE TABLE push_to_falsepos_t2 as
            SELECT *, max(patnum) as maxpatnum, sum(case when empirank = 1 then 1 else 0 end) as empi_ind
            FROM push_to_falsepos_t2
            GROUP BY member_key;
        QUIT;

        PROC SORT DATA=push_to_falsepos_t2;
            BY member_key patnum multisysmemid practice_id  system_member_id lname fname dob sex zip phone;
        RUN;
	
	
	/* Step 3a: Update patnum if necessary - only check within MK and DSID combination - NO EMPI records */
    /*Note 1:
       If a patnum is updated and within the same member_key and practice_id exist a null system_member_id record
       that record(s) will be designated for a new member_key too. When a patnum is updated we cannot
       identify if the newly split record should belong too another so we split it and let false negative handle the potential record collasping.

    */		
		DATA push_to_falsepos_t2_2(drop=lag: curdemo maxpatnum total_cnt) push_to_falsepos_t2_patid(keep=member_key audit_comment);
            /* order vars */ retain old_patnum patnum lagpatnum member_key practice_id lagpracticeid system_member_id lagsysmemid audit_comment2 audit_comment memcount ;
            length lagsysmemid $30. system_member_id $30. lagpracticeid $12. bucket $10. audit_comment2 $20.;
            SET push_to_falsepos_t2;
            by member_key patnum multisysmemid practice_id ;
                format member_key 16.;
				old_patnum=patnum;
                lagsysmemid=lag(system_member_id);
                lagpracticeid=lag(practice_id);
                lagpatnum=lag(patnum);
                lag_fname=lag(fname);
                lag_lname=lag(lname);
                lag_dob=lag(dob);
                lag_sex=lag(sex);
                lagzip=lag(zip);
                lagphone=lag(phone);

				%ssntest;
				if ssnTYPE='INVALID' then new_ssn=_N_; 																		/* assign row number to invalid ssn to prevent dup matches */
				else new_ssn=ssn; 
				lag_ssn=lag(new_ssn);                
                lagdemo=upcase(cats(lag_fname,lag_lname,lag_dob,lag_sex));
                curdemo=upcase(cats(fname,lname,dob,sex));
				lagdemo2=upcase(cats(lag_ssn,lag_fname,lag_dob));
                curdemo2=upcase(cats(new_ssn, fname,dob));
				
                    if empi_ind > 0 then do;																											/* do not touch EMPI recordsets */
						bucket='EMPI';
					end; 
					else if first.member_key then do;  
                       if multisysmemid > 1 AND patnum = 0 then do;                                                                                     /* new mk and set counter + 1 */
                           memcount=maxpatnum + 1;
                           patnum=memcount;
                           audit_comment2='DIFFPATID-AUTO';
						   bucket='start1';
                        end;
                        else if patnum = 0 then do;
                            memcount=maxpatnum + 1;
                           patnum=memcount;
                           audit_comment2='DIFFPATID-AUTO';
						   bucket='start2';
                        end;
                        else do;																														/* reset increment var */
                            memcount=maxpatnum; 
							patnum=memcount;		
							bucket='start3';
						end;
                    end; /* 1 */
                    else if first.member_key = 0 and patnum = lagpatnum then do;
                        if practice_id = coalesce(&empi_datasource_id.,0) and lagpracticeid = practice_id then patnum = memcount;					  /* do not increment EMPI dsids */
                        else if multisysmemid < 2 then do;																				/* first record of new recordset to evaluate */
                            	patnum = memcount;
								audit_comment2='DIFFPATID-UNKN';
								bucket='step1';
							
                        end;/* 2 */
						else if multisysmemid >= 2 and practice_id = lagpracticeid then do;
							if coalescec(system_member_id,'0' ) = coalescec(lagsysmemid,'0' ) then do;   												/* retain previous patnum */
								patnum = memcount;
								audit_comment2='SAMEPATID-AUTO';
								bucket='step2';
							end; 
							else do; /* 3 */																					/* assign new patnum if demographics are different */
								if (lagdemo = curdemo OR lagdemo2 = curdemo2) AND (zip = lagzip OR phone = lagphone) then do;
									patnum = memcount;
									audit_comment2='SAMEDEMO-AUTO';
									bucket= 'step3';
								end;
								else do;		
								   memcount + 1;
								   patnum=memcount;
								   audit_comment2='DIFFPATID-AUTO';
								   bucket='step4';
								end; 	
							end; /* 3 */
						end; /* 2 */
                    	else do; /* if system_member_id > 2 and practice_id NE previous increment beg recordset */
							   memcount + 1;
							   patnum=memcount;
							   audit_comment2='DIFFPATID-AUTO';
							   bucket='step5';
                        end;                   
                    end; /* 1 */
					else do; 																															/* leverage existing patnum */
					   memcount + 1;
					   patnum=memcount;
					   audit_comment2='DIFFPATID-AUTO';
					   bucket='step6';
					end;
                if last.member_key and audit_comment2 = 'DIFFPATID-AUTO' then output push_to_falsepos_t2_patid;
                output push_to_falsepos_t2_2;
        RUN;
		
		/* 
			If a recordset had different system member keys but demographics were the same the prevous logic mis-identified the records as new member key candidates.
			This dataset checks an entire recordset for identical patnums for the forementioned reason (new member key is not necessary). 	  
		*/
			
/* Step 3b: Remove records from getting new member key if necessary */	
			proc sql;
				create table patnum_reversal as
					select distinct member_key, 'REVERSAL' as audit_comment2
					from push_to_falsepos_t2_2
					where multisysmemid > 1  
					group by member_key, practice_id
					having count(distinct patnum) = 1 
					union 
					select distinct member_key, 'REVERSAL' as audit_comment2
					from push_to_falsepos_t2_2
					group by member_key 
					having max(multisysmemid) < 2 ;
				
				/* Make sure a single person key is not associated to more than one MK */				 
			    create table multi_personkey as
					select distinct member_key,person_key,max(patnum) as max_patnum, 'SAME_PK' as audit_comment2
					from push_to_falsepos_t2_2
					group by member_key, person_key
					having count(distinct patnum) > 1 ;
				
			quit; 
			
		/* Create Final List for new member keys by joining misidentified records and removing them from getting new member_keys */
			proc sql undo_policy=none;
				create table push_to_falsepos_t2 as
				   select case 
							when NOT missing(reset.member_key) then old_patnum 
 							when NOT missing(patnum_chk.member_key) then patnum_chk.max_patnum 
							else patnum end as patnum
						, case 
							when NOT missing(reset.member_key) then reset.audit_comment2 
							when NOT missing(patnum_chk.member_key) then  patnum_chk.audit_comment2 
							else orig.audit_comment2 end as audit_comment2
						, orig.audit_comment
						, orig.member_key          
						, orig.practice_id         
						, orig.system_member_id    
						, orig.ssn             
						, orig.fname           
						, orig.mname           
						, orig.lname           
						, orig.sex             
						, orig.dob             
						, orig.address1        
						, orig.address2        
						, orig.city            
						, orig.zip             
						, orig.phone   
						, orig.person_key      
						, orig.state           
						, orig.client_group_key
						, orig.client_key      
						, orig.empirank 
				     from push_to_falsepos_t2_2 orig
				     left join patnum_reversal reset
				       on orig.member_key = reset.member_key
					 left join multi_personkey patnum_chk
					   on orig.member_key = patnum_chk.member_key
					  and orig.person_key = patnum_chk.person_key
				    where case when NOT missing(reset.member_key) then old_patnum else patnum end > 0;
				quit;
 
	%if %sysfunc(exist(push_to_falsepos)) %then %do; proc sql; drop table push_to_falsepos; quit; %end;
	proc datasets lib=work nolist; change push_to_falsepos_t2=push_to_falsepos; quit;
 

	proc sort data=push_to_falsepos; by member_key patnum empirank client_group_key;
	data push_to_falsepos_mklist(keep=member_key patnum client_group_key);
		set push_to_falsepos;
		by member_key patnum empirank client_group_key;
		/* the assignment of the group_key is arbitrary here */
		if first.patnum;
	run;
%mend mep_auto_push;
%mep_auto_push;

%macro mep_autoload_mfp;
	%empi_all_patient_key(allmemlist,m_client_id=&client_id.);
	data allmemberlist / view=allmemberlist;
		set allmemlist(rename=(patient_key=member_key));
		format client_group_key $8.;
		client_group_key=put(member_key,z16.);
	run;
	proc sql;
		create table maxmemberlist as
		select	client_group_key, max(member_key) as VIDmax
		from	allmemberlist
		group by client_group_key;
	quit;

	proc sql;
		create table falsepos_pushlist as
		select	member_key, patnum, a.client_group_key,
				case when b.VIDmax=. then input(a.client_group_key||put(0,z8.),16.) else b.VIDmax end as VIDmax
		from	push_to_falsepos_mklist a left join maxmemberlist b
				on a.client_group_key=b.client_group_key
		order by client_group_key, member_key, patnum;
	quit;
	data falsepos_pushlist(drop=cgk_num);
		set falsepos_pushlist(rename=(member_key=bad_member_key));
		by client_group_key bad_member_key patnum;
		if first.client_group_key then cgk_num=1;
		else cgk_num+1;

		format member_key 16.;
		member_key=VIDmax+cgk_num;
	run;

/* still need to build safeguard here, in case same practice same demo one has empi one does not, and we force to not
	change the one with empi, but the one without will get changed, and now we break the table rule */
	proc sql;
		create table cistage.fp_pushlist_&client_id._&wflow_exec_id. as
		select	distinct b.member_key as new_member_key, b.bad_member_key as member_key, b.patnum,
				/*source, */person_key, practice_id as datasource_id, a.system_member_id,
				ssn, fname, mname, lname, sex, 
				case when dob='' then . 
					 else dhms(mdy(input(substr(dob,5,2),2.),input(substr(dob,7,2),2.),input(substr(dob,1,4),4.)),0,0,0) end as dob,
				address1, address2, city, state, zip, phone, datetime() as created_on, 'false - positive' as created_by, &wflow_exec_id. as wflow_exec_id
		from	push_to_falsepos a, falsepos_pushlist(keep=bad_member_key patnum member_key) b
		where	a.member_key=b.bad_member_key and a.patnum=b.patnum
		order by member_key, new_member_key, person_key, datasource_id;
	quit;
/* audit 1 */
	proc sql;
		create table audit1 as
		select	*
		from	cistage.fp_pushlist_&client_id._&wflow_exec_id.
		group by person_key
		having	count(distinct new_member_key) ne 1;
	quit;
	options orientation=landscape pageno=1 ls=256 ps=83 missing=' ';
	proc print data=audit1; title 'One person key has more than 1 new member key'; run; title;

	proc sql;
		create table newfp_pushlist as
		select	distinct &client_id. as client_key, member_key as patient_key, person_key, new_member_key as new_patient_key, 
				wflow_exec_id as created_wflow_exec_id, created_by
		from	cistage.fp_pushlist_&client_id._&wflow_exec_id.;

		create table newfp_patient_key as
		select	distinct client_key, new_patient_key as patient_key, 0 as delete_flag, created_wflow_exec_id, created_by
		from	newfp_pushlist;
	quit;
	%bulkload_to_cio(&wflow_exec_id.,newfp_patient_key,m_desttable=vh_empi.dbo.patient);

	%set_error_flag;
  	%on_error(ACTION=ABORT);

	%bulkload_to_cio(&wflow_exec_id.,newfp_pushlist,m_desttable=vh_empi.dbo.person_patient_false_positive);

	%set_error_flag;
  	%on_error(ACTION=ABORT);

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
	%if %symexist(sas_mode) and %upcase(&sas_mode.)=PROD %then %let xl=\\&ids_client_path1.\&ids_client_path2.\reports\Data_Quality_Reports\Member_False_Positive_Autopush_List_&ids_client_name._&wflow_exec_id..txt;
	%else %let xl=\\&ids_client_path1.\&ids_client_path2.\reports\Data_Quality_Reports\test\Member_False_Positive_Autopush_List_&ids_client_name._&wflow_exec_id..txt;

	options orientation=landscape pageno=1 ls=256 ps=83 missing=' ';
	proc printto file="&xl." new;

	proc print data=cistage.fp_pushlist_&client_id._&wflow_exec_id.(drop=state created_on created_by wflow_exec_id); 
		title "False Positive Autopush List for client &ids_client_name.";
		by member_key notsorted;
		id member_key;
		format member_key new_member_key 16. address1 $15. address2 $6. lname city $15. dob datetime9.;
		format fname $15. mname $5. system_member_id $25.;
		label member_key='bad member key' member_key='new member key';
	run; title;

	proc printto; run;
%mend mep_autoload_mfp;
%mep_autoload_mfp;

proc sql noprint;
	select	count(distinct person_key)
	into	:tgt_record_cnt
	from	cistage.fp_pushlist_&client_id._&wflow_exec_id.;
quit;

proc sql noprint;
	  update vbpm.sk_process_control a
	  set EXT_OUTPUT_LOG = "&xl."
	  where a.wflow_exec_id=&wflow_exec_id.
	    and a.client_id=&client_id.
		and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
quit;
