
/*HEADER------------------------------------------------------------------------
|
| program:  edw_practice_addr_validations.sas
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


%macro edw_practice_addr_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, by_variable=);

    %local count_new count_delete count_change ;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW PRACTICE ADDRESSES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;

		%put NOTE: Performing EDW - Practice address validations for the CI program - NEW ;

		proc sql noprint;
		create table edw_practice_addr_validate_new as
		select 
			&wflow_exec_id. 				as wflow_exec_id,
			left(put(a.&by_variable.,30.)) 	as vld_value,
			a.&by_variable. 				as entity_id,  
			a.&by_variable. 				as practice_addr_key,
			&oldval.    					as old_val length=50,
			&newval.    					as new_val length=50,
			97 								as val_type,
			&validation_type_id.    		as validation_type_id
		from &in_dataset1. as a left join
		 	 &in_dataset2. as b
		on a.&by_variable. = b.&by_variable. 
		where b.&by_variable. = . ;
		quit;
		
		%let count_new_practice_addr=0;

		proc sql noprint;
		select count(*) into: count_new
		from edw_practice_addr_validate_new ;
		quit;
		
		%if &count_new. ne 0 %then %do;		

			proc sort data = VSOURCE_PRACTICE_ADDR;
			by &by_variable.;
			run;

			proc sort data = edw_practice_addr_validate_new  
			          out  = new (keep = &by_variable. validation_type_id);
			by &by_variable.;
			run;

			data VSOURCE_PRACTICE_ADDR;
			merge VSOURCE_PRACTICE_ADDR (in=a)
				  new              		(in=b);
			by &by_variable.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;

		%end;

		%put NOTE: Counts - Practice address validations for the CI program - NEW:  &count_new. ;

	%end; 

	
	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED PRACTICE ADDRESSES
	|
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE %then %do;

	    %put NOTE: Performing EDW - Practice address validations for the CI program - CHANGE ;

	    proc sql noprint;
		  create table edw_practiceaddr_validate_change as
		  select  
		    &wflow_exec_id. 																as wflow_exec_id,
		    left(put(a.&by_variable.,30.)) 													as vld_value,
			a.&by_variable. 																as entity_id, 
			a.&by_variable. 																as practice_addr_key,
			case when a.addr_line_1				ne b.addr_line_1   				then b.addr_line_1	
				 when a.addr_line_2				ne b.addr_line_2				then b.addr_line_2		
				 when a.city					ne b.city						then b.city	
				 when a.state					ne b.state						then b.state
				 when a.zip_code				ne b.zip_code					then b.zip_code
				 when a.county					ne b.county						then b.county
				 when a.data_cmplt_ind			ne b.data_cmplt_ind				then b.data_cmplt_ind
				 when a.prim_addr_ind			ne b.prim_addr_ind				then b.prim_addr_ind
				 else "NULL"															end	as old_val length=50, 															
			case when a.addr_line_1				ne b.addr_line_1   				then a.addr_line_1	
				 when a.addr_line_2				ne b.addr_line_2				then a.addr_line_2		
				 when a.city					ne b.city						then a.city	
				 when a.state					ne b.state						then a.state
				 when a.zip_code				ne b.zip_code					then a.zip_code
				 when a.county					ne b.county						then a.county
				 when a.data_cmplt_ind			ne b.data_cmplt_ind				then a.data_cmplt_ind
				 when a.prim_addr_ind			ne b.prim_addr_ind				then a.prim_addr_ind
				 else "NULL"															end	as new_val length=50, 														
		    99																				as val_type,
			&validation_type_id.    														as validation_type_id
		  from &in_dataset1. 	as a,
		       &in_dataset2. 	as b
		  where a.&by_variable. = b.&by_variable.
		    and (
				a.ADDR_LINE_1				ne b.ADDR_LINE_1			or
				a.ADDR_LINE_2	 			ne b.ADDR_LINE_2	 		or
				a.CITY						ne b.CITY					or
				a.STATE					 	ne b.STATE				 	or
				a.ZIP_CODE				 	ne b.ZIP_CODE			 	or
				a.COUNTY				 	ne b.COUNTY				 	or
				a.DATA_CMPLT_IND 			ne b.DATA_CMPLT_IND 		or
				a.PRIM_ADDR_IND				ne b.PRIM_ADDR_IND			
				);
		quit;
		
		%let count_change=0;		

		proc sql noprint;
		select count(*) into: count_change
		from edw_practiceaddr_validate_change;
		quit;
		
		%if &count_change. ne 0 %then %do;		


			proc sort data = VSOURCE_PRACTICE_ADDR;
			by &by_variable. ;
			run;

			proc sort data = edw_practiceaddr_validate_change  
			          out  = change (keep = &by_variable. validation_type_id);
			by &by_variable. ;
			run;

			data VSOURCE_PRACTICE_ADDR;
			merge VSOURCE_PRACTICE_ADDR (in=a)
			      change 		   		(in=b);
			by &by_variable. ;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Practice address validations for the CI program - CHANGE:  &count_change. ;

	%end; 

%mend  edw_practice_addr_validations;
