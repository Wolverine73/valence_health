
/*HEADER------------------------------------------------------------------------
|
| program:  edw_provpracxref_valids.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose: validate vSource, vLinkNSAP.dbo.tblProviderGroups records  
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
| 13JUL2012 - Winnie Lee  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/


%macro edw_provpracxref_valids(vt_name=, validation_type_id=, ds1=, ds2=, oldval=, newval=, byvar=, byvar1=, byvar2=, byvar3=, byvar4=);

    %local count_new count_change count_critical;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW PROVIDER PRACTICE XREF
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;

		%put NOTE: Performing EDW - Provider Practice XREF validations for the CI program - NEW ;

		%let newval="&byvar3.-" || trim(left(put(a.&byvar3.,30.))) || ", &byvar4.-" || trim(left(put(a.&byvar4.,30.)));

		proc sql noprint;
		create table edw_provpracxref_validate_new as
		select 
			&wflow_exec_id. 				as wflow_exec_id,
/*			left(put(a.&byvar.,30.)) 	as vld_value,*/
/*			a.&byvar. 				as entity_id,  */
/*			a.&byvar. 				as provpracxref_key,*/
			a.&byvar3.,
			a.&byvar4.,
			&oldval.    					as old_val length=100,
			&newval.    					as new_val length=100,
			97 								as val_type,
			&validation_type_id.    		as validation_type_id
		from &ds1. as a left outer join
			 (
				select distinct
					p.&byvar3.,
					g.&byvar4.
				from &ds2. as pg left outer join
					 ciedw.provider as p on pg.provider_key=p.provider_key and pg.client_key=p.client_key left outer join
					 ciedw.practice as g on pg.practice_key=g.practice_key and pg.client_key=g.client_key
			 )as b on a.&byvar3. = b.&byvar3. and a.&byvar4. = b.&byvar4.
		where b.&byvar3. = . and b.&byvar4. = .;
		quit;
		
		%let count_new_provpracxref=0;

		proc sql noprint;
		select count(*) into: count_new
		from edw_provpracxref_validate_new ;
		quit;

		%put NOTE: &count_new. NEW PROVIDER PRACTICE XREF RECORDS;
		
		%if &count_new. ne 0 %then %do;		

			proc sort data = VSOURCE_PROVPRACXREF;
			by &byvar3. &byvar4.;
			run;

			proc sort data = edw_provpracxref_validate_new  
			          out  = new (keep = &byvar3. &byvar4. validation_type_id);
			by &byvar3. &byvar4.;
			run;

			data VSOURCE_PROVPRACXREF;
			merge VSOURCE_PROVPRACXREF  (in=a)
				  new              		(in=b);
			by &byvar3. &byvar4.;
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
		    left(put(b.&byvar.,30.)) 													as vld_value,
			b.&byvar. 																as entity_id, 
			b.&byvar.,
			a.&byvar3.,
			a.&byvar4.,
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
		  from &ds1. 	as a,
		       &ds2. 	as b
		  where a.&byvar1. = b.&byvar1. and
		  		a.&byvar2. = b.&byvar2. and
				a.&byvar1. ne . and 
				a.&byvar2. ne .
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
		
		%put NOTE: &count_change. CHANGED PROVIDER PRACTICE XREF RECORDS;

		%if &count_change. ne 0 %then %do;		


			proc sort data = VSOURCE_PROVPRACXREF;
			by &byvar3. &byvar4.;
			run;

			proc sort data = edw_provpracxref_validate_change  
			          out  = change (keep = &byvar. &byvar3. &byvar4. validation_type_id);
			by &byvar3. &byvar4.;
			run;

			data VSOURCE_PROVPRACXREF;
			merge VSOURCE_PROVPRACXREF  (in=a)
			      change 		   		(in=b);
			by &byvar3. &byvar4.;
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
		set  edw_provpracxref_validate_new			(in=a keep=&byvar3. &byvar4.)
			 edw_provpracxref_validate_change 		(in=b keep=&byvar. &byvar3. &byvar4.);
		run;

		proc sort data=edw_provpracxref_valid_critical1 nodupkey;
		by &byvar3. &byvar4.;
		run;

		proc sort data=ciedw.provider (keep=&byvar3.) nodup out=prov;
		by &byvar3.;
		where &byvar3. ne .;
		run;

		proc sort data=ciedw.practice (keep=&byvar4.) nodup out=prac;
		by &byvar4.;
		where &byvar4. ne .;
		run;

		data edw_provpracxref_valid_critical2;
		merge edw_provpracxref_valid_critical1 	(in=a)
			  prov								(in=b);
		by &byvar3.;
		if a;
		if a and not b then not_in_provider_edw = 1;
		else not_in_provider_edw = 0;
		run;

		proc sort data=edw_provpracxref_valid_critical2;
		by &byvar4.;
		run;

		data edw_provpracxref_valid_critical3;
		merge edw_provpracxref_valid_critical2 	(in=a)
			  prac								(in=b);
		by &byvar4.;
		if a;
		if a and not b then not_in_practice_edw = 1;
		else not_in_practice_edw = 0;
		run;

		proc sort data=edw_provpracxref_valid_critical3 nodupkey;
		by &byvar3. &byvar4.;
		run;
		
		%let varexist_id=%sysfunc(open(&ds1.));
		%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
		%let varexist_rc=%sysfunc(close(&varexist_id.));

		%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;

		proc sort data=&ds1.;
		by &byvar3. &byvar4.;
		run;

		data edw_provpracxref_valid_critical (keep=	wflow_exec_id vld_value entity_id &byvar3. &byvar4. 
													old_val new_val val_type validation_type_id);
		merge edw_provpracxref_valid_critical3 	(in=a)
		      &ds1.					   	(in=b %if &varexist_ind. > 0 %then %do; drop= validation_type_id %end;);
		by &byvar3. &byvar4.;
		if a then do;
		length wflow_exec_id 8. vld_value $30. entity_id practice_key 8. old_val new_val $50. val_type validation_type_id 8.;
		wflow_exec_id = &wflow_exec_id.;
		if &byvar. ne . then vld_value 	  = left(put(&byvar.,30.));
		else vld_value = '';
		if &byvar. ne . then entity_id = &byvar.;
		else entity_id = .;
		old_val		  = "NULL";
		new_val		  = "NULL";
		valiation_type_id = .;
		if &byvar1. = . then do;
			new_val = left(put(&byvar4.,30.));
			validation_type_id = 27;
		end;
		else if &byvar2. = . then do;
			new_val = left(put(&byvar3.,30.));
			validation_type_id = 26;
		end;
		else if not_in_practice_edw then do;
			new_val = left(put(&byvar4.,30.));
			validation_type_id = 38;
		end;
		else if not_in_provider_edw then do;
			new_val = left(put(&byvar3.,30.));
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
		
		%put NOTE: &count_critical. CRITICAL PROVIDER PRACTICE XREF RECORDS;

		%if &count_critical. ne 0 %then %do;		


			proc sort data = VSOURCE_PROVPRACXREF;
			by &byvar3. &byvar4.;
			run;

			proc sort data = edw_provpracxref_valid_critical  
			          out  = critical (keep = &byvar3. &byvar4. validation_type_id);
			by &byvar3. &byvar4.;
			run;

			data VSOURCE_PROVPRACXREF;
			merge VSOURCE_PROVPRACXREF 	(in=a)
			      critical 		   		(in=b);
			by &byvar3. &byvar4. ;
			if a and b then do;
				validation_id = validation_type_id;
			end;
			run;
		
		%end;

		%put NOTE: Counts - Provider Practice XREF validations for the CI program - CRITICAL:  &count_critical. ;

	%end;


%mend  edw_provpracxref_valids;
