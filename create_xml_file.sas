%macro create_xml_file(outfile=, indata=, additional_var=);

	proc sql noprint;
	select count(*)+2 into: xmlcount
	from &indata.;
	quit;

	%put &xmlcount.;

	data end;
	name="&additional_var.";
	varnum=&xmlcount;
	format='';
	run;

	proc sort data = &indata.;
	  by varnum;
	run;

	data temp_xml;
	set &indata.;
	varnum=varnum+1;
	run;

	data temp_xml;
	format sqlformat $30. ;
	set temp_xml end;
	if format='' and upcase(NAME) in ('UNITS','MARKET_VALUE','SUBMITTED') then sqlformat='SQLMONEY';
	else if upcase(NAME) in ('STATEMENT_BEGIN_DATE','STATEMENT_END_DATE') then sqlformat='SQLDATE';
	else if format='' then sqlformat='SQLBIGINT';
	else if format='$' then sqlformat='SQLVARYCHAR';
	else if format='DATETIME' then sqlformat='SQLDATETIME';
	else sqlformat='SQLBIGINT';
	run;

	data temp_xml;
		set temp_xml ;
		i+1;
		ii=left(put(i,4.));
		vnum=left(put(varnum,4.));
		call symput('name'||ii,trim(name));
		call symput('format'||ii,trim(sqlformat));
		call symput('varnum'||ii,trim(vnum));
		call symput('xmltotal',trim(ii));
	run;

	data _null_; 
		file "&sql_dir.\&outfile."; lrecl=1000 ;
		put
			'<?xml version="1.0"?>'/
			'<BCPFORMAT xmlns="http://schemas.microsoft.com/sqlserver/2004/bulkload/format" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'/
			'<RECORD>'/
			' '/
			%do i = 1 %to &xmltotal. ;
				%if &i = &xmltotal. %then %do;
				'<FIELD ID="'"&&varnum&i"'" xsi:type="CharTerm" TERMINATOR="\r\n" MAX_LENGTH="999999999"/> '
				%end;
				%else %do;
				'<FIELD ID="'"&&varnum&i"'" xsi:type="CharTerm" TERMINATOR="|" MAX_LENGTH="999999999"/> '/
				%end;
			%end;;
			put '</RECORD>';
			put '<ROW>';
			%do j=1 %to &xmltotal.;
				put '<COLUMN SOURCE="' "&&varnum&j" '" NAME="' "&&name&j" '" xsi:type="' "&&format&j" '"/>';
			%end;
		put '</ROW>';
		put '</BCPFORMAT>';
	run;

%mend create_xml_file;
