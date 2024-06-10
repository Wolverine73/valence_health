/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_payer_pharmacy_extract.sas
|
| LOCATION: M:\CI\programs\Development\EDW
|
| PURPOSE: Extract payer pharmacy data from a view in VHSTAGE_PAYER                                
|           
| INPUT: view in VHSTAGE_PAYER                                       
|
| OUTPUT: cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.;                          
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JUN2012 - Winnie Lee/G Liu - Clinical Integration Release v1.3.H01
|			  Original
+-----------------------------------------------------------------------HEADER*/

/*SASDOC----------------------------------------------------------------------
| Define SAS macros for program                                               
+----------------------------------------------------------------------SASDOC*/
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
%let sysparm=%str(wflow_exec_id=816 SK_PRCS_CTRL_ID=791 client_id=15 sas_prgm_id=47 system_id=0 practice_id=1380 batch_key=3 filename=1380-batchkey3 file_directory=); 
/*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*/ 
/*%let sysparm=%str(wflow_exec_id=49185 SK_PRCS_CTRL_ID=10326 client_id=15 sas_mode=test sas_prgm_id=47 system_id=0 practice_id=1380 batch_key=2 filename=1380-batchkey2 file_directory=);*/
%bpm_environment; 


%macro edw_payer_pharmacy_extract;
	%let do_practice_id=&practice_id.;

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.        
	+------------------------------------------------------------------------SASDOC*/ 
	%bpm_process_control(timevar=START);

	/*SASDOC--------------------------------------------------------------------------
	| Information on DataSourceID.        
	+------------------------------------------------------------------------SASDOC*/ 
	%data_source_information;

	%put NOTE: dataformatid  		= &dataformatid. ;
	%put NOTE: dataformatgroupid 	= &dataformatgroupid. ;
	%put NOTE: dataformatgroupdesc 	= &dataformatgroupdesc. ;
	%put NOTE: payer_key 			= &payer_key.;

	%set_error_flag;
	%on_error(ACTION=ABORT);

	/*SASDOC--------------------------------------------------------------------------
	| Extract from payer pharmacy view.        
	+------------------------------------------------------------------------SASDOC*/ 
	%payer_rx_view_dataformatid_&dataformatid.;

	/*SASDOC--------------------------------------------------------------------------
	| Set up variables.        
	+------------------------------------------------------------------------SASDOC*/ 

	%let ds_id			= %sysfunc(open(payer_rx_view_&do_practice_id.));
	%let ds_paiddt_ind	= %sysfunc(varnum(&ds_id.,paid_date));
	%let ds_rc			= %sysfunc(close(&ds_id.));

	data payer_pharmacy_&do_practice_id. (index = (npi) 
										  drop = _dob rx_fill_date 
												  %if &ds_paiddt_ind. %then %do; _paid_date %end;);
		length 	payer_key dob svcdt %if &ds_paiddt_ind. %then %do; paid_date %end; 8. drug_strength $30. pharmacy_rx_number payer_rx_claim_number $50. tin $9.;
		format 	dob svcdt %if &ds_paiddt_ind. %then %do; paid_date %end; mmddyy10.;

		set payer_rx_view_&do_practice_id. (rename = (dob=_dob 
													  %if &ds_paiddt_ind. %then %do; paid_date=_paid_date %end;
											));

		payer_key 	= &payer_key.;
		dob   		= input(_dob, yymmdd10.);
		svcdt		= input(rx_fill_date, yymmdd10.);
		%if &ds_paiddt_ind. %then %do; paid_date = input(_paid_date, yymmdd10.); %end;
		tin 		= '';

		rename pharmacy_rx_number=pharmacy_prescription_number;
	run;


	%set_error_flag;
	%on_error(ACTION=ABORT);

	/* Rename if view has different variable name */
	%let ds_id					= %sysfunc(open(payer_pharmacy_&do_practice_id.));
	%let ds_dispense_bad_ind	= %sysfunc(varnum(&ds_id.,dispensed_as_written_flag_pfkey));
	%let ds_dispense_good_ind	= %sysfunc(varnum(&ds_id.,dispensed_as_written_pfkey));
	%let ds_rc					= %sysfunc(close(&ds_id.));
	%if &ds_dispense_bad_ind. and &ds_dispense_good_ind.=0 %then %do;
		proc datasets lib=work nolist;
			modify payer_pharmacy_&do_practice_id.;
				rename dispensed_as_written_flag_pfkey=dispensed_as_written_pfkey;
		quit;
	%end;
	
	/*SASDOC--------------------------------------------------------------------------
	| Source Extract Count.        
	+------------------------------------------------------------------------SASDOC*/ 
	%let dsid			= %sysfunc(open(payer_pharmacy_&do_practice_id.));
	%let src_record_cnt	= %sysfunc(attrn(&dsid.,nobs));
	%let dsrc			= %sysfunc(close(&dsid.));

  	%put NOTE: Source Extract Count = &src_record_cnt.;

	%if &src_record_cnt. > 0 %then %do;
		/*SASDOC--------------------------------------------------------------------------
		| Get PROVIDER_KEY.        
		+------------------------------------------------------------------------SASDOC*/ 
