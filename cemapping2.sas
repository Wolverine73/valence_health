/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  cemapping(care element mapping)
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  using the format-driven method to replace the following SAS-unoptimizable Cartesian product join
|
|		proc sql;
|			create table &outdsn as select distinct
|				a.*,
|				b.care_granular as care_element,
|				b.rev_flag
|
|			from  &indsn as a
|					inner join
|					(select * from &cedsn) as b
|						on (a.diag1 = b.code and b.indicator = 'DIAG')
|						or (a.diag2 = b.code and b.indicator = 'DIAG')
|						or (a.diag3 = b.code and b.indicator = 'DIAG')
|						or (a.diag4 = b.code and b.indicator = 'DIAG')
|						or (a.diag5 = b.code and b.indicator = 'DIAG')
|						or (a.diag6 = b.code and b.indicator = 'DIAG')
|						or (a.diag7 = b.code and b.indicator = 'DIAG')
|						or (a.diag8 = b.code and b.indicator = 'DIAG')
|						or (a.diag9 = b.code and b.indicator = 'DIAG')
|						or (a.proccd = b.code and b.indicator = 'CPT')
|						or (a.loinc = b.code and b.indicator = 'LOINC')
|						or (a.revcd = b.code and  b.indicator = 'REVCD')
|						or (a.surg1 = b.code and b.indicator = 'SURG')
|			order by  a.memberid, a.svcdt, b.care_granular 
|			;
|		quit;
|
| INPUT:   
|				indsn			: 	in dataset name
|				outdsn			: 	out dataset name
|				cedsn			: 	care element lookup table dataset name
|				indsnvarlst		:	in dataset var list
|				outdsnvarlst	:	out dataset var list
|				dgnidx			:	maximum diag code array index
|				measname		:	care element control table logic name
|
| OUTPUT:   	output of the macro will be deduped care element mapped dataset
|
| USAGE EXAMPLES: 
|		%cemapping(edw_g0diag,edw_g0,cccpp_careelements, ,,dgnidx=9,measname=val);
|		%cemapping(reg2b,registry2c,ce,
|			,&_outkplst
|			,dgnidx=9
|			,measname=val
|			,mappingcode=proccd revcd
|			,innerjoin=0);
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| Original - 10NOV2011 - John Zheng - Clinical Integration 
| 		   - 12DEC2011 - John Zheng - add format existing check logic
| 		   - 13DEC2011 - John Zheng - add format-driven datasets deleting logic
| 		   - 04JAN2012 - LS make adjustments to allow LOINCS to be formated by care elements.
| 26JAN2012 - EM set length statements when applying care element formats for codes with more
|				 than 1 ce
| 23MAR2012 - LS create v2 to keep hcpcs ,cpt2, and delete_prospective flags
| 03APR2012 - LS implement logic to subset on only prospective elements when it's not a guideline day.
+-----------------------------------------------------------------------HEADER*/
%macro cemapping2(indsn,outdsn,cedsn,indsnvarlst,outdsnvarlst
				,dgnidx=9
				,measname=val
				,mappingcode=diag proccd revcd surg1 loinc
				,innerjoin=0);



/*prepressing the datat to create code specific formats */
proc sort data = &cedsn.; 
by indicator code;
run; 

data _&measname.cedgn _&measname.cedgn2 
	_&measname.cecpt _&measname.cecpt2 _&measname.cecpt3 _&measname.cecpt4 _&measname.cecpt5 _&measname.cecpt6  _&measname.cecpt7 _&measname.cecpt8
	_&measname.cerev _&measname.cerev2 
	_&measname.celoinc _&measname.celoinc2 _&measname.celoinc3 _&measname.celoinc4 _&measname.celoinc5 _&measname.celoinc6 _&measname.celoinc7 _&measname.celoinc8
	_&measname.cesurg _&measname.cesurg2 _&measname.cesurg3
	_all;

set &cedsn. ;

/*	%if &client_run_day. ne &day_run. %then %do; */
/*		where is_prospective = 1;*/
/*	%end; */

	by indicator code;
	if first.code then _cnt=1;
	else _cnt+1;

	flgs=catx("|",care_granular,rev_flag,hcpcs,cpt2,delete_prospective);
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

