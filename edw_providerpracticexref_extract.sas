
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_providerpracticexref_extract.sas
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
+-----------------------------------------------------------------------HEADER*/

/*SASDOC----------------------------------------------------------------------
| Define SAS options for program                                               
+----------------------------------------------------------------------SASDOC*/
/*options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);*/

/*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*/
/*%let sysparm=%str(sk_prcs_ctrl_id=74 wflow_exec_id=30 sas_prgm_id=23 client_id=4 sas_mode=test);*/
/*%bpm_environment;*/
/*%bpm_initialize_variables;*/
options mprint symbolgen;

%macro edw_providerpracticexref_extract(dataout=, vmine_client_id=);

	/*SASDOC--------------------------------------------------------------------------
	| Extract provider practice relationship data from vSource 
	+------------------------------------------------------------------------SASDOC*/
	proc sql;
	connect to oledb(init_string=&vlink.);
	create table VSOURCE_PROVPRACXREF1 as select * from connection to oledb
	(	
		select 
				pg.[GroupID]								as VSOURCE_PRACTICE_KEY,
				pg.[ProviderID]								as VSOURCE_PROVIDER_KEY,
				p.[P-NPI]									as NPI1,
				g.[GroupFTIN]								as TIN,
				&client_id.									as CLIENT_KEY,
				case when pg.[IsPrimary]= 1 then 'Y'
					 else 'N'							end as PRIMARY_PRACTICE_IND,
				pg.[EffDt]									as EFF_DT,
				pg.[TermDt]									as EXP_DT,
				&wflow_exec_id.								as WFLOW_EXEC_ID
		from 	[dbo].[tblProviderGroups]	as pg										left outer join
				[dbo].[tblProvider]			as p	on pg.[ProviderID] = p.[ProviderID] left outer join
				[dbo].[tblGroups]			as g	on pg.[GroupID] = g.[GroupID]
		where 	(p.[ClientID] in (&client_id., -&client_id.) or g.[ClientID] in (&client_id., -&client_id.)) and
				(p.[P-CIEffDt] is not null or p.[P-CIPar] in (1,2) or g.[G-CIPar] in (1,2))
		order by p.[ProviderID], g.[GroupID]
	);
	quit;  

	proc sql noprint;
		create table VSOURCE_PROVPRACXREF as
		select
			a.VSOURCE_PROVIDER_KEY,
			a.VSOURCE_PRACTICE_KEY,
			b.PROVIDER_KEY,
			c.PRACTICE_KEY,
			a.NPI1,
			a.TIN,
			a.CLIENT_KEY,
			a.PRIMARY_PRACTICE_IND,
			a.EFF_DT,
			a.EXP_DT,
			a.WFLOW_EXEC_ID
		from VSOURCE_PROVPRACXREF1 as a left join
			 ciedw.PROVIDER as b on a.VSOURCE_PROVIDER_KEY=b.VSOURCE_PROVIDER_KEY and a.CLIENT_KEY=b.CLIENT_KEY left join
			 ciedw.PRACTICE as c on a.VSOURCE_PRACTICE_KEY=c.VSOURCE_PRACTICE_KEY and a.CLIENT_KEY=c.CLIENT_KEY
		;
	quit;


	/*SASDOC--------------------------------------------------------------------------
	| EDW - Create source and edw variables for data staging tables 
	|
	+------------------------------------------------------------------------SASDOC*/ 
	%edw_create_source_variables(in_dataset1=VSOURCE_PROVPRACXREF);


	/*SASDOC--------------------------------------------------------------------------
	| EDW - Provider Practice XREF cleansing rules for the CI program 
	|
	+------------------------------------------------------------------------SASDOC*/
	%edw_provpracxref_cleansing_rules(in_dataset1=VSOURCE_PROVPRACXREF);
	%set_error_flag;
	%on_error(ACTION=ABORT);


	/*SASDOC--------------------------------------------------------------------------
	| EDW - Perform practice address validations on the data and set the prevent load indicator
	|  1.  validation - practice address new
	|  2.  validation - practice address terms
	|  3.  validation - practice address change
	|  4.  validation - practice address critical
	+------------------------------------------------------------------------SASDOC*/
	%edw_provpracxref_valids(vt_name=NEW,validation_type_id=24,ds1=VSOURCE_PROVPRACXREF,ds2=CIEDW.PROVIDER_PRACTICE_XREF,byvar=PROV_PRCTC_XREF_KEY,byvar1=NPI1,byvar2=TIN,byvar3=VSOURCE_PROVIDER_KEY,byvar4=VSOURCE_PRACTICE_KEY);
	%set_error_flag;
  	%on_error(ACTION=ABORT);

	%edw_provpracxref_valids(vt_name=CHANGE,validation_type_id=25,ds1=VSOURCE_PROVPRACXREF,ds2=CIEDW.PROVIDER_PRACTICE_XREF,byvar=PROV_PRCTC_XREF_KEY,byvar1=PRACTICE_KEY,byvar2=PROVIDER_KEY,byvar3=VSOURCE_PROVIDER_KEY,byvar4=VSOURCE_PRACTICE_KEY);
	%set_error_flag;
  	%on_error(ACTION=ABORT);

	%edw_provpracxref_valids(vt_name=CRITICAL,validation_type_id=.,ds1=VSOURCE_PROVPRACXREF,byvar=PROV_PRCTC_XREF_KEY,byvar1=PRACTICE_KEY,byvar2=PROVIDER_KEY,byvar3=VSOURCE_PROVIDER_KEY,byvar4=VSOURCE_PRACTICE_KEY);
	%set_error_flag;
  	%on_error(ACTION=ABORT);


	/*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into edw.validations    
	|
	+------------------------------------------------------------------------SASDOC*/ 
	%bpm_validations(in_dataset=edw_provpracxref_validate_new);
	%bpm_validations(in_dataset=edw_provpracxref_validate_change);
	%bpm_validations(in_dataset=edw_provpracxref_valid_critical);


	/*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into cihold.hold_practice    
	|
	+------------------------------------------------------------------------SASDOC*/
	%cihold_hold_provpracxref (in_dataset=VSOURCE_PROVPRACXREF);


	/*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into edw.exceptions     
	|
	+------------------------------------------------------------------------SASDOC*/
	%bpm_validation_detail(in_datasets=%str(edw_provpracxref_validate_new edw_provpracxref_validate_change edw_provpracxref_valid_critical));
	%set_error_flag;
	%on_error(ACTION=ABORT);

%mend edw_providerpracticexref_extract;
