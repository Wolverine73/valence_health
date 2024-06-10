 
	%macro mcp_varcombo(m_auditnum,m_min_numofvar,m_max_numofvar,m_varstring);
	  /* Find variable names related to fname, dob, ssn, to make sure combo has at least 1 of them. 
			Without at least 1, we will flag records from family members as duplication. */
	  %let mcp_fnamevar=fname;
	  %let mcp_dobvar=dob;
	  %let mcp_ssnvar=ssn;
	  %do i=1 %to %length(&m_varstring.);
		%let mcp_var&i.=%scan(&m_varstring.,&i.);
		%if %index(&&mcp_var&i,&mcp_fnamevar.) %then %do; %let mcp_fnamevar=&&mcp_var&i; %end;
		%if %index(&&mcp_var&i,&mcp_dobvar.) %then %do; %let mcp_dobvar=&&mcp_var&i; %end;
		%if %index(&&mcp_var&i,&mcp_ssnvar.) %then %do; %let mcp_ssnvar=&&mcp_var&i; %end;
		%if &&mcp_var&i= %then %do;
			%let mcp_numofvar=%eval(&i.-1);
			%let i=%eval(%length(&m_varstring.)+1);
		%end;
	  %end;

	  %global max_varstring_length;
	  %if &max_varstring_length.= %then %do; %let max_varstring_length=0; %end;
	  %let max_varstring_length=%sysfunc(max(%length(&m_varstring.),&max_varstring_length.));

		/* Create all permutation of select variables out of the list of var in string */
		data audit_combo(drop=varnum0);
			varnum0=0;
  		  %do m_i=1 %to &mcp_numofvar.;
			do varnum&m_i.=varnum%eval(&m_i.-1)+1 to &mcp_numofvar.;
				%if &m_i. ge &m_min_numofvar. %then %do; output; %end;
  		  %end;
  		  %do m_i=&mcp_numofvar. %to 1 %by -1;
			end;
			varnum&m_i.=.;
  		  %end;
		run;

		data audit_combo(drop=i);
			set audit_combo;
			array varnum(&mcp_numofvar.);
			format audvar1-audvar&mcp_numofvar. $32. audit_varstring $%length(&m_varstring.).;
			array audvar(&mcp_numofvar.);
			audit_numofvar=0;
			do i=1 to dim(varnum);
				if varnum(i) ne . then do;
					audit_numofvar=audit_numofvar+1;
					audvar(i)=scan("&m_varstring",varnum(i));
					audit_varstring=compbl(left(audit_varstring)||' '||audvar(i));
				end;
			end;
			if &m_min_numofvar. le audit_numofvar le &m_max_numofvar. and 
				(index(audit_varstring,"&mcp_fnamevar.") or index(audit_varstring,"&mcp_dobvar.") or index(audit_varstring,"&mcp_ssnvar."));
				/* combo must have at least 1 of 3 key variables, otherwise we get family member records */
		data audit_combo;
			set audit_combo end=lstobs;
			combonum=_n_;
			if lstobs then call symput('m_numofcombo',trim(left(put(_n_,5.))));
		run;

	  %do i=1 %to &m_numofcombo;
		proc sql noprint;
			select	trim(left(put(audit_numofvar,2.))), audit_varstring
				%do j=1 %to &m_max_numofvar.;
					, trim(left(audvar&j.))
				%end;
			into	:m_audit_numofvar, :m_audit_varstring
				%do j=1 %to &m_max_numofvar.;
					, :m_audit_varnum&j.
				%end;
			from	audit_combo
			where	combonum=&i.;
		quit;

		data mcp_temp / view=mcp_temp;
			set member(keep=client_key 	%do j=1 %to &m_audit_numofvar.;
											&&m_audit_varnum&j
										%end; 
							member_key
						);
			where 1	%do j=1 %to &m_audit_numofvar.;
						and &&m_audit_varnum&j is not null
					%end;
			;
			format md5 $hex32.;
			md5=md5(client_key	%do j=1 %to &m_audit_numofvar.;
									|| &&m_audit_varnum&j
								%end;
					);
			keep md5 member_key;
		run;

		proc sql;
			create view mcp_temp2 as 
			select	distinct md5, member_key
			from	mcp_temp;

			create table audit&i._combo as
			select	md5, member_key, count(*) as dupcnt
			from	mcp_temp2
			group by 1
			having	dupcnt ne 1
			order by 1,2;

			drop view mcp_temp, mcp_temp2;
		quit;
	
		data audit&i._combo_summ(keep=client_key audit_numofvar audit_result_str audit_varstring);
			set audit&i._combo;
			by md5 member_key;
			client_key=&client_id.;
			audit_numofvar=&m_audit_numofvar;
			format audit_varstring $%length(&m_varstring.).;
			audit_varstring="&m_audit_varstring.";
			format audit_result_str $101.; /* 101 can fit 6 16-digit member keys */
			retain rtdupcnt 0 audit_result_str;
			if rtdupcnt=0 then do;
				rtdupcnt=dupcnt-1;
				audit_result_str=put(member_key,z16.);
			end;
			else do;
				audit_result_str=compress(audit_result_str)||'='||put(member_key,z16.);
				rtdupcnt=rtdupcnt-1;
				output;
			end;
		run;
	  %end;

		data member_key_dup_id&m_auditnum.;
			set %do i=1 %to &m_numofcombo; audit&i._combo_summ %end; ;
		run;

		/* If 2 records have 6 variables matching, we'll have 1 group of records with audit_numofvar=6, then
			we should have 5 group of records with audit_numofvar=5, and so on, and all these have the same
			audit_result_str. The maximum number of variables matching, that number should only have 1 group of 
			records, so, we pick that group, and discard all others.
		*/ 
		proc sort data=member_key_dup_id&m_auditnum. nodup; by client_key audit_result_str audit_numofvar;
		data member_key_dup_id&m_auditnum.;
			set member_key_dup_id&m_auditnum.;
			by client_key audit_result_str audit_numofvar;
			if last.audit_result_str;
		run;
	%mend mcp_varcombo;
