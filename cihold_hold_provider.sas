
/*HEADER------------------------------------------------------------------------
|
| program:  cihold_hold_provider.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:   
|
| logic:     
|           
|
| input:               
|
| output:    
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro cihold_hold_provider (in_dataset=);

	%local count_hold condition_validation_type_id;

	%let count_hold=0;

    proc sql noprint;
	  delete *
	  from cihold.hold_provider
	  where wflow_exec_id = &wflow_exec_id. ;
	quit;	

	%let varexist_id=%sysfunc(open(&in_dataset.));
	%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_id));
	%let varexist_rc=%sysfunc(close(&varexist_id.));

	%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;	

	%if &varexist_ind. > 0 %then %do; 
	    proc sql noprint;
		  select count(*) into: count_hold
		  from &in_dataset.
	      where validation_id ne 0;
		quit;
	%end;

	%put NOTE: Provider Hold Count: &count_hold. ;

	%if &count_hold. ne 0 %then %do;	

		%let src_record_cnt=&count_hold.;
		%let tgt_record_cnt=&count_hold.;
		
		proc sql noprint;
		  select validation_type_id into: condition_validation_type_id separated by ','
		  from vbpm.validation_type
		  where load_flag=1;
		quit;
		
		%put NOTE: condition_validation_type_id = &condition_validation_type_id;

	    data hold_provider;
		  set &in_dataset.;
	      where validation_id ne 0;
		  if validation_id in (&condition_validation_type_id.) then load_flag = 1;  /** new, term, change  **/
		  else load_flag = 0;                              /** critical           **/
		run;

		proc sql;
		  insert into cihold.hold_provider
		   (	wflow_exec_id,
				client_key,
				validation_type_id,		
				provider_name,  		
				provider_title,
				network_status,	
				ci_status,
				clncl_int_eff_dt,  		
				clncl_int_exp_dt,  		
				network_eff_dt,  			
				network_exp_dt,  			
				dea,  				
				npi1,
				data_cmplt_ind,  		
				manual_rpt_ind, 
				load_flag, 
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by,
				is_attributable,
				vsource_provider_key,
				is_vsource_data,
				is_payer_data
		   )
			  select distinct
				wflow_exec_id,
				client_key,
				validation_type_id,	
				provider_name,  		
				provider_title,
				network_status,	
				ci_status,
				clncl_int_eff_dt,  		
				clncl_int_exp_dt,  		
				network_eff_dt,  			
				network_exp_dt,  			
				dea,  				
				npi1,	
				data_cmplt_ind,  		
				manual_rpt_ind, 
				load_flag, 
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by,
				is_attributable,
				vsource_provider_key,
				is_vsource_data,
				0
			  from hold_provider ;
			quit;

	%end;

%mend cihold_hold_provider;
