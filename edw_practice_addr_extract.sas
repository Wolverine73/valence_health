
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_practice_addr_extract.sas
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
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS options for program                                               
+----------------------------------------------------------------------SASDOC*;
/*options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);*/

*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*;
/*%let sysparm=%str(sk_prcs_ctrl_id=74 wflow_exec_id=30 sas_prgm_id=23 client_id=4 sas_mode=test);*/
/*%bpm_environment;*/
/*%bpm_initialize_variables;*/

%macro edw_practice_addr_extract(dataout=, vmine_client_id=);

	*SASDOC--------------------------------------------------------------------------
	| Extract practice address data from vSource 
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
	connect to oledb(init_string=&vlink.);
	create table VSOURCE_PRACTICE_ADDR1 as select * from connection to oledb
	(	
		select distinct
				go.[GroupOfficeID]									as PRACTICE_ADDR_KEY,
				g.[GroupID]											as VSOURCE_PRACTICE_KEY,
				&client_id.											as CLIENT_KEY,
				convert(char(250),o.[Address1])						as ADDR_LINE_1,
				convert(char(250),o.[Address2])						as ADDR_LINE_2,
				convert(char(50),o.[City])							as CITY,
				convert(char(2),o.[State])							as STATE,
				convert(char(12),o.[Zip])							as ZIP_CODE,
				convert(char(50),o.[County])						as COUNTY,
				case when
					o.[OfficeName] 	<> '' and
					o.[Address1]	<> '' and
					o.[City]		<> '' and
					o.[State]		<> '' and
					o.[Zip]			<> '' then 'Y'
				else 'N'										end as DATA_CMPLT_IND,
				case when go.[Primary] = 0 then 'N'
				else 'Y'										end as PRIM_ADDR_IND,
				&wflow_exec_id.										as WFLOW_EXEC_ID
			from 	[dbo].[tblGroups]			as g								left outer join
					[dbo].[tblGroupOffices] 	as go 	on g.[GroupID]=go.[GroupID]	left outer join
				 	[dbo].[tblOffices]			as o	on go.[OfficeID] = o.[OfficeID]
			where g.[ClientID] = &client_id. and go.[GroupOfficeID] is not null
	);
	quit;  

	proc sql noprint;
		create table VSOURCE_PRACTICE_ADDR as 
			select 
				a.PRACTICE_ADDR_KEY,
				b.PRACTICE_KEY,
				a.CLIENT_KEY,
				a.ADDR_LINE_1,
				a.ADDR_LINE_2,
				a.CITY,
				a.STATE,
				a.ZIP_CODE,
				a.COUNTY,
				a.DATA_CMPLT_IND,
				a.PRIM_ADDR_IND,
				a.WFLOW_EXEC_ID
			from VSOURCE_PRACTICE_ADDR1 as a inner join
				 ciedw.PRACTICE as b on a.VSOURCE_PRACTICE_KEY=b.VSOURCE_PRACTICE_KEY
		;
	quit;


	*SASDOC--------------------------------------------------------------------------
	| EDW - Create source and edw variables for data staging tables 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%edw_create_source_variables(in_dataset1=VSOURCE_PRACTICE_ADDR);


	*SASDOC--------------------------------------------------------------------------
	| EDW - Practice cleansing rules for the CI program 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%edw_practiceaddr_cleansing_rules(in_dataset1=VSOURCE_PRACTICE_ADDR);
	%set_error_flag;
	%on_error(ACTION=ABORT);


	*SASDOC--------------------------------------------------------------------------
	| EDW - Perform practice address validations on the data and set the prevent load indicator
	|  1.  validation - practice address new
	|  2.  validation - practice address terms
	|  3.  validation - practice address change
	|  4.  validation - practice address critical
	+------------------------------------------------------------------------SASDOC*; 
	%edw_practice_addr_validations(vt_name=NEW     ,validation_type_id=22,in_dataset1=VSOURCE_PRACTICE_ADDR,in_dataset2=CIEDW.PRACTICE_ADDR  ,newval=a.ADDR_LINE_1,by_variable=PRACTICE_ADDR_KEY);
	%edw_practice_addr_validations(vt_name=CHANGE  ,validation_type_id=23,in_dataset1=VSOURCE_PRACTICE_ADDR,in_dataset2=CIEDW.PRACTICE_ADDR  ,newval=			  ,by_variable=PRACTICE_ADDR_KEY);
	%set_error_flag;
  	%on_error(ACTION=ABORT);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into edw.validations    
	|
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_validations(in_dataset=edw_practice_addr_validate_new);
	%bpm_validations(in_dataset=edw_practiceaddr_validate_change);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into cihold.hold_practice    
	|
	+------------------------------------------------------------------------SASDOC*; 
	%cihold_hold_practice_addr (in_dataset=VSOURCE_PRACTICE_ADDR);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into edw.exceptions     
	|
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_validation_detail(in_datasets=%str(edw_practice_addr_validate_new 
											edw_practiceaddr_validate_change));
	%set_error_flag;
	%on_error(ACTION=ABORT);

%mend edw_practice_addr_extract;
