%macro mk_HEDIS (dsn=, start=,label=, fmtname=, type=C, Library=work, Other="OTHER");
data _temp ; set &dsn  end=last;
  if missing(&start) then delete;
    start   =trim(left(&start.));
    fmtname ="&fmtname.";
    type    ="&type.";
    label   =&label;
    output;
    if last then do;
      	start = "OTHER";
/*    	%if &OTHER ne "" %then label = &OTHER; */
/*		%else label = . ; ;*/
		label = &OTHER; 
        output;
    end;
    keep start fmtname type label;
run;

proc sort data=_temp nodupkey; by start; run;
proc format cntlin=_temp library=&library; run;
proc sql;drop table _temp;quit;
%mend mk_HEDIS;
