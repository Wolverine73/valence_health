
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
| MACROS:  bpm_environment, bpm_process_control, edw_create_source_variables
|          edw_PRACTICE_payer_validations, bpm_validations, bpm_validation_detail                                      
+--------------------------------------------------------------------------------
| HISTORY: 
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 
| 05MAY2012 - Brandon Fletcher - Copied Structure from CI process - Original 
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS options for program                                               
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos); 

*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*;
/*%let sysparm=%str(sk_prcs_ctrl_id=24304 wflow_exec_id=113523 sas_prgm_id=51 client_id=6 practice_id=1332 batch_key=1); */ 

%bpm_environment

%macro edw_practice_payer_extract();

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
	| EDW - Extract practice data FROM the Payer Source tables 
	| SOURCE: PRACTICE
	| SAS DS: PRACTICE_PAYER_SRC	|
	+------------------------------------------------------------------------SASDOC*;
	%payer_prac_vw_dataformatid_&dataformatid.;	
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
		from PRACTICE_payer_src_&client_id.;
	quit;

  	%put NOTE: Source Extract Count = &src_record_cnt.;

	%if &src_record_cnt. > 0 %then %do;

			
		%edw_create_source_variables(in_dataset1=practice_payer_src_&client_id)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 	  

		*SASDOC---------------------------------------------------------------------------------------------
		| EDW - Perform PRACTICE and PRACTICE_payer validations on the data and set the prevent load indicator     
		|  1.  validations - PRACTICE new
		|  2.  validations - PRACTICE change
		|  3.  validations - PRACTICE critical
		|
		+----------------------------------------------------------------------------------------------------SASDOC*; 
		/* NEW */
		%edw_PRACTICE_payer_validations(vt_name=NEW, validation_type_id=87, in_dataset1=PRACTICE_payer_src_&client_id., in_dataset2=PRACTICE, newval=, by_variable=tin, by_variable2=vhstage_payer_src_key)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
		%edw_PRACTICE_payer_validations(vt_name=NEW, validation_type_id=89, in_dataset1=PRACTICE_payer_src_&client_id., in_dataset2=PRACTICE_PAYER, newval=, by_variable=tin, by_variable2=system_practice_id, by_variable3=vhstage_payer_src_key)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		/* CHANGE */
		%edw_PRACTICE_payer_validations(vt_name=CHANGE, validation_type_id=88, in_dataset1=PRACTICE_payer_src_&client_id., in_dataset2=PRACTICE, newval=,by_variable=tin, by_variable2=vhstage_payer_src_key)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint;  		
		%edw_PRACTICE_payer_validations(vt_name=CHANGE, validation_type_id=90, in_dataset1=PRACTICE_payer_src_&client_id., in_dataset2=PRACTICE_PAYER, newval=,by_variable=tin, by_variable2=system_practice_id, by_variable3=vhstage_payer_src_key)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

		/* CRITICAL */	
		%edw_PRACTICE_payer_validations(vt_name=CRITICAL, validation_type_id=., in_dataset1=PRACTICE_payer_src_&client_id.  , in_dataset2=PRACTICE, newval=,BY_variable=tin, by_variable2=vhstage_payer_src_key)
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
		
		%let varexist_id=%sysfunc(open(practice_payer_src_&client_id));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));
			
		/* FLAG LOAD INDICATOR AGAINST VALIDATION TYPES */
		/* load_flag = 0 means no inserts or updates so had to update */
		data cihold_PRACTICE_payer_src_&client_id.;
		set practice_payer_src_&client_id;
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
		| BPM - Drop if table exist then insert PRACTICE into cihold.PRACTICE_payer_src_&client_id 
		|
		+-----------------------------------------------------------------------------------------SASDOC*;   
			
			* USE CIHOLD TABLE;
			
			proc sql;
				connect to oledb(init_string=&cihold);
				execute (				
						IF  EXISTS(SELECT *
									 FROM sys.tables
									WHERE name = %str(%')saswrk_practice_payer_src_&client_id.%str(%')
									  AND schema_id = SCHEMA_ID('dbo'))								
							   DROP TABLE cihold.dbo.saswrk_practice_payer_src_&client_id.;						
						)					
				by oledb;
			quit;
			
			
			PROC APPEND BASE = bcphold.saswrk_practice_payer_src_&client_id.
						DATA = cihold_practice_payer_src_&client_id. FORCE;
			run;
			
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	  
	  *SASDOC--------------------------------------------------------------------------
	  | BPM - Insert practice data into edw.validations    
	  |
	  +------------------------------------------------------------------------SASDOC*; 
	/* NEW */
	  %bpm_validations(in_dataset=practice_payer_validate_new)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	  %bpm_validations(in_dataset=practice_validate_new)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	/* CHANGE */
	  %bpm_validations(in_dataset=practice_payer_vldt_change)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	  %bpm_validations(in_dataset=practice_vldt_change)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 
	/* CRITICAL */
	  %bpm_validations(in_dataset=practice_validate_critical)
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

	  *SASDOC--------------------------------------------------------------------------
	  | BPM - Insert practice data into edw.exceptions     
	  |
	  +------------------------------------------------------------------------SASDOC*; 
	  %bpm_validation_detail(in_datasets=%str(practice_payer_validate_new  practice_validate_new practice_payer_vldt_change practice_vldt_change practice_validate_critical))
 			options nomlogic nomprint; 
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint; 

	%end; /*** end of &src_record_cnt. > 0*/

	%else %do; /*** when src_target_cnt is not greater than 0 ***/
	    options nomlogic nomprint nosymbolgen; 
		%let tgt_record_cnt = 0;
		%put NOTE: Source Target Count = &tgt_record_cnt.;
	
		%put;%put ERROR: There are 0 practice payer records from BATCH_KEY=&batch_key. within practice payer view.;%put;

		%macro send_email_alert;
			filename mail_out email to=("EDWPROD@valencehealth.com" "bfletcher@valencehealth.com" "wlee@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - No Practice Payer from BATCH_KEY=&batch_key. within practice payer view.";

			data _null_;
				file mail_out lrecl=32767;  
				put "Practice Payer";
				put "ClientID = &client_id.";
				put "DataSourceID = &practice_id.";
				put "Batch Key = &batch_key.";
				put "SAS MODE = &sas_mode.";
			run;
		%mend send_email_alert;
		%send_email_alert;

		%bpm_additional_validations(validation_rule=94,validation_count=0);

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
  
%mend edw_practice_payer_extract;

%edw_practice_payer_extract()
