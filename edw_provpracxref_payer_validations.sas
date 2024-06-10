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


%macro edw_provpracxref_payer_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, by_variable=, by_variable1=, by_variable2=, by_variable3=);

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
	/*			left(put(a.&by_variable3.,30.)) as vld_value,*/
	/*			left(put(a.&by_variable3.,30.))	as entity_id,  */
	/*			a.&by_variable. 				as provpracxref_key,*/
				a.&by_variable1.				as practice_key,
				a.&by_variable2.				as provider_key,
				&oldval.    					as old_val length=50,
				left(put(a.&by_variable3.,30.)) as new_val length=50,
				97 								as val_type,
				&validation_type_id.    		as validation_type_id
			from &in_dataset1. as a left join
			 	 &in_dataset2. as b
			on 	a.&by_variable1. = b.&by_variable1. and
				a.&by_variable2. = b.&by_variable2. 
			where b.&by_variable1. = . and b.&by_variable2. = .
		;
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


%mend  edw_provpracxref_payer_validations;
