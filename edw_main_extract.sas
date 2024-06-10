
/*HEADER------------------------------------------------------------------------
|
| program:  edw_main_extract.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create driver program to handle vmine and non-vmine data  
|
| logic:    
|              
|
| input:    Macro parameters and /or SQL server practices
|           sas_prgm_id - the sas program id (e.g., 27)
|           system_id   - the pm system id from vmine (e.g., 1=Medisoft) 
|           practice_id - opitional field but the practice id from vmine (e.g., 256) 
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|           filename - files to be processed (e.g., 710-20110825T09400000.txt)
|                        
| output:   
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
| 13JUN2011 - G Liu - Clinical Integration 1.3.01
|			  Add programs for payor medical (ub & hcfa) data. 
|				Rx does not use this main_extract.
+-----------------------------------------------------------------------HEADER*/


*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
options bufsize=600k; 


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment; 


*SASDOC--------------------------------------------------------------------------
| Macro -  edw_main_extract       
|
| Determine if vmine or non-vmine and execute the routine
------------------------------------------------------------------------SASDOC*; 
%macro edw_main_extract;

	%data_source_information;

	%put NOTE: edw_directory = &edw_directory. ;
	
	
	%*SASDOC----------------------------------------------------------------------
	| vmine data source
	+----------------------------------------------------------------------SASDOC*;
	%if  &dataformatid. = 6 %then %do; 
	  %include "&edw_directory.\edw_vmine_extract.sas";
	%end;
	%*SASDOC----------------------------------------------------------------------
	| 837 Professional data source
	+----------------------------------------------------------------------SASDOC*;
	%else %if &dataformatid. = 47 %then %do; 
		%include "&edw_directory.\edw_837_professional_extract.sas";
	%end;
	%*SASDOC----------------------------------------------------------------------
	| 837 Institutional data source
	+----------------------------------------------------------------------SASDOC*;
	%else %if &dataformatid. = 56 %then %do;
		%include "&edw_directory.\edw_837_institutional_extract.sas";
	%end;
	%*SASDOC----------------------------------------------------------------------
	| HL7 data source
	+----------------------------------------------------------------------SASDOC*;
	%else %if &dataformatid. = 53 or &dataformatgroupid. = 16 %then %do; /** HL7 data source **/
		%include "&edw_directory.\edw_HL7_extract.sas";
	%end;
	%*SASDOC----------------------------------------------------------------------
	| Payer Medical (UB & HCFA) data source
	+----------------------------------------------------------------------SASDOC*;
	%else %if &dataformatgroupid.=20 %then %do;
		%if &PayerContainUB. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._ub_batch&batch_key.)) and
			&PayerContainHCFA. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._hcfa_batch&batch_key.)) %then %do;
			%put NOTE: Both UB and HCFA claims have been processed for client &client_id. payer &payer_key. data with dataformatgroup &dataformatgroupid. for batch &batch_key.;
			%put ERROR: There is nothing else to process;
			%let err_fl=1;
			%set_error_flag;
		  	%on_error(ACTION=ABORT);		
		%end;
		%else %if &PayerContainHCFA.=0 and &PayerContainUB. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._ub_batch&batch_key.)) %then %do;
			%put NOTE: UB claims have been processed for client &client_id. payer &payer_key. data with dataformatgroup &dataformatgroupid. for batch &batch_key.;
			%put ERROR: Payer does not provide HCFA claims; there is nothing else to process;
			%let err_fl=1;
			%set_error_flag;
		  	%on_error(ACTION=ABORT);		
		%end;
		%else %if &PayerContainUB.=0 and &PayerContainHCFA. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._hcfa_batch&batch_key.)) %then %do;
			%put NOTE: HCFA claims have been processed for client &client_id. payer &payer_key. data with dataformatgroup &dataformatgroupid. for batch &batch_key.;
			%put ERROR: Payer does not provide UB claims; there is nothing else to process;
			%let err_fl=1;
			%set_error_flag;
		  	%on_error(ACTION=ABORT);		
		%end;
		%else %do;
			%include "&edw_directory.\edw_payer_medical_extract.sas";
		%end;
	%end;
	%*SASDOC----------------------------------------------------------------------
	| non-vmine data source
	+----------------------------------------------------------------------SASDOC*;
	%else %do;
	  %include "&edw_directory.\edw_nonvmine_extract.sas";
	%end;
	

%mend edw_main_extract;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
%edw_main_extract;
