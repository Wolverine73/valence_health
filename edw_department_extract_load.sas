
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_department_extract_load.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:                                 
|           
| INPUT:                                        
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|  
|
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 H04
|
|            
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS options for program                                               
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

%**let sysparm=%str(client_id=6 sas_mode=test);
%bpm_environment;


%macro edw_department_extract_load (dataout=, vmine_client_id=);

	*SASDOC--------------------------------------------------------------------------
	| Extract distinct department parent codes and names from vSource 
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
	connect to oledb(init_string=&vsource.);
	create table VSOURCE_DEPARTMENT_PARENT as select * from connection to oledb
	(	
		SELECT DISTINCT
			b.clientid 					as client_key,
			a.department_parent_code	as department_code,
			a.department_parent_name	as department_name
		FROM dbo.tblProviderGroups as a left outer join
			 dbo.tblProvider as b on a.ProviderID=b.ProviderID
		WHERE a.department_parent_code is not null and b.clientid = &client_id.
		ORDER BY a.department_parent_code
	);
	quit;  


	*SASDOC--------------------------------------------------------------------------
	| Extract department codes and names from CIEDW 
	|
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
		connect to oledb(init_string=&ciedw.);
		create table CIEDW_DEPARTMENT_PARENT as select * from connection to oledb
		(
			SELECT 
				client_key,
				department_code,
				department_name,
				department_parent_key
			FROM ciedw.dbo.department
			ORDER BY department_code
		);
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	*SASDOC--------------------------------------------------------------------------
	| Find any new department codes in CIEDW 
	|
	+------------------------------------------------------------------------SASDOC*; 
	data department_update_parent;
	merge VSOURCE_DEPARTMENT_PARENT (in=a)
		  CIEDW_DEPARTMENT_PARENT	(in=b keep=department_code);
	by department_code;
	if a and not b;
	run;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	proc sql noprint;
		select count(*) into: new_parent_code
		from department_update_parent
		;
	quit;

	%put NOTE: New parent code record count - &new_parent_code.;

	
	*SASDOC--------------------------------------------------------------------------
	| Insert any new department codes in CIEDW 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%if &new_parent_code. > 0 %then %do;
		proc sql;
			insert into ciedw.DEPARTMENT
				(
				CLIENT_KEY,
				DEPARTMENT_CODE,
				DEPARTMENT_NAME
				)
			select
				CLIENT_KEY,
				DEPARTMENT_CODE,
				DEPARTMENT_NAME
			from department_update_parent;
		quit;

		%set_error_flag;
	  	%on_error(ACTION=ABORT);
	%end;


	*SASDOC-----------------------------------------------------------------------------------
	| Extract parent department codes with relation to the child department codes from vSource 
	+----------------------------------------------------------------------------------SASDOC*; 
	proc sql;
	connect to oledb(init_string=&vsource.);
	create table VSOURCE_DEPARTMENT as select * from connection to oledb
	(	
		SELECT DISTINCT
			b.clientid as client_key,
			a.department_code,
			a.department_name,
			a.department_parent_code
		FROM dbo.tblProviderGroups as a left outer join
			 dbo.tblProvider as b on a.ProviderID=b.ProviderID
		WHERE a.department_parent_code is not null and b.clientid = &client_id.
		ORDER BY a.department_parent_code
	);
	quit;


	*SASDOC--------------------------------------------------------------------------
	| Extract department codes and names from CIEDW 
	|
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
		connect to oledb(init_string=&ciedw.);
		create table CIEDW_DEPARTMENT as select * from connection to oledb
		(
			SELECT 
				department_key,
				client_key,
				department_code
			FROM ciedw.dbo.department
			ORDER BY department_code
		);
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	proc sql;
		create table department_parent_update_2 as
		(
			select distinct
				a.client_key,
				a.department_code,
				a.department_name,
				b.department_key as department_parent_key
			from vsource_department	 as a left outer join
				 ciedw_department	 as b on a.department_parent_code=b.department_code and
				 								 a.client_key=b.client_key
		) order by department_code, department_key;
	quit;

	proc sql;
		connect to oledb(init_string=&ciedw.);
		create table CIEDW_DEPARTMENT as select * from connection to oledb
		(
			SELECT 
				client_key,
				department_code,
				department_name,
				department_parent_key
			FROM ciedw.dbo.department
			ORDER BY department_code, department_parent_key
		);
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	data department_update;
	merge department_parent_update_2 (in=a)
		  CIEDW_DEPARTMENT	(in=b keep=department_code department_parent_key);
	by department_code department_parent_key;
	if a and not b;
	run;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	proc sql noprint;
		select count(*) into: new_department_code
		from department_update
		;
	quit;

	%put NOTE: New parent code record count - &new_department_code.;

	
	*SASDOC--------------------------------------------------------------------------
	| Insert any new department codes in CIEDW 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%if &new_department_code. > 0 %then %do;
		proc sql;
			insert into ciedw.DEPARTMENT
				(
				CLIENT_KEY,
				DEPARTMENT_CODE,
				DEPARTMENT_NAME,
				DEPARTMENT_PARENT_KEY
				)
			select
				CLIENT_KEY,
				DEPARTMENT_CODE,
				DEPARTMENT_NAME,
				DEPARTMENT_PARENT_KEY
			from department_update;
		quit;

		%set_error_flag;
	  	%on_error(ACTION=ABORT);
	%end;

%mend edw_department_extract_load;
