/* This macro will bulkload a SAS dataset to SQL Server table in CIO. If you do not specify a destination  
	table, it will bulkload to a temporary unique CIHold table in SQLCIDEV.

   The macro will generate a temporary XML format, then write the dataset to a TXT file, and bulkload the
	TXT file to CIO using the XML format. Both the XML format and TXT file will be tagged with the 
	workflow id supplied to the macro in order to make sure the files are unique and we do not accidentally 
	overwrite files from other jobs.

   Data formats currently handled by this macro only include the following:
	Alphanumeric: VARCHAR/CHAR
	Numeric		: INT/BIGINT, (2) DECIMALS/NUMERIC, DATE, DATETIME.
	If you have a field type not in the above, then the macro will bomb. Special numeric missing values 
		such as .A, .N etc needs to be reset to . in order for bulkload to work. 
	Also please note that if you have decimals variables, it's imperative that you format those variables
		with xx.2. Otherwise, you might lose precision on some of the big numbers.

   Warning: If you do not specify a destination table, a temp table in CIHold will be created for you. 
	Please clean up after yourself when you are done using that temporary table. You can execute the 
	following SQL statement at the end of your program to delete the temporary table CIHold.
		proc sql;
			execute (	drop table cihold.dbo.saswrk_bulkload_&m_wflow.
					)
			by oledb;
		quit;

	Required positional macro parameters:
	1. m_wflow - 		If &wflow_exec_id does not exist and you cannot pass this value to the macro, I
							recommend using your name string so that it is unique.

	2. m_inputset - 	Input SAS dataset to be bulkloaded. A SAS view won't work.

	Optional macro parameters:
	1. m_desttable - 	Destination table where you want your data to be bulkloaded (eg. ciedw.dbo.member).
							ciedw.dbo is the SQL catalog name. If your table is at ciedw_bl_test.dbo, then 
							specify the catalog name accordingly. Also make sure that the variable names, 
							type, and length are appropriately matching between your SAS dataset and the 
							SQL destination table.

	2. m_keepvar - 		List of variables to be bulkloaded.
						If you specify m_keepvar, then it means you only want to bulkload those variables. 
						If you do not specify m_keepvar, then by default all variables will be bulkloaded.

	3. m_dropvar - 		List of variables to be dropped, and will not be bulkloaded.
						If you specify m_dropvar, then it means you do not want to bulkload those variables. 
						If you do not specify m_dropvar, then by default no variables will be dropped.
						If variable is in both keepvar and dropvar, keepvar wins.

	4. m_isdate - 		List of variables that are DATE fields.
						If you specify m_isdate, those fields will be treated as date field. Otherwise,
							the program will rely on format to differentiate numeric vs date.

	5. m_isdatetime - 	List of variables that are DATETIME fields.
						If you specify m_isdate, those fields will be treated as datetime field. Otherwise,
							the program will rely on format to differentiate numeric vs datetime.

	6. m_isdecimal - 	List of variables that have decimals.
						If you specify m_isdecimal, those fields will be treated as numeric field with
							decimals. Otherwise, the macro will default to bigint, and you'll lose precision.
							The program will also attempt to look at the format to see if it has decimals,
							but don't bank on that, coz sometimes the format is not specified.

	7. m_delimiter -	Specify the delimiter for the txt file that SAS is writing to, for bulkload use later.
							Default is pipe. If you know your data has pipe in it, then obviously you do not 
							want to use pipe.

	8. m_keepidentity -	Keep identity for the SQL table. This should ONLY be used if we are fixing things in
							the SQL table, and want to keep the surrogate keys intact.
							Default is off.

	9. m_truncate -		Allow truncation if SQL table has too short of a character field. 
							Default is off, i.e. do not allow truncation, and return error.

	To call, 
		%bulkload_to_cio(GLIU,work.loaddata,m_desttable=ciedw.dbo.member);
		%bulkload_to_cio(GLIU,work.loaddata,m_isdate=dob,m_isdatetime=created_on);
		%bulkload_to_cio(GLIU,work.loaddata,m_keepvar=fname lname sex dob);
		%bulkload_to_cio(GLIU,work.loaddata,m_dropvar=updated_on updated_by,m_isdatetime=created_on updated_on);

*/
%macro bulkload_to_cio(m_wflow,m_inputset,m_desttable=,m_keepvar=,m_dropvar=,m_isdate=,m_isdatetime=,m_isdecimal=,m_delimiter=|,m_keepidentity=0,m_truncate=0);
  %IF %sysfunc(exist(&m_inputset)) %THEN %DO;
	%let m_wflow=%upcase(%sysfunc(compress(&m_wflow.)));
	%if %str(&m_keepvar.) ne %then %do; %let m_keepvar=%upcase(%sysfunc(compbl(&m_keepvar.))); %end;
	%if %str(&m_dropvar.) ne %then %do; %let m_dropvar=%upcase(%sysfunc(compbl(&m_dropvar.))); %end;
	%if %str(&m_isdate.) ne %then %do; %let m_isdate=%upcase(%sysfunc(compbl(&m_isdate))); %end;
	%if %str(&m_isdatetime.) ne %then %do; %let m_isdatetime=%upcase(%sysfunc(compbl(&m_isdatetime))); %end;
	%if %str(&m_isdecimal.) ne %then %do; %let m_isdecimal=%upcase(%sysfunc(compbl(&m_isdecimal))); %end;
	%if %symexist(sql_dir) %then %do; 
		%let m_sql_dir=&sql_dir.;
	%end;
	%else %do;
		%let m_sql_dir=\\sqlcidev\temp;
	%end;
	%if %symexist(sqlci) %then %do;
		%let m_sqlci=&sqlci.;
	%end;
	%else %do;
		%let m_sqlci=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;");
		libname cihold oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=CIHold;" insertbuff=10000 readbuff=10000;
	%end;

	options nosymbolgen;
	data m_bulkload_variables(drop=dsid num rc i);
		length name $32 type $1 format blvarformat blvartype sqlvartype $15;
		dsid=open("&m_inputset.","i");
		num=attrn(dsid,"nvars");
		do i=1 to num;
			name=upcase(varname(dsid,i));
			format=varfmt(dsid,i);
			type=vartype(dsid,i);
			length=varlen(dsid,i);
			if type='C' then do; blvartype='SQLVARYCHAR'; sqlvartype='varchar'; end;
			else if type='N' then do;
					 if index(" &m_isdatetime ",' '||trim(name)||' ') or 
						index(format,'DATETIME') 										 then do; blvartype='SQLDATETIME'; sqlvartype='datetime'; end;
				else if	index(" &m_isdate ",' '||trim(name)||' ') or 
						index(format,'DATE') or 
						index(format,'MM') and index(format,'DD') and index(format,'YY') then do; blvartype='SQLDATE'; sqlvartype='date'; end;
				else if index(" &m_isdecimal ",' '||trim(name)||' ') or 
						index(format,'PERCENT') or 
						scan(format,2,'.') ne ''  										 then do; blvartype='SQLMONEY'; sqlvartype='decimal'; end;
				else do; blvartype='SQLBIGINT'; sqlvartype='bigint'; end;
			end;
			
			if format='' then do;
				if sqlvartype='varchar' then blvarformat='$'||cats(length)||'.';
				else if sqlvartype='decimal' then blvarformat=cats(length*2+2)||'.2';
				else if sqlvartype='bigint' then blvarformat=cats(length*2)||'.';
				else blvarformat='';
			end;
			else if index(format,'DOLLAR') then do;
				blvarformat=left(tranwrd(format,'DOLLAR',''));
				format=blvarformat;
			end;
			else blvarformat='';

				 if "&m_keepvar." eq "" and "&m_dropvar." eq "" then output;
			else if "&m_keepvar." ne "" and "&m_dropvar." eq "" then do;
				if index(" &m_keepvar. ",' '||trim(name)||' ') then output;
			end;
			else if "&m_keepvar." eq "" and "&m_dropvar." ne "" then do;
				if index(" &m_dropvar. ",' '||trim(name)||' ')=0 then output;
			end;
			else do;
				if index(" &m_keepvar. ",' '||trim(name)||' ') then output;
			end;
		end;
		rc=close(dsid);
	run;
	data _null_;
		set m_bulkload_variables end=lstobs;
		if blvartype in ('SQLDATE','SQLDATETIME') then datetime_exist+1;
		call symput('m_bl_varname'||cats(_n_),trim(name));
		call symput('m_bl_vartype'||cats(_n_),trim(blvartype));
		call symput('m_bl_varformat'||cats(_n_),trim(blvarformat));
		call symput('m_sql_varname'||cats(_n_),'['||cats(name)||']');
		call symput('m_sql_vartype'||cats(_n_),'['||cats(sqlvartype)||']');
		if sqlvartype in ('int','bigint','date','datetime') then call symput('m_sql_varlen'||cats(_n_),' ');
		else if sqlvartype in ('decimal') then do;
			if format ne '' then call symput('m_sql_varlen'||cats(_n_),'('||cats(tranwrd(format,'.',','))||')');
			else do; dlength=length*2+2; call symput('m_sql_varlen'||cats(_n_),'('||cats(dlength)||',2)'); end;
		end;
		else call symput('m_sql_varlen'||cats(_n_),'('||cats(length)||')');
		if lstobs then do;
			call symput('m_numofvar',cats(_n_));
			call symput('m_numofvar_datetime',cats(datetime_exist));
			call symput('m_bl_txtfile',"'&m_sql_dir.\bulkload_&m_wflow..txt'");
			call symput('m_bl_xmlfile',"'&m_sql_dir.\bulkload_format_&m_wflow..xml'");
			call symput('m_del_txtfile',"&m_sql_dir.\bulkload_&m_wflow..txt");
			call symput('m_del_xmlfile',"&m_sql_dir.\bulkload_format_&m_wflow..xml");
		end;
	run;

	%if &m_numofvar. gt 0 %then %do;
		data _null_;
			file &m_bl_xmlfile.;
			put '<?xml version="1.0"?>';
			put '<BCPFORMAT xmlns="http://schemas.microsoft.com/sqlserver/2004/bulkload/format" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">';
			put '<RECORD>';
		  %do i=1 %to &m_numofvar.;	  	
		  	%if &i.=&m_numofvar. %then %do;
				put '<FIELD ID="' "&i" '" xsi:type="CharTerm" TERMINATOR="\r\n" MAX_LENGTH="999999999"/>';
			%end;
			%else %do;
				put '<FIELD ID="' "&i" '" xsi:type="CharTerm" TERMINATOR="|" MAX_LENGTH="999999999"/>';
			%end;
		  %end;
			put '</RECORD>';
			put '<ROW>';
		  %do i=1 %to &m_numofvar.;
			put '<COLUMN SOURCE="' "&i" '" NAME="' "&&m_bl_varname&i" '" xsi:type="' "&&m_bl_vartype&i" '"/>';
		  %end;
			put '</ROW>';
			put '</BCPFORMAT>';
		run;

		options missing='';
		data _null_;
			file &m_bl_txtfile. delimiter="&m_delimiter." lrecl=32767; 
			set &m_inputset.(%if &m_numofvar_datetime. %then %do;
								rename=(%do i=1 %to &m_numofvar.;
											%if &&m_bl_vartype&i=SQLDATE or &&m_bl_vartype&i=SQLDATETIME %then %do;
												&&m_bl_varname&i=m_org_var&i
											%end;
										%end;
										)
							 %end;
							);
			%do i=1 %to &m_numofvar.;
				%if &&m_bl_vartype&i=SQLDATE %then %do;
					if m_org_var&i ne . then &&m_bl_varname&i=put(m_org_var&i,yymmdd10.);
				%end;
				%else %if &&m_bl_vartype&i=SQLDATETIME %then %do;
					if m_org_var&i ne . then &&m_bl_varname&i=put(datepart(m_org_var&i),yymmdd10.)||' '||put(timepart(m_org_var&i),time8.);
				%end;
				%else %if %str(&&m_bl_varformat&i) ne %then %do;
					format &&m_bl_varname&i &&m_bl_varformat&i;
				%end;
			%end;
			zzlinezz=%do i=1 %to &m_numofvar.; 
						%if &i. ge 2 %then %do;
							||"&m_delimiter."||
						%end;
						cats(&&m_bl_varname&i) 
					 %end; ;
			put zzlinezz;
		run;
		options missing=.;

		%if %str(&m_desttable.) ne %then %do; /* destination table specified */
			proc sql;
				connect to oledb(init_string=&m_sqlci.);
				execute ( 	%if &m_truncate. %then %do; set ansi_warnings off %end;
							declare @interrorcode int
							begin tran
							insert into &m_desttable.
							%if &m_keepidentity. %then %do; with (keepidentity) %end;
								(	%do i=1 %to &m_numofvar.;
										&&m_sql_varname&i %if &i. ne &m_numofvar. %then , ;
									%end;
								)
							select 	%do i=1 %to &m_numofvar.;
										&&m_sql_varname&i %if &i. ne &m_numofvar. %then , ;
									%end;
							from 	openrowset(	bulk &m_bl_txtfile., 
												formatfile=&m_bl_xmlfile.,
												rows_per_batch = 1000
											  ) as n; 
							if (@interrorcode <> 0) begin
								rollback tran
							end
							commit tran
						) 
				by oledb;
			quit;
		%end; /* destination table specified */
		%else %do; /* destination table does not exist */
			%if %sysfunc(exist(cihold.saswrk_bulkload_&m_wflow.)) %then %do;
				proc sql;
					connect to oledb(init_string=&m_sqlci.);
					execute (	drop table cihold.dbo.saswrk_bulkload_&m_wflow.
							)
					by oledb;
				quit;
			%end;

			proc sql;
				connect to oledb(init_string=&m_sqlci.);
				execute (	create table cihold.dbo.saswrk_bulkload_&m_wflow.
							(	%do i=1 %to &m_numofvar.;
									&&m_sql_varname&i &&m_sql_vartype&i &&m_sql_varlen&i null %if &i. ne &m_numofvar. %then , ;
								%end;
							)
						)
				by oledb;

				execute ( 	%if &m_truncate. %then %do; set ansi_warnings off %end;
							declare @interrorcode int
							begin tran
							insert into cihold.dbo.saswrk_bulkload_&m_wflow.
							%if &m_keepidentity. %then %do; with (keepidentity) %end;
							select 	*
							from 	openrowset(	bulk &m_bl_txtfile., 
												formatfile=&m_bl_xmlfile.,
												rows_per_batch = 1000
											  ) as n; 
							if (@interrorcode <> 0) begin
								rollback tran
							end
							commit tran
						) 
				by oledb;
			quit;
		%end; /* destination table does not exist */

		%global err_fl;
		%if &syserr. gt 6 %then %do;
			%let err_fl=1;
		%end;
		%else %do;
			%let err_fl=0;
		%end;

		%if &err_fl.=0 %then %do;
			options noxwait;
			data _null_;
				x "del &m_del_txtfile.";
				x "del &m_del_xmlfile.";
			run;
		%end;
	%end;
	%else %do;
		%put ERROR: There are no variables to bulkload.;
	%end;

	proc datasets lib=work nolist;
		delete m_bulkload_variables;
	quit;
  %END;
  %ELSE %DO;
	%put ERROR: The dataset needed for bulkload DOES NOT EXIST!;
  %END;
%mend bulkload_to_cio;
