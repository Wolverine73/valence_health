
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
| MACROS: edw_create_source_variables, edw_provpracxref_cleansing_rules, edw_provpracxref_validations
|         bpm_validations, bpm_validation_detail
+--------------------------------------------------------------------------------
| HISTORY:  
|  
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
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

%macro edw_provpracxref_payer_extract(dataout=, vmine_client_id=);

%global provpracxref_count; /* used in practice_payer_load call for provpracxref_payer_load flag*/

	*SASDOC--------------------------------------------------------------------------
	| Extract provider practice relationship data from vSource 
	| GET ORPHAN PRACTICE_KEYS, ORPHAN PROVIDER_KEYS, AND JOIN TO SOURCE DATA
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
	connect to oledb(init_string=&sqlci.);
	create table VSOURCE_PROVPRACXREF as select * from connection to oledb
	(	
		SELECT DISTINCT 
			  PROV.provider_KEY
			, PRAC.MIN_PRACTICE_KEY AS PRACTICE_KEY
			, SOURCE.CLIENT_KEY 
			, SOURCE.WFLOW_EXEC_ID 
			, 0 AS IS_VSOURCE_DATA
			, 1 AS IS_PAYER_DATA
			, 1 AS LOAD_FLAG
		FROM cihold.dbo.saswrk_practice_payer_src_&client_id.  SOURCE
	   INNER JOIN (SELECT TIN    
					    , MIN(PRACTICE_KEY) AS MIN_PRACTICE_KEY
					    , CLIENT_KEY
				     FROM CIEDW.dbo.practice
				    WHERE PRACTICE_KEY > 0
				    GROUP BY TIN
					    , CLIENT_KEY
						)  										PRAC
	      ON SOURCE.TIN = PRAC.TIN 
		 AND SOURCE.CLIENT_KEY = PRAC.CLIENT_KEY 
	INNER JOIN CIEDW.dbo.provider 								PROV 
	   ON SOURCE.NPI1 = PROV.NPI1 AND 
			SOURCE.CLIENT_KEY = PROV.CLIENT_KEY AND
			PROV.provider_key > 0 AND 
			PROV.IS_PAYER_DATA = 1 /* ignore vsource ONLY data */			
				);
	quit;  


	*SASDOC--------------------------------------------------------------------------
	| EDW - Create source and edw variables for data staging tables 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%edw_create_source_variables(in_dataset1=VSOURCE_PROVPRACXREF)

	*SASDOC--------------------------------------------------------------------------
	| EDW - Provider Practice XREF cleansing rules for the CI program 
	|
	+------------------------------------------------------------------------SASDOC*; 
	%edw_provpracxref_cleansing_rules(in_dataset1=VSOURCE_PROVPRACXREF)
	%set_error_flag
	%on_error(ACTION=ABORT)

	*SASDOC--------------------------------------------------------------------------
	| EDW - Perform practice address validations on the data and set the prevent load indicator
	|  1.  validation - practice address new
	|  2.  validation - practice address terms
	|  3.  validation - practice address change
	|  4.  validation - practice address critical
	+------------------------------------------------------------------------SASDOC*; 
	%edw_provpracxref_validations(vt_name=NEW,validation_type_id=93,in_dataset1=VSOURCE_PROVPRACXREF,in_dataset2=CIEDW.PROVIDER_PRACTICE_XREF,newval= ,by_variable=PROV_PRCTC_XREF_KEY,by_variable1=PRACTICE_KEY,by_variable2=PROVIDER_KEY);
	%set_error_flag
	%on_error(ACTION=ABORT)
	
	/* NEED EMPTY CHANGED DATASET FOR CRITICAL MACRO CHECK */
/*		DATA EDW_PROVPRACXREF_VALIDATE_CHANGE;*/
/*			PROV_PRCTC_XREF_KEY=.;*/
/*			PRACTICE_KEY = .;*/
/*			PROVIDER_KEY = .; */
/*			IF _n_ = 1 THEN DELETE;*/
/*		RUN;*/
/**/
/*	%edw_provpracxref_validations(vt_name=CRITICAL,validation_type_id=.,in_dataset1=VSOURCE_PROVPRACXREF,in_dataset2=                             ,newval= ,by_variable=PROV_PRCTC_XREF_KEY,by_variable1=PRACTICE_KEY,by_variable2=PROVIDER_KEY);*/
/*		%set_error_flag*/
/*		%on_error(ACTION=ABORT)*/


	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into edw.validations    
	|
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_validations(in_dataset=edw_provpracxref_validate_new)
		%set_error_flag
		%on_error(ACTION=ABORT)
/*	%bpm_validations(in_dataset=edw_provpracxref_validate_change)*/
/*	%bpm_validations(in_dataset=edw_provpracxref_valid_critical)*/
/*		%set_error_flag*/
/*		%on_error(ACTION=ABORT)*/

  *SASDOC-----------------------------------------------------------------------------------
  | BPM - Drop if table exist then insert provider_practice_xref into cihold.saswrk_hold_provpracxref_payer_&client_id. 
  |
  +-----------------------------------------------------------------------------------------SASDOC*;  
  
  %local count_hold ;

	%let count_hold=0;
  
	%let varexist_id=%sysfunc(open(VSOURCE_PROVPRACXREF));
	%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_id));
	%let varexist_rc=%sysfunc(close(&varexist_id.));
	
	%if &varexist_ind. > 0 %then %do; 
	    proc sql noprint;
		  select count(*) into: count_hold
		  from vsource_provpracxref
	      where validation_id ne 0;
		quit;
	%end;
    
	%put NOTE: Provider Practice XREF Hold Count: &count_hold. ;
	
	%let provpracxref_count=&count_hold;
	
    %if &count_hold. ne 0 %then %do;
	
		%let src_record_cnt=&count_hold.;
		%let tgt_record_cnt=&count_hold.;

	    data hold_provpracxref_payer_&client_id.;
		  set vsource_provpracxref;
	      where validation_id > 0 and validation_id ne .;
		  if validation_id in (93) then load_flag = 1;  	/** new, term, change  **/
		  else load_flag = 0;                              		/** critical           **/
		run;

  
		* USE CIHOLD TABLE;
		
		proc sql;
			connect to oledb(init_string=&cihold);
			execute (				
					IF  EXISTS(SELECT *
								 FROM sys.tables
								WHERE name = %str(%')saswrk_hld_provpracx_pyr_&client_id.%str(%')
								  AND schema_id = SCHEMA_ID('dbo'))								
						   DROP TABLE cihold.dbo.saswrk_hld_provpracx_pyr_&client_id.;						
					)					
			by oledb;
		quit;
		
		
		PROC APPEND BASE = bcphold.saswrk_hld_provpracx_pyr_&client_id.
                    DATA = hold_provpracxref_payer_&client_id. FORCE;
        run;
		
	  %set_error_flag
	  %on_error(ACTION=ABORT)
  
	  %end;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Insert practice address data into edw.exceptions     
	|
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_validation_detail(in_datasets=%str(edw_provpracxref_validate_new ))
	%set_error_flag
	%on_error(ACTION=ABORT)

%mend edw_provpracxref_payer_extract;
