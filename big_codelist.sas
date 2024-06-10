%let filepath=\\fs\DataTeam\CI\HEDIS\Sasdata\2011\ndc files\Table AMM-D_OHG.xls;
%let sheet=Table AMM-D;
%let column=ndc_code;
%let name=depression_elig;
%let gvar=ndc;

%macro big_codelist(filepath=, sheet=, column=, name=, gvar=) ;
Data MVars ( Keep = Name ) ;
  Set SasHelp.VMacro ;
  Where Scope = 'GLOBAL' ;
Run ;

Data _Null_ ;
name="&name.";
  Call Symdel(name) ;
Run ;
	%macro testing;
	%if %substr(&sysscpl.,1,3) = X64 %then %do; *64-bit;
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

data _null_;
set in1."&sheet.$"n (keep=&column. obs=1);
length len $2.;
l=length(trim(&column.));
len=put(l, $2.);
length= "$" || cats(len) || "."; 
call symput('l', length);
run;

%put &L.;

data y;
set in1."&sheet.$"n (keep=&column.);
code=left(put(cats(&column), &l.));
m="'"||trim(code)||"'";
drop &column.;
run;

data _null_;
set y end=end;
file "\\fs\OHG\Data\Payer\&name..txt";
if _n_=1 then do;
put " if cats(&gvar.) in (";
end;
put m ',';
if end then do;
put m ') then do;';
end;
run;
%global &name.;

%let &name.=  "\\fs\OHG\Data\Payer\&name..txt";


%mend big_codelist;

/*options noxwait;*/
/*data _null_;*/
/* x "del F:\SASWORK\aisaacs\test.txt";*/
/*run;*/

