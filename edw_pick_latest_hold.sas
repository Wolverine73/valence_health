/* 	Picks the latest and greatest rows from HOLD table 

	Macro is called in the following programs:
		\EDW\edw_member_error.sas
		\EDW\edw_claims_reprocess_error.sas
*/

*SASDOC------------------------------------------------------------------------------------------------------------------------------
|  The reason we want the latest rows in hold table is so that if we have two identical historical records of the same practice,
|	we only want the latest row (based on hold_ehd_key) since they have the same detail_key from encounter table. Otherwise, the
|	recent row might have been reprocessed by say the error program, and a new member key got created for it, and that row became
|	a different detail key. The 2nd row's ehd_key is now in the orig_xx_ehd_key for the 3rd row, which means we won't pick up the
|	2nd row for any reprocessing anymore, but the 1st row's ehd_key is not in any other row as orig_xx_ehd_key. And because the old row 
|	still has the old detail key (different than the new detail key), it looks like that old row is now the latest and 
|	greatest for the old detail key, but the old detail key is obsolete anyway, and we should never look at that old row anymore.
|  Same concept applies to nl hold table, except since nl hold does not have detail key values, we use the raw data to "approximate"
|	the detail key, i.e. the dedupping logic. 
|  FYI, technically we are only using the hold_ehd_key to approximate the "latest" row. This is assuming that under normal 
|	circumstances, the newly modified row is loaded later than original row. This might not be true when say we load things
|	out of sequence, or maybe full historical and no moddt to sort all rows etc. Moddt definitely currently is not consistent
|	nor filled in for all PM systems, so, we're not using that field.
+-----------------------------------------------------------------------------------------------------------------------------SASDOC*; 
%macro edw_pick_latest_hold(m_outset,m_client_id,m_datasource_id=,m_keepvar=_all_);

  *SASDOC------------------------------------------------------------------------------------------------------------------------------
  |  The latest rows cannot have its ehd_key in orig_xx_ehd_key column. If so, it means that the row has been reprocessed to a
  |		different row with different ehd_key.
  +-----------------------------------------------------------------------------------------------------------------------------SASDOC*; 
  proc sql;
	connect to oledb(init_string=&sqlci. readbuff=10000);
	create view plh_hehd_origkey as
	select	distinct start
	from	connection to oledb
			(	select	distinct orig_hold_ehd_key as start
				from	cihold.dbo.hold_encounter_header_detail(nolock)
				where	client_key=&m_client_id.
			   %if %str(&m_datasource_id.) ne %then %do;
				and		practice_id in (&m_datasource_id.)
			   %end;
				and		orig_wflow_exec_id is not null
				and		load_flag <> 4
			   union
				select	distinct orig_nl_hold_ehd_key as start
				from	cihold.dbo.nl_hold_encounter_header_detail(nolock)
				where	client_key=&m_client_id.
			   %if %str(&m_datasource_id.) ne %then %do;
				and		practice_id in (&m_datasource_id.)
			   %end;
				and		load_flag=5
			);
  quit;

  data plh_hehd_origkey_fmt;
  	set plh_hehd_origkey end=lstobs;
	fmtname='plholdk';
	label='Y';
	output;
	if lstobs then do;
		hlo='O'; label='N'; output;
	end;
  run;

  %let ds_id=%sysfunc(open(plh_hehd_origkey_fmt));
  %let ds_obs=%sysfunc(attrn(&ds_id.,nobs));
  %let ds_rc=%sysfunc(close(&ds_id.));
  %if &ds_obs.=0 %then %do;
	data plh_hehd_origkey_fmt;
		fmtname='plholdk'; hlo='O'; start=.; label='N'; output;
	run;
  %end;
  proc format cntlin=plh_hehd_origkey_fmt; run;

  data plh_wantvar(keep=varnm);
	i=1; lstvar=0;
	format varnm $32.;
	if "&m_keepvar."="_all_" then do; varnm='a.*'; output; end;
	else do until(lstvar=1);
		varnm=scan("hold_ehd_key orig_hold_ehd_key client_key detail_key &m_keepvar.",i);
		if varnm ne '' then output;
		else lstvar=1;
		i+1;
	end;
  run;
  proc sql noprint;
	select	distinct varnm
	into	:m_keepvar_comma separated by ','
	from	plh_wantvar;
  quit;

  proc sql;
	connect to oledb(init_string=&sqlci. readbuff=10000);
	create table &m_outset.(bufsize=64k bufno=1k compress=yes keep=&m_keepvar.) as 
	select	*
	from 	connection to oledb
			(	select	&m_keepvar_comma.
				from	cihold.dbo.hold_encounter_header_detail(nolock) a inner join
						(	select	max(hold_ehd_key) [ajinomoto]
							from	cihold.dbo.hold_encounter_header_detail(nolock)
							where	client_key=&m_client_id.
							group by detail_key
						) b on a.hold_ehd_key=b.ajinomoto
			   %if %str(&m_datasource_id.) ne %then %do;
				where	practice_id in (&m_datasource_id.)
			   %end;
			)
	where	put(hold_ehd_key,plholdk.)='N';
  quit;

  proc sql;
	drop view plh_hehd_origkey;
	drop table plh_hehd_origkey_fmt, plh_wantvar;
  quit;
%mend edw_pick_latest_hold;
