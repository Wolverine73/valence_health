
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_provider_payer_extract.sas
|
| LOCATION: M:\CI\programs\EDW 
|
| PURPOSE: Load provider payer data into the EDW                                
|           
| INPUT:                                        
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  05MAY2012 - Brandon Fletcher - Copied Structure from CI provider practice process - Original
|     
| WARNING! NEED TO ADD MACRO VARIABLE FOR THE VIEW CALL FOR MMO/TCHP/ETC  
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
/* MMO %let sysparm=%str(sk_prcs_ctrl_id=10056 wflow_exec_id=48883 sas_prgm_id=49 client_id=6 sas_mode=test practice_id=1332 batch_key=1);  */

%bpm_environment

%macro edw_provider_payer_extract();

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START)

	*SASDOC--------------------------------------------------------------------------
	| Information on DataSourceID.        
	+------------------------------------------------------------------------SASDOC*; 
	%data_source_information;

	%put NOTE: dataformatid  = &dataformatid. ;
	%put NOTE: dataformatgroupid = &dataformatgroupid. ;
	%put NOTE: dataformatgroupdesc = &dataformatgroupdesc. ;   
	
	*SASDOC--------------------------------------------------------------------------
	| EDW - Extract provider data FROM the Payer Source tables 
	| SOURCE: PROVIDER
	| SAS DS: PROVIDER_PAYER_SRC	|
	+------------------------------------------------------------------------SASDOC*;
	%payer_prov_vw_dataformatid_&dataformatid.;	
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

	*SASDOC--------------------------------------------------------------------------
	| Source Extract Count.        
	+------------------------------------------------------------------------SASDOC*; 
	%let src_record_cnt = 0;

	proc sql noprint;
		select count(*) into: src_record_cnt
		from provider_payer_src_&client_id.;
	quit;

  	%put NOTE: Source Extract Count = &src_record_cnt.;

	%if &src_record_cnt. > 0 %then %do;

		%edw_create_source_variables(in_dataset1=provider_payer_src_&client_id)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	  
		*SASDOC---------------------------------------------------------------------------------------------
		| EDW - Perform provider and provider_payer validations on the data and set the prevent load indicator     
		|  1.  validations - provider new
		|  2.  validations - provider change
		|  3.  validations - provider critical
		|
		+----------------------------------------------------------------------------------------------------SASDOC*; 
		/* NEW */
		%edw_provider_payer_validations(vt_name=NEW, validation_type_id=79, in_dataset1=provider_payer_src_&client_id., in_dataset2=PROVIDER, newval=, by_variable=NPI1, by_variable2=SYSTEM_PROVIDER_ID, by_variable3=VHSTAGE_PAYER_SRC_KEY)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
		%edw_provider_payer_validations(vt_name=NEW, validation_type_id=81, in_dataset1=provider_payer_src_&client_id., in_dataset2=PROVIDER_PAYER, newval=, by_variable=NPI1, by_variable2=SYSTEM_PROVIDER_ID, by_variable3=VHSTAGE_PAYER_SRC_KEY)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		/* CHANGE */
		%edw_provider_payer_validations(vt_name=CHANGE, validation_type_id=82, in_dataset1=provider_payer_src_&client_id., in_dataset2=PROVIDER_PAYER, newval=,by_variable=NPI1, by_variable2=SYSTEM_PROVIDER_ID, by_variable3=VHSTAGE_PAYER_SRC_KEY)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
		%edw_provider_payer_validations(vt_name=CHANGE, validation_type_id=80, in_dataset1=provider_payer_src_&client_id., in_dataset2=PROVIDER, newval=,by_variable=NPI1, by_variable2=SYSTEM_PROVIDER_ID, by_variable3=VHSTAGE_PAYER_SRC_KEY)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
		
		/* CRITICAL */	
		%edw_provider_payer_validations(vt_name=CRITICAL, validation_type_id=., in_dataset1=provider_payer_src_&client_id. , in_dataset2=PROVIDER, newval=,BY_variable=NPI1, by_variable2=SYSTEM_PROVIDER_ID, by_variable3=VHSTAGE_PAYER_SRC_KEY)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		
		/* READ IN VALIDATION TYPES */
		proc sql noprint;
			select validation_type_id into: condition_validation_type_id separated by ','
			from vbpm.validation_type
			where load_flag=1;
		quit;

		/* READ IN VALIDATION TYPES */
		proc sql noprint;
			select validation_type_id into: nlhold_condition_type_id separated by ',' 
			from vbpm.validation_type
			where load_flag=0;
		quit;	
		
		%put ;%put NOTE: condition_validation_type_id = &condition_validation_type_id;%put ;
		%put ;%put NOTE: critical condition validation type id = &nlhold_condition_type_id;%put ;

		%let varexist_id=%sysfunc(open(provider_payer_src_&client_id));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));
			
		/* FLAG LOAD INDICATOR AGAINST VALIDATION TYPES */
		/* load_flag = 0 means no inserts or updates so had to update */
		data cihold_provider_payer_src_&client_id.;
		set provider_payer_src_&client_id;
		where validation_type_id ne 0;
		if validation_type_id in (&condition_validation_type_id.) then load_flag = 1;  /** new, term, change  **/
		else if validation_type_id in (&nlhold_condition_type_id.) then load_flag = -1; /* critical failure */                              								 /** critical  **/
		else load_flag = 0;  /* no update or insert in practice or practice_payer */
		run;
		
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		
		*SASDOC-----------------------------------------------------------------------------------
		| BPM - Drop if table exist then insert provider into cihold.provider_payer_src_&client_id 
		|
		+-----------------------------------------------------------------------------------------SASDOC*;   

		proc sql;
			connect to oledb(init_string=&cihold);
			execute 
			(
				IF EXISTS
				(
					SELECT *
					FROM sys.tables
					WHERE name = %str(%')saswrk_provider_payer_src_&client_id.%str(%') AND schema_id = SCHEMA_ID('dbo'))								

					DROP TABLE cihold.dbo.saswrk_provider_payer_src_&client_id.;						
				)					
			by oledb;
		quit;		

		PROC APPEND BASE = bcphold.saswrk_provider_payer_src_&client_id.
		            DATA = cihold_provider_payer_src_&client_id. FORCE;
		run;

 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	  
		*SASDOC--------------------------------------------------------------------------
		| BPM - Insert provider data into edw.validations    
		|
		+------------------------------------------------------------------------SASDOC*; 
		/* NEW */
		%bpm_validations(in_dataset=provider_payer_validate_new)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
		%bpm_validations(in_dataset=provider_validate_new)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		/* CHANGE */
		%bpm_validations(in_dataset=provider_payer_vldt_change)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
		%bpm_validations(in_dataset=provider_vldt_change)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		/* CRITICAL */
		%bpm_validations(in_dataset=provider_validate_critical)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		*SASDOC--------------------------------------------------------------------------
		| BPM - Insert provider data into edw.exceptions     
		|
		+------------------------------------------------------------------------SASDOC*; 
		%bpm_validation_detail(in_datasets=%str(provider_payer_validate_new provider_validate_new provider_payer_vldt_change provider_vldt_change provider_validate_critical))
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 


		*SASDOC--------------------------------------------------------------------------
		| Source Target Count.        
		+------------------------------------------------------------------------SASDOC*; 
		%let tgt_record_cnt = 0;
		proc sql noprint;
			select count(*) into: tgt_record_cnt
			from provider_payer_src_&client_id.;
		quit;

		%put NOTE: Source Target Count = &tgt_record_cnt.;

	%end; /*** end of &src_record_cnt. > 0*/

	%else %do; /*** when src_target_cnt is not greater than 0 ***/
		options nomlogic nomprint nosymbolgen;  
		%let tgt_record_cnt = 0;
		%put;%put NOTE: Source Target Count = &tgt_record_cnt.;

		%put;%put ERROR: There are 0 provider payer records from BATCH_KEY=&batch_key. within provider payer view.;%put;

		%macro send_email_alert;
			filename mail_out email to=("EDWPROD@valencehealth.com" "bfletcher@valencehealth.com" "wlee@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - No Provider Payer from BATCH_KEY=&batch_key. within provider payer view.";

			data _null_;
				file mail_out lrecl=32767;  
				put "Provider Payer";
				put "ClientID = &client_id.";
				put "DataSourceID = &practice_id.";
				put "Batch Key = &batch_key.";
				put "SAS MODE = &sas_mode.";
			run;
		%mend send_email_alert;
		%send_email_alert;

		%bpm_additional_validations(validation_rule=86,validation_count=0);

		%let err_fl=1;
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	%end;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.  
	| 
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE)  
  
%mend edw_provider_payer_extract;

%edw_provider_payer_extract()
