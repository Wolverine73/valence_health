
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  	edw_member_extract.sas
|
| LOCATION: 	M:\CI\programs\StandardMacros 
|
| PURPOSE:      
|
| INPUT:		Requirements for linking macro to work, please see edw_linking.sas header
|
|				Requirements for the payer view output
|					Required fields:
|					- system_member_id, ssn, fname, mname, lname, sex, dob, address1, city, state, zip, phone
|					- elig_effective_date, elig_termination_date
|					- is_drug_eligible (bit, 0 or 1)
|
|					Optional fields:
|					- address2, address3, county, race 
|					- subscriber_ssn, relationship_code_pfkey (preset flag)
|					- product_type, plan_code (although these 2 are nullable in SQL table, we should at least have 1 of these, otherwise,
|												what are the members eligible for?)
|					- policy_number, employer_name, employer_id
|           
| OUTPUT:		&incoming.		- original input dataset with person_key and member_key
|				&incoming._plmk	- new dataset that tracks linking methodology
|				If input dataset is missing, for payer, it creates cistage.memelig_ dataset
|                                            
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
| 28MAY2012 - G Liu - Clinical Integration 1.3.01
|			  Add codes to handle payer eligibility files
|				- If normal &incoming does not exist and it is payer dataformatgroup, create 
|				  cistage.payer_member_and_elig dataset using payer-specific view, and reset &incoming.
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program                                               
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);



*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment; 


%macro edw_member_extract(incoming=);

  /*SASDOC--------------------------------------------------------------------------
  | BPM - Reset the process control tables to start.        
  +------------------------------------------------------------------------SASDOC*/ 
  %bpm_process_control(timevar=START)

  %data_source_information
 
  %if %sysfunc(exist(&incoming.))=0 %then %do;
	%if &dataformatgroupid.=20 and &PayerContainMemberElig. %then %do; /* payer data, if incoming is missing, and has elig */ 
		%let incoming=cistage.memelig_&practice_id._&client_id._&wflow_exec_id.;

		%payer_member_view_dataformat&dataformatid.(&batch_key.)

		data &incoming.;
			set payer_member_and_elig;
			format member_key 16. svcdt mmddyy10.;
			member_key=0;
			historical=5;
			practice_id=&practice_id.; group_id=&practice_id.;
			source='P'; /* this is just so that we utilize the same linking logic as physician claims */
			svcdt=datepart(datetime());
			dq_member_flag=0;
			claim_key=_n_;
			client_key=&client_id.; payer_key=&payer_key.;
		run;
	%end;
	%else %do;
		%put ERROR: Data set &incoming. does not exist.;
		%let err_fl=1;
	%end;
  %end;

  %set_error_flag
  %on_error(ACTION=ABORT)

  proc sql noprint;
    select count(*) 
	into: check_src
	from &incoming. ;
  quit;

  %put check_src = &check_src;

  %if &check_src. eq 0 %then %do;
     %put ERROR: There are 0 observations within &incoming. ;
	 %let err_fl = 1;
  %end;
  %else %if &check_src. ne 0 %then %do;
     %put NOTE: There are &check_src observations within &incoming.;
  %end;

  %set_error_flag
  %on_error(ACTION=ABORT)

  *SASDOC--------------------------------------------------------------------------
  | SAS DATA EDW - Call linking algorithm to determine member validation  
  |  1.  validations - member (within linking algorithm)
  |  2.  assign member key
  |  3.  load satellite tables
  +------------------------------------------------------------------------SASDOC*;  
  %edw_linking(incoming=&incoming)

  %set_error_flag
  %on_error(ACTION=ABORT)
  
  proc sql;
      connect to oledb(init_string=&ciedw.);
      execute ( 
                delete from [bpmmetadata].[dbo].[validations ]  
                where wflow_exec_id = &wflow_exec_id. ;
              ) 
     by oledb; 
  quit;
   
  proc sql;
      connect to oledb(init_string=&ciedw.);
      execute ( 
                delete from [bpmmetadata].[dbo].[validation_detail ]  
                where wflow_exec_id = &wflow_exec_id. ;
              ) 
     by oledb; 
  quit;


  *SASDOC--------------------------------------------------------------------------
  | EDW - Get the current Member information from the EDW for comparison to new records  
  |
  +------------------------------------------------------------------------SASDOC*; 
  %set_error_flag
  %on_error(ACTION=ABORT)

  *SASDOC--------------------------------------------------------------------------
  | SAS DATA/EDW  - Perform member validations on the data 
  |  1.  validations - member new
  |  2.  validations - member change
  |  3.  validations - member critical
  |
  +------------------------------------------------------------------------SASDOC*; 
  %edw_member_validations(in_dataset2=ciedw.member,in_dataset1=&incoming.,by_variable=member_key, newval=a.member_key)
  %set_error_flag
  %on_error(ACTION=ABORT)

  *SASDOC--------------------------------------------------------------------------
  | SAS DATA - Get the counts of the data pulled and expected to be loaded. 
  |
  +------------------------------------------------------------------------SASDOC*; 

  proc sql noprint;
    select count(*) 
	into: count_src
	from &incoming. ;

	select count(*) 
	into: count_tgt
	from &incoming.
	where dq_member_flag=0 ;
  quit;

  %put NOTE: count_src = &count_src;
  %put NOTE: count_tgt = &count_tgt;

  %if &count_src ne 0 %then %do;
	  %let src_record_cnt=&count_src.;
	  %let tgt_record_cnt=&count_tgt.;
  %end;

  %set_error_flag
  %on_error(ACTION=ABORT)

  *SASDOC--------------------------------------------------------------------------
  | BPM - Insert member data into edw.validations    
  |
  +------------------------------------------------------------------------SASDOC*; 
  %bpm_validations(in_dataset=edw_member_validate_new)
  %bpm_validations(in_dataset=edw_member_validate_change)
  %bpm_validations(in_dataset=edw_member_validate_critical)

  %set_error_flag
  %on_error(ACTION=ABORT)

  *SASDOC--------------------------------------------------------------------------
  | BPM - Insert member data into edw.validations_detail
  |
  +------------------------------------------------------------------------SASDOC*; 
  %bpm_validation_detail(in_datasets=%str(edw_member_validate_new edw_member_validate_change edw_member_validate_critical))
  %set_error_flag
  %on_error(ACTION=ABORT)


  *SASDOC--------------------------------------------------------------------------
  | BPM - Reset the process control tables to complete.        
  +------------------------------------------------------------------------SASDOC*;
  %bpm_process_control(timevar=COMPLETE)

%mend edw_member_extract;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
options bufsize=100000;
%edw_member_extract(incoming=cistage.claims_&practice_id._&client_id._&wflow_exec_id.)
options bufsize=32767;
