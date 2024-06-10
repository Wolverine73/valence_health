
%macro  create_ndccodeformat( filepath=, sheet=, label=, start=, type=, name=, lablen=); 

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
	data codefmt;
			length start $11. label &lablen.;
	set in2."&sheet.$"n;
		retain fmtname ("&name.") type ("&type.");
		start=&start.;
		label=upcase(&label.);
		keep fmtname type start label;
	run;

	proc sort data=codefmt nodupkey;
	by start;
	run;

	proc format cntlin=codefmt;
	run;

	libname in2 clear;

%mend;

