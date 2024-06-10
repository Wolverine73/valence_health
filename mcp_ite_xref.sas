%macro mcp_ite_xref;
	 %DO %UNTIL (&ds1_obs.=0 and &ds2_obs.=0);
	  proc sql;
		create table inconsistent_xref as
		select	distinct mk_from, mk_to, count(distinct mk_to) as xref_to_cnt
		from	xref_pushlist
		group by mk_from
		order by mk_from, mk_to;
	  quit;
	  data swap_xref;
		set inconsistent_xref;
		where xref_to_cnt ne 1;
	  run;

	  %let ds1_id=%sysfunc(open(swap_xref));
	  %let ds1_obs=%sysfunc(attrn(&ds1_id.,nobs));
	  %let ds1_rc=%sysfunc(close(&ds1_id.));

	  %if &ds1_obs. ne 0 %then %do;
		/* if 1 mk maps to 2 different ones, swap from and to on the first mapping */
		data xref_pushlist(keep=mk_from mk_to);
			set inconsistent_xref;
			by mk_from mk_to;
			org_from=mk_from; org_to=mk_to;
			if xref_to_cnt ne 1 and first.mk_from then do;
				mk_from=org_to; mk_to=org_from;
			end;
		run;
	  %end;

	  proc sql;
		create table temp_xref as
		select	*
		from	xref_pushlist
		group by mk_from
		having	count(*)=1;

		create table double_xref as
		select	a.mk_from, a.mk_to, b.mk_from as mk_from2, b.mk_to as mk_to2
		from	temp_xref a, temp_xref b
		where	a.mk_to=b.mk_from;
	  quit;

	  %let ds2_id=%sysfunc(open(double_xref));
	  %let ds2_obs=%sysfunc(attrn(&ds2_id.,nobs));
	  %let ds2_rc=%sysfunc(close(&ds2_id.));

	  %if &ds2_obs. ne 0 %then %do;
		/* if map_to is also in map_from, then remap map_to to the other map_to */
		proc sql;
			update xref_pushlist a
			set		mk_to = (select	mk_to from temp_xref b where a.mk_to=b.mk_from)
			where	mk_to in (select mk_from from temp_xref);
		quit;
	  %end;
	  proc sort data=xref_pushlist nodups; by mk_from mk_to; run;
	 %END;
%mend mcp_ite_xref;
