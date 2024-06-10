/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  check_person_pharmacy_vars.sas
|
| LOCATION: M:\CI\programs\Development\StandardMacros
|
| PURPOSE:  Check CIEDW.dbo.PERSON_PHARMACY variables  
|
| INPUT:    
|                        
| OUTPUT:    
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 03JUN2012 - Valence Health  - Clinical Integration  Release v1.3.H01
|             Original
+-----------------------------------------------------------------------HEADER*/

%macro check_person_pharmacy_vars (validation=);

	proc contents data = ciedw.person_pharmacy  out = contents1 (keep=name) noprint;
	run;

	proc contents data = work.person_pharmacy   out = contents_sas (keep=name) noprint;
	run;

	data contents_edw;
	set contents1;
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
		%put ERROR: The following variables need to be initialized within the temp SAS dataset of person_pharmacy: &contents_name. ;
	%end;

%mend check_person_pharmacy_vars; 
