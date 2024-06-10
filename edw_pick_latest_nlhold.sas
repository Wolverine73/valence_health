/* 	Picks the latest and greatest rows from NL HOLD table 

	Macro is called in the following programs:
		\EDW\edw_member_error.sas
		\EDW\edw_claims_reprocess_error.sas
		\EDW\edw_claims_reprocessing_nl_hold.sas

	For additional notes, see edw_pick_latest_hold.sas
*/

%macro edw_pick_latest_nlhold(m_outset,m_client_id,m_datasource_id=,m_keepvar=_all_,m_update_proccd=0);
  /* use fname, lname, sex, and dob to approximate a member, for dedupping process */
  proc sql;
	connect to oledb(init_string=&sqlci. readbuff=10000);
	create table pln_v_nlhold_memdemo(index=(tablekey=(fname lname sex dob))) as
	select	*
	from	connection to oledb
			(	select	distinct nlh.fname, nlh.lname, nlh.sex, nlh.dob
				from	cihold.dbo.nl_hold_encounter_header_detail(nolock) nlh left join
						ciedw.dbo.person_member_map pmm on nlh.client_key=pmm.client_key and nlh.person_key=pmm.person_key
				where	nlh.client_key=&m_client_id.
			  %if %str(&m_datasource_id.) ne %then %do;
				and		nlh.practice_id in (&m_datasource_id.)
			  %end;
				and		pmm.member_key is null
				and 	nlh.fname is not null and nlh.lname is not null and nlh.sex is not null and nlh.dob is not null
			);
  quit;
  data pln_nlhold_memdemo;
	set pln_v_nlhold_memdemo;
	by fname lname sex dob;
	if _n_=1 then fake_member_key=1;
	fake_member_key+1;
  run;
  proc sql; drop table pln_v_nlhold_memdemo; quit;

  *SASDOC-----------------------------------------------------------
  | If service date failed validation during time of loading, value
  | 	is bogus, and we should never retry these claims.
  | At the same time, reassign procedure_cd_key
  +---------------------------------------------------------SASDOC*;
  %let pln_svcdt_failed_val=0;
  proc sql;
	connect to oledb(init_string=&sqlci. readbuff=10000);
	create view pln_v_svcdt_failed_val as
	select	*
	from	connection to oledb
			(	select	entity_id, validation_type_id
				from	bpmmetadata.dbo.validation_detail(nolock)
				where	validation_type_id=31
			);
  quit;
  data pln_svcdt_failed_val(keep=fmtname start label hlo);
	set pln_v_svcdt_failed_val end=lstobs;
	fmtname='plnsvcdt';
	label='Y';
	output;
	if lstobs then do;
		label='N'; hlo='O'; output;
	end;
	rename entity_id=start;
  run;
  proc sort data=pln_svcdt_failed_val nodup; by fmtname start label hlo; run;
  proc sql; drop view pln_v_svcdt_failed_val; quit;

  %let dsn_id=%sysfunc(open(pln_svcdt_failed_val));
  %let dsn_obs=%sysfunc(attrn(&dsn_id.,nobs));
  %let dsn_rc=%sysfunc(close(&dsn_id.));
  %if &dsn_obs.=0 %then %do;
	data pln_svcdt_failed_val;
		fmtname='plnsvcdt';
		start=0;
		label='N'; hlo='O'; output;
	run;
  %end;
  proc format cntlin=pln_svcdt_failed_val; run;

  proc sql;
  	create table pln_nl_hold_ehd(index=(tablekey=(fname lname sex dob))
									%if &m_update_proccd. %then %do;
										drop=oldprockey
									%end;
								) /*group_id practice_key provider_key)*/ as
	select	a.*, coalesce(pmm.member_key,0) as member_key
		%if &m_update_proccd. %then %do;
			, coalesce(c.procedure_code_key,0) as procedure_code_key
		%end;
														/* keep these variables in order for code below to work regardless
															of &m_keepvar. */
	from	cihold.nl_hold_encounter_header_detail(keep=nl_hold_ehd_key orig_nl_hold_ehd_key client_key person_key fname lname sex dob 
														 npi practice_id svcdt proccd mod1 mod2 tin 
														 procedure_code_key group_id practice_key provider_key
														 &m_keepvar.
														 enterprise_member_id source_system_id system_member_id
												%if &m_update_proccd. %then %do;
												   rename=(procedure_code_key=oldprockey) 
												%end; ) a left join
			ciedw.person_member_map pmm on a.client_key=pmm.client_key and a.person_key=pmm.person_key
		%if &m_update_proccd. %then %do;
			left join ciedw.procedure_cd c on a.proccd=c.procedure_code
		%end;
	where	a.client_key=&m_client_id.
	and		put(nl_hold_ehd_key,plnsvcdt.) ne 'Y'
   %if %str(&m_datasource_id.) ne %then %do;
	and		a.practice_id in (&m_datasource_id.)
   %end;
	;
  quit;

  *SASDOC-----------------------------------------------------------
  | Reassign group_id, practice_key, provider_key
  | Do not perform this anymore. We will use whatever logic within
  |		the extract program.
  +---------------------------------------------------------SASDOC*;
