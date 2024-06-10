
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_provider_extract.sas
|
| LOCATION: M:\CI\programs\EDW 
|
| PURPOSE:                                 
|           
| INPUT:                                        
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  01DEC2010 - Winnie Lee - Original
|     
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 H04 M03
| 
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
/*%let sysparm=%str(sk_prcs_ctrl_id=10026 wflow_exec_id=48865 sas_prgm_id=1 client_id=6 sas_mode=test); */


%bpm_environment;


%macro edw_provider_extract(dataout=, vmine_client_id=);

  *SASDOC--------------------------------------------------------------------------
  | BPM - Reset the process control tables to start.   
  | 
  +------------------------------------------------------------------------SASDOC*; 
  %bpm_process_control(timevar=START);


  *SASDOC--------------------------------------------------------------------------
  | CIHOLD - Make sure there are no records in the HOLD_PROVIDER table   
  | 
  +------------------------------------------------------------------------SASDOC*;
	proc sql;
		delete *
		from cihold.hold_provider
		where client_key in (&client_id.,-&client_id.);
	quit;


  *SASDOC--------------------------------------------------------------------------
  | CIEDW - Make sure the SPECIALTY table is up to date
  | 
  +------------------------------------------------------------------------SASDOC*;
	proc sql;
		connect to oledb(init_string=&vSource.);
	  	create table dw_specialty as select * from connection to oledb
		(	
			select 
				provspec					as specialty_code,
				provspecdesc				as specialty_description,
				getdate()	as created_on,
				'BPM - SAS'					as created_by,
				getdate()	as updated_on,
				'BPM - SAS'					as updated_by
			from dbo.vDWProvSpec
			order by provspec
		);
	quit;

	proc sql;
		connect to oledb(init_string=&ciedw.);
		create table dw_specialty_edw as select * from connection to oledb
		(
			select 
				SPECIALTY_CODE,
				SPECIALTY_DESCRIPTION,
				CREATED_ON,
				CREATED_BY,
				UPDATED_ON,
				UPDATED_BY
			from CIEDW.dbo.SPECIALTY
			order by SPECIALTY_CODE
		);
	quit;

	data dw_specialty_update;
	merge dw_specialty 		(in=a)
		  dw_specialty_edw 	(in=b keep=specialty_code);
	by specialty_code;
	if a and not b;
	run;

	proc sql;
		insert into ciedw.SPECIALTY
			(
			SPECIALTY_CODE,
			SPECIALTY_DESCRIPTION,
			CREATED_ON,
			CREATED_BY,
			UPDATED_ON,
			UPDATED_BY 			
			)
		select
			SPECIALTY_CODE,
			SPECIALTY_DESCRIPTION,
			CREATED_ON,
			CREATED_BY,
			UPDATED_ON,
			UPDATED_BY
		from dw_specialty_update;
	quit;


  *SASDOC--------------------------------------------------------------------------
  | CIEDW - Make sure the DEPARTMENT table is up to date
  | 
  +------------------------------------------------------------------------SASDOC*;
	%edw_department_extract_load;


  *SASDOC--------------------------------------------------------------------------
  | EDW - Extract provider data from the vSource database 
  |
  +------------------------------------------------------------------------SASDOC*;

  proc sql;
    connect to oledb(init_string=&vsource.);
    create table vsource_provider as select * from connection to oledb
	(	
	with sp as
		(
		select distinct
			 sp.[providerid]
			,sp.[s-specialtyid]
			,sp.[s-primary]
		from [dbo].[tblspecialty] as sp
		where sp.[s-primary] = 1
		)

	,sp2 as
		(
		select 
			 sp2.[providerid]
			,count(sp2.[s-primary]) as specialty_primary_count
		from [dbo].[tblspecialty] as sp2
		where sp2.[s-primary] = 1
		group by sp2.[providerid]
		)

	,group_cipar as
		(
		SELECT
			*
		FROM
			(
			SELECT
				A.*,
				ROW_NUMBER() OVER (	
									PARTITION BY 	[ProviderID] 
									ORDER BY		[ProviderID], [GroupID] DESC
								   ) AS [ProvGrpsOrder]
			FROM
				(
				SELECT distinct
					     p.[ProviderID]
					    ,pg.[GroupID]
						,g.[GroupName]
						,g.[G-CIPar]
						,g.[G-CIEffdt]
						,g.[G-TermDt]
				FROM	[dbo].[tblProvider]		  as p 										left outer join
						[dbo].[tblProviderGroups] as pg on p.[ProviderID]=pg.[ProviderID] 	left outer join
						[dbo].[tblGroups]		  as g 	on pg.[GroupID]=g.[GroupID]
				where p.[ClientID] in (&client_id.,-&client_id.) and p.[P-CIPar] = 1 and pg.[TermDt] is null and g.[G-CITermDt] is null and g.[G-CIPar] = 1
				) as A
			) as B where B.ProvGrpsOrder = 1
		)

  	select distinct
		pr.[providerid]                                 													as vsource_provider_key, 
		pr.[clientid]																						as client_key,
		case when pr.[p-lastname] is not null and pr.[p-firstname] is not null then 
				  upper(convert(char(50), ltrim(rtrim(pr.[p-lastname])) + ', ' + ltrim(rtrim(pr.[p-firstname]))))    								
			 when pr.[p-lastname] is not null and pr.[p-firstname] is null then
				  upper(convert(char(50), ltrim(rtrim(pr.[p-lastname]))))
			 when pr.[p-lastname] is null and pr.[p-firstname] is not null then
			 	  upper(convert(char(50), ltrim(rtrim(pr.[p-firstname]))))
			 when pr.[p-lastname] is null and pr.[p-firstname] is null then ''
			 else ''																					end	as provider_name,
		upper(ltrim(rtrim(pr.[p-title])))               													as provider_title,
		case when pr.[p-cipar] = 1 then 'PAR'										
			 when pr.[p-cipar] = 2 then 'NONPAR'
			 else 'UNKNOWN'																				end	as ci_status,
		ns.networkstatus																					as network_status,
		pr.[p-cieffdt]                    																	as clncl_int_eff_dt,
		pr.[p-citermdt]                   																	as clncl_int_exp_dt, 
		case when pr.[p-networkstatus] = 5 then pr.[p-effectivedate] 		 							end as network_eff_dt,
		case when pr.[p-networkstatus] = 8 then pr.[p-effectivedate] 		 							end as network_exp_dt,
		pr.[p-deanumber]                  																	as dea, 
		convert(char(10),pr.[p-npi])      																	as npi1,
		sp.[s-specialtyid]																					as specialty_code,
		sp.[s-primary]																						as specialty_primary,
		sp2.[specialty_primary_count]																		as specialty_primary_count,
		group_cipar.[g-cipar]																				as tied_to_group,
		group_cipar.[groupid]																				as groupid,
/*		--case when pd.[realcategory] in ('vMine','PGF') then pd.[realcategory]							end as data_cmplt_ind,*/
		'Y'																									as data_cmplt_ind,
/*		--case when pd.[realcategory] = ('Manual') then 'Y'												end as manual_rpt_ind,*/
		'Y'																									as manual_rpt_ind,
		0                               																	as validation_id,
		&wflow_exec_id.                                	 													as wflow_exec_id,
		NULL																								as sas_prov_id,
		case when is_attributable is null then is_attributable
			 when is_attributable = 0 then 0			 
			 else 1																						end as is_attributable,
		1																									as is_vsource_data
	from  [dbo].[tblprovider]					as pr 									   		left outer join
		  sp									on pr.[providerid] = sp.[providerid] 			left outer join
		  sp2									on sp.[providerid] = sp2.[providerid]			left outer join
		  group_cipar							on pr.[ProviderID] = group_cipar.[ProviderID]	left outer join
		  [dbo].[vAllClientsCIProgressDetailed] as pd on pr.[providerid] = pd.[providerid] 		left outer join
		  [dbo].[dtblNetworkStatus]				as ns on pr.[p-networkstatus] = ns.[networkstatusid]
	where pr.[clientid] in (&client_id., -&client_id.) 
	order by pr.[providerid]
    );
  quit;
 
  %set_error_flag;
  %on_error(ACTION=ABORT);

  proc sort data = vsource_provider nodupkey ; 
  by vsource_provider_key; 
  run;


  *SASDOC--------------------------------------------------------------------------
  | EDW - Create source and edw variables for data staging tables 
  |
  +------------------------------------------------------------------------SASDOC*;

  %edw_create_source_variables(in_dataset1=VSOURCE_PROVIDER);

  *SASDOC--------------------------------------------------------------------------
  | EDW - Provider cleansing rules for the CI program 
  |
  +------------------------------------------------------------------------SASDOC*; 
  %edw_provider_cleansing_rules(in_dataset1=VSOURCE_PROVIDER);
  %set_error_flag;
  %on_error(ACTION=ABORT);


  *SASDOC--------------------------------------------------------------------------
  | EDW - Perform provider validations on the data and set the prevent load indicator     
  |  1.  validations - provider new
  |  2.  validations - provider terms
  |  3.  validations - provider change
  |  4.  validations - provider critical
  |
  +------------------------------------------------------------------------SASDOC*; 
  %edw_provider_validations(vt_name=NEW ,  	 	     	validation_type_id=1, in_dataset1=VSOURCE_PROVIDER,in_dataset2=ciedw.PROVIDER  ,newval=a.provider_name,by_variable=NPI1,				by_variable2=VSOURCE_PROVIDER_KEY);
  %edw_provider_validations(vt_name=NEW_FACILITY ,   	validation_type_id=76,in_dataset1=VSOURCE_PROVIDER,in_dataset2=ciedw.PROVIDER  ,newval=a.provider_name,by_variable=VSOURCE_PROVIDER_KEY,by_variable2=NPI1);
  %edw_provider_validations(vt_name=TERM,  	 	     	validation_type_id=2, in_dataset1=ciedw.PROVIDER  ,in_dataset2=VSOURCE_PROVIDER,oldval=a.provider_name,by_variable=NPI1,				by_variable2=VSOURCE_PROVIDER_KEY);
  %edw_provider_validations(vt_name=TERM_FACILITY,   	validation_type_id=77,in_dataset1=ciedw.PROVIDER  ,in_dataset2=VSOURCE_PROVIDER,oldval=a.provider_name,by_variable=VSOURCE_PROVIDER_KEY,by_variable2=NPI1);
  %edw_provider_validations(vt_name=CHANGE,			 	validation_type_id=3, in_dataset1=VSOURCE_PROVIDER,in_dataset2=ciedw.PROVIDER  ,newval=				  ,by_variable=NPI1,				by_variable2=VSOURCE_PROVIDER_KEY);
  %edw_provider_validations(vt_name=CHANGE_FACILITY, 	validation_type_id=78,in_dataset1=VSOURCE_PROVIDER,in_dataset2=ciedw.PROVIDER  ,newval=				  ,by_variable=VSOURCE_PROVIDER_KEY,by_variable2=NPI1);
  %edw_provider_validations(vt_name=CRITICAL,			validation_type_id=., in_dataset1=VSOURCE_PROVIDER,in_dataset2= 			   ,newval=				  ,by_variable=NPI1,				by_variable2=VSOURCE_PROVIDER_KEY);
  %edw_provider_validations(vt_name=CRITICAL_FACILITY, 	validation_type_id=., in_dataset1=VSOURCE_PROVIDER,in_dataset2= 			   ,newval=				  ,by_variable=VSOURCE_PROVIDER_KEY,by_variable2=NPI1);
  %set_error_flag;
  %on_error(ACTION=ABORT);


  *SASDOC--------------------------------------------------------------------------
  | BPM - Insert provider data into edw.validations    
  |
  +------------------------------------------------------------------------SASDOC*; 
  %bpm_validations(in_dataset=edw_provider_validate_new);
  %bpm_validations(in_dataset=edw_provider_validate_term);
  %bpm_validations(in_dataset=edw_provider_validate_change);
  %bpm_validations(in_dataset=edw_provider_validate_critical);
  %bpm_validations(in_dataset=edw_facility_validate_new);
  %bpm_validations(in_dataset=edw_facility_validate_term);
  %bpm_validations(in_dataset=edw_facility_validate_change);
  %bpm_validations(in_dataset=edw_facility_validate_critical);

  *SASDOC--------------------------------------------------------------------------
  | BPM - Insert provider data into cihold.hold_provider    
  |
  +------------------------------------------------------------------------SASDOC*; 
  %cihold_hold_provider (in_dataset=VSOURCE_PROVIDER);


  *SASDOC--------------------------------------------------------------------------
  | BPM - Insert provider data into edw.exceptions     
  |
  +------------------------------------------------------------------------SASDOC*; 
  %bpm_validation_detail(in_datasets=%str(edw_provider_validate_new 
										  edw_provider_validate_term 
										  edw_provider_validate_change 
										  edw_provider_validate_critical
										  edw_facility_validate_new
										  edw_facility_validate_term 
										  edw_facility_validate_change 
										  edw_facility_validate_critical));
  %set_error_flag;
  %on_error(ACTION=ABORT);


  *SASDOC--------------------------------------------------------------------------
  | BPM - Reset the process control tables to complete.  
  | 
  +------------------------------------------------------------------------SASDOC*;
  %bpm_process_control(timevar=COMPLETE);


%mend edw_provider_extract;

%edw_provider_extract;
