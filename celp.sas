%macro celp(indsn,outdsn,ce_lst,dgnidx=3,measname=val,condvars=N);
proc sql; 
create table Care_elements as
	select * from control.care_elements
		where care_granular in (select distinct care_element from control.element_pattern where element_pattern = "&ce_lst")
			and indicator not in ('TESTNAME')
	order by indicator,code;
quit;

data _&measname.cedgn _&measname.cedgn2 
	_&measname.cecpt _&measname.cecpt2 _&measname.cecpt3 _&measname.cecpt4 _&measname.cecpt5 _&measname.cecpt6  _&measname.cecpt7 _&measname.cecpt8
	_&measname.cerev _&measname.cerev2 
	_&measname.celoinc _&measname.celoinc2 _&measname.celoinc3 _&measname.celoinc4 _&measname.celoinc5 _&measname.celoinc6 _&measname.celoinc7 _&measname.celoinc8
	_&measname.cesurg _&measname.cesurg2 _&measname.cesurg3
	_all;
set Care_elements ;
	by indicator code;
	if first.code then _cnt=1;
	else _cnt+1;
	if indicator in ("DIAG") then do;
		if _cnt=1 then output _&measname.cedgn;
		else if _cnt=2 then output _&measname.cedgn2;
	end;
	else if indicator in ("CPT") then do;
		if _cnt=1 then output _&measname.cecpt;
		else if _cnt=2 then output _&measname.cecpt2;
		else if _cnt=3 then output _&measname.cecpt3;
		else if _cnt=4 then output _&measname.cecpt4;
		else if _cnt=5 then output _&measname.cecpt5;
		else if _cnt=6 then output _&measname.cecpt6;
		else if _cnt=7 then output _&measname.cecpt7;
		else if _cnt=8 then output _&measname.cecpt8;
	end;
	else if indicator in ("REVCD") then do;
		if _cnt=1 then output _&measname.cerev;
		else if _cnt=2 then output _&measname.cerev2;
	end;
	else if indicator in ("SURG") then do;
		if _cnt=1 then output _&measname.cesurg;
		else if _cnt=2 then output _&measname.cesurg2;
		else if _cnt=3 then output _&measname.cesurg3;
	end;
	else if indicator in ("LOINC") then  do;
		if _cnt=1 then output _&measname.celoinc;
		else if _cnt=2 then output _&measname.celoinc2;
		else if _cnt=3 then output _&measname.celoinc3;
		else if _cnt=4 then output _&measname.celoinc4;
		else if _cnt=5 then output _&measname.celoinc5;
		else if _cnt=6 then output _&measname.celoinc6;
		else if _cnt=7 then output _&measname.celoinc7;
		else if _cnt=8 then output _&measname.celoinc8;
	end;
	output _all;
run;

*care element formats;
%mk_fmt(dsn=_&measname.cedgn,start=code,label=care_granular,fmtname=&measname.cedgn,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cedgn2,start=code,label=care_granular,fmtname=&measname.ce2dgn,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.cerev,start=code,label=care_granular,fmtname=&measname.cerev,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cerev2,start=code,label=care_granular,fmtname=&measname.ce2rev,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.cesurg,start=code,label=care_granular,fmtname=&measname.cesurg,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cesurg2,start=code,label=care_granular,fmtname=&measname.ce2surg,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cesurg3,start=code,label=care_granular,fmtname=&measname.ce3surg,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.cecpt,start=code,label=care_granular,fmtname=&measname.cecpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt2,start=code,label=care_granular,fmtname=&measname.ce2cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt3,start=code,label=care_granular,fmtname=&measname.ce3cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt4,start=code,label=care_granular,fmtname=&measname.ce4cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt5,start=code,label=care_granular,fmtname=&measname.ce5cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt6,start=code,label=care_granular,fmtname=&measname.ce6cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt7,start=code,label=care_granular,fmtname=&measname.ce7cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt8,start=code,label=care_granular,fmtname=&measname.ce8cpt,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.celoinc,start=code,label=care_granular,fmtname=&measname.celn,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc2,start=code,label=care_granular,fmtname=&measname.ce2ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc3,start=code,label=care_granular,fmtname=&measname.ce3ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc4,start=code,label=care_granular,fmtname=&measname.ce4ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc5,start=code,label=care_granular,fmtname=&measname.ce5ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc6,start=code,label=care_granular,fmtname=&measname.ce6ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc7,start=code,label=care_granular,fmtname=&measname.ce7ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc8,start=code,label=care_granular,fmtname=&measname.ce8ln,type=C, library=work,Other="");

