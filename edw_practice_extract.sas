
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_practice_extract.sas
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS options for program                                               
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*;
/*%let sysparm=%str(sk_prcs_ctrl_id=10027 wflow_exec_id=48865 sas_prgm_id=2 client_id=6 sas_mode=test);*/
/*%let test_case = 4; *UPDATE FOR TEST CASES;*/

%bpm_environment;

%macro edw_practice_extract(dataout=, vmine_client_id=);

	%put _all_;

	*SASDOC--------------------------------------------------------------------------
	| Test Cases  
	| 
	+------------------------------------------------------------------------SASDOC*; 

/*	%if &sas_mode. = test %then %do;*/
/*		%include "M:\CI\programs\EDW\test_cases\test_case_practice_&test_case..sas";*/
/*	%end;*/

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);


	*SASDOC--------------------------------------------------------------------------
	| CIHOLD - Make sure there are no records in the HOLD_PRACTICE table.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
		delete *
		from cihold.hold_practice
		where client_key in (&client_id.,-&client_id.);
	quit; 

	%set_error_flag;
	%on_error(ACTION=ABORT);



	*SASDOC--------------------------------------------------------------------------
	| Extract practice data from vSource 
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
	connect to oledb(init_string=&chisql.);
	create table VSOURCE_PRACTICE as select * from connection to oledb
	(	
		with prvgrp as
		(
			select 
				 prvgrp.[GroupID]
				,count(prvgrp.[ProviderID]) as provider_count
			from 	[vLinkNSAP].[dbo].[tblProvider] as p left outer join
					[vLinkNSAP].[dbo].[tblProviderGroups] as prvgrp on p.[ProviderID]=prvgrp.[ProviderID]
			where p.[ClientID] in (&client_id., -&client_id.) and p.[P-CIPar] in (1)
			group by prvgrp.[GroupID]
		)

		select distinct 
			grp.[ClientID]                                      as CLIENT_KEY,
	  upper(grp.[GroupName])                                    as PRACTICE_NAME, 
			grp.[G-Version]		                				as PRACTICE_MGT_KEY, 
			grp.[GroupFTIN]                    			        as TIN,
			grp.[GroupAltName]         			                as TIN_NAME,
			grp.[G-NPI]                			                as NPI2,
			pgr.[RealCategory]         			                as DATA_CATEGORY,
			NULL		                        	            as VMINE_INSTALLED_SCHED,
			NULL		   			                 			as VMINE_INSTALLED_DATE,
			'NULL'                        			            as VMINE_INSTALLER_NAME,
			pgr.[InstallStat]             			            as VMINE_STATUS,
			grp.[G-EffDt]										as PRACTICE_EFF_DATE,
			grp.[G-TermDt]										as PRACTICE_EXP_DATE,
			case when grp.[G-CIPar] = 1 then 'PAR'								
				 when grp.[G-CIPar] = 2 then 'NONPAR'		
				 else 'UNKNOWN'								end	as CI_STATUS,
			case when 
				grp.[GroupID] 		<> '' and
				grp.[ClientID]		<> '' and 
				grp.[GroupName]		<> '' and 
				grp.[GroupFTIN]		<> '' and
				pgr.[RealCategory]	<> '' and
				grp.[G-CIPar]		<> '' then 'Y'						
				else 'N'									end as DATA_CMPLT_IND,
			&wflow_exec_id.            			                as WFLOW_EXEC_ID,
			case when prvgrp.[provider_count] >= 1 then 'Y'	
			else 'N'										end	as PROVIDER_TIED,
			grp.[GroupID]										as VSOURCE_PRACTICE_KEY,
			1													as IS_VSOURCE_DATA
		from  	[vLinkNSAP].[dbo].[tblGroups]         			as grp 	LEFT OUTER JOIN
				[vLinkNSAP].[dbo].[vAllClientsCIProgressDetailed]	as pgr	on grp.[groupid] = pgr.[groupid] LEFT OUTER JOIN
				prvgrp 													on grp.[groupid] = prvgrp.[groupid]
		where 	grp.[ClientID] in (&client_id., -&client_id.)
	);
	quit;  


	*SASDOC--------------------------------------------------------------------------
	| EDW - Create source and edw variables for data staging tables 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%edw_create_source_variables(in_dataset1=VSOURCE_PRACTICE);


	*SASDOC--------------------------------------------------------------------------
	| EDW - Practice cleansing rules for the CI program 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%edw_practice_cleansing_rules(in_dataset1=VSOURCE_PRACTICE);
	%set_error_flag;
	%on_error(ACTION=ABORT);


	*SASDOC--------------------------------------------------------------------------
	| EDW - Perform practice validations on the data and set the prevent load indicator
	|  1.  validation - practice new
	|  2.  validation - practice terms
	|  3.  validation - practice change
	|  4.  validation - practice critical
	+------------------------------------------------------------------------SASDOC*; 
	%edw_practice_validations(vt_name=NEW     	  		,validation_type_id=12,in_dataset1=VSOURCE_PRACTICE,in_dataset2=CIEDW.PRACTICE  ,newval=a.practice_name,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%edw_practice_validations(vt_name=NEW_FACILITY		,validation_type_id=76,in_dataset1=VSOURCE_PRACTICE,in_dataset2=CIEDW.PRACTICE  ,newval=a.practice_name,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%edw_practice_validations(vt_name=TERM    			,validation_type_id=13,in_dataset1=CIEDW.PRACTICE  ,in_dataset2=VSOURCE_PRACTICE,oldval=a.practice_name,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%edw_practice_validations(vt_name=TERM_FACILITY		,validation_type_id=77,in_dataset1=CIEDW.PRACTICE  ,in_dataset2=VSOURCE_PRACTICE,oldval=a.practice_name,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%edw_practice_validations(vt_name=CHANGE  			,validation_type_id=14,in_dataset1=VSOURCE_PRACTICE,in_dataset2=CIEDW.PRACTICE  ,newval=			   ,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%edw_practice_validations(vt_name=CHANGE_FACILITY	,validation_type_id=78,in_dataset1=VSOURCE_PRACTICE,in_dataset2=CIEDW.PRACTICE  ,newval=			   ,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%edw_practice_validations(vt_name=CRITICAL			,validation_type_id=. ,in_dataset1=VSOURCE_PRACTICE,in_dataset2=CIEDW.PRACTICE  ,newval=			   ,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%edw_practice_validations(vt_name=CRITICAL_FACILITY	,validation_type_id=. ,in_dataset1=VSOURCE_PRACTICE,in_dataset2=CIEDW.PRACTICE  ,newval=			   ,by_variable=TIN,by_variable2=VSOURCE_PRACTICE_KEY);
	%set_error_flag;
  	%on_error(ACTION=ABORT);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice data into edw.validations    
	|
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_validations(in_dataset=edw_practice_validate_new);
	%bpm_validations(in_dataset=edw_practice_validate_term);
	%bpm_validations(in_dataset=edw_practice_validate_change);
	%bpm_validations(in_dataset=edw_practice_validate_critical);
	%bpm_validations(in_dataset=edw_facility_validate_new);
	%bpm_validations(in_dataset=edw_facility_validate_term);
	%bpm_validations(in_dataset=edw_facility_validate_change);
	%bpm_validations(in_dataset=edw_facility_validate_critical);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice data into cihold.hold_practice    
	|
	+------------------------------------------------------------------------SASDOC*; 
	%cihold_hold_practice (in_dataset=VSOURCE_PRACTICE);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice data into edw.exceptions     
	|
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_validation_detail(in_datasets=%str(edw_practice_validate_new 
											edw_practice_validate_term 
											edw_practice_validate_change 
											edw_practice_validate_critical
											edw_facility_validate_new 
											edw_facility_validate_term 
											edw_facility_validate_change 
											edw_facility_validate_critical
											));
	%set_error_flag;
	%on_error(ACTION=ABORT);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.  
	| 
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);

%mend edw_practice_extract;

%edw_practice_extract;
