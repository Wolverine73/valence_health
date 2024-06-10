
/*HEADER------------------------------------------------------------------------
|
| program:  edw_practice_validations.sas
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/


%macro edw_practice_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, by_variable=, by_variable2=);

    %local count_new count_new_facility count_term count_term_facility count_change count_change_facility count_critical count_critical_facility;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW PRACTICES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;

		%put NOTE: Performing EDW - Practice validations for the CI program - NEW ;

		proc sql noprint;
			create table edw_practice_validate_new as
				select 
					&wflow_exec_id. 				as wflow_exec_id,
					left(put(a.&by_variable2.,30.)) as vld_value,
					a.&by_variable2. 				as entity_id,  
					a.&by_variable2. 				as vsource_practice_key,
					&oldval.    					as old_val length=50,
					&newval.    					as new_val length=50,
					97 								as val_type,
					&validation_type_id.    		as validation_type_id
				from &in_dataset1. as a left join
					 &in_dataset2. as b on (a.&by_variable2.=b.&by_variable2.) or 
					 					   (a.&by_variable.=b.&by_variable. and a.practice_name=b.practice_name)
				where a.client_key=&client_id. and (b.&by_variable2.=. or b.&by_variable.='')
			;
		quit;
		
		%let count_new=0;

		proc sql noprint;
		select count(*) into: count_new
		from edw_practice_validate_new ;
		quit;

		%put NOTE: Number of new vSource practices - &count_new.;
		
		%if &count_new. ne 0 %then %do;		

			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2.;
			run;

			proc sort data = edw_practice_validate_new  
			          out  = new (keep = &by_variable2. validation_type_id);
			by &by_variable2.;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
				  new              (in=b);
			by &by_variable2.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;

		%end;

		%put NOTE: Counts - Practice validations for the CI program - NEW:  &count_new. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW FACILITIES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW_FACILITY %then %do;

		%put NOTE: Performing EDW - Facility validations for the CI program - NEW ;

		proc sql noprint;
			create table edw_facility_validate_new as
				select distinct
					&wflow_exec_id. 				as wflow_exec_id,
					left(put(a.&by_variable2.,30.)) as vld_value,
					a.&by_variable2. 				as entity_id,  
					a.&by_variable2. 				as vsource_practice_key,
					&oldval.    					as old_val length=50,
					&newval.    					as new_val length=50,
					97 								as val_type,
					&validation_type_id.    		as validation_type_id
				from &in_dataset1. as a left join
					 &in_dataset2. as b on (a.&by_variable2.=b.&by_variable2.) or 
					 					   (a.&by_variable.=b.&by_variable. and a.practice_name=b.practice_name and a.client_key=-&client_id.)
				where a.client_key=-&client_id. and (b.&by_variable2.=. or b.&by_variable.='')
			;
		quit;
		
		%let count_new_facility=0;

		proc sql noprint;
		select count(*) into: count_new_facility
		from edw_facility_validate_new ;
		quit;

		%put NOTE: Number of new vSource facilities - &count_new_facility.;
		
		%if &count_new_facility. ne 0 %then %do;		

			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2.;
			run;

			proc sort data = edw_facility_validate_new  
			          out  = new (keep = &by_variable2. validation_type_id);
			by &by_variable2.;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
				  new              (in=b);
			by &by_variable2.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;

		%end;

		%put NOTE: Counts - Facility validations for the CI program - NEW:  &count_new_facility. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR TERMED PRACTICES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = TERM %then %do;

	    %put NOTE: Performing EDW - Practice validations for the CI program - TERM ;

		proc sql noprint;
		create table edw_practice_validate_term as
		select  
			&wflow_exec_id. 				as wflow_exec_id,
			left(put(a.&by_variable2.,30.)) as vld_value,
			a.&by_variable2. 				as entity_id,  
			a.&by_variable2. 				as vsource_practice_key,
			&oldval.    					as old_val length=50,
			&newval.    					as new_val length=50,
			98								as val_type,
			&validation_type_id.    		as validation_type_id
		from &in_dataset1. as a
		where  	upcase(a.ci_status) = 'PAR' and 
				a.&by_variable2. in 
								   (select &by_variable2.
									from &in_dataset2. as b
									where upcase(b.ci_status)='NONPAR' and b.client_key=&client_id.);
		quit;
		
		%let count_term=0;		

		proc sql noprint;
		select count(*) into: count_term
		from edw_practice_validate_term ;
		quit;

		%put NOTE: Number of termed vSource practices - &count_term.;
		
		%if &count_term. ne 0 %then %do;		

			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2.;
			run;

			proc sort data = edw_practice_validate_term  
			          out  = term (keep = &by_variable2. validation_type_id);
			by &by_variable2.;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
			      term 			   (in=b);
			by &by_variable2.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Practice validations for the CI program - TERM:  &count_term. ;

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
			&wflow_exec_id. 				as wflow_exec_id,
			left(put(a.&by_variable2.,30.)) as vld_value,
			a.&by_variable2. 				as entity_id,  
			a.&by_variable2. 				as vsource_practice_key,
			&oldval.    					as old_val length=50,
			&newval.    					as new_val length=50,
			98								as val_type,
			&validation_type_id.    		as validation_type_id
		from &in_dataset1. as a
		where  	upcase(a.ci_status) = 'PAR' and 
				a.&by_variable2. in 
								   (select &by_variable2.
									from &in_dataset2. as b
									where upcase(b.ci_status)='NONPAR' and b.client_key=-&client_id.);
		quit;
		
		%let count_term_facility=0;		

		proc sql noprint;
		select count(*) into: count_term_facility
		from edw_facility_validate_term ;
		quit;

		%put NOTE: Number of termed vSource facilities - &count_term_facility.;
		
		%if &count_term_facility. ne 0 %then %do;		

			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2.;
			run;

			proc sort data = edw_facility_validate_term  
			          out  = term (keep = &by_variable2. validation_type_id);
			by &by_variable2.;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
			      term 			   (in=b);
			by &by_variable2.;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Facility validations for the CI program - TERM:  &count_term_facility. ;

	%end; 


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED PRACTICES
	|
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE %then %do;

	    %put NOTE: Performing EDW - Practice validations for the CI program - CHANGE ;


	    proc sql noprint;
			create table ciedw_prov_tied as
			select
				practice_key,
				tin,
				case when provider_count >= 1 then 'Y'
				else 'N'								end as provider_tied
			from
				(
				select 	
					prvgrp.practice_key			as practice_key,
	   		  		count(prvgrp.provider_key) 	as provider_count,
					g.tin					
			  	from ciedw.provider_practice_xref as prvgrp left outer join
					 ciedw.provider as p on prvgrp.provider_key = p.provider_key left outer join
					 ciedw.practice as g on prvgrp.practice_key = g.practice_key
				where upcase(p.ci_status) = 'PAR'
				group by prvgrp.practice_key
				);
		quit;

		proc sql noprint;
			create table ciedw_practice as
			select 
				a.*,
				b.provider_tied
			from &in_dataset2. as a left outer join
				 ciedw_prov_tied as b on a.practice_key=b.practice_key
			where a.client_key = &client_id. and a.practice_key > 0
			;
		quit;

	    proc sql noprint;
		  create table edw_practice_validate_change as
		  select distinct
		    &wflow_exec_id. 																as wflow_exec_id,
		    left(put(a.&by_variable2.,30.)) 												as vld_value,
			a.&by_variable2. 																as entity_id, 
			a.&by_variable2. 																as vsource_practice_key,
			case when a.practice_name 			ne b.practice_name  			then b.practice_name	
				 when a.tin	 					ne b.tin						then b.tin	
				 when a.tin_name				ne b.tin_name   				then b.tin_name	
				 when a.npi2					ne b.npi2						then b.npi2		
				 when a.data_category			ne b.data_category				then b.data_category	
				 when a.vmine_installed_sched	ne b.vmine_installed_sched		then put(b.vmine_installed_sched,datetime22.3)
				 when a.vmine_installed_date	ne b.vmine_installed_date		then put(b.vmine_installed_date,datetime22.3)
				 when a.vmine_installer_name	ne b.vmine_installer_name		then b.vmine_installer_name
				 when a.vmine_status			ne b.vmine_status				then b.vmine_status
				 when a.practice_eff_date		ne b.practice_eff_date			then put(b.practice_eff_date,datetime22.3)
				 when a.practice_exp_date		ne b.practice_exp_date			then put(b.practice_exp_date,datetime22.3)
				 when a.ci_status				ne b.ci_status					then b.ci_status
				 when a.data_cmplt_ind			ne b.data_cmplt_ind				then b.data_cmplt_ind
				 when a.provider_tied			ne b.provider_tied				then b.provider_tied
				 else "NULL"															end	as old_val length=50, 															
			case when a.practice_name 			ne b.practice_name  			then a.practice_name	
				 when a.tin	 					ne b.tin						then a.tin	
				 when a.tin_name  			 	ne b.tin_name   				then a.tin_name				
				 when a.npi2 					ne b.npi2						then a.npi2		
				 when a.data_category			ne b.data_category				then a.data_category	
				 when a.vmine_installed_sched	ne b.vmine_installed_sched		then put(a.vmine_installed_sched,datetime22.3)
				 when a.vmine_installed_date 	ne b.vmine_installed_date		then put(a.vmine_installed_date,datetime22.3)
				 when a.vmine_installer_name	ne b.vmine_installer_name		then a.vmine_installer_name
				 when a.vmine_status			ne b.vmine_status				then a.vmine_status
				 when a.practice_eff_date		ne b.practice_eff_date			then put(a.practice_eff_date,datetime22.3)
				 when a.practice_exp_date		ne b.practice_exp_date			then put(a.practice_exp_date,datetime22.3)
				 when a.ci_status				ne b.ci_status					then a.ci_status
				 when a.data_cmplt_ind			ne b.data_cmplt_ind				then a.data_cmplt_ind	
				 when a.provider_tied			ne b.provider_tied				then a.provider_tied
				 else "NULL"															end	as new_val length=50, 														
		    99																				as val_type,
			&validation_type_id.    														as validation_type_id
		  from &in_dataset1. 	as a left outer join
		       ciedw_practice 	as b on (
											(
												a.&by_variable2. = b.&by_variable2. and 
												b.&by_variable2. ne . 
											) or
											(
												a.&by_variable. = b.&by_variable. and 
											 	upcase(a.practice_name) = upcase(b.practice_name)
											)
										)
		  where  a.client_key = &client_id. and
				 upcase(a.ci_status) = 'PAR' and 
				(
					a.PRACTICE_NAME 			ne b.PRACTICE_NAME 			or 
					a.TIN			 			ne b.TIN			 		or 
					a.TIN_NAME					ne b.TIN_NAME				or
					a.NPI2			 			ne b.NPI2			 		or
					a.DATA_CATEGORY				ne b.DATA_CATEGORY			or
					a.VMINE_INSTALLED_SCHED 	ne b.VMINE_INSTALLED_SCHED 	or
					a.VMINE_INSTALLED_DATE	 	ne b.VMINE_INSTALLED_DATE 	or
					a.VMINE_INSTALLER_NAME	 	ne b.VMINE_INSTALLER_NAME 	or
					a.VMINE_STATUS 				ne b.VMINE_STATUS			or
					a.PRACTICE_EFF_DATE			ne b.PRACTICE_EFF_DATE		or
					a.PRACTICE_EXP_DATE			ne b.PRACTICE_EXP_DATE		or
					a.CI_STATUS					ne b.CI_STATUS				or
					a.DATA_CMPLT_IND 			ne b.DATA_CMPLT_IND 		or
					a.PROVIDER_TIED				ne b.PROVIDER_TIED			
				)	
		  order by VSOURCE_PRACTICE_KEY;
		quit;

		data edw_practice_validate_change;
		set edw_practice_validate_change;
		by vsource_practice_key;
		if first.vsource_practice_key then output;
		run;

		%let count_change=0;		

		proc sql noprint;
		select count(*) into: count_change
		from edw_practice_validate_change;
		quit;

		%put NOTE: Number of changed vSource practices - &count_change.;
		
		%if &count_change. ne 0 %then %do;		


			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2. ;
			run;

			proc sort data = edw_practice_validate_change  
			          out  = change (keep = &by_variable2. validation_type_id);
			by &by_variable2. ;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
			      change 		   (in=b);
			by &by_variable2. ;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Practice validations for the CI program - CHANGE:  &count_change. ;

	%end; 


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED FACILITIES
	|
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE_FACILITY %then %do;

	    %put NOTE: Performing EDW - Facility validations for the CI program - CHANGE ;


	    proc sql noprint;
			create table ciedw_prov_tied as
			select
				practice_key,
				tin,
				case when provider_count >= 1 then 'Y'
				else 'N'								end as provider_tied
			from
				(
				select 	
					prvgrp.practice_key			as practice_key,
	   		  		count(prvgrp.provider_key) 	as provider_count,
					g.tin					
			  	from ciedw.provider_practice_xref as prvgrp left outer join
					 ciedw.provider as p on prvgrp.provider_key = p.provider_key left outer join
					 ciedw.practice as g on prvgrp.practice_key = g.practice_key
				where upcase(p.ci_status) = 'PAR'
				group by prvgrp.practice_key
				);
		quit;

		proc sql noprint;
			create table ciedw_practice as
			select 
				a.*,
				b.provider_tied
			from &in_dataset2. as a left outer join
				 ciedw_prov_tied as b on a.practice_key=b.practice_key
			where a.client_key = &client_id. and a.practice_key > 0
			;
		quit;

	    proc sql noprint;
		  create table edw_facility_validate_change as
		  select distinct
		    &wflow_exec_id. 																as wflow_exec_id,
		    left(put(a.&by_variable2.,30.)) 												as vld_value,
			a.&by_variable2. 																as entity_id, 
			a.&by_variable2. 																as vsource_practice_key,
			case when a.practice_name 			ne b.practice_name  			then b.practice_name	
				 when a.tin	 					ne b.tin						then b.tin	
				 when a.tin_name				ne b.tin_name   				then b.tin_name	
				 when a.npi2					ne b.npi2						then b.npi2		
				 when a.data_category			ne b.data_category				then b.data_category	
				 when a.vmine_installed_sched	ne b.vmine_installed_sched		then put(b.vmine_installed_sched,datetime22.3)
				 when a.vmine_installed_date	ne b.vmine_installed_date		then put(b.vmine_installed_date,datetime22.3)
				 when a.vmine_installer_name	ne b.vmine_installer_name		then b.vmine_installer_name
				 when a.vmine_status			ne b.vmine_status				then b.vmine_status
				 when a.practice_eff_date		ne b.practice_eff_date			then put(b.practice_eff_date,datetime22.3)
				 when a.practice_exp_date		ne b.practice_exp_date			then put(b.practice_exp_date,datetime22.3)
				 when a.ci_status				ne b.ci_status					then b.ci_status
				 when a.data_cmplt_ind			ne b.data_cmplt_ind				then b.data_cmplt_ind
				 when a.provider_tied			ne b.provider_tied				then b.provider_tied
				 else "NULL"															end	as old_val length=50, 															
			case when a.practice_name 			ne b.practice_name  			then a.practice_name	
				 when a.tin	 					ne b.tin						then a.tin	
				 when a.tin_name  			 	ne b.tin_name   				then a.tin_name				
				 when a.npi2 					ne b.npi2						then a.npi2		
				 when a.data_category			ne b.data_category				then a.data_category	
				 when a.vmine_installed_sched	ne b.vmine_installed_sched		then put(a.vmine_installed_sched,datetime22.3)
				 when a.vmine_installed_date 	ne b.vmine_installed_date		then put(a.vmine_installed_date,datetime22.3)
				 when a.vmine_installer_name	ne b.vmine_installer_name		then a.vmine_installer_name
				 when a.vmine_status			ne b.vmine_status				then a.vmine_status
				 when a.practice_eff_date		ne b.practice_eff_date			then put(a.practice_eff_date,datetime22.3)
				 when a.practice_exp_date		ne b.practice_exp_date			then put(a.practice_exp_date,datetime22.3)
				 when a.ci_status				ne b.ci_status					then a.ci_status
				 when a.data_cmplt_ind			ne b.data_cmplt_ind				then a.data_cmplt_ind	
				 when a.provider_tied			ne b.provider_tied				then a.provider_tied
				 else "NULL"															end	as new_val length=50, 														
		    99																				as val_type,
			&validation_type_id.    														as validation_type_id
		  from &in_dataset1. 	as a left outer join
		       ciedw_practice 	as b on (
											(
												a.&by_variable2. = b.&by_variable2. and 
												b.&by_variable2. ne . 
											) or
											(
												a.&by_variable. = b.&by_variable. and 
											 	upcase(a.practice_name) = upcase(b.practice_name)
											)
										)
		  where  a.client_key = -&client_id. and
				 upcase(a.ci_status) = 'PAR' and 
				(
					a.PRACTICE_NAME 			ne b.PRACTICE_NAME 			or 
					a.TIN			 			ne b.TIN			 		or 
					a.TIN_NAME					ne b.TIN_NAME				or
					a.NPI2			 			ne b.NPI2			 		or
					a.DATA_CATEGORY				ne b.DATA_CATEGORY			or
					a.VMINE_INSTALLED_SCHED 	ne b.VMINE_INSTALLED_SCHED 	or
					a.VMINE_INSTALLED_DATE	 	ne b.VMINE_INSTALLED_DATE 	or
					a.VMINE_INSTALLER_NAME	 	ne b.VMINE_INSTALLER_NAME 	or
					a.VMINE_STATUS 				ne b.VMINE_STATUS			or
					a.PRACTICE_EFF_DATE			ne b.PRACTICE_EFF_DATE		or
					a.PRACTICE_EXP_DATE			ne b.PRACTICE_EXP_DATE		or
					a.CI_STATUS					ne b.CI_STATUS				or
					a.DATA_CMPLT_IND 			ne b.DATA_CMPLT_IND 		or
					a.PROVIDER_TIED				ne b.PROVIDER_TIED			
				)
		   order by VSOURCE_PRACTICE_KEY;
		quit;

		data edw_facility_validate_change;
		set edw_facility_validate_change;
		by vsource_practice_key;
		if first.vsource_practice_key then output;
		run;
		
		%let count_change_facility=0;		

		proc sql noprint;
		select count(*) into: count_change_facility
		from edw_facility_validate_change;
		quit;

		%put NOTE: Number of changed vSource facilities - &count_change_facility.;
		
		%if &count_change_facility. ne 0 %then %do;		


			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2. ;
			run;

			proc sort data = edw_facility_validate_change  
			          out  = change (keep = &by_variable2. validation_type_id);
			by &by_variable2. ;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
			      change 		   (in=b);
			by &by_variable2. ;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Facility validations for the CI program - CHANGE:  &count_change_facility. ;

	%end; 


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR PRACTICES WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL %then %do;

	    %put NOTE: Performing EDW - Practice validations for the CI program - CRITICAL ;

		data edw_practice_validate_critical_a;
		set  edw_practice_validate_new		(in=a keep=&by_variable2.)
			 edw_practice_validate_change 	(in=b keep=&by_variable2.);
		run;

		proc sort data=edw_practice_validate_critical_a nodupkey;
		by &by_variable2.;
		run;

		proc sql noprint;
		  create table edw_practice_validate_critical_b as
		  select  
			  a.&by_variable2.,
			  b.npi2
		  from 	edw_practice_validate_critical_a	as a left outer join
		  		&in_dataset1.						as b on a.&by_variable2. = b.&by_variable2.
		  order by &by_variable.;
		quit;

		data edw_practice_validate_critical_c;
		set edw_practice_validate_critical_b;
		%luhn_npi_check (npi2);
		run;

		proc sort data=edw_practice_validate_critical_c;
		by &by_variable2.;
		run;

		
		/*SASDOC--------------------------------------------------------------------------
		| EDW - Create test cases for critical validation
		|
		+------------------------------------------------------------------------SASDOC*/ 
