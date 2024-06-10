

%macro  create_codelist( filepath=, sheet=, column=, name=); 

	%macro testing;
	%if %substr(&sysscpl.,1,3) = X64 %then %do; *64-bit;
	libname in2 oledb init_string="Provider=Microsoft.ACE.OLEDB.12.0;
	data source = &filepath.;
	  	extended Properties=Excel 12.0";
	%end;
	%else %if "&sysscpl."="NET_SRV" %then %do; *32-bit;
	libname in2 oledb provider=jet provider_string='Excel 8.0'
	datasource="&filepath.";
	%end;
	%mend;
	%testing;

	%global &name.;
	data x;
	set in2."&sheet.$"n;
	run;

	proc sql noprint;
	select quote(trim(&column.)) into: &name. separated by ','
	from x;
	quit;
	libname in2 clear;

%mend;