%if "&ce_lst"="female_element" %then %do; %let genderlst="FEMALE"; %end;
%if "&ce_lst"="male_element" %then %do; %let genderlst="MALE";%end;
%if "&ce_lst"="granular_element" %then %do; %let genderlst="FEMALE" "MALE" "";%end;

data _pattern1(drop=_: diag1-diag&dgnidx. proccd surg1 revcd sex) ;
set &indsn.
	( where=( sex in ( &genderlst) )
	keep=member_key svcdt loinc detail_key %if "&ce_lst"="granular_element" %then %do; provspec %end; proccd surg1 sex
		diag1-diag&dgnidx. %if "&condvars"="Y" %then %do; condition /*dgncd*/ %end;
	);
	revcd="";
	*keep care element & condition combinatin;
	length  _ce_diag1-_ce_diag&dgnidx _ce_cpt _ce_rev _ce_surg _ce_ln $50. care_element $30. ;
	array dgn{*} $ diag1-diag&dgnidx;
	array ce{*} $ _ce_diag1-_ce_diag&dgnidx _ce_cpt _ce_rev _ce_surg _ce_ln;

	*assgin conditions flag array for all codes;
	%if %sysfunc(cexist(work.formats.&measname.cedgn.formatc)) %then %do;
		do _i=1 to &dgnidx.;
			ce{_i}=	put(dgn{_i}, $&measname.cedgn.);
		end;
	%end;
	%if %sysfunc(cexist(work.formats.&measname.cecpt.formatc)) %then %do;
	_ce_cpt	=	put(proccd, $&measname.cecpt.);
	%end;

	%if %sysfunc(cexist(work.formats.&measname.cerev.formatc)) %then %do;
	_ce_rev	=	put(revcd, $&measname.cerev.);
	%end;

	%if %sysfunc(cexist(work.formats.&measname.cesurg.formatc)) %then %do;
	_ce_surg=	put(surg1, $&measname.cesurg.);
	%end;

	%if %sysfunc(cexist(work.formats.&measname.celn.formatc)) %then %do;
	_ce_ln	=	put(loinc, $&measname.celn.);
	%end;

	_cecnt=0;
	do _i=1 to &dgnidx.+4;
		if not missing(ce(_i)) then _cecnt+1;
	end;

	*keep care element & condition combinatin;
	if _cecnt gt 0 then 
		do _j=1 to &dgnidx.+4;
			if not missing(ce{_j}) then do;
				care_element = ce(_j);
				output _pattern1;
				if _j <=&dgnidx. then do; 
					%if %nobs(_&measname.cedgn2)>0 %then %do;
					if not missing(put(dgn{_j}, $&measname.ce2dgn.)) then do;
						care_element=put(dgn{_j}, $&measname.ce2dgn.);
						output _pattern1;
					end;
					%end;
				end;
				else if _j=&dgnidx.+1 then do;
					%if %nobs(_&measname.cecpt2)>0 %then %do;
					if not missing(put(proccd, $&measname.ce2cpt.)) then do;
						care_element=put(proccd, $&measname.ce2cpt.);
						output _pattern1;
						%if %nobs(_&measname.cecpt3)>0 %then %do;
						if not missing(put(proccd, $&measname.ce3cpt.)) then do;
							care_element=put(proccd, $&measname.ce3cpt.);
							output _pattern1;

							%if %nobs(_&measname.cecpt4)>0 %then %do;
							if not missing(put(proccd, $&measname.ce4cpt.)) then do;
								care_element=put(proccd, $&measname.ce4cpt.);
								output _pattern1;

								%if %nobs(_&measname.cecpt5)>0 %then %do;
								if not missing(put(proccd, $&measname.ce5cpt.)) then do;
									care_element=put(proccd, $&measname.ce5cpt.);
									output _pattern1;
							
									%if %nobs(_&measname.cecpt6)>0 %then %do;
									if not missing(put(proccd, $&measname.ce6cpt.)) then do;
										care_element=put(proccd, $&measname.ce6cpt.);
										output _pattern1;

										%if %nobs(_&measname.cecpt7)>0 %then %do;
										if not missing(put(proccd, $&measname.ce7cpt.)) then do;
											care_element=put(proccd, $&measname.ce7cpt.);
											output _pattern1;

											%if %nobs(_&measname.cecpt8)>0 %then %do;
											if not missing(put(proccd, $&measname.ce8cpt.)) then do;
												care_element=put(proccd, $&measname.ce8cpt.);
												output _pattern1;
											end;
											%end;
										end;
										%end;
									end;
									%end;
								end;
								%end;
							end;
							%end;
						end;
						%end;
					end;
					%end;
				end;
				else if _j=&dgnidx.+2 then do;
					%if %nobs(_&measname.cerev2)>0 %then %do;
					if not missing(put(revcd, $&measname.ce2rev.)) then do;
						care_element=put(revcd, $&measname.ce2rev.);
						output _pattern1;
					end;
					%end;
				end;
				else if _j=&dgnidx.+3 then do;
					%if %nobs(_&measname.cesurg2)>0 %then %do;
					if not missing(put(surg1, $&measname.ce2surg.)) then do;
						care_element=put(surg1, $&measname.ce2surg.);
						output _pattern1;

						%if %nobs(_&measname.cesurg3)>0 %then %do;
						if not missing(put(surg1, $&measname.ce3surg.)) then do;
							care_element=put(surg1, $&measname.ce3surg.);
							output _pattern1;
						end;
						%end;
					end;
					%end;
				end;
				else if _j=&dgnidx.+4 then do;
					%if %nobs(_&measname.celoinc2)>0 %then %do;
					if not missing(put(loinc, $&measname.ce2ln.)) then do;
						care_element=put(loinc, $&measname.ce2ln.);
						output _pattern1;

						%if %nobs(_&measname.celoinc3)>0 %then %do;
						if not missing(put(loinc, $&measname.ce3ln.)) then do;
							care_element=put(loinc, $&measname.ce3ln.);
							output _pattern1;

							%if %nobs(_&measname.celoinc4)>0 %then %do;
							if not missing(put(loinc, $&measname.ce4ln.)) then do;
								care_element=put(loinc, $&measname.ce4ln.);
								output _pattern1;

								%if %nobs(_&measname.celoinc5)>0 %then %do;
								if not missing(put(loinc, $&measname.ce5ln.)) then do;
									care_element=put(loinc, $&measname.ce5ln.);
									output _pattern1;
							
									%if %nobs(_&measname.celoinc6)>0 %then %do;
									if not missing(put(loinc, $&measname.ce6ln.)) then do;
										care_element=put(loinc, $&measname.ce6ln.);
										output _pattern1;

										%if %nobs(_&measname.celoinc7)>0 %then %do;
										if not missing(put(loinc, $&measname.ce7ln.)) then do;
											care_element=put(loinc, $&measname.ce7ln.);
											output _pattern1;

											%if %nobs(_&measname.celoinc8)>0 %then %do;
											if not missing(put(loinc, $&measname.ce8ln.)) then do;
												care_element=put(loinc, $&measname.ce8ln.);
												output _pattern1;
											end;
											%end;
										end;
										%end;
									end;
									%end;
								end;
								%end;
							end;
							%end;
						end;
						%end;
					end;
					%end;
				end;
			end;
		end;

run;

proc sort data=_pattern1 out=&outdsn nodupkeys;
by care_element member_key svcdt;
run;

%mend celp;

/*%celp(membs_transact_data,pattern1,granular_element,dgnidx=3,measname=val);*/
/*%celp(Membs_transact_data,pattern4_female,female_element,dgnidx=3,measname=val);*/
/*%celp(membs_transact_data,pattern4_male,male_element,dgnidx=3,measname=val);*/

