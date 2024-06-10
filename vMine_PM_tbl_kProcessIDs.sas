/*HEADER------------------------------------------------------------------------
|
| program:  vmine_PM_tbl_kProcessIDs.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Return distinct kProcessIDs from specified PM System tables from CIMaster
|
| logic:    
|
| input:  SQL tables       
|                        
| output: SAS work dataset   
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 23AUG2011 - Winnie Lee - Clinical Integration 1.0.01
|
|
+-----------------------------------------------------------------------HEADER*/

%macro vMine_PM_tbl_kprocessIDs (like_statement=);

/*	%bpm_environment(); */

	%if "&system." = "AmericanMedicalSoftware" %then %do;
		%let system = AMS;
	%end;

	proc sql;
	connect to oledb(init_string=&ciedw. );
	create table tables_cimaster as select * from connection to oledb
	(	
	  select table_name
	  from cimaster.information_schema.tables
	  where table_type = 'BASE TABLE' and SUBSTRING(UPPER(table_name),1,4) not in ('KTBL','SQLT')
	  order by table_name
	);
	quit;

	data tables_cimaster;
	 set tables_cimaster;
	 if index(upcase(table_name),upcase("&system.")) > 0;
	run;

	%let table_total=0; 

	data null_;
	  set tables_cimaster  end=eof;
	  prefix=substr(table_name,1,32);
	  suffix=substr(table_name,33,64);
	  i+1;
	  ii=left(put(i,4.));
	  call symput('prefix'||ii,trim(prefix)); 
	  call symput('suffix'||ii,trim(suffix)); 
	  if eof then call symput('table_total',ii);
	run;

	%do tbl = 1 %to &table_total. ;
		proc sql;
		connect to oledb(init_string=&ciedw. );
		create table table&tbl. as select * from connection to oledb
		(	
			select distinct 
				kClientID as ClientID,
				kPracticeID as DatasourceID,
				kProcessID
			from cimaster.dbo.&&prefix&tbl.&&suffix&tbl.
		);
		quit;
	%end;

	data sql_kProcessIDs;
	set
		%do tbl = 1 %to &table_total.;
			table&tbl.
		%end;
	;
	run;

	proc sort data=sql_kProcessIDs nodup;
	by ClientID DataSourceID kProcessID;
	run;

	proc datasets library=work;
	delete 
	%do tbl=1 %to &table_total.;
		table&tbl.
	%end;
	;
	run;
	quit;

	%if "&system." = "AMS" %then %do;
		%let system = AmericanMedicalSoftware;
	%end;

%mend vMine_PM_tbl_kProcessIDs;



