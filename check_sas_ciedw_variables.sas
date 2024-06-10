
%macro check_sas_ciedw_variables(validation=);

	proc contents data = ciedw.encounter_header  out = contents1 (keep=name) noprint;
	run;

	proc contents data = ciedw.encounter_detail  out = contents2 (keep=name) noprint;
	run;

	proc contents data = work.encounter_detail   out = contents_sas (keep=name) noprint;
	run;

	data contents_edw;
	set contents1 contents2;
	name=upcase(name);
	run;

	data contents_sas;
	set contents_sas;
	name=upcase(name);
	run;

	proc sort data = contents_edw nodupkey;
	by name;
	run;

	proc sort data = contents_sas nodupkey;
	by name;
	run;

	data contents_all;
	merge contents_sas (in=a)
	      contents_edw (in=b);
	by name;
	if b and not a;
	if scan(name,2,'_') ne 'SOURCE';
	if name in ('CLAIM_ID') then delete;
	run;

	proc sql noprint;
	select count(*) into: contents_match separated by ''
	from contents_all;
	quit;

	proc sql noprint;
	select name into: contents_name separated by ', '
	from contents_all;
	quit;

	%put NOTE: contents_match = &contents_match. ;
	%if &contents_match. ne 0 %then %do;
		%put ERROR: The following variables need to be initialized within the temp SAS dataset of encounter_detail: &contents_name. ;
	%end;

%mend check_sas_ciedw_variables; 