/*		%edw_primsec_provider_xref(&client_id.,m2_inset=payer_pharmacy_&do_practice_id.);*/

		proc sql;
			connect to oledb(init_string=&ciedw. readbuff=10000);
			create table provider as 
			select 	*, count(*) as dupcnt
			from 	connection to oledb
					(	select
							npi1 as npi,
							provider_key,
							provider_name
						from ciedw.dbo.provider
						where client_key = &client_id and provider_key > 0 and npi1 is not null
					)
			group by npi
			order by npi;
		quit;

		data _null_;
			set provider;
			where dupcnt ne 1;
			if _n_=1 then put 'NPI with multiple provider keys';
			put _all_;
		run;
		
		/*SASDOC--------------------------------------------------------------------------
		| SAS - Output permanent SAS dataset in staging area.        
		+------------------------------------------------------------------------SASDOC*/ 
		data cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.(drop=tin dupcnt);
			if _n_=0 then do;
				set ciedw.cds_ndc(keep=ndc_code_no_dash ndc_key);
				set provider(keep=npi provider_key dupcnt);
			end;
			declare hash h_ndc(dataset:'ciedw.cds_ndc(keep=ndc_code_no_dash ndc_key))');
			h_ndc.defineKey('ndc_code_no_dash');
			h_ndc.defineData('ndc_key');
			h_ndc.defineDone();
			declare hash h_prov(dataset:'provider(keep=npi provider_key dupcnt where=(dupcnt=1))');
			h_prov.defineKey('npi');
			h_prov.defineData('provider_key');
			h_prov.defineDone();
			call missing(ndc_code_no_dash,ndc_key,npi,provider_key);

			do while (not lstobs);
				provider_key=.; ndc_key=.;
				format member_key 16.;
				set payer_pharmacy_&do_practice_id. end=lstobs;
				source='R';
				group_id=&practice_id.; 
				practice_id=&practice_id.;
				dq_claim_flag=0;
				member_key=0; dq_member_flag=0;
				dq_member_flag=0;
				wflow_exec_id=&wflow_exec_id.; 
				historical=2;
				etl_source_key = &dataformatgroupid.;
				claim_key=_n_;
				claim_exists_key=0;
				if h_ndc.find() or h_prov.find() then output;
				else output;
			end;
		run;

		%set_error_flag;
		%on_error(ACTION=ABORT);


		/*SASDOC--------------------------------------------------------------------------
		| Source Target Count.        
		+------------------------------------------------------------------------SASDOC*/ 
		%let dsid			= %sysfunc(open(cistage.claims_&do_practice_id._&client_id._&wflow_exec_id.));
		%let tgt_record_cnt	= %sysfunc(attrn(&dsid.,nobs));
		%let dsrc			= %sysfunc(close(&dsid.));

		%put NOTE: Source Target Count = &tgt_record_cnt.;
	%end;

	%else %do; /*** when src_target_cnt is not greater than 0 ***/

		%let tgt_record_cnt = 0;
		%put NOTE: Source Target Count = &tgt_record_cnt.;

		%put ERROR: There are no pharmacy claims from BATCH_KEY=&batch_key. within payer_pharmacy_view_dataformatid_&dataformatid.;

		%macro send_email_alert;
			filename mail_out email to=("bstropich@valencehealth.com" "bfletcher@valencehealth.com" "gliu@valencehealth.com" "wlee@valencehealth.com" "EDWPROD@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - No Pharmacy Claims from BATCH_KEY=&batch_key. within payer_pharmacy_view_dataformatid_&dataformatid..";

			data _null_;
				file mail_out lrecl=32767;  
				put "Payer Pharmacy Claims Load";
				put "client ID = &client_id."; 
				put "DataSourceID = &practice_id.";
				put "Payer Key = &payer_key.";
				put "Batch_Key = &batch_key.";	
			run;
		%mend send_email_alert;
		%send_email_alert;

		%bpm_additional_validations(validation_rule=74,validation_count=0);

		%let err_fl=1;
		%set_error_flag;
		%on_error(ACTION=ABORT);	

	%end;

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*/
	%bpm_process_control(timevar=COMPLETE);

%mend edw_payer_pharmacy_extract;

/*SASDOC--------------------------------------------------------------------------
| Execute macro
------------------------------------------------------------------------SASDOC*/
%edw_payer_pharmacy_extract;