/*  %edw_primsec_provider_xref(&m_client_id.,m2_inset=pln_nl_hold_ehd,m2_outset=pln_latest_nlhold1);
*/
  
  *SASDOC------------------------------------------------------------------------------------------------------------------------------
  |  The latest rows cannot have its ehd_key in orig_xx_ehd_key column. If so, it means that the row has been reprocessed to a
  |		different row with different ehd_key.
  +-----------------------------------------------------------------------------------------------------------------------------SASDOC*; 
  proc sql;
	connect to oledb(init_string=&sqlci. readbuff=10000);
	create view pln_nlhehd_origkey as
	select	distinct start
	from	connection to oledb
			(	select	distinct orig_nl_hold_ehd_key as start
				from	cihold.dbo.nl_hold_encounter_header_detail(nolock)
				where	client_key=&m_client_id.
			   %if %str(&m_datasource_id.) ne %then %do;
				and		practice_id in (&m_datasource_id.)
			   %end;
				and		orig_wflow_exec_id is not null
				and		load_flag <> 5
			   union
				select	distinct orig_hold_ehd_key as start
				from	cihold.dbo.hold_encounter_header_detail(nolock)
				where	client_key=&m_client_id.
			   %if %str(&m_datasource_id.) ne %then %do;
				and		practice_id in (&m_datasource_id.)
			   %end;
				and		load_flag=4
			);
  quit;
  
  data pln_nlhehd_origkey_fmt;
  	set pln_nlhehd_origkey end=lstobs;
	fmtname='plnlhdk';
	label='Y';
	output;
	if lstobs then do;
		hlo='O'; label='N'; output;
	end;
  run;

  %let ds_id=%sysfunc(open(pln_nlhehd_origkey_fmt));
  %let ds_obs=%sysfunc(attrn(&ds_id.,nobs));
  %let ds_rc=%sysfunc(close(&ds_id.));
  %if &ds_obs.=0 %then %do;
	data pln_nlhehd_origkey_fmt;
		fmtname='plnlhdk'; hlo='O'; start=.; label='N'; output;
	run;
  %end;
  proc format cntlin=pln_nlhehd_origkey_fmt; run;

  *SASDOC-----------------------------------------------------------
  | Find the latest row for each identifiable patient, or if not,
  |		just pull everything and treat all as "latest" rows
  +---------------------------------------------------------SASDOC*;
  proc sql;
	create table &m_outset.(bufsize=64k bufno=1k compress=yes keep=&m_keepvar.) as 
	select	a.*
	from	pln_nl_hold_ehd a left join pln_nlhold_memdemo b
			on a.fname=b.fname and a.lname=b.lname and a.sex=b.sex and a.dob=b.dob
	where	client_key=&m_client_id.
	and	(	member_key ne 0 or member_key=0 and fake_member_key ne .)
	and		npi is not null
	and 	practice_id is not null
	group by client_key, member_key, fake_member_key, npi, practice_id, svcdt, proccd, mod1, mod2
	having	nl_hold_ehd_key=max(nl_hold_ehd_key)
	and		put(nl_hold_ehd_key,plnlhdk.)='N'
   union
	select	c.*
	from	pln_nl_hold_ehd c left join pln_nlhold_memdemo d
			on c.fname=d.fname and c.lname=d.lname and c.sex=d.sex and c.dob=d.dob
	where	client_key=&m_client_id.
	and	(	member_key=0 and fake_member_key=.
		 or npi is null 
		 or practice_id is null)
	and		put(nl_hold_ehd_key,plnlhdk.)='N';

	drop view pln_nlhehd_origkey;
	drop table pln_nlhold_memdemo, pln_nl_hold_ehd, pln_nlhehd_origkey_fmt;
  quit;
%mend edw_pick_latest_nlhold;