/*care element formats */
%mk_fmt(dsn=_&measname.cedgn,start=code,label=flgs,fmtname=&measname.cedgn,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cedgn2,start=code,label=flgs,fmtname=&measname.ce2dgn,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.cerev,start=code,label=flgs,fmtname=&measname.cerev,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cerev2,start=code,label=flgs,fmtname=&measname.ce2rev,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.cesurg,start=code,label=flgs,fmtname=&measname.cesurg,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cesurg2,start=code,label=flgs,fmtname=&measname.ce2surg,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cesurg3,start=code,label=flgs,fmtname=&measname.ce3surg,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.cecpt,start=code,label=flgs,fmtname=&measname.cecpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt2,start=code,label=flgs,fmtname=&measname.ce2cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt3,start=code,label=flgs,fmtname=&measname.ce3cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt4,start=code,label=flgs,fmtname=&measname.ce4cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt5,start=code,label=flgs,fmtname=&measname.ce5cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt6,start=code,label=flgs,fmtname=&measname.ce6cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt7,start=code,label=flgs,fmtname=&measname.ce7cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.cecpt8,start=code,label=flgs,fmtname=&measname.ce8cpt,type=C, library=work,Other="");

%mk_fmt(dsn=_&measname.celoinc,start=code,label=flgs,fmtname=&measname.celn,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc2,start=code,label=flgs,fmtname=&measname.ce2ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc3,start=code,label=flgs,fmtname=&measname.ce3ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc4,start=code,label=flgs,fmtname=&measname.ce4ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc5,start=code,label=flgs,fmtname=&measname.ce5ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc6,start=code,label=flgs,fmtname=&measname.ce6ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc7,start=code,label=flgs,fmtname=&measname.ce7ln,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.celoinc8,start=code,label=flgs,fmtname=&measname.ce8ln,type=C, library=work,Other="");

