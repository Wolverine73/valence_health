/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  condmapping(diagnosis condition mapping)
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  using the format-driven method to replace the following SAS-unoptimizable Cartesian product join
|
|	proc sql noprint;
|	create table registry2b as  
|		 (select distinct
|				 r.*
|				,dc.condition format $25.
|				,dc.any_dx_on format 3.
|				,dc.any_dx_off format 3.
|				,dc.any_proc_on format 3.
|				,dc.any_proc_off format 3.
|				,dc.create_elig format 3.
|
|				from registry2a as r,diagnosis_condition2 as dc
|				where 
|					((r.diag1= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or
|					 (r.diag2= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.diag3= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.diag4= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.diag5= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.diag6= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.diag7= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.diag8= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.diag9= dc.code and dc.indicator in ('DIAG3', 'DIAG4', 'DIAG5')) or 
|					 (r.proccd=dc.code and dc.indicator in ('CPT','CPT2','HCPCS')) or  
|					 (r.revcd=dc.code and dc.indicator in ('REVCD')) or
|					 (r.loinc=dc.code and dc.indicator in ('LOINC')) or
|					 (r.surg1 = dc.code and dc.indicator in ('SURG'))))
|					order by member_key, condition, svcdt;
|	quit;
|
| INPUT:   
|				indsn			: 	in dataset name
|				outdsn			: 	out dataset name
|				cedsn			: 	care element lookup table dataset name
|				indsnvarlst		:	in dataset var list
|				outdsnvarlst	:	out dataset var list
|				dgnidx			:	maximum diag code array index
|				measname		:	care element control table logic name
|				mappingcode		:	variables needed to match on
|				innerjoin		:	inner join flag 
|
| OUTPUT:   	output of the macro will be deduped care element mapped dataset
|
| USAGE EXAMPLES: 


|	%let _inkplst=member_key svcdt proccd revcd mod1 surg1 admdt2 disdt2 majcat provspec encounter_key;
|	%let _outkplst=admdt2 any_dx_off any_dx_on any_proc_off any_proc_on condition create_elig 
|					disdt2 encounter_key majcat member_key mod1 proccd provspec revcd surg1 svcdt;
|
|	%condmapping(registry2a,registry2b,diagnosis_condition2
|			,&_inkplst
|			,&_outkplst
|			,dgnidx=9
|			,measname=val
|			,mappingcode=proccd revcd surg1);
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| Original - 10NOV2011 - John Zheng - Clinical Integration 
| 		   - 12DEC2011 - John Zheng - add format existing check logic
| 		   - 13DEC2011 - John Zheng - add format-driven datasets deleting logic
| 26JAN2012 - EM set length statements when applying condition formats for codes with more than 1 cond
+-----------------------------------------------------------------------HEADER*/
%macro condmapping(indsn,outdsn,conddsn,indsnvarlst,outdsnvarlst
					,dgnidx=9
					,measname=val
					,mappingcode=proccd revcd surg1
					,innerjoin=1
		);

*prepressing the datat to create code specific formats;
proc sort data=&conddsn. out=_&conddsn.; by indicator code;run; 

data _&measname.conddgn _&measname.conddgn2 _&measname.conddgn3 _&measname.condcpt _&measname.condcpt2 
		_&measname.condrev _&measname.condsurg _&measname.condsurg2;
set _&conddsn.;
by indicator code;
	if first.code then _cnt=1;
	else _cnt+1;

	flgs=catx("|",condition,any_dx_on,any_dx_off,any_proc_on,any_proc_off,create_elig);
	if indicator in:("DIAG") then do;
		if _cnt=1 then output _&measname.conddgn;
		else if _cnt=2 then output _&measname.conddgn2;
		else if _cnt=3 then output _&measname.conddgn3;
	end;
	else if indicator in:("CPT" "HCPCS") then do;
		if _cnt=1 then output _&measname.condcpt;
		else if _cnt=2 then output _&measname.condcpt2;
	end;
	else if indicator in:("REVCD") then output _&measname.condrev;
	else if indicator in:("SURG") then do;
		if _cnt=1 then output _&measname.condsurg;
		else if _cnt=2 then output _&measname.condsurg2;
	end;
run;

*condtion formats;
%mk_fmt(dsn=_&measname.conddgn,start=code,label=flgs,fmtname=&measname.conddgn,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.conddgn2,start=code,label=flgs,fmtname=&measname.cond2dgn,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.conddgn3,start=code,label=flgs,fmtname=&measname.cond3dgn,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.condcpt,start=code,label=flgs,fmtname=&measname.condcpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.condcpt2,start=code,label=flgs,fmtname=&measname.cond2cpt,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.condrev,start=code,label=flgs,fmtname=&measname.condrev,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.condsurg,start=code,label=flgs,fmtname=&measname.condsurg,type=C, library=work,Other="");
%mk_fmt(dsn=_&measname.condsurg2,start=code,label=flgs,fmtname=&measname.cond2surg,type=C, library=work,Other="");

*looped mapping strategy;
data _registry2bdiag(drop=_: %if "&outdsnvarlst" ne "" %then %do; keep=&outdsnvarlst. %end; );
set &indsn.
	(%if "&indsnvarlst" ne "" %then %do; keep=&indsnvarlst. diag1-diag&dgnidx.%end; 
		%else %do; keep=_all_%end; );

	*keep care element & condition combinatin;
	length  _cond_dgn1-_cond_dgn&dgnidx _cond_cpt _cond_rev _cond_surg 
			_cond2 _cond3 _cpt2 _surg2 $50.;
	length condition cond_diag1-cond_diag&dgnidx $30. any_dx_on any_dx_off any_proc_on any_proc_off create_elig 3.;
	array dgn{*} $ diag1-diag&dgnidx;
	array cond{*} $ _cond_dgn1-_cond_dgn&dgnidx _cond_cpt _cond_rev _cond_surg;
	array dgncond{*} $ cond_diag1-cond_diag&dgnidx;
	
	%if %index(&mappingcode,proccd) = 0 %then %do; 
	length proccd $5.; proccd="";
	%end; 
	%if %index(&mappingcode,revcd) = 0 %then %do; 
	length revcd $3.; revcd="";
	%end; 
	%if %index(&mappingcode,surg1) = 0 %then %do; 
	length surg1 $5.; surg1="";
	%end; 

	*assgin conditions flag array for all codes;
	%if %sysfunc(cexist(work.formats.&measname.conddgn.formatc)) %then %do;
		do _i=1 to &dgnidx.;
			cond{_i}=	put(dgn{_i}, $&measname.conddgn.);
		end;
	%end;
	%if %sysfunc(cexist(work.formats.&measname.condcpt.formatc)) %then %do;
	_cond_cpt	=	put(proccd, $&measname.condcpt.);
	%end;
	%if %sysfunc(cexist(work.formats.&measname.condrev.formatc)) %then %do;
	_cond_rev	=	put(revcd, $&measname.condrev.);
	%end;
	%if %sysfunc(cexist(work.formats.&measname.condsurg.formatc)) %then %do;
	_cond_surg	=	put(surg1, $&measname.condsurg.);
	%end;
	_condcnt=0;
	do _i=1 to &dgnidx.+3;
		if not missing(cond(_i)) then _condcnt+1;
	end;

	*keep care element & condition combinatin;
	if _condcnt gt 0 then 
		do _j=1 to &dgnidx.+3;
			if not missing(cond{_j}) then do;
				condition = scan(cond(_j), 1,"|");
				if _j<=&dgnidx. then do;
					call missing(of dgncond(*));
					dgncond(_j) = condition;
				end;
				any_dx_on = input(scan(cond(_j), 2,"|"),3.);
				any_dx_off = input(scan(cond(_j), 3,"|"),3.);
				any_proc_on = input(scan(cond(_j), 4,"|"),3.);
				any_proc_off = input(scan(cond(_j), 5,"|"),3.);
				create_elig = input(scan(cond(_j), 6,"|"),3.);
				output _registry2bdiag;
				
				%*multiple matching handling logic starts here;
				if _j <=&dgnidx. then do; 
					%if %nobs(_&measname.conddgn2)>0 %then %do;
					if not missing(put(dgn{_j}, $&measname.cond2dgn.)) then do;
						_cond2=put(dgn{_j}, $&measname.cond2dgn.);
						condition = scan(_cond2, 1,"|");
						call missing(of dgncond(*));
						dgncond(_j) = condition;

						any_dx_on = input(scan(_cond2, 2,"|"),3.);
						any_dx_off = input(scan(_cond2, 3,"|"),3.);
						any_proc_on = input(scan(_cond2, 4,"|"),3.);
						any_proc_off = input(scan(_cond2, 5,"|"),3.);
						create_elig = input(scan(_cond2, 6,"|"),3.);
						output _registry2bdiag;

						%if %nobs(_&measname.conddgn3)>0 %then %do;
						if not missing(put(dgn{_j}, $&measname.cond3dgn.)) then do;
							_cond3=put(dgn{_j}, $&measname.cond3dgn.);
							condition = scan(_cond3, 1,"|");
							call missing(of dgncond(*));
							dgncond(_j) = condition;

							any_dx_on = input(scan(_cond3, 2,"|"),3.);
							any_dx_off = input(scan(_cond3, 3,"|"),3.);
							any_proc_on = input(scan(_cond3, 4,"|"),3.);
							any_proc_off = input(scan(_cond3, 5,"|"),3.);
							create_elig = input(scan(_cond3, 6,"|"),3.);
							output _registry2bdiag;
						end;
						%end;
					end;
					%end;
				end;
				else if _j=&dgnidx.+1 then do;
					%if %nobs(_&measname.condcpt2)>0 %then %do;
					if not missing(put(proccd, $&measname.cond2cpt.)) then do;
						_cpt2=put(proccd, $&measname.cond2cpt.);
						condition = scan(_cpt2, 1,"|");
						any_dx_on = input(scan(_cpt2, 2,"|"),3.);
						any_dx_off = input(scan(_cpt2, 3,"|"),3.);
						any_proc_on = input(scan(_cpt2, 4,"|"),3.);
						any_proc_off = input(scan(_cpt2, 5,"|"),3.);
						create_elig = input(scan(_cpt2, 6,"|"),3.);
						output _registry2bdiag;
					end;
					%end;
				end;
				else if _j=&dgnidx.+3 then do;
					%if %nobs(_&measname.condsurg2)>0 %then %do;
					if not missing(put(surg1, $&measname.cond2surg.)) then do;
						_surg2=put(surg1, $&measname.cond2surg.);
						condition = scan(_surg2, 1,"|");
						any_dx_on = input(scan(_surg2, 2,"|"),3.);
						any_dx_off = input(scan(_surg2, 3,"|"),3.);
						any_proc_on = input(scan(_surg2, 4,"|"),3.);
						any_proc_off = input(scan(_surg2, 5,"|"),3.);
						create_elig = input(scan(_surg2, 6,"|"),3.);
						output _registry2bdiag;
					end;
					%end;
				end;
			end;
		end;
		%if "&innerjoin" ne "1" %then %do; 
		else output _registry2bdiag;
		%end; 

run;
proc sort data=_registry2bdiag nodupkeys out=&outdsn; by _all_;run;

*delete the temp datasets;
proc sql;
select distinct memname into: _deltblst separated by " " from dictionary.members
where index(memname,"_")=1 and libname="WORK";
quit;

proc datasets library = work nolist;
delete &_deltblst;
quit;
%mend condmapping;
