
/*HEADER------------------------------------------------------------------------
|
| program:  cihold_hold_practice.sas
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

%macro cihold_hold_practice (in_dataset=);

	%local count_hold ;

	%let count_hold=0;

    proc sql noprint;
	  delete *
	  from cihold.hold_practice
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

	%put NOTE: practice Hold Count: &count_hold. ;

	%if &count_hold. ne 0 %then %do;	

		%let src_record_cnt=&count_hold.;
		%let tgt_record_cnt=&count_hold.;

	    data hold_practice;
		  set &in_dataset.;
	      where validation_id > 0 and validation_id ne .;
		  if validation_id in (12,13,14,76,77,78) then load_flag = 1;  	/** new, term, change  **/
		  else load_flag = 0;                              		/** critical           **/
		run;

		proc sql;
		  insert into cihold.hold_practice
		   (	wflow_exec_id,
				client_key,
				practice_name,  		
				practice_mgt_key,
				tin,	
				tin_name,
				npi2,  		
				data_category,  		
				vmine_installed_sched,  			
				vmine_installed_date,  			
				vmine_installer_name,  				
				vmine_status,
				practice_eff_date,
				practice_exp_date,
				ci_status,
				data_cmplt_ind,  		
				load_flag, 
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by,
				vsource_practice_key,
				is_vsource_data,
				is_payer_data
		   )
			  select distinct
				wflow_exec_id,
				client_key,
				practice_name,  		
				practice_mgt_key,
				tin,	
				tin_name,
				npi2,  		
				data_category,  		
				vmine_installed_sched,  			
				vmine_installed_date,  			
				vmine_installer_name,  				
				vmine_status,
				practice_eff_date,
				practice_exp_date,
				ci_status,
				data_cmplt_ind,  		
				load_flag, 
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by,
				vsource_practice_key,
				is_vsource_data,
				0
			  from hold_practice ;
			quit;

	%end;

%mend cihold_hold_practice;
