/*HEADER------------------------------------------------------------------------
|
| program:  vmine_tbl_rec_cnt.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Count number of records for datasource tables in latest file to create
|			DATAERROR flag for the update datasource inventory list on 
|			CHISQL.IntegrationDateSource
|
| logic:    
|
| input:  SAS claims dataset       
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 07JUN2011 - Winnie Lee - Clinical Integration 1.0.01
|
| 09AUG2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Replace with code below to only look at tables and not views
|
+-----------------------------------------------------------------------HEADER*/

%macro vmine_tbl_rec_cnt(like_statement=); 

/*	proc sql;*/
/*	connect to oledb(init_string=&ciedw. );*/
/*	create table tables_cimaster as select * from connection to oledb*/
/*	(	*/
/*	  select distinct table_name*/
/*	  from cimaster.information_schema.columns */
/*	);*/
/*	quit;*/		/*09AUG2011 - Winnie Lee - Replace with code below to only look at tables and not views*/

	proc sql;
	connect to oledb(init_string=&ciedw. );
	create table tables_cimaster as select * from connection to oledb
	(	
	  select table_name
	  from cimaster.information_schema.tables
	  where table_type = 'BASE TABLE'
	  order by table_name
	);
	quit;

	data tables_cimaster;
	 set tables_cimaster;
	 if index(upcase(table_name),upcase("&like_statement")) > 0;
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
		create table temp as select * from connection to oledb
		(	
		  select count(*) as cnt
		  from cimaster.dbo.&&prefix&tbl.&&suffix&tbl.
		  where kpracticeid = &practice_id.  
		);
		quit;

		proc sql noprint;
		  select cnt into: table&tbl.
		  from temp  ;  
		quit;
	%end;

	%do tbl = 1 %to &table_total. ;
		%put NOTE: &&prefix&tbl.&&suffix&tbl. - &&table&tbl records ;
	%end;

	data tblcnts;
	  %do z = 1 %to &table_total. ;
	    %if &z = 1 %then %do;
	      if &&table&z. in (.,0) then dataerrors = 1;
		%end;
		%else %do;
		  else if &&table&z. in (.,0) then dataerrors = 1;
		%end;
	  %end;
	  else dataerrors = 0; 
	run;

%mend vmine_tbl_rec_cnt;

