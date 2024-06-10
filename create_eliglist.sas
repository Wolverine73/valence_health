/**/
/*%let filepath=\\fs\ohg\Process\Measures\Coding Process\Table CDC-A_DCDC-A.xls;*/
/*%let sheet=Table CDC-A_DCDC-A;*/
/*%let column=ndc_code;*/

%macro create_eliglist(name=, filepath=, sheet=, column=);

	%macro testing;
	%if "&sysscpl."="X64_ESRV" or "&sysscpl."="X64_VSPRO" or 
	"&sysscpl."="X64_SRV08" %then %do; *64-bit;
	libname in1 oledb init_string="Provider=Microsoft.ACE.OLEDB.12.0;
	data source = &filepath.;
	  	extended Properties=Excel 12.0";
	%end;
	%else %if "&sysscpl."="NET_SRV" %then %do; *32-bit;
	libname in1 oledb provider=jet provider_string='Excel 8.0'
	datasource="&filepath.";
	%end;
	%mend;
	%testing;

	data eligcodes;
	set in1."&sheet.$"n;
	run;

	proc sql;
	create table unique as
	select distinct &column.
		from eligcodes;
		quit;

	data _null_;
		%global eligtotal;
		set eligcodes end=lastrec;
		if lastrec then do;
		call symput('eligtotal',_n_);
		end;
	run;
	%put &eligtotal;

	%macro assign_names;
		%do n=1 %to &eligtotal;
		%global eligcode&n;
		data _null_;
		set eligcodes;
		if &n=_n_; /* keep only the nth data record */
		call symput("eligcode&n", &column.);
		run;
		%end; /* end of the %do-loop 				*/
	%mend assign_names;

	%assign_names;

	%macro eliglist;
		%do k=1 %to &eligtotal;
		&&eligcode&k
		%end;
	%mend;

%mend;
