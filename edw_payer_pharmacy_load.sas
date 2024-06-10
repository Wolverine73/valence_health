/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_payer_pharmacy_load.sas
|
| LOCATION: M:\CI\programs\EDW
|
| PURPOSE:  Load payer pharmacy data into the CIEDW.dbo.PERSON_PHARMACY  
|
| INPUT: cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;    
|                        
| OUTPUT: 
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 10JUN2012 - G Liu  - Clinical Integration  Release v1.3.H01
|             Original
|			  Temporarily loading ndc_code_no_dash to ndc_key column since
|				ciedw.cds_ndc table is not ready yet
|
| 25JUL2012 - Winnie Lee - Clinical Integration Release 1.4 H01
|				Added 2 new fields to bring into CIEDW.dbo.PERSON_PHARMACY
|				1. ndc_code_from_raw_data 
|				2. drug_name_from_raw_data
+-----------------------------------------------------------------------HEADER*/
 
/*sasdoc----------------------------------------------------------------------
| define sas macros for program    
| +----------------------------------------------------------------------SASDOC*/
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

/*SASDOC--------------------------------------------------------------------------
| standard assignments 
|+------------------------------------------------------------------------SASDOC*/  
/*%let sysparm = %str(wflow_exec_id=49185 SK_PRCS_CTRL_ID=10329 client_id=15 sas_mode=test sas_prgm_id=48 system_id=0 practice_id=1380 filename=1380-batchkey2 file_directory=);*/
%bpm_environment; 


