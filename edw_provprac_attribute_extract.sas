/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_provprac_attribute_extract.sas
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
| 
+-----------------------------------------------------------------------HEADER*/

/*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*/
/*options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);*/


/*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+-------------------------------------------------------------------------SASDOC*/ 
/*%let sysparm=%str(sk_prcs_ctrl_id=10056 wflow_exec_id=48883 sas_prgm_id=49 client_id=15 sas_mode=test practice_id=1380 batch_key=1); */
/**/
/*%bpm_environment*/

%macro edw_provprac_attribute_extract();

		

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+-------------------------------------------------------------------------SASDOC*/ 
	%bpm_process_control(timevar=START)

	/*SASDOC--------------------------------------------------------------------------
	| Information on DataSourceID.        
	+-------------------------------------------------------------------------SASDOC*/
	%data_source_information;

	%put NOTE: dataformatid  = &dataformatid. ;
	%put NOTE: dataformatgroupid = &dataformatgroupid. ;
	%put NOTE: dataformatgroupdesc = &dataformatgroupdesc. ;

	%set_error_flag;
	%on_error(ACTION=ABORT);

	/*SASDOC--------------------------------------------------------------------------
	| Extract from provider attributes view.        
	+------------------------------------------------------------------------SASDOC*/
	%prov_attr_view_dataformatid_&dataformatid.;

	%set_error_flag
	%on_error(ACTION=ABORT)

	proc sql;
		connect to oledb(init_string=&ciedw.);
		create table provpracxref as select * from connection to oledb
		(
			select distinct
				a.prov_prctc_xref_key,
				a.provider_key,
				b.npi1,
				a.practice_key,
				c.tin 
			from dbo.provider_practice_xref as a left outer join
				 dbo.provider as b on a.provider_key=b.provider_key and a.client_key=b.client_key left outer join
				 dbo.practice as c on a.practice_key=c.practice_key and a.client_key=c.client_key
			where a.client_key=&client_id. and a.provider_key > 0
		);
	quit; 

	%set_error_flag
	%on_error(ACTION=ABORT)

	proc sql;
		create table provprac_attributes as
		(
			select distinct
				a.prov_prctc_xref_key,
				b.attribute_type_key,
				b.attribute_value,
				b.effective_date,
				b.termination_date,
				b.parent_attribute_value,
				&wflow_exec_id.			as created_wflow_exec_id,
				&wflow_exec_id.			as updated_wflow_exec_id,
				b.vhstage_source_key 		as vhstage_payer_src_key,
				b.vhstage_parent_source_key
			from provpracxref as a inner join
				 prov_attr_view_&practice_id. as b on a.npi1=b.npi and a.tin=b.tin 
		)
		order by prov_prctc_xref_key,vhstage_parent_source_key, attribute_type_key,attribute_value,effective_date,termination_date
		;
	quit; 

	/* This step is supposed to check for collaspable records by looking at lag term date to eff date 
	   This is code from G that Winnie installed. I need to look into making sure it works properly 
	   Need to collaspe children attributes only */

	data provprac_attributes2 (drop=effective_date termination_date lagend char_date_plus_one date_plus_one
	                           rename=(finalbeg=effective_date finalend=termination_date));
	set provprac_attributes;
	by prov_prctc_xref_key vhstage_parent_source_key attribute_type_key attribute_value effective_date termination_date;
	length  n_test_date $50; 
	date_plus_one=mdy(substr(termination_date,6,2),substr(termination_date,9,2),substr(termination_date,1,4)) + 1;	
	if substr(termination_date,1,4) = '9999' then char_date_plus_one=termination_date;
	else char_date_plus_one= catx('-',year(date_plus_one),put(month(date_plus_one),z2.),put(day(date_plus_one),z2.));
	lagend=lag(char_date_plus_one);
	retain finalbeg finalend;
	if first.attribute_value then do;
	    finalbeg = effective_date; 
		finalend = termination_date;
	end;
	else if effective_date <= char_date_plus_one then do;
	    finalend = termination_date;
	end;
	else do;
	    output;
	    finalbeg = effective_date; 
		finalend = termination_date;
	end;
	if last.attribute_value then output;
	run;

	%set_error_flag
	%on_error(ACTION=ABORT)

	/*SASDOC--------------------------------------------------------------------------
	| Source Extract Count.        
	+-------------------------------------------------------------------------SASDOC*/
   
	%let dsid=%sysfunc(open(provprac_attributes2));
	%let nobs=%sysfunc(attrn(&dsid.,nobs));
	%let dsrc=%sysfunc(close(&dsid.));
  
	
  	%put NOTE: Source Extract Count = &nobs.;

	%if &nobs. > 0 %then %do;

		%edw_create_source_variables(in_dataset1=provprac_attributes2)
		%set_error_flag
		%on_error(ACTION=ABORT)
	  
		/*SASDOC----------------------------------------------------------------------------------------------
		| EDW - Perform provider practice attribute validations on the data and set the prevent load indicator     
		|  1.  validations - attribute new
		|  2.  validations - attribute change
		|  3.  validations - attribute critical
		+----------------------------------------------------------------------------------------------SASDOC*/
		/* NEW */
		%edw_provprac_attr_validations(vt_name=NEW, validation_type_id=97, in_dataset1=provprac_attributes2, in_dataset2=CIEDW.PROVIDER_PRACTICE_ATTRIBUTE, newval=,
									   by_variable=prov_prctc_xref_key, by_variable2=attribute_type_key, by_variable3=attribute_value, 
									   by_variable4=vhstage_payer_src_key, by_variable5=parent_prov_prctc_attribute_key, by_variable6=PROV_PRCTC_ATTRIBUTE_KEY, by_variable7=parent_attribute_value)
		%set_error_flag
		%on_error(ACTION=ABORT)

		/* TERM */
		%edw_provprac_attr_validations(vt_name=TERM, validation_type_id=98, in_dataset1=provprac_attributes2, in_dataset2=CIEDW.PROVIDER_PRACTICE_ATTRIBUTE, newval=,
									   by_variable=prov_prctc_xref_key, by_variable2=attribute_type_key, by_variable3=attribute_value, 
									   by_variable4=vhstage_payer_src_key, by_variable5=parent_prov_prctc_attribute_key, by_variable6=PROV_PRCTC_ATTRIBUTE_KEY, by_variable7=parent_attribute_value)
		%set_error_flag
		%on_error(ACTION=ABORT)

		/* CRITICAL */
		%edw_provprac_attr_validations(vt_name=CRITICAL, validation_type_id=, in_dataset1=provprac_attributes2, in_dataset2=, newval=,
									   by_variable=prov_prctc_xref_key, by_variable4=vhstage_payer_src_key)
		%set_error_flag
		%on_error(ACTION=ABORT)

	  
		/*SASDOC--------------------------------------------------------------------------
		| BPM - Insert provider practice attribute data into BPMMetatData.Validations
		|		table
		+-------------------------------------------------------------------------SASDOC*/
		/* NEW */
		%bpm_validations(in_dataset=edw_attribute_validate_new)
		%set_error_flag
		%on_error(ACTION=ABORT)

		/* TERM */
		%bpm_validations(in_dataset=edw_attribute_validate_term)
		%set_error_flag
		%on_error(ACTION=ABORT)

		/* CRITICAL */
		%bpm_validations(in_dataset=edw_attribute_validate_critical)
		%set_error_flag
		%on_error(ACTION=ABORT)

		/*SASDOC--------------------------------------------------------------------------
		| BPM - Insert provider practice attribute data into 
		|		BPMMetaData.Validation_Detail table
		+------------------------------------------------------------------------SASDOC*/
		%bpm_validation_detail(in_datasets=%str(edw_attribute_validate_new
												edw_attribute_validate_term
												edw_attribute_validate_critical))
		%set_error_flag
		%on_error(ACTION=ABORT)


		/*SASDOC--------------------------------------------------------------------------
		| BPM - Insert provider practice attribute data into as a temp table in CIHold    
		|
		+-------------------------------------------------------------------------SASDOC*/
		%cihold_hold_provprac_attribute (in_dataset=provprac_attributes2);


		/*SASDOC--------------------------------------------------------------------------
		| Source Target Count.        
		+-------------------------------------------------------------------------SASDOC*/
		%let tgt_record_cnt = 0;
		%let dsid=%sysfunc(open(provprac_attributes2));
		%let tgt_record_cnt=%sysfunc(attrn(&dsid.,nobs));
		%let dsrc=%sysfunc(close(&dsid.));
		
		%put NOTE: Source Target Count = &tgt_record_cnt.;

	%end; /*** end of &nobs. > 0*/

	%else %do; /*** count is not greater than 0 ***/
		%put NOTE: Source Target Count = &nobs.;

		%put ERROR: There are 0 provider practice attribute records from DATA_SOURCE_ID = &practice_id. and BATCH_KEY=&batch_key. within provider practice attributes view.;

		%macro send_email_alert;
			filename mail_out email to=("EDWPROD@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - No Provider Payer Attributes from BATCH_KEY=&batch_key. within provider attributes view.";

			data _null_;
				file mail_out lrecl=32767;  
				put "Provider Practice Attributes from Payer";
				put "ClientID = &client_id.";
				put "DataSourceID = &practice_id.";
				put "Batch Key = &batch_key.";
				put "SAS MODE = &sas_mode.";
			run;
		%mend send_email_alert;
		%send_email_alert;

		%bpm_additional_validations(validation_rule=101,validation_count=0);

		%let err_fl=1;
		%set_error_flag;
		%on_error(ACTION=ABORT);	
	%end;

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.  
	| 
	+-------------------------------------------------------------------------SASDOC*/
	%bpm_process_control(timevar=COMPLETE)  
  
%mend edw_provprac_attribute_extract;
