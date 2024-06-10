
/*HEADER------------------------------------------------------------------------
|
| program:  edw_provpracxref_validations.sas
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


%macro edw_provpracxref_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, by_variable=, by_variable1=, by_variable2=);

    %local count_new count_delete count_change ;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW PROVIDER PRACTICE XREF
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;

		%put NOTE: Performing EDW - Provider Practice XREF validations for the CI program - NEW ;

		proc sql noprint;
		create table edw_provpracxref_validate_new as
		select 
			&wflow_exec_id. 				as wflow_exec_id,
/*			left(put(a.&by_variable.,30.)) 	as vld_value,*/
/*			a.&by_variable. 				as entity_id,  */
/*			a.&by_variable. 				as provpracxref_key,*/
			a.&by_variable1.				as practice_key,
			a.&by_variable2.				as provider_key,
			&oldval.    					as old_val length=50,
			&newval.    					as new_val length=50,
			97 								as val_type,
			&validation_type_id.    		as validation_type_id
		from &in_dataset1. as a left join
		 	 &in_dataset2. as b
		on 	a.&by_variable1. = b.&by_variable1. and
			a.&by_variable2. = b.&by_variable2. 
		where b.&by_variable1. = . and b.&by_variable2. = .;
		quit;
		
		%let count_new_provpracxref=0;

		proc sql noprint;
		select count(*) into: count_new
		from edw_provpracxref_validate_new ;
		quit;

		%put NOTE:"&count_new. NEW PROVIDER PRACTICE XREF RECORDS";
		
		%if &count_new. ne 0 %then %do;		

			proc sort data = VSOURCE_PROVPRACXREF;
			by &by_variable1. &by_variable2.;
			run;

			proc sort data = edw_provpracxref_validate_new  
			          out  = new (keep = &by_variable1. &by_variable2. validation_type_id);
			by &by_variable1. &by_variable2.;
			run;

			data VSOURCE_PROVPRACXREF;
			merge VSOURCE_PROVPRACXREF  (in=a)
				  new              		(in=b);
			by &by_variable1. &by_variable2.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;

		%end;

		%put NOTE: Counts - Provider Practice XREF validations for the CI program - NEW:  &count_new. ;

	%end; 

	
	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED PROVIDER PRACTICE XREF
	|
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE %then %do;

	    %put NOTE: Performing EDW - Provider Practice XREF validations for the CI program - CHANGE ;

	    proc sql noprint;
		  create table edw_provpracxref_validate_change as
		  select  
		    &wflow_exec_id. 																as wflow_exec_id,
		    left(put(b.&by_variable.,30.)) 													as vld_value,
			b.&by_variable. 																as entity_id, 
			b.&by_variable. 																as &by_variable.,
			a.&by_variable1.																as practice_key,
			a.&by_variable2.																as provider_key,
			case when a.primary_practice_ind	ne b.primary_practice_ind		then b.primary_practice_ind
				 when a.eff_dt					ne b.eff_dt						then put(b.eff_dt,datetime22.3)	
				 when a.exp_dt					ne b.exp_dt						then put(b.exp_dt,datetime22.3)
				 else "NULL"															end	as old_val length=50, 															
			case when a.primary_practice_ind	ne b.primary_practice_ind		then a.primary_practice_ind
				 when a.eff_dt					ne b.eff_dt						then put(a.eff_dt,datetime22.3)
				 when a.exp_dt					ne b.exp_dt						then put(a.exp_dt,datetime22.3)
				 else "NULL"															end	as new_val length=50, 														
		    99																				as val_type,
			&validation_type_id.    														as validation_type_id
		  from &in_dataset1. 	as a,
		       &in_dataset2. 	as b
		  where a.&by_variable1. = b.&by_variable1. and
		  		a.&by_variable2. = b.&by_variable2.
		    and (
				a.PRIMARY_PRACTICE_IND	 	ne b.PRIMARY_PRACTICE_IND 	or
				a.EFF_DT				 	ne b.EFF_DT			 		or
				a.EXP_DT				 	ne b.EXP_DT	
				);
		quit;
		
		%let count_change=0;		

		proc sql noprint;
		select count(*) into: count_change
		from edw_provpracxref_validate_change;
		quit;
		
		%put NOTE:"&count_change. CHANGED PROVIDER PRACTICE XREF RECORDS";

		%if &count_change. ne 0 %then %do;		


			proc sort data = VSOURCE_PROVPRACXREF;
			by &by_variable1. &by_variable2.;
			run;

			proc sort data = edw_provpracxref_validate_change  
			          out  = change (keep = &by_variable. &by_variable1. &by_variable2. validation_type_id);
			by &by_variable1. &by_variable2.;
			run;

			data VSOURCE_PROVPRACXREF;
			merge VSOURCE_PROVPRACXREF  (in=a)
			      change 		   		(in=b);
			by &by_variable1. &by_variable2.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Provider Practice XREF validations for the CI program - CHANGE:  &count_change. ;

	%end; 


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR PROVIDER PRACTICE XREF WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL %then %do;

	    %put NOTE: Performing EDW - Provider Practice XREF validations for the CI program - CRITICAL ;

		data edw_provpracxref_valid_critical1;
		set  edw_provpracxref_validate_new			(in=a keep=&by_variable1. &by_variable2.)
			 edw_provpracxref_validate_change 		(in=b keep=&by_variable. &by_variable1. &by_variable2.);
		run;

		proc sort data=edw_provpracxref_valid_critical1 nodupkey;
		by &by_variable1. &by_variable2.;
		run;

		proc sort data=ciedw.provider (keep=provider_key) out=prov;
		by &by_variable2.;
		run;

		proc sort data=ciedw.practice (keep=practice_key) out=prac;
		by &by_variable1.;
		run;

		data edw_provpracxref_valid_critical2;
		merge edw_provpracxref_valid_critical1 	(in=a)
			  prac								(in=b);
		by &by_variable1.;
		if a;
		if a and not b then not_in_practice_edw = 1;
		else not_in_practice_edw = 0;
		run;

		proc sort data=edw_provpracxref_valid_critical2;
		by &by_variable2.;
		run;

		data edw_provpracxref_valid_critical3;
		merge edw_provpracxref_valid_critical2 	(in=a)
			  prov								(in=b);
		by &by_variable2.;
		if a;
		if a and not b then not_in_provider_edw = 1;
		else not_in_provider_edw = 0;
		run;

		proc sort data=edw_provpracxref_valid_critical3 nodupkey;
		by &by_variable1. &by_variable2.;
		run;
		
		/*SASDOC--------------------------------------------------------------------------
		| EDW - Create test cases for critical validation
		|
		+------------------------------------------------------------------------SASDOC*/ 
		%if &sas_mode. = test %then %do;
			%include "M:\CI\programs\EDW\test_cases\test_critical_provpracxref_&test_case..sas";
		%end;
	
		%let varexist_id=%sysfunc(open(&in_dataset1.));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));

		%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;

		proc sort data=&in_dataset1.;
		by &by_variable1. &by_variable2.;
		run;

		data edw_provpracxref_valid_critical (keep=	wflow_exec_id vld_value entity_id &by_variable1. &by_variable2. 
													old_val new_val val_type validation_type_id);
		merge edw_provpracxref_valid_critical3 	(in=a)
		      &in_dataset1.					   	(in=b %if &varexist_ind. > 0 %then %do; drop= validation_type_id %end;);
		by &by_variable1. &by_variable2.;
		if a then do;
		length wflow_exec_id 8. vld_value $30. entity_id practice_key 8. old_val new_val $50. val_type validation_type_id 8.;
		wflow_exec_id = &wflow_exec_id.;
		if &by_variable. ne . then vld_value 	  = left(put(&by_variable.,30.));
		else vld_value = '';
		if &by_variable. ne . then entity_id = &by_variable.;
		else entity_id = .;
		old_val		  = "NULL";
		new_val		  = "NULL";
		valiation_type_id = .;
		if practice_key = . then do;
			new_val = practice_key;
			validation_type_id = 27;
		end;
		else if provider_key = . then do;
			new_val = provider_key;
			validation_type_id = 26;
		end;
		else if not_in_practice_edw then do;
			new_val = practice_key;
			validation_type_id = 38;
		end;
		else if not_in_provider_edw then do;
			new_val = provider_key;
			validation_type_id = 39;
		end;
		val_type = 99;
		if validation_type_id ne . then output;
		end;
		run;
		
		%let count_critical=0;		

		proc sql noprint;
		select count(*) into: count_critical
		from edw_provpracxref_valid_critical;
		quit;
		
		%put NOTE:"&count_critical. CRITICAL PROVIDER PRACTICE XREF RECORDS";

		%if &count_critical. ne 0 %then %do;		


			proc sort data = VSOURCE_PROVPRACXREF;
			by &by_variable1. &by_variable2.;
			run;

			proc sort data = edw_provpracxref_valid_critical  
			          out  = critical (keep = &by_variable1. &by_variable2. validation_type_id);
			by &by_variable1. &by_variable2.;
			run;

			data VSOURCE_PROVPRACXREF;
			merge VSOURCE_PROVPRACXREF 	(in=a)
			      critical 		   		(in=b);
			by &by_variable1. &by_variable2. ;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Provider Practice XREF validations for the CI program - CRITICAL:  &count_critical. ;

	%end;


%mend  edw_provpracxref_validations;
