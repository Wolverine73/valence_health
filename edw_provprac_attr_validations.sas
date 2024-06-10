/*HEADER------------------------------------------------------------------------
|
| program:  edw_provprac_attr_validations.sas
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
| 27JUN2012 - Winnie  - Clinical Integration  v1.4
|
+-----------------------------------------------------------------------HEADER*/


%macro edw_provprac_attr_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, 
									 by_variable=, by_variable2=, by_variable3=, by_variable4=, by_variable5=, by_variable6=, by_variable7=);

    %local count_new count_term count_critical;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW PROVIDER PRACTICE ATTRIBUTE
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;

	    %put NOTE: Performing EDW - Provider Practice Attribute validations for the CI program - NEW ;

			proc sql noprint;
			create table edw_attribute_validate_new as
				select distinct
					&wflow_exec_id. 				as wflow_exec_id,
					left(put(source.&by_variable4.,30.))	as vld_value,
					source.&by_variable4.				as entity_id, 
					&by_variable4., 
					&oldval.    					as old_val length=50,
					left(put(source.&by_variable4.,30.))	as new_val length=50,
					97 								as val_type,
					&validation_type_id.    		as validation_type_id
				from &in_dataset1. as source 
				
				left join 
				
					 (   select &by_variable, &by_variable2.  /* get parent attribute */
						      , '0' as parent_attribute_value, &by_variable3. 
						   from CIEDW.PROVIDER_PRACTICE_ATTRIBUTE 
						  where parent_prov_prctc_attribute_key is null  

						  union all 

						select child.&by_variable,child.&by_variable2.  /* get child attribute */
						     , parent.&by_variable3. as parent_attribute_value
							 , child.&by_variable3.   
						  from CIEDW.PROVIDER_PRACTICE_ATTRIBUTE parent
						 inner join CIEDW.PROVIDER_PRACTICE_ATTRIBUTE child
							on child.&by_variable5. = parent.&by_variable6.
						   and parent.&by_variable5. is null 
						   ) as target 		        
							            on source.&by_variable.  = target.&by_variable. and
					 					   source.&by_variable2. = target.&by_variable2. and
										   source.&by_variable3. = target.&by_variable3. and
										   source.&by_variable7. = target.&by_variable7.
						where missing(target.&by_variable.)
			;
		quit;
		
		%let count_new=0;

		proc sql noprint;
			select 
				count(*) into: count_new
			from edw_attribute_validate_new ;
		quit;

		%put NOTE: count_new - &count_new.;

		%if &count_new. ne 0 %then %do;		

			proc sort data = &in_dataset1.;
			by &by_variable4.;
			run;

			proc sort data = edw_attribute_validate_new  
			     	  out  = new (keep = &by_variable4. validation_type_id);
			by &by_variable4.;
			run;

			data &in_dataset1.;
			merge &in_dataset1. (in=a)
			      new           (in=b);
			by &by_variable4.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;

		%end;

		%put NOTE: Counts - Provider Practice Attribute validations for the CI program - NEW:  &count_new. ;

	%end; 


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR TERMED PROVIDER PRACTICE ATTRIBUTE
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = TERM %then %do;

	    %put NOTE: Performing EDW - Provider Practice Attribute validations for the CI program - TERM ;

		proc sql noprint;
			create table edw_attribute_validate_term as
				select distinct
					&wflow_exec_id. 				as wflow_exec_id,
					left(put(source.&by_variable4.,30.))	as vld_value,
					source.&by_variable4.				as entity_id, 
					&by_variable4., 
					target.termination_date 				as old_val,
					source.termination_date 				as new_val,
					98 								as val_type,
					&validation_type_id.    		as validation_type_id
				from &in_dataset1. as source 
				
				inner join 
				
					 (   select &by_variable, &by_variable2.  /* get parent attribute */
						      , '0' as parent_attribute_value, &by_variable3.
							  , termination_date
						   from CIEDW.PROVIDER_PRACTICE_ATTRIBUTE 
						  where parent_prov_prctc_attribute_key is null  

						  union all 

						select child.&by_variable,child.&by_variable2.  /* get child attribute */
						     , parent.&by_variable3. as parent_attribute_value
							 , child.&by_variable3., child.termination_date   
						  from CIEDW.PROVIDER_PRACTICE_ATTRIBUTE parent
						 inner join CIEDW.PROVIDER_PRACTICE_ATTRIBUTE child
							on child.&by_variable5. = parent.&by_variable6.
						   and parent.&by_variable5. is null 
						   ) as target 		        
							            on source.&by_variable.  = target.&by_variable. and
					 					   source.&by_variable2. = target.&by_variable2. and
										   source.&by_variable3. = target.&by_variable3. and
										   source.&by_variable7. = target.&by_variable7.
						where source.termination_date ne target.termination_date		
				;
		quit;
		
		%let count_term=0;		

		proc sql noprint;
			select 
				count(*) into: count_term
			from edw_attribute_validate_term ;
		quit;
		
		%put NOTE: count_term - &count_term.;

		%if &count_term. ne 0 %then %do;		

			proc sort data = &in_dataset1.;
			by &by_variable4.;
			run;

			proc sort data = edw_attribute_validate_term  
			  		  out  = term (keep = &by_variable4. validation_type_id);
			by &by_variable4.;
			run;

			data &in_dataset1.;
			merge &in_dataset1. (in=a)
				  term 			(in=b);
			by &by_variable4.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Provider Practice Attribute validations for the CI program - TERM:  &count_term. ;

	%end; 


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR PROVIDER PRACTICE ATTRIBUTE WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL %then %do;

	    %put NOTE: Performing EDW - Provider Practice Attribute validations for the CI program - CRITICAL ;

		data edw_attr_validate_critical_a;
		set  edw_attribute_validate_new	 (in=a keep=&by_variable4.)
			 edw_attribute_validate_term (in=a keep=&by_variable4.);
		run;

		proc sort data=edw_attr_validate_critical_a nodupkey;
		by &by_variable4.;
		run;

		proc sort data=&in_dataset1.;
		by &by_variable4.;
		run;
		
		%let varexist_id=%sysfunc(open(&in_dataset1.));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));

		%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;

		data edw_attribute_validate_critical (keep=wflow_exec_id vld_value entity_id &by_variable4. old_val new_val val_type validation_type_id);
		merge edw_attr_validate_critical_a 	(in=a)
		      &in_dataset1.					(in=b /*%if &varexist_ind. > 0 %then %do; drop=validation_type_id %end;*/);
		by &by_variable4.;
		if a then do;
		length wflow_exec_id 8. vld_value $30. entity_id 8. old_val new_val $50. val_type validation_type_id 8.;
		wflow_exec_id = &wflow_exec_id.;
		vld_value 	  = left(put(&by_variable4.,30.));
		entity_id	  = &by_variable4.;
		old_val		  = "NULL";
		new_val		  = "NULL";
		validation_type_id = .;
		if termination_date < effective_date then do;
			new_val = termination_date;
			validation_type_id = 99;
		end;
		val_type = 99;
		if validation_type_id ne . then output;
		end;
		run;
		
		%let count_critical=0;		

		proc sql noprint;
			select 
				count(*) into: count_critical
			from edw_attribute_validate_critical;
		quit;

		%put NOTE: count_critical - &count_critical.;
		
		%if &count_critical. ne 0 %then %do;		


			proc sort data = &in_dataset.;
			by &by_variable4.;
			run;

			proc sort data = edw_attribute_validate_critical  
			          out  = critical (keep = &by_variable4. validation_type_id);
			by &by_variable4.;
			run;

			data &in_dataset.;
			merge &in_dataset. 	(in=a)
				  critical 		(in=b);
			by &by_variable4.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Provider Practice Attribute validations for the CI program - CRITICAL:  &count_critical. ;

	%end;

%mend  edw_provprac_attr_validations;
