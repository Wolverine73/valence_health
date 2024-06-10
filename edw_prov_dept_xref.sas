
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_prov_dept_xref.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE: To load CIEDW.dbo.PROVIDER_DEPARTMENT_XREF                                 
|           
| INPUT: vSource.dbo.tblProviderGroups                                        
|
| OUTPUT: CIEDW.dbo.PROVIDER_DEPARTMENT_XREF                          
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|  
|
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 H04
|   
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

%**let sysparm=%str(client_id=6 sas_mode=test); 
%bpm_environment;


%macro edw_prov_dept_xref ();

		proc sql;
		  connect to oledb(init_string=&ciedw.);
		  create table ciedw_provider_key as select * from connection to oledb
		  (
				select distinct
					client_key,
					provider_key,
					vsource_provider_key
				from dbo.Provider
				where client_key = &client_id. and vsource_provider_key is not null
				order by provider_key
		  );
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
		  connect to oledb(init_string=&vsource.);
		  create table vsource_prov_dept as select * from connection to oledb
		  (
				select
					ProviderID								as vsource_provider_key,
					Department_Code,
					Department_Parent_Code,
					case when IsPrimary is not null then isPrimary
						 else 0							end	as is_primary
				from dbo.tblProviderGroups
				where department_code is not null
				order by providerid, department_code
		  );
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc summary data=vsource_prov_dept nway missing;
		class vsource_provider_key;
		var is_primary;
		output out=vsource_prov_dept_isprimary (drop=_type_ _freq_ rename=is_primary=have_primary) sum=;
		run;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
			create table vsource_prov_dept_2 as
				select
					a.*,
					b.have_primary
				from vsource_prov_dept as a left outer join
					 vsource_prov_dept_isprimary as b on a.vsource_provider_key=b.vsource_provider_key
				order by vsource_provider_key, department_code
			;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		data vsource_prov_dept_3;
		set vsource_prov_dept_2;
		by vsource_provider_key;
		if first.vsource_provider_key and have_primary = 0 then is_primary = 1;
		run;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
		  connect to oledb(init_string=&ciedw.);
		  create table ciedw_department_key as select * from connection to oledb
		  (
				select 
			  		a.client_key,
					a.department_key,
					a.department_code,
					b.department_code as department_parent_code
				from dbo.department as a left outer join
					 dbo.department as b on a.department_parent_key=b.department_key
				where a.client_key = &client_id.
				order by a.client_key, a.department_code, b.department_code
		  );
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
		create table provider_department_xref as
			select 
				a.client_key,
				a.provider_key,
				c.department_key,
				b.is_primary
			from ciedw_provider_key 	as a inner join
				 vsource_prov_dept_3 	as b on a.vsource_provider_key=b.vsource_provider_key left outer join
				 ciedw_department_key 	as c on a.client_key=c.client_key and 
												b.department_code=c.department_code and 
												b.department_parent_code=c.department_parent_code
			order by provider_key
			;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
			delete *
			from ciedw.provider_department_xref
			where client_key=&client_id. and provider_key > 0;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
		  insert into ciedw.provider_department_xref
			(
				client_key,
				provider_key,
				department_key,
				is_primary
			)
		  select 
		  		client_key,
				provider_key,
				department_key,
				is_primary
		  from provider_department_xref;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

%mend edw_prov_dept_xref;
