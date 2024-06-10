/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  condmaplt (condition mapping)
|
| LOCATION: M:\CI\programs\StandardMacros
||
+--------------------------------------------------------------------------------
| history:  
| 26JAN2012 - EM set length statements when applying condition formats for codes with more than 1 cond
+-----------------------------------------------------------------------HEADER*/

%macro condmaplt(indsn,outdsn,conddsn,dgnidx=3,measname=val);
	*prepressing the datat to create code specific formats;
	proc sort data=&conddsn. out=_&conddsn.; by indicator code;run; 

	data _&measname.conddgn _&measname.conddgn2 _&measname.conddgn3;
	set _&conddsn.;
	by indicator code;
		if first.code then _cnt=1;
		else _cnt+1;

		if indicator in:("DIAG") then do;
			if _cnt=1 then output _&measname.conddgn;
			else if _cnt=2 then output _&measname.conddgn2;
			else if _cnt=3 then output _&measname.conddgn3;
		end;
	run;

	*condtion formats;
	%mk_fmt(dsn=_&measname.conddgn,start=code,label=condition,fmtname=&measname.conddgn,type=C, library=work,Other="");
	%mk_fmt(dsn=_&measname.conddgn2,start=code,label=condition,fmtname=&measname.cond2dgn,type=C, library=work,Other="");
	%mk_fmt(dsn=_&measname.conddgn3,start=code,label=condition,fmtname=&measname.cond3dgn,type=C, library=work,Other="");

	*looped mapping strategy;
	data _registry2bdiag( drop=_: cond_diag1-cond_diag&dgnidx);
	set &indsn.;
		*keep care element & condition combinatin;
		length  _cond_dgn1-_cond_dgn&dgnidx 
				_cond2 _cond3 $50.;
		length condition cond_diag1-cond_diag&dgnidx $25.;
		array dgn{*} $ diag1-diag&dgnidx;
		array cond{*} $ _cond_dgn1-_cond_dgn&dgnidx;
		array dgncond{*} $ cond_diag1-cond_diag&dgnidx;

		*assgin conditions flag array for all codes;
		do _i=1 to &dgnidx.;
			cond{_i}=	put(dgn{_i}, $&measname.conddgn.);
		end;

		_condcnt=0;
		do _i=1 to &dgnidx.;
			if not missing(cond(_i)) then _condcnt+1;
		end;

		*keep care element & condition combinatin;
		if _condcnt gt 0 then 
			do _j=1 to &dgnidx.;
				if not missing(cond{_j}) then do;
					condition = cond(_j);
					if _j<=&dgnidx. then do;
						call missing(of dgncond(*));
						dgncond(_j) = condition;
					end;
					output _registry2bdiag;
					
					%*multiple matching handling logic starts here;
					if _j <=&dgnidx. then do; 
						%if %nobs(_&measname.conddgn2)>0 %then %do;
						if not missing(put(dgn{_j}, $&measname.cond2dgn.)) then do;
							_cond2=put(dgn{_j}, $&measname.cond2dgn.);
							condition = _cond2;
							call missing(of dgncond(*));
							dgncond(_j) = condition;

							output _registry2bdiag;

							%if %nobs(_&measname.conddgn3)>0 %then %do;
							if not missing(put(dgn{_j}, $&measname.cond3dgn.)) then do;
								_cond3=put(dgn{_j}, $&measname.cond3dgn.);
								condition = _cond3;
								call missing(of dgncond(*));
								dgncond(_j) = condition;

								output _registry2bdiag;
							end;
							%end;
						end;
						%end;
					end;
				end;
			end;
			else output _registry2bdiag;

	run;
	proc sort data=_registry2bdiag nodupkeys out=&outdsn; by _all_;run;
%mend condmaplt;
