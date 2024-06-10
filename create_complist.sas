%let filepath=\\fs\ohg\Process\Measures\Coding Process\Table CDC-L_DCDC-P.xls;
%let sheet=Table CDC-L_DCDC-P;
%let column=ndc_code;

%macro create_complist(name=, filepath=, sheet=, column=);

	%macro testing;
	%if "&sysscpl."="X64_ESRV" or "&sysscpl."="X64_VSPRO" or 
	"&sysscpl."="X64_SRV08" %then %do; *64-bit;
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

	data compcodes;
	set in2."&sheet.$"n;
	run;

	proc sql;
	create table unique as
	select distinct &column.
		from compcodes;
		quit;

	data _null_;
		%global comptotal;
		set codes end=lastrec;
		if lastrec then do;
		call symput('comptotal',_n_);
		end;
	run;
	%put &comptotal;

	%macro assign_names;
		%do n=1 %to &comptotal;
		%global compcode&n;
		data _null_;
		set compcodes;
		if &n=_n_; /* keep only the nth data record */
		call symput("compcode&n", &column.);
		run;
		%end; /* end of the %do-loop 				*/
	%mend assign_names;

	%assign_names;

	%macro complist;
		%do k=1 %to &comptotal.;
		&&compcode&k
		%end;
	%mend;

%mend;
