%let lib=ndc;
%let dataset=cdc_a;


%macro  create_sascodelist( lib=, dataset=, sheet=, column=, name=); 

	%global &name.;
	data x;
	set &lib..&dataset.;
	run;

	proc sql noprint;
	select quote(trim(&column.)) into: &name. separated by ','
	from x;
	quit;
	libname in2 clear;

%mend;

