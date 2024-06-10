/* 	Picks the latest and greatest rows from NL HOLD table 

	Macro is called in the following programs:
		\EDW\edw_member_error.sas
		\EDW\edw_claims_reprocess_error.sas
		\EDW\edw_claims_reprocessing_nl_hold.sas

	For additional notes, see edw_pick_latest_hold.sas
*/

%macro edw_pick_latest_nlhold(m_outset,m_client_id,m_keepvar=_all_);
  /* use fname, lname, sex, and dob to approximate a member, for dedupping process */
  proc sql;
	create table pln_nlhold_memdemo as
	select	distinct fname, lname, sex, dob
	from	cihold.nl_hold_encounter_header_detail(keep=client_key member_key fname lname sex dob)
	where	client_key=&m_client_id.
	and		member_key=0
	and 	fname is not null and lname is not null and sex is not null and dob is not null
	order by fname, lname, sex, dob;
  quit;
  data pln_nlhold_memdemo;
	set pln_nlhold_memdemo;
	by fname lname sex dob;
	if _n_=1 then fake_member_key=1;
	fake_member_key+1;
  run;

  *SASDOC-----------------------------------------------------------
  | If service date failed validation during time of loading, value
  | 	is bogus, and we should never retry these claims.
  | At the same time, reassign procedure_cd_key
  +---------------------------------------------------------SASDOC*;
  proc sql;
	create view pln_v_svcdt_failed_val as
	select	distinct entity_id, validation_type_id
	from	vbpm.validation_detail
	where	validation_type_id=31;

  	create table pln_nl_hold_ehd(drop=oldprockey /*group_id practice_key provider_key*/) as
	select	a.*, coalesce(c.procedure_code_key,0) as procedure_code_key
														/* keep these variables in order for code below to work regardless
															of &m_keepvar. */
	from	cihold.nl_hold_encounter_header_detail(keep=nl_hold_ehd_key orig_nl_hold_ehd_key client_key member_key fname lname sex dob 
														 npi practice_id svcdt proccd mod1 mod2 tin 
														 procedure_code_key group_id practice_key provider_key
														 &m_keepvar.
												   rename=(procedure_code_key=oldprockey)) a left join
			pln_v_svcdt_failed_val b on a.nl_hold_ehd_key=b.entity_id left join
			ciedw.procedure_cd c on a.proccd=c.procedure_code
	where	a.client_key=&m_client_id.
	and		b.validation_type_id ne 31;

	drop view pln_v_svcdt_failed_val;
  quit;

  *SASDOC-----------------------------------------------------------
  | Reassign group_id, practice_key, provider_key
  | Do not perform this anymore. We will use whatever logic within
  |		the extract program.
  +---------------------------------------------------------SASDOC*;
/*  %edw_primsec_provider_xref(&m_client_id.,m2_inset=pln_nl_hold_ehd,m2_outset=pln_latest_nlhold1);
*/
  *SASDOC-----------------------------------------------------------
  | Find the latest row for each identifiable patient, or if not,
  |		just pull everything and treat all as "latest" rows
  +---------------------------------------------------------SASDOC*;
  proc sql;
	create table pln_latest_nlhold2 as 
	select	a.*
	from	pln_nl_hold_ehd a left join pln_nlhold_memdemo b
			on a.fname=b.fname and a.lname=b.lname and a.sex=b.sex and a.dob=b.dob
	where	client_key=&m_client_id.
	and	(	member_key ne 0 or member_key=0 and fake_member_key ne .)
	and		npi is not null
	and 	practice_id is not null
	group by client_key, member_key, fake_member_key, npi, practice_id, svcdt, proccd, mod1, mod2
	having	nl_hold_ehd_key=max(nl_hold_ehd_key)
   union
	select	c.*
	from	pln_nl_hold_ehd c left join pln_nlhold_memdemo d
			on c.fname=d.fname and c.lname=d.lname and c.sex=d.sex and c.dob=d.dob
	where	client_key=&m_client_id.
	and	(	member_key=0 and fake_member_key=.
		 or npi is null 
		 or practice_id is null);

	drop table pln_nlhold_memdemo, pln_nl_hold_ehd/*, pln_latest_nlhold1*/;
  quit;

  *SASDOC------------------------------------------------------------------------------------------------------------------------------
  |  The latest rows cannot have its ehd_key in orig_xx_ehd_key column. If so, it means that the row has been reprocessed to a
  |		different row with different ehd_key.
  +-----------------------------------------------------------------------------------------------------------------------------SASDOC*; 
  proc sql;
	create view pln_nlhehd_origkey as
	select	orig_nl_hold_ehd_key, max(orig_wflow_exec_id) as orig_wflow_exec_id
	from	cihold.nl_hold_encounter_header_detail(keep=client_key orig_nl_hold_ehd_key orig_wflow_exec_id load_flag)
	where	client_key=&m_client_id.
	and		orig_wflow_exec_id ne .
	and		load_flag ne 5
	group by orig_nl_hold_ehd_key
   union
	select	orig_hold_ehd_key as orig_nl_hold_ehd_key, max(orig_wflow_exec_id) as orig_wflow_exec_id
	from	cihold.hold_encounter_header_detail(keep=client_key orig_hold_ehd_key orig_wflow_exec_id load_flag)
	where	client_key=&m_client_id.
	and		load_flag=4
	group by orig_hold_ehd_key;

	create table &m_outset.(bufsize=64k bufno=1k compress=yes keep=&m_keepvar.) as
	select	a.*
	from	pln_latest_nlhold2 a left join pln_nlhehd_origkey b
			on a.nl_hold_ehd_key=b.orig_nl_hold_ehd_key
	where	b.orig_wflow_exec_id=.;

	drop view pln_nlhehd_origkey;
	drop table pln_latest_nlhold2;
  quit;
%mend edw_pick_latest_nlhold;
