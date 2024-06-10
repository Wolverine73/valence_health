/*HEADER------------------------------------------------------------------------
|
| program:  edw_provider_validations.sas
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
| 08JUN2012 - Winnie Lee - Release 1.3 H01
|			  Modify to accomodate providers from payer data
+-----------------------------------------------------------------------HEADER*/


%macro edw_provider_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, by_variable=, by_variable2=);

    %local count_new count_new_facilities count_term count_term_facilities count_change count_change_facilties count_critical count_critical_facilities;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW PROVIDERS
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;

	    %put NOTE: Performing EDW - Providers validations for the CI program - NEW ;

		proc sql noprint;
			create table edw_provider_validate_new as
				select distinct
					&wflow_exec_id. 				as wflow_exec_id,
					a.&by_variable. 				as vld_value,
					a.&by_variable2. 				as entity_id,  
					a.&by_variable. 				as npi1,
					a.&by_variable2.				as vsource_provider_key,
					a.client_key,
					&oldval.    					as old_val length=50,
					&newval.    					as new_val length=50,
					97 								as val_type,
					&validation_type_id.    		as validation_type_id
				from &in_dataset1. as a left join 
					 &in_dataset2. as b on a.&by_variable. = b.&by_variable. and a.client_key = b.client_key
				where a.client_key = &client_id. and b.&by_variable. = ''
			;
		quit;
		
		%let count_new_providers=0;

		proc sql noprint;
			select 
				count(*) into: count_new
			from edw_provider_validate_new ;
		quit;

		%put NOTE: Number of new vSource providers based on NPI - &count_new.;

		%if &count_new. ne 0 %then %do;		

			proc sort data = vsource_provider;
			by &by_variable. &by_variable2. client_key;
			run;

			proc sort data = edw_provider_validate_new  
			     	  out  = new (keep = &by_variable. &by_variable2. client_key validation_type_id);
			by &by_variable. &by_variable2. client_key;
			run;

			data vsource_provider;
			merge vsource_provider (in=a)
			      new              (in=b);
			by &by_variable. &by_variable2. client_key;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;

		%end;

		%put NOTE: Counts - Providers validations for the CI program - NEW:  &count_new. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW FACILITY
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW_FACILITY %then %do;

	    %put NOTE: Performing EDW - Facliity validations for the CI program - NEW ;

		proc sql noprint;
			create table edw_facility_validate_new as
				select distinct
					&wflow_exec_id. 				as wflow_exec_id,
					left(put(a.&by_variable.,30.))	as vld_value,
					a.&by_variable. 				as entity_id,  
					a.&by_variable. 				as vsource_provider_key,
					a.client_key,
					&oldval.    					as old_val length=50,
					&newval.    					as new_val length=50,
					97 								as val_type,
					&validation_type_id.    		as validation_type_id
				from &in_dataset1. as a left join 
					 &in_dataset2. as b on a.&by_variable. = b.&by_variable.
				where a.client_key = -&client_id. and b.&by_variable. = .
			;
		quit;
		
		%let count_new_facilities=0;

		proc sql noprint;
			select 
				count(*) into: count_new_facilities
			from edw_facility_validate_new ;
		quit;

		%put NOTE: Number of new vSource facilitites - &count_new_facilities.;

		%if &count_new_facilities. ne 0 %then %do;		

			proc sort data = vsource_provider;
			by &by_variable. client_key;
			run;

			proc sort data = edw_facility_validate_new  
			     	  out  = new_facility (keep = &by_variable. client_key validation_type_id);
			by &by_variable. client_key;
			run;

			data vsource_provider;
			merge vsource_provider (in=a)
			      new_facility     (in=b);
			by &by_variable. client_key;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;

		%end;

		%put NOTE: Counts - Facility validations for the CI program - NEW:  &count_new_facilities. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR TERMED PROVIDERS
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = TERM %then %do;

	    %put NOTE: Performing EDW - Providers validations for the CI program - TERM ;

		proc sql noprint;
			create table edw_provider_validate_term as
				select  
					&wflow_exec_id. 					as wflow_exec_id,
					a.&by_variable. 					as vld_value,
					a.&by_variable2. 					as entity_id,  
					substr(left(a.&by_variable.),1,10) 	as npi1,
					a.&by_variable2. 					as vsource_provider_key,
					a.client_key,
					&oldval.    						as old_val length=50,
					&newval.    						as new_val length=50,
					98									as val_type,
					&validation_type_id.    			as validation_type_id
				from &in_dataset1. as a
				where (a.clncl_int_exp_dt = . or a.clncl_int_exp_dt is null) and 
					   a.client_key = &client_id. and
					   a.vsource_provider_key ne . and
					   a.&by_variable. in 
						(
							select &by_variable.
						    from &in_dataset2. as b
						    where b.clncl_int_exp_dt ne . and b.client_key=&client_id. and b.&by_variable. ne ''
						) 
			;
		quit;
		
		%let count_term=0;		

		proc sql noprint;
			select 
				count(*) into: count_term
			from edw_provider_validate_term ;
		quit;

		%put NOTE: Number of vSource providers termed - &count_term.;
		
		%if &count_term. ne 0 %then %do;		

			proc sort data = VSOURCE_PROVIDER;
			by &by_variable. &by_variable2. client_key;
			run;

			proc sort data = edw_provider_validate_term  
			  		  out  = term (keep = &by_variable. &by_variable2. client_key validation_type_id);
			by &by_variable. &by_variable2. client_key;
			run;

			data VSOURCE_PROVIDER;
			merge VSOURCE_PROVIDER (in=a)
				  term 			   (in=b);
			by &by_variable. &by_variable2. client_key;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Providers validations for the CI program - TERM:  &count_term. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR TERMED FACILITIES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = TERM_FACILITY %then %do;

	    %put NOTE: Performing EDW - Facility validations for the CI program - TERM ;

		proc sql noprint;
			create table edw_facility_validate_term as
				select  
					&wflow_exec_id. 					as wflow_exec_id,
					left(put(a.&by_variable.,30.))		as vld_value,
					a.&by_variable. 					as entity_id,  
					a.&by_variable. 					as vsource_provider_key,
					&oldval.    						as old_val length=50,
					&newval.    						as new_val length=50,
					98									as val_type,
					&validation_type_id.    			as validation_type_id
				from &in_dataset1. as a
				where (a.clncl_int_exp_dt = . or a.clncl_int_exp_dt is null) and 
					   a.&by_variable. ne . and
					   a.&by_variable. in 
						(
							select &by_variable.
						    from &in_dataset2. as b
						    where b.clncl_int_exp_dt ne . and b.client_key=-&client_id. and b.&by_variable. ne .
						) 
			;
		quit;
		
		%let count_term_facilities=0;		

		proc sql noprint;
			select 
				count(*) into: count_term_facilities
			from edw_facility_validate_term ;
		quit;
		
		%if &count_term_facilities. ne 0 %then %do;		

			proc sort data = VSOURCE_PROVIDER;
			by &by_variable.;
			run;

			proc sort data = edw_facility_validate_term  
			  		  out  = term_facility (keep = &by_variable. validation_type_id);
			by &by_variable.;
			run;

			data VSOURCE_PROVIDER;
			merge VSOURCE_PROVIDER (in=a)
				  term_facility	   (in=b);
			by &by_variable.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Facility validations for the CI program - TERM:  &count_term_facilities. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED PROVIDERS
	|
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE %then %do;

	    %put NOTE: Performing EDW - Providers validations for the CI program - CHANGE ;

		proc sql;
			 connect to oledb(init_string=&ciedw.);
    		 	create table ciedw_provider as select * from connection to oledb
    		 (
				select 
					provider_key,
					vsource_provider_key,
					client_key,
					provider_name,
					provider_title,
					network_status,
					ci_status,
					clncl_int_eff_dt,
					clncl_int_exp_dt,
					network_eff_dt,
					network_exp_dt,
					dea,
					substring(npi1,1,10) as npi1,
					data_cmplt_ind,
					manual_rpt_ind,
					wflow_exec_id,
					created_on,
					created_by,
					updated_on,
					updated_by,
					sas_prov_id,
					case when is_attributable is null then 0
			 			 when is_attributable = 0 then 0			 
			 			 else 1												end is_attributable,
					case when is_vsource_data = 0 then 0
						 else 1												end is_vsource_data
				from dbo.provider
				where client_key = &client_id. and provider_key > 0 and npi1 is not null
			)
			 ;
		quit;

	    proc sql noprint;
		  create table edw_provider_validate_change as
		  select  
		    &wflow_exec_id. 												as wflow_exec_id,
		    a.&by_variable.													as vld_value,
			a.&by_variable2. 												as entity_id, 
			a.&by_variable2.												as vsource_provider_key,
			a.&by_variable. 												as npi1,
			a.client_key,
			case when a.specialty_code	 	 ne d.specialty_code		then d.specialty_code	
				 when a.dea  			 	 ne b.dea   				then b.dea	
				 when a.clncl_int_exp_dt 	 ne b.clncl_int_exp_dt		then put(b.clncl_int_exp_dt,datetime22.3)		
				 when a.clncl_int_eff_dt 	 ne b.clncl_int_eff_dt		then put(b.clncl_int_eff_dt,datetime22.3)
				 when a.ci_status		 	 ne b.ci_status				then b.ci_status	
				 when a.network_exp_dt 	 	 ne b.network_exp_dt		then put(b.network_exp_dt,datetime22.3)			
				 when a.network_eff_dt 	 	 ne b.network_eff_dt		then put(b.network_eff_dt,datetime22.3)	
				 when a.network_status	 	 ne b.network_status		then b.network_status
				 when a.data_cmplt_ind	 	 ne b.data_cmplt_ind		then b.data_cmplt_ind		
				 when a.manual_rpt_ind	 	 ne b.manual_rpt_ind		then b.manual_rpt_ind		
				 when a.provider_name	 	 ne b.provider_name 		then b.provider_name		
				 when a.provider_title	 	 ne b.provider_title 		then b.provider_title
				 when a.is_attributable  	 ne b.is_attributable		then put(b.is_attributable,1.)	
				 when a.is_vsource_data  	 ne b.is_vsource_data   	then put(b.is_vsource_data,1.)
				 when a.vsource_provider_key ne b.vsource_provider_key 	then cats(b.vsource_provider_key)
				 else "NULL"												end	as old_val length=50, 															
			case when a.specialty_code	 	 ne d.specialty_code		then a.specialty_code	
				 when a.dea  			 	 ne b.dea   				then a.dea				
				 when a.clncl_int_exp_dt 	 ne b.clncl_int_exp_dt		then put(a.clncl_int_exp_dt,datetime22.3)		
				 when a.clncl_int_eff_dt 	 ne b.clncl_int_eff_dt		then put(a.clncl_int_eff_dt,datetime22.3)
				 when a.ci_status		 	 ne b.ci_status				then a.ci_status	
				 when a.network_exp_dt 	 	 ne b.network_exp_dt		then put(a.network_exp_dt,datetime22.3)
				 when a.network_eff_dt 	 	 ne b.network_eff_dt		then put(a.network_eff_dt,datetime22.3)
				 when a.network_status	 	 ne b.network_status		then a.network_status
				 when a.data_cmplt_ind	 	 ne b.data_cmplt_ind		then a.data_cmplt_ind		
				 when a.manual_rpt_ind	 	 ne b.manual_rpt_ind		then a.manual_rpt_ind		
				 when a.provider_name		 ne b.provider_name 		then a.provider_name		
				 when a.provider_title	 	 ne b.provider_title 		then a.provider_title
				 when a.is_attributable  	 ne b.is_attributable		then put(a.is_attributable,1.)
				 when a.is_vsource_data  	 ne b.is_vsource_data		then put(a.is_vsource_data,1.)
				 when a.vsource_provider_key ne b.vsource_provider_key 	then cats(a.vsource_provider_key)
				 else "NULL"											end	as new_val length=50, 														
		    	 99															as val_type,
				 &validation_type_id.    									as validation_type_id
		  from &in_dataset1. 					as a inner join
		       ciedw_provider 					as b on a.&by_variable. = b.&by_variable. and 
														a.client_key = &client_id. and 
														a.&by_variable. ne '' and 
														b.&by_variable. ne '' and
														b.provider_key > 0 left outer join
			   ciedw.provider_specialty_xref 	as c on b.provider_key = c.provider_key and 
														c.provider_key > 0 and 
														c.isPrimary ne 0 and 
														c.isPrimary ne -0 left outer join
			   ciedw.specialty 					as d on c.specialty_key = d.specialty_key
		  where a.clncl_int_exp_dt = . and a.&by_variable. ne '' and b.&by_variable ne '' and b.provider_key > 0
		    and (
				a.PROVIDER_NAME 		ne b.PROVIDER_NAME 		or 
				a.PROVIDER_TITLE 		ne b.PROVIDER_TITLE 	or 
				a.CI_STATUS				ne b.CI_STATUS			or
				a.NETWORK_STATUS 		ne b.NETWORK_STATUS 	or
				a.CLNCL_INT_EFF_DT 		ne b.CLNCL_INT_EFF_DT 	or
				a.CLNCL_INT_EXP_DT 		ne b.CLNCL_INT_EXP_DT 	or
				a.NETWORK_EFF_DT 		ne b.NETWORK_EFF_DT 	or
				a.NETWORK_EXP_DT 		ne b.NETWORK_EXP_DT 	or
				a.DEA 					ne b.DEA 				or
				a.NPI1 					ne b.NPI1 				or
				a.DATA_CMPLT_IND 		ne b.DATA_CMPLT_IND 	or
				a.MANUAL_RPT_IND 		ne b.MANUAL_RPT_IND 	or
				a.SPECIALTY_CODE		ne d.SPECIALTY_CODE		or
				a.IS_ATTRIBUTABLE		ne b.IS_ATTRIBUTABLE	or
				a.IS_VSOURCE_DATA		ne b.IS_VSOURCE_DATA	or
				a.VSOURCE_PROVIDER_KEY 	ne b.VSOURCE_PROVIDER_KEY
				);
		quit;
		
		%let count_change=0;		

		proc sql noprint;
		select 
			count(*) into: count_change
		from edw_provider_validate_change;
		quit;

		%put NOTE: Number of changed vSource providers - &count_change.;
		
		%if &count_change. ne 0 %then %do;		

			proc sort data = VSOURCE_PROVIDER;
			by &by_variable. &by_variable2. client_key;
			run;

			proc sort data = edw_provider_validate_change  
			          out  = change (keep = &by_variable. &by_variable2. client_key validation_type_id);
			by &by_variable. client_key;
			run;

			data VSOURCE_PROVIDER;
			merge VSOURCE_PROVIDER (in=a)
			      change 		   (in=b);
			by &by_variable. &by_variable2. client_key;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Providers validations for the CI program - CHANGE:  &count_change. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED FACILITIES
	|
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE_FACILITY %then %do;

	    %put NOTE: Performing EDW - Facility validations for the CI program - CHANGE ;

		proc sql;
			 connect to oledb(init_string=&ciedw.);
    		 	create table ciedw_facility as select * from connection to oledb
    		 (
				select 
					provider_key,
					vsource_provider_key,
					client_key,
					provider_name,
					provider_title,
					network_status,
					ci_status,
					clncl_int_eff_dt,
					clncl_int_exp_dt,
					network_eff_dt,
					network_exp_dt,
					dea,
					substring(npi1,1,10) as npi1,
					data_cmplt_ind,
					manual_rpt_ind,
					wflow_exec_id,
					created_on,
					created_by,
					updated_on,
					updated_by,
					sas_prov_id,
					case when is_attributable is null then 0
			 			 when is_attributable = 0 then 0			 
			 			 else 1												end is_attributable,
					case when is_vsource_data = 0 then 0
						 else 1												end is_vsource_data
				from dbo.provider
				where client_key = &client_id. and provider_key > 0 and vsource_provider_key is not null
			)
			 ;
		quit;

	    proc sql noprint;
		  create table edw_facility_validate_change as
		  select  
		    &wflow_exec_id. 												as wflow_exec_id,
		    left(put(a.&by_variable.,30.))									as vld_value,
			a.&by_variable. 												as entity_id, 
			a.&by_variable. 												as vsource_provider_key,
			a.client_key,
			case when a.dea  			 	 ne b.dea   				then b.dea	
				 when a.clncl_int_exp_dt 	 ne b.clncl_int_exp_dt		then put(b.clncl_int_exp_dt,datetime22.3)		
				 when a.clncl_int_eff_dt 	 ne b.clncl_int_eff_dt		then put(b.clncl_int_eff_dt,datetime22.3)
				 when a.ci_status		 	 ne b.ci_status				then b.ci_status	
				 when a.network_exp_dt 	 	 ne b.network_exp_dt		then put(b.network_exp_dt,datetime22.3)			
				 when a.network_eff_dt 	 	 ne b.network_eff_dt		then put(b.network_eff_dt,datetime22.3)	
				 when a.network_status	 	 ne b.network_status		then b.network_status
				 when a.data_cmplt_ind	 	 ne b.data_cmplt_ind		then b.data_cmplt_ind		
				 when a.manual_rpt_ind	 	 ne b.manual_rpt_ind		then b.manual_rpt_ind		
				 when a.provider_name	 	 ne b.provider_name 		then b.provider_name		
				 when a.provider_title	 	 ne b.provider_title 		then b.provider_title
				 when a.is_attributable  	 ne b.is_attributable		then put(b.is_attributable,1.)	
				 when a.is_vsource_data  	 ne b.is_vsource_data   	then put(b.is_vsource_data,1.)
				 else "NULL"										    end  as old_val length=50, 															
			case when a.dea  			 	 ne b.dea   				then a.dea				
				 when a.clncl_int_exp_dt 	 ne b.clncl_int_exp_dt		then put(a.clncl_int_exp_dt,datetime22.3)		
				 when a.clncl_int_eff_dt 	 ne b.clncl_int_eff_dt		then put(a.clncl_int_eff_dt,datetime22.3)
				 when a.ci_status		 	 ne b.ci_status				then a.ci_status	
				 when a.network_exp_dt 	 	 ne b.network_exp_dt		then put(a.network_exp_dt,datetime22.3)
				 when a.network_eff_dt 	 	 ne b.network_eff_dt		then put(a.network_eff_dt,datetime22.3)
				 when a.network_status	 	 ne b.network_status		then a.network_status
				 when a.data_cmplt_ind	 	 ne b.data_cmplt_ind		then a.data_cmplt_ind		
				 when a.manual_rpt_ind	 	 ne b.manual_rpt_ind		then a.manual_rpt_ind		
				 when a.provider_name		 ne b.provider_name 		then a.provider_name		
				 when a.provider_title	 	 ne b.provider_title 		then a.provider_title
				 when a.is_attributable  	 ne b.is_attributable		then put(a.is_attributable,1.)
				 when a.is_vsource_data  	 ne b.is_vsource_data		then put(a.is_vsource_data,1.)
				 else "NULL"											end	as new_val length=50, 														
		    	 99															as val_type,
				 &validation_type_id.    									as validation_type_id
		  from &in_dataset1. 					as a inner join
		       ciedw_facility 					as b on a.&by_variable. = b.&by_variable. and 
														a.client_key = -&client_id. and 
														b.provider_key > 0 
		  where a.clncl_int_exp_dt = . and b.provider_key > 0
		    and (
				a.PROVIDER_NAME 		ne b.PROVIDER_NAME 		or 
				a.PROVIDER_TITLE 		ne b.PROVIDER_TITLE 	or 
				a.CI_STATUS				ne b.CI_STATUS			or
				a.NETWORK_STATUS 		ne b.NETWORK_STATUS 	or
				a.CLNCL_INT_EFF_DT 		ne b.CLNCL_INT_EFF_DT 	or
				a.CLNCL_INT_EXP_DT 		ne b.CLNCL_INT_EXP_DT 	or
				a.NETWORK_EFF_DT 		ne b.NETWORK_EFF_DT 	or
				a.NETWORK_EXP_DT 		ne b.NETWORK_EXP_DT 	or
				a.DEA 					ne b.DEA 				or
				a.NPI1 					ne b.NPI1 				or
				a.DATA_CMPLT_IND 		ne b.DATA_CMPLT_IND 	or
				a.MANUAL_RPT_IND 		ne b.MANUAL_RPT_IND 	or
				a.IS_ATTRIBUTABLE		ne b.IS_ATTRIBUTABLE	or
				a.IS_VSOURCE_DATA		ne b.IS_VSOURCE_DATA
				);
		quit;
		
		%let count_change_facilties=0;		

		proc sql noprint;
		select 
			count(*) into: count_change_facilties
		from edw_facility_validate_change;
		quit;

		%put NOTE: Number of vSource facility changes - &count_change_facilties.;
		
		%if &count_change_facilties. ne 0 %then %do;		

			proc sort data = VSOURCE_PROVIDER;
			by &by_variable. client_key;
			run;

			proc sort data = edw_facility_validate_change  
			          out  = change_facility (keep = &by_variable. client_key validation_type_id);
			by &by_variable. client_key;
			run;

			data VSOURCE_PROVIDER;
			merge VSOURCE_PROVIDER (in=a)
			      change_facility  (in=b);
			by &by_variable. client_key;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Facility validations for the CI program - CHANGE:  &count_change_facilties. ;

	%end; 


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR PROVIDERS WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL %then %do;

	    %put NOTE: Performing EDW - Providers validations for the CI program - CRITICAL ;

		data edw_provider_validate_critical_a;
		set  Edw_provider_validate_new			(in=a keep=&by_variable. &by_variable2.)
			 Edw_provider_validate_change 		(in=b keep=&by_variable. &by_variable2.);
		run;

		proc sort data=edw_provider_validate_critical_a nodupkey;
		by &by_variable. &by_variable2.;
		run;

		data npidups;
		set &in_dataset1. (keep=&by_variable. &by_variable2.);
		where &by_variable ne '';
		run;

		proc sort data=npidups nodupkey;
		by &by_variable. &by_variable2.;
		run;

		data npidups2 (drop=&by_variable2.);
		set npidups;
		by &by_variable.;
		if first.&by_variable. and last.&by_variable. then delete;
		else do;
			length npi_duplicate 8.;
			npi_duplicate = 1;
			output;
		end;
		run;

		proc sql noprint;
			create table edw_provider_validate_critical_b as
				select  
					a.&by_variable.,
					b.npi_duplicate
				from edw_provider_validate_critical_a	as a left outer join
					 npidups2							as b on a.&by_variable. = b.&by_variable.
				order by a.&by_variable.
			;
		quit;

		data edw_provider_validate_critical_c;
		set edw_provider_validate_critical_b;
		%luhn_npi_check (&by_variable.);
		run;

		data provspecfmt (keep=fmtname type start label);
		set ciedw.specialty;
		length fmtname $11. type $1. start $2. label $1.;
		start = specialty_code;
		label = 'Y';
		retain fmtname 'provspecfmt' type 'C';
		output;
		if _n_ = 1 then do;
			start = '';
			label = 'N';
			output;
		end;
		run;

		proc sort data=provspecfmt nodupkey;
		by start;
		run;

		proc format cntlin=provspecfmt;
		run;

		proc sort data = &in_dataset1.;
		by &by_variable. client_key;
		run;

		%let varexist_id  = %sysfunc(open(&in_dataset1.));
		%let varexist_ind = %sysfunc(varnum(&varexist_id.,validation_type_id));
		%let varexist_rc  = %sysfunc(close(&varexist_id.));

		%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;

		data edw_provider_validate_critical (keep=wflow_exec_id vld_value entity_id &by_variable. old_val new_val val_type validation_type_id client_key);
		merge edw_provider_validate_critical_c (in=a)
		      &in_dataset1.					   (in=b  where=(client_key=&client_id.) %if &varexist_ind. > 0 %then %do; drop=validation_type_id %end;);
		by &by_variable.;
		if a then do;
		length wflow_exec_id 8. vld_value $30. entity_id vsource_provider_key 8. old_val new_val $50. val_type validation_type_id 8.;
		wflow_exec_id = &wflow_exec_id.;
		vld_value 	  = &by_variable.;
		entity_id	  = &by_variable2.;
		&by_variable. = &by_variable.;
		old_val		  = "NULL";
		new_val		  = "NULL";
		validation_type_id = .;
		if client_key = &client_id. then do;
			if upcase(ci_status) not in ("PAR","NONPAR") then do;
				new_val = ci_status;
				validation_type_id = 6;
			end;
			else if upcase(ci_status) = 'NONPAR' then do;
				if provider_name = "" then do;
					new_val = provider_name;
					validation_type_id = 4;
				end;
				else if npi1 = "" or length(npi1) ne 10 or npi_valid ne 1 then do;
					new_val = npi1;
					validation_type_id = 5;
				end;
	/*			else if clncl_int_exp_dt = . then do;*/
	/*				new_val = clncl_int_exp_dt;*/
	/*				validationt_type_id = ;*/
	/*			end;*/
			end;
			else if provider_name = "" then do;
				new_val = provider_name;
				validation_type_id = 4;
			end;
			else if npi1 = "" or length(npi1) ne 10 or npi_valid ne 1 then do;
				new_val = npi1;
				validation_type_id = 5;
			end;
			else if npi_duplicate = 1 then do;
				new_val = npi1;
				validation_type_id = 63;
			end;
			else if specialty_code = "" or put(specialty_code,$provspecfmt.) ne 'Y' or put(specialty_code,$provspecfmt.)=specialty_code then do;
				new_val = specialty_code;
				validation_type_id = 7;
			end;
			else if specialty_primary ne -1 or specialty_primary_count > 1 then do;
				new_val = specialty_code;
				validation_type_id = 8;
			end;
			else if tied_to_group = . then do;
				new_val = groupid;
				validation_type_id = 9;
			end;
		end;
		else if client_key = -&client_id. then do;
			if upcase(ci_status) not in ("PAR","NONPAR") then do;
				new_val = ci_status;
				validation_type_id = 6;
			end;
			else if provider_name = "" then do;
				new_val = provider_name;
				validation_type_id = 4;
			end;
			else if tied_to_group = . then do;
				new_val = groupid;
				validation_type_id = 9;
			end;
		end;
		val_type = 99;
		if validation_type_id ne . then output;
		end;
		run;
		
		%let count_critical=0;		

		proc sql noprint;
			select 
				count(*) into: count_critical
			from edw_provider_validate_critical;
		quit;

		%put NOTE: Number of critical vSource providers - &count_critical.;
		
		%if &count_critical. ne 0 %then %do;		


			proc sort data = VSOURCE_PROVIDER;
			by &by_variable. client_key;
			run;

			proc sort data = edw_provider_validate_critical  
			          out  = critical (keep = &by_variable. client_key validation_type_id);
			by &by_variable. client_key;
			run;

			data VSOURCE_PROVIDER;
			merge VSOURCE_PROVIDER (in=a)
				  critical 		   (in=b);
			by &by_variable. client_key;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Providers validations for the CI program - CRITICAL:  &count_critical. ;

	%end;


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR FACILITES WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL_FACILITY %then %do;

	    %put NOTE: Performing EDW - Facility validations for the CI program - CRITICAL ;

		data edw_facility_validate_critical_a;
		set  edw_facility_validate_new			(in=a keep=&by_variable.)
			 edw_facility_validate_change 		(in=b keep=&by_variable.);
		run;

		proc sort data=edw_facility_validate_critical_a nodupkey;
		by &by_variable.;
		run;

		data npidups;
		set &in_dataset1. (keep=&by_variable. &by_variable2. client_key);
		where &by_variable2. ne '';
		run;

		proc sort data=npidups nodupkey;
		by &by_variable2. &by_variable. ;
		run;

		data npidups2;
		set npidups;
		by &by_variable2.;
		if first.&by_variable2. and last.&by_variable2. then delete;
		else do;
			length npi_duplicate 8.;
			npi_duplicate = 1;
			output;
		end;
		run;

		proc sql noprint;
			create table edw_facility_validate_critical_b as
				select  
					a.&by_variable.,
					b.npi_duplicate
				from edw_facility_validate_critical_a	as a left outer join
					 npidups2							as b on a.&by_variable. = b.&by_variable.
				order by a.&by_variable.
			;
		quit;

		data edw_facility_validate_critical_c;
		length npi1 $10.;
		set edw_facility_validate_critical_b;
		%luhn_npi_check (&by_variable2.);
		run;

		proc sort data = &in_dataset1.;
		by &by_variable. client_key;
		run;

		%let varexist_id=%sysfunc(open(&in_dataset1.));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));

		%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;

		data edw_facility_validate_critical (keep=wflow_exec_id vld_value entity_id &by_variable. old_val new_val val_type validation_type_id client_key);
		merge edw_facility_validate_critical_c (in=a)
		      &in_dataset1.					   (in=b  where=(client_key=&client_id.) %if &varexist_ind. > 0 %then %do; drop=validation_type_id %end;);
		by &by_variable.;
		if a then do;
			length wflow_exec_id 8. vld_value $30. entity_id vsource_provider_key 8. old_val new_val $50. val_type validation_type_id 8.;
			wflow_exec_id = &wflow_exec_id.;
			vld_value 	  = left(put(&by_variable.,30.));
			entity_id	  = &by_variable.;
			&by_variable. = &by_variable.;
			old_val		  = "NULL";
			new_val		  = "NULL";
			validation_type_id = .;
			if client_key = -&client_id. then do;
				if upcase(ci_status) not in ("PAR","NONPAR") then do;
					new_val = ci_status;
					validation_type_id = 6;
				end;
				else if provider_name = "" then do;
					new_val = provider_name;
					validation_type_id = 4;
				end;
				else if tied_to_group = . then do;
					new_val = groupid;
					validation_type_id = 9;
				end;
			end;
			val_type = 99;
			if validation_type_id ne . then output;
		end;
		run;
		
		%let count_critical_facilities=0;		

		proc sql noprint;
			select 
				count(*) into: count_critical_facilities
			from edw_facility_validate_critical;
		quit;

		%put NOTE: Number of critical vSource facilities - &count_critical_facilities.;
		
		%if &count_critical_facilities. ne 0 %then %do;		


			proc sort data = VSOURCE_PROVIDER;
			by &by_variable. client_key;
			run;

			proc sort data = edw_facility_validate_critical  
			          out  = critical_facility (keep = &by_variable. client_key validation_type_id);
			by &by_variable. client_key;
			run;

			data VSOURCE_PROVIDER;
			merge VSOURCE_PROVIDER  (in=a)
				  critical_facility (in=b);
			by &by_variable. client_key;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Facility validations for the CI program - CRITICAL:  &count_critical_facilities. ;

	%end;

%mend  edw_provider_validations;
