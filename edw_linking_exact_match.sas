	*SASDOC--------------------------------------------------------------------------
	| Logic to link patient_key to identical member information 
	+------------------------------------------------------------------------SASDOC*; 
		%macro edw_linking_exact_match(inset,outset,input,match_by_datasource=,match_nonnull_only=0,match_start=0,match_end=0,assign_pl_rank=0);
			%if &match_start.=1 %then %do;
				proc sql _method;
		  		  create table &outset.(index=(patient_key)) as
		  		  select 	distinct a.patient_key as patient_key format 16.,x.*
		  		  from 		sasPL_&input. a inner join 
							&inset. x on 
									%if %upcase(&input.)=DOB %then %do; a.&input.=x.&input. %end;
									%else %do; trim(a.&input.)=trim(x.&input.) %end;
									%if &match_by_datasource. ne %then %do;
										and a.datasourceid=&match_by_datasource. 
									%end;
									%if &match_nonnull_only. %then %do;
										and	a.&input. is not null
									%end;
				  ;
				quit;
			%end;
			%else %if &match_end.=0 %then %do;
				proc sql _method;
		  		  create table &outset.(index=(patient_key)) as
		  		  select 	distinct x.*
		  		  from 		sasPL_&input. a inner join 
							&inset. x on a.patient_key=x.patient_key and 
									%if %upcase(&input.)=DOB %then %do; a.&input.=x.&input. %end;
									%else %do; trim(a.&input.)=trim(x.&input.) %end;
									%if &match_by_datasource. ne %then %do;
										and a.datasourceid=&match_by_datasource. 
									%end;
									%if &match_nonnull_only. %then %do;
										and	a.&input. is not null
									%end;
				  ;
				quit;
			%end;
			%else %do;
				proc sql _method;
		  		  create table &outset. as
		  		  select 	distinct x.*, sum(a.counter) as counter
		  		  from 		sasPL_&input. a inner join 
							&inset. x on a.patient_key=x.patient_key and 
									%if %upcase(&input.)=DOB %then %do; a.&input.=x.&input. %end;
									%else %do; trim(a.&input.)=trim(x.&input.) %end;
									%if &match_by_datasource. ne %then %do;
										and a.datasourceid=&match_by_datasource. 
									%end;
									%if &match_nonnull_only. %then %do;
										and	a.&input. is not null
									%end;
				  group by RID, a.patient_key, a.&input.
				  order by RID, counter;
				quit;

				data &outset.(drop=counter);
                  set &outset.;
                  by RID counter;
				  pl_rank=&assign_pl_rank.;
                  if last.RID;
                run;
			%end;
		%mend edw_linking_exact_match;