*looped mapping strategy;
data _pattern1(drop=_: /*diag1-diag&dgnidx.*/ %if "&outdsnvarlst" ne "" %then %do; keep=&outdsnvarlst. %end; ) ;
set &indsn.
	( %if "&indsnvarlst" ne "" %then %do; keep=&indsnvarlst. diag1-diag&dgnidx.%end; 
		%else %do; keep=_all_%end;)
	;
	/*keep care element var */
	length  _ce_diag1-_ce_diag&dgnidx _ce_cpt _ce_rev _ce_surg _ce_ln 
			_ce $50. 
			care_granular $30. 
			rev_flag 3.
			hcpcs 3. 
			cpt2 3.
			delete_prospective 3.;

	array dgn{*} $ diag1-diag&dgnidx;
	array ce{*} $ _ce_diag1-_ce_diag&dgnidx _ce_cpt _ce_rev _ce_surg _ce_ln;

	/*mapping variable setting up */
	%if %index(&mappingcode,proccd) = 0 %then %do; 
	length proccd $5.; proccd="";
	%end; 
	%if %index(&mappingcode,revcd) = 0 %then %do; 
	length revcd $3.; revcd="";
	%end; 
	%if %index(&mappingcode,surg1) = 0 %then %do; 
	length surg1 $5.; surg1="";
	%end; 
	%if %index(&mappingcode,loinc) = 0 %then %do; 
	length loinc $7.; loinc="";
	%end; 
	%if %index(&mappingcode,diag) = 0 %then %do; 
	length diag1-diag&dgnidx $6.; call missing(of dgn(*));
	%end; 

	/*assgin conditions flag array for all codes */
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

	/*keep care element flags */
	if _cecnt gt 0 then 
		do _j=1 to &dgnidx.+4;
			if not missing(ce{_j}) then do;
				care_granular=scan(ce(_j), 1,"|");
				rev_flag=input(scan(ce(_j), 2,"|"),3.);
				hcpcs=input(scan(ce(_j), 3,"|"),3.);
				cpt2=input(scan(ce(_j), 4,"|"),3.);
				delete_prospective=input(scan(ce(_j), 5,"|"),3.);
				output _pattern1;

				%*multiple matching handling logic starts here;
				if _j <=&dgnidx. then do; 
					%if %nobs(_&measname.cedgn2)>0 %then %do;
					if not missing(put(dgn{_j}, $&measname.ce2dgn.)) then do;
						_ce=put(dgn{_j}, $&measname.ce2dgn.);
						care_granular=scan(_ce, 1,"|");
						rev_flag=input(scan(_ce, 2,"|"),3.);
						hcpcs=input(scan(_ce, 3,"|"),3.);
						cpt2=input(scan(_ce, 4,"|"),3.);
						delete_prospective=input(scan(_ce, 5,"|"),3.);
						output _pattern1;
					end;
					%end;
				end;
				else if _j=&dgnidx.+1 then do;
					%if %nobs(_&measname.cecpt2)>0 %then %do;
					if not missing(put(proccd, $&measname.ce2cpt.)) then do;
						_ce=put(proccd, $&measname.ce2cpt.);
						care_granular=scan(_ce, 1,"|");
						rev_flag=input(scan(_ce, 2,"|"),3.);
						hcpcs=input(scan(_ce, 3,"|"),3.);
						cpt2=input(scan(_ce, 4,"|"),3.);
						delete_prospective=input(scan(_ce, 5,"|"),3.);
						output _pattern1;
						%if %nobs(_&measname.cecpt3)>0 %then %do;
						if not missing(put(proccd, $&measname.ce3cpt.)) then do;
							_ce=put(proccd, $&measname.ce3cpt.);
							care_granular=scan(_ce, 1,"|");
							rev_flag=input(scan(_ce, 2,"|"),3.);
							hcpcs=input(scan(_ce, 3,"|"),3.);
							cpt2=input(scan(_ce, 4,"|"),3.);
							delete_prospective=input(scan(_ce, 5,"|"),3.);
							output _pattern1;

							%if %nobs(_&measname.cecpt4)>0 %then %do;
							if not missing(put(proccd, $&measname.ce4cpt.)) then do;
								_ce=put(proccd, $&measname.ce4cpt.);
								care_granular=scan(_ce, 1,"|");
								rev_flag=input(scan(_ce, 2,"|"),3.);
								hcpcs=input(scan(_ce, 3,"|"),3.);
								cpt2=input(scan(_ce, 4,"|"),3.);
								delete_prospective=input(scan(_ce, 5,"|"),3.);
								output _pattern1;

								%if %nobs(_&measname.cecpt5)>0 %then %do;
								if not missing(put(proccd, $&measname.ce5cpt.)) then do;
									_ce=put(proccd, $&measname.ce5cpt.);
									care_granular=scan(_ce, 1,"|");
									rev_flag=input(scan(_ce, 2,"|"),3.);
									hcpcs=input(scan(_ce, 3,"|"),3.);
									cpt2=input(scan(_ce, 4,"|"),3.);
									delete_prospective=input(scan(_ce, 5,"|"),3.);
									output _pattern1;
							
									%if %nobs(_&measname.cecpt6)>0 %then %do;
									if not missing(put(proccd, $&measname.ce6cpt.)) then do;
										_ce=put(proccd, $&measname.ce6cpt.);
										care_granular=scan(_ce, 1,"|");
										rev_flag=input(scan(_ce, 2,"|"),3.);
										hcpcs=input(scan(_ce, 3,"|"),3.);
										cpt2=input(scan(_ce, 4,"|"),3.);
										delete_prospective=input(scan(_ce, 5,"|"),3.);
										output _pattern1;

										%if %nobs(_&measname.cecpt7)>0 %then %do;
										if not missing(put(proccd, $&measname.ce7cpt.)) then do;
											_ce=put(proccd, $&measname.ce7cpt.);
											care_granular=scan(_ce, 1,"|");
											rev_flag=input(scan(_ce, 2,"|"),3.);
											hcpcs=input(scan(_ce, 3,"|"),3.);
											cpt2=input(scan(_ce, 4,"|"),3.);
											delete_prospective=input(scan(_ce, 5,"|"),3.);
											output _pattern1;

											%if %nobs(_&measname.cecpt8)>0 %then %do;
											if not missing(put(proccd, $&measname.ce8cpt.)) then do;
												_ce=put(proccd, $&measname.ce8cpt.);
												care_granular=scan(_ce, 1,"|");
												rev_flag=input(scan(_ce, 2,"|"),3.);
												hcpcs=input(scan(_ce, 3,"|"),3.);
												cpt2=input(scan(_ce, 4,"|"),3.);
												delete_prospective=input(scan(_ce, 5,"|"),3.);
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
						_ce=put(revcd, $&measname.ce2rev.);
						care_granular=scan(_ce, 1,"|");
						rev_flag=input(scan(_ce, 2,"|"),3.);
						hcpcs=input(scan(_ce, 3,"|"),3.);
						cpt2=input(scan(_ce, 4,"|"),3.);
						delete_prospective=input(scan(_ce, 5,"|"),3.);
						output _pattern1;
					end;
					%end;
				end;
				else if _j=&dgnidx.+3 then do;
					%if %nobs(_&measname.cesurg2)>0 %then %do;
					if not missing(put(surg1, $&measname.ce2surg.)) then do;
						_ce=put(surg1, $&measname.ce2surg.);
						care_granular=scan(_ce, 1,"|");
						rev_flag=input(scan(_ce, 2,"|"),3.);
						hcpcs=input(scan(_ce, 3,"|"),3.);
						cpt2=input(scan(_ce, 4,"|"),3.);
						delete_prospective=input(scan(_ce, 5,"|"),3.);
						output _pattern1;

						%if %nobs(_&measname.cesurg3)>0 %then %do;
						if not missing(put(surg1, $&measname.ce3surg.)) then do;
							_ce=put(surg1, $&measname.ce3surg.);
							care_granular=scan(_ce, 1,"|");
							rev_flag=input(scan(_ce, 2,"|"),3.);
							hcpcs=input(scan(_ce, 3,"|"),3.);
							cpt2=input(scan(_ce, 4,"|"),3.);
							delete_prospective=input(scan(_ce, 5,"|"),3.);
							output _pattern1;
						end;
						%end;
					end;
					%end;
				end;
				else if _j=&dgnidx.+4 then do;
					%if %nobs(_&measname.celoinc2)>0 %then %do;
					if not missing(put(loinc, $&measname.ce2ln.)) then do;
						_ce=put(loinc, $&measname.ce2ln.);
						care_granular=scan(_ce, 1,"|");
						rev_flag=input(scan(_ce, 2,"|"),3.);
						hcpcs=input(scan(_ce, 3,"|"),3.);
						cpt2=input(scan(_ce, 4,"|"),3.);
						delete_prospective=input(scan(_ce, 5,"|"),3.);
						output _pattern1;

						%if %nobs(_&measname.celoinc3)>0 %then %do;
						if not missing(put(loinc, $&measname.ce3ln.)) then do;
							_ce=put(loinc, $&measname.ce3ln.);
							care_granular=scan(_ce, 1,"|");
							rev_flag=input(scan(_ce, 2,"|"),3.);
							hcpcs=input(scan(_ce, 3,"|"),3.);
							cpt2=input(scan(_ce, 4,"|"),3.);
							delete_prospective=input(scan(_ce, 5,"|"),3.);
							output _pattern1;

							%if %nobs(_&measname.celoinc4)>0 %then %do;
							if not missing(put(loinc, $&measname.ce4ln.)) then do;
								_ce=put(loinc, $&measname.ce4ln.);
								care_granular=scan(_ce, 1,"|");
								rev_flag=input(scan(_ce, 2,"|"),3.);
								hcpcs=input(scan(_ce, 3,"|"),3.);
								cpt2=input(scan(_ce, 4,"|"),3.);
								delete_prospective=input(scan(_ce, 5,"|"),3.);
								output _pattern1;

								%if %nobs(_&measname.celoinc5)>0 %then %do;
								if not missing(put(loinc, $&measname.ce5ln.)) then do;
									_ce=put(loinc, $&measname.ce5ln.);
									care_granular=scan(_ce, 1,"|");
									rev_flag=input(scan(_ce, 2,"|"),3.);
									hcpcs=input(scan(_ce, 3,"|"),3.);
									cpt2=input(scan(_ce, 4,"|"),3.);
									delete_prospective=input(scan(_ce, 5,"|"),3.);
									output _pattern1;
					
									%if %nobs(_&measname.celoinc6)>0 %then %do;
									if not missing(put(loinc, $&measname.ce6ln.)) then do;
										_ce=put(loinc, $&measname.ce6ln.);
										care_granular=scan(_ce, 1,"|");
										rev_flag=input(scan(_ce, 2,"|"),3.);
										hcpcs=input(scan(_ce, 3,"|"),3.);
										cpt2=input(scan(_ce, 4,"|"),3.);
										delete_prospective=input(scan(_ce, 5,"|"),3.);
										output _pattern1;

										%if %nobs(_&measname.celoinc7)>0 %then %do;
										if not missing(put(loinc, $&measname.ce7ln.)) then do;
											_ce=put(loinc, $&measname.ce7ln.);
											care_granular=scan(_ce, 1,"|");
											rev_flag=input(scan(_ce, 2,"|"),3.);
											hcpcs=input(scan(_ce, 3,"|"),3.);
											cpt2=input(scan(_ce, 4,"|"),3.);
											delete_prospective=input(scan(_ce, 5,"|"),3.);
											output _pattern1;

											%if %nobs(_&measname.celoinc8)>0 %then %do;
											if not missing(put(loinc, $&measname.ce8ln.)) then do;
												_ce=put(loinc, $&measname.ce8ln.);
												care_granular=scan(_ce, 1,"|");
												rev_flag=input(scan(_ce, 2,"|"),3.);
												hcpcs=input(scan(_ce, 3,"|"),3.);
												cpt2=input(scan(_ce, 4,"|"),3.);
												delete_prospective=input(scan(_ce, 5,"|"),3.);
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
				%*multiple matching handling logic ends here;
			end;
		end;
		%if "&innerjoin" ne "1" %then %do; 
		else output _pattern1;
		%end; 
run;

proc sort data=_pattern1
	out=&outdsn nodupkeys;by _all_;run;

/*delete the temp datasets */
proc sql;
select distinct memname into: _deltblst separated by " " from dictionary.members
where index(memname,"_")=1 and libname="WORK";
quit;

proc datasets library = work nolist;
delete &_deltblst;
quit;
%mend cemapping2;