%macro edw_payer_pharmacy_load(incoming=);
	%if %sysfunc(exist(&incoming.)) %then %do;  /** begin - incoming **/
	 	%let incoming_library = %scan(&incoming.,-2,'.');
		%let incoming_dataset = %scan(&incoming.,-1,'.');
	 	%if &incoming_library.= %then %let incoming_library=work;

		%let sasprogramby='bpm - sas';

		/*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to start.   
		+------------------------------------------------------------------------SASDOC*/
		%bpm_process_control(timevar=START); 

		/*SASDOC--------------------------------------------------------------------------
		| data_source_information - retrieve information about data source.   
		+------------------------------------------------------------------------SASDOC*/ 		
		%data_source_information;

		%put NOTE: dataformatid  		= &dataformatid. ;
		%put NOTE: dataformatgroupid 	= &dataformatgroupid. ;
		%put NOTE: dataformatgroupdesc	= &dataformatgroupdesc. ;
		%put NOTE: payer_key 			= &payer_key.;

	    /*SASDOC--------------------------------------------------------------------------
	    | CIEDW and NL HOLD table clean up
	    +------------------------------------------------------------------------SASDOC*/
		proc sql noprint;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			select	*
			into	:eppl_wflow_loaded_cnt separated by ','
			from	connection to oledb
					(	select	count(*)
						from	ciedw.dbo.person_pharmacy
						where	created_wflow_exec_id=&wflow_exec_id.
					);
		quit;

		%if &eppl_wflow_loaded_cnt. %then %do;
			%put NOTE: Records already loaded with this wflow_exec_id = &eppl_wflow_loaded_cnt.;
			%put NOTE: Perform delete statements;

			%macro del_same_wflow(m_table,m_wflow_var=created_wflow_exec_id);
				proc sql;
					connect to oledb(init_string=&sqlci.);
					execute	(	delete from &m_table.
								where	&m_wflow_var.=&wflow_exec_id.
							)
					by oledb;
				quit;
			%mend;
			%del_same_wflow(ciedw.dbo.person_pharmacy)
			%del_same_wflow(cihold.dbo.nl_hold_person_pharmacy)
		%end;

	    /*SASDOC--------------------------------------------------------------------------
	    | Prepare data to be loaded
	    +------------------------------------------------------------------------SASDOC*/
		%let ds_id				= %sysfunc(open(&incoming.));
		%let ds_svcdt_ind		= %sysfunc(varnum(&ds_id.,svcdt));
		%let ds_filldt_ind		= %sysfunc(varnum(&ds_id.,rx_fill_date));
		%let ds_paiddt_ind		= %sysfunc(varnum(&ds_id.,paid_date));
		%let ds_billedamt_ind	= %sysfunc(varnum(&ds_id.,billed_amt));
		%let ds_allowedamt_ind	= %sysfunc(varnum(&ds_id.,allowed_amt));
		%let ds_paidamt_ind		= %sysfunc(varnum(&ds_id.,paid_amt));
		%let ds_copayamt_ind	= %sysfunc(varnum(&ds_id.,copay_amt));
		%let src_record_cnt		= %sysfunc(attrn(&ds_id.,nobs));
		%let ds_rc				= %sysfunc(close(&ds_id.));
		%if &ds_svcdt_ind. and &ds_filldt_ind.=0 %then %do;
			proc datasets lib=&incoming_library. nolist;
				modify &incoming_dataset.;
					rename svcdt=rx_fill_date;
			quit;
		%end;

		data edw_person_pharmacy(keep=	provider_key person_key payer_key 
										rx_fill_date is_refill days_supply metric_units ndc_key drug_strength is_generic 
										therapeutic_formulary_pfkey dispensed_as_written_pfkey pharmacy_prescription_number claim_type_pfkey
										payer_rx_claim_number is_reversal etl_source_key 
										created_wflow_exec_id created_on created_by 
										is_deleted rx_source_unique_id
										%if &ds_paiddt_ind. 	> 0 %then %do; 	paid_date 	%end;
										%if &ds_billedamt_ind. 	> 0 %then %do; 	billed_amt 	%end;
										%if &ds_allowedamt_ind. > 0 %then %do; 	allowed_amt %end;
										%if &ds_paidamt_ind. 	> 0 %then %do; 	paid_amt 	%end;
										%if &ds_copayamt_ind. 	> 0 %then %do;	copay_amt 	%end;
										ndc_code_from_raw_data drug_name_from_raw_data
								)
			 nl_hold_person_pharmacy(keep=	payer_key rx_source_unique_id person_key datasourceid dq_member_flag etl_source_key 
											created_wflow_exec_id created_on);
			set &incoming.(rename=(practice_id=datasourceid));
			if is_reversal then is_deleted=1; 
			else is_deleted=0;
			created_wflow_exec_id=&wflow_exec_id.;
			created_on=datetime();
			created_by=&sasprogramby.;
			if dq_member_flag=0 then output edw_person_pharmacy;
			else output nl_hold_person_pharmacy;
		run;

		%set_error_flag;
	  	%on_error(ACTION=ABORT);

		%let ds_id=%sysfunc(open(edw_person_pharmacy));
		%let tgt_record_cnt=%sysfunc(attrn(&ds_id.,nobs));
		%let ds_rc=%sysfunc(close(&ds_id.));

		%bulkload_to_cio(&wflow_exec_id.,edw_person_pharmacy,
							m_desttable=ciedw.dbo.person_pharmacy,
							m_isdecimal=billed_amt allowed_amt paid_amt copay_amt,
							m_isdate=rx_fill_date paid_date,
							m_isdatetime=created_on);
		%set_error_flag;
	  	%on_error(ACTION=ABORT);

		%bulkload_to_cio(&wflow_exec_id.,nl_hold_person_pharmacy,
							m_desttable=cihold.dbo.nl_hold_person_pharmacy,
							m_isdatetime=created_on);
		%set_error_flag;
	  	%on_error(ACTION=ABORT);

		/*SASDOC--------------------------------------------------------------------------
		| Change is_delete column based on payer-specific logic
		+------------------------------------------------------------------------SASDOC*/ 
		%payer_rx_reversal_dataformat&dataformatid.(&payer_key.,&wflow_exec_id.);

		/* Rename staging dataset so that we know it is pharmacy data */
		proc datasets lib=&incoming_library. nolist;
			change &incoming_dataset.=rx_&incoming_dataset.;
		quit;

		/*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to start.   
		+------------------------------------------------------------------------SASDOC*/ 
		%bpm_process_control(timevar=COMPLETE)

	%end;  /** end - incoming **/
	%else %do;
		%put NOTE: The dataset &incoming. does not exists ;
		%let err_fl=1;
		%set_error_flag;
	  	%on_error(ACTION=ABORT);
	%end;

	%macro send_email_alert;
		filename mail_out email to=("bstropich@valencehealth.com" "bfletcher@valencehealth.com" "gliu@valencehealth.com" "wlee@valencehealth.com" "EDWPROD@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - Complete";

		data _null_;
			file mail_out lrecl=32767;
			put "Payer Pharmacy Claims Extract";
			put "client ID = &client_id."; 
			put "DataSourceID = &practice_id.";
			put "Payer Key = &payer_key.";
			put "Batch_Key = &batch_key.";		
		run;
	%mend send_email_alert;
	%send_email_alert


	%if %sysfunc(exist(&incoming._plmk)) %then %do;
		proc sql; 
			drop table &incoming._plmk; 
		quit;
	%end;

%mend edw_payer_pharmacy_load;

%edw_payer_pharmacy_load(incoming=cistage.claims_&practice_id._&client_id._&wflow_exec_id.)