/*		%if &sas_mode. = test %then %do;*/
/*			%include "M:\CI\programs\EDW\test_cases\test_critical_practice_validations_&test_case..sas";*/
/*		%end;*/

		%let varexist_id=%sysfunc(open(&in_dataset1.));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));

		%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;	

		data edw_practice_validate_critical (keep=wflow_exec_id vld_value entity_id vsource_practice_key old_val new_val val_type validation_type_id);
		merge edw_practice_validate_critical_c (in=a)
		      &in_dataset1.					   (in=b drop=npi2 %if &varexist_ind. > 0 %then %do; validation_type_id %end;);
		by &by_variable2.;
		if a then do;;
		length wflow_exec_id 8. vld_value $30. entity_id vsource_practice_key 8. old_val new_val $50. val_type validation_type_id 8.;
		wflow_exec_id = &wflow_exec_id.;
		vld_value 	  = left(put(&by_variable2.,30.));
		entity_id	  = &by_variable2.;
		vsource_practice_key  = &by_variable2.;
		old_val		  = "NULL";
		new_val		  = "NULL";
		valiation_type_id = .;
		if client_key = &client_id. then do;
			if upcase(ci_status) not in ("PAR","NONPAR") then do;
				new_val = ci_status;
				validation_type_id = 17;
			end;
			else if upcase(ci_status) = 'NONPAR' then do;
				if practice_name = "" then do;
					new_val = practice_name;
					validation_type_id = 15;
				end;
				else if tin = "" or length (tin) ne 9 or tin*1 = . then do;
					new_val = tin;
					validation_type_id = 16;
				end;
			end;
			else if practice_name = "" then do;
				new_val = practice_name;
				validation_type_id = 15;
			end;
			else if tin = "" or length (tin) ne 9 or tin*1 = . then do;
				new_val = tin;
				validation_type_id = 16;
			end;
			else if provider_tied ne 'Y' then do;
				new_val = provider_tied;
				validation_type_id = 18;
			end;
		end;
		else if client_key = -&client_id. then do;
			if upcase(ci_status) not in ("PAR","NONPAR") then do;
				new_val = ci_status;
				validation_type_id = 17;
			end;
			else if practice_name = "" then do;
				new_val = practice_name;
				validation_type_id = 15;
			end;
			else if tin ne "" then do;
				if length(tin) ne 9 or tin*1 = . then do;
					new_val = tin;
					validation_type_id = 16;
				end;
			end;
			else if provider_tied ne "Y" then do;
				new_val = provider_tied;
				validation_type_id = 18;
			end;
		end;
		val_type = 99;
		if validation_type_id ne . then output;
		end;
		run;
		
		%let count_critical=0;		

		proc sql noprint;
		select count(*) into: count_critical
		from edw_practice_validate_critical;
		quit;

		%put NOTE: Number of critical vSource practices - &count_critical.;
		
		%if &count_critical. ne 0 %then %do;		


			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2. ;
			run;

			proc sort data = edw_practice_validate_critical  
			          out  = critical (keep = &by_variable2. validation_type_id);
			by &by_variable2. ;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
			      critical 		   (in=b);
			by &by_variable2. ;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Practice validations for the CI program - CRITICAL:  &count_critical. ;

	%end;


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR FACILITIES WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL_FACILITY %then %do;

	    %put NOTE: Performing EDW - Practice validations for the CI program - CRITICAL ;

		data edw_facility_validate_critical_a;
		set  edw_facility_validate_new		(in=a keep=&by_variable2.)
			 edw_facility_validate_change 	(in=b keep=&by_variable2.);
		run;

		proc sort data=edw_facility_validate_critical_a nodupkey;
		by &by_variable2.;
		run;

		proc sql noprint;
		  create table edw_facility_validate_critical_b as
		  select  
			  a.&by_variable2.,
			  b.npi2
		  from 	edw_facility_validate_critical_a	as a left outer join
		  		&in_dataset1.						as b on a.&by_variable2. = b.&by_variable2.
		  order by &by_variable2.;
		quit;

		data edw_facility_validate_critical_c;
		set edw_facility_validate_critical_b;
		%luhn_npi_check (npi2);
		run;

		proc sort data=edw_practice_validate_critical_c;
		by &by_variable2.;
		run;

		%let varexist_id=%sysfunc(open(&in_dataset1.));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));

		%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;	

		data edw_facility_validate_critical (keep=wflow_exec_id vld_value entity_id vsource_practice_key old_val new_val val_type validation_type_id);
		merge edw_facility_validate_critical_c (in=a)
		      &in_dataset1.					   (in=b drop=npi2 %if &varexist_ind. > 0 %then %do; validation_type_id %end;);
		by &by_variable2.;
		if a then do;;
		length wflow_exec_id 8. vld_value $30. entity_id vsource_practice_key 8. old_val new_val $50. val_type validation_type_id 8.;
		wflow_exec_id = &wflow_exec_id.;
		vld_value 	  = left(put(&by_variable2.,30.));
		entity_id	  = &by_variable2.;
		vsource_practice_key  = &by_variable2.;
		old_val		  = "NULL";
		new_val		  = "NULL";
		valiation_type_id = .;

		if upcase(ci_status) not in ("PAR","NONPAR") then do;
			new_val = ci_status;
			validation_type_id = 17;
		end;
		else if practice_name = "" then do;
			new_val = practice_name;
			validation_type_id = 15;
		end;
		else if tin ne "" then do;
			if length(tin) ne 9 or tin*1 = . then do;
				new_val = tin;
				validation_type_id = 16;
			end;
		end;
		else if provider_tied ne "Y" then do;
			new_val = provider_tied;
			validation_type_id = 18;
		end;
		val_type = 99;
		if validation_type_id ne . then output;
		end;
		run;
		
		%let count_critical_facility=0;		

		proc sql noprint;
		select count(*) into: count_critical_facility
		from edw_facility_validate_critical;
		quit;

		%put NOTE: Number of critical vSource facilities - &count_critical_facility.;
		
		%if &count_critical_facility. ne 0 %then %do;		


			proc sort data = VSOURCE_PRACTICE;
			by &by_variable2. ;
			run;

			proc sort data = edw_facility_validate_critical  
			          out  = critical (keep = &by_variable2. validation_type_id);
			by &by_variable2. ;
			run;

			data VSOURCE_PRACTICE;
			merge VSOURCE_PRACTICE (in=a)
			      critical 		   (in=b);
			by &by_variable2. ;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Facility validations for the CI program - CRITICAL:  &count_critical. ;

	%end;

%mend  edw_practice_validations;
