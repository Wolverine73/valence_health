
/*HEADER------------------------------------------------------------------------
|
| program:  edw_claim_validations.sas
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
|             
+-----------------------------------------------------------------------HEADER*/


%macro edw_claim_validations(vt_name=, validation_type_id=, in_dataset1=, oldval=, newval=, by_variable=,critical_variables_list=);

    %local count_new count_critical count_change ;  
	  
	%if &oldval = %then %let oldval=%str("NULL");
	%if &newval = %then %let newval=%str("NULL");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - Validations for new claims
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;

	    %put NOTE: Performing EDW - Claims validations for the CI program - NEW ;

	    proc sql noprint;
		  create table edw_claim_validate_new as
		  select 
		    &wflow_exec_id. 				as wflow_exec_id,
		    left(put(a.&by_variable.,32.)) 	as vld_value,
			a.&by_variable. 				as entity_id,  
			a.&by_variable. 				as claim_key,
		    &oldval.    					as old_val length=32,
		    left(put(a.&by_variable.,32.))	as new_val length=32,
		    97 								as val_type,
		    &validation_type_id.    		as validation_type_id
		  from &in_dataset1. as a  
          where a.claim_exists_key = 0 
            and a.dq_claim_flag    = 0 
            and a.dq_member_flag   = 0;
		quit;
		
		%let count_new_providers=0;

		proc sql noprint;
		  select count(*) into: count_new
		  from edw_claim_validate_new ;
		quit;

		%if &count_new. ne 0 %then %do;		

			proc sort data = &dsn.;
			  by claim_key ;
			run;

			proc sort data = edw_claim_validate_new  
			          out  = new (keep = claim_key validation_type_id) nodupkey;
			  by claim_key ;
			run;

			data &dsn.;
			  merge &dsn.   (in=a)
			        new     (in=b);
			  by claim_key ;
			  if a;
			  if a and b then do;
			    validation_id = validation_type_id;
				load_flag=0;
			  end;
			run;

		%end;
		
		%put NOTE: Counts - Claims validations for the CI program - NEW:  &count_new. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED PROVIDERS
	|
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE %then %do;

	    %put NOTE: Performing EDW - Claims validations for the CI program - CHANGE ;


	    proc sql noprint;
		  create table edw_claim_validate_change as
		  select  
		    &wflow_exec_id. 																as wflow_exec_id,
		    left(put(b.&by_variable.,32.)) 													as vld_value,
			b.&by_variable. 																as entity_id, 
			a.claim_key   																    as claim_key,
			case when a.diagnosis_cd1	 ne b.diagnosis_cd1		then b.diagnosis_cd1	
				 when a.diagnosis_cd2	 ne b.diagnosis_cd2  	then b.diagnosis_cd2
				 when a.diagnosis_cd3	 ne b.diagnosis_cd3  	then b.diagnosis_cd3
				 when a.diagnosis_cd4	 ne b.diagnosis_cd4  	then b.diagnosis_cd4
				 when a.diagnosis_cd5	 ne b.diagnosis_cd5  	then b.diagnosis_cd5
				 when a.diagnosis_cd6	 ne b.diagnosis_cd6  	then b.diagnosis_cd6
				 when a.diagnosis_cd7	 ne b.diagnosis_cd7  	then b.diagnosis_cd7
				 when a.diagnosis_cd8	 ne b.diagnosis_cd8  	then b.diagnosis_cd8
				 when a.diagnosis_cd9	 ne b.diagnosis_cd9  	then b.diagnosis_cd9	
				 when a.pos  			 ne b.pos   			then b.pos
				 when a.revenue_code	 ne b.revenue_code		then b.revenue_code	
				 when a.maj_cat_name	 ne b.maj_cat_name  	then left(put(b.maj_cat_name,32.))
				 when a.units  			 ne b.units   			then left(put(b.units,32.))
				 when a.submitted		 ne b.submitted   		then left(put(b.submitted,32.)) 		
				 when a.payer_key   	 ne b.payer_key 	    then left(put(b.payer_key,32.))	
				 when a.admit_diagnosis_cd ne b.admit_diagnosis_cd 	then left(put(b.admit_diagnosis_cd,32.)) 
				 when a.drg_key			 ne b.drg_key   		then left(put(b.drg_key,32.))	
				 when a.bill_type  		 ne b.bill_type   		then b.bill_type
				 when a.discharge_status ne b.discharge_status  then b.discharge_status
				 when a.tin              ne b.tin               then b.tin
				 when a.referral         ne b.referral          then b.referral
				 when a.vMine_kProcessID ne b.vMine_kProcessID  then left(put(b.vMine_kProcessID,32.))
				 else "NULL"															end	as old_val length=32, 															
			case when a.diagnosis_cd1	 ne b.diagnosis_cd1		then a.diagnosis_cd1	
				 when a.diagnosis_cd2	 ne b.diagnosis_cd2  	then a.diagnosis_cd2
				 when a.diagnosis_cd3	 ne b.diagnosis_cd3  	then a.diagnosis_cd3
				 when a.diagnosis_cd4	 ne b.diagnosis_cd4  	then a.diagnosis_cd4
				 when a.diagnosis_cd5	 ne b.diagnosis_cd5  	then a.diagnosis_cd5
				 when a.diagnosis_cd6	 ne b.diagnosis_cd6  	then a.diagnosis_cd6
				 when a.diagnosis_cd7	 ne b.diagnosis_cd7  	then a.diagnosis_cd7
				 when a.diagnosis_cd8	 ne b.diagnosis_cd8  	then a.diagnosis_cd8
				 when a.diagnosis_cd9	 ne b.diagnosis_cd9  	then a.diagnosis_cd9	
				 when a.pos  			 ne b.pos   			then a.pos	
				 when a.revenue_code	 ne b.revenue_code		then a.revenue_code	
				 when a.maj_cat_name	 ne b.maj_cat_name  	then left(put(a.maj_cat_name,32.))
				 when a.units  			 ne b.units   			then left(put(a.units,32.))
				 when a.submitted		 ne b.submitted   		then left(put(a.submitted,32.)) 		
				 when a.payer_key   	 ne b.payer_key 	    then left(put(a.payer_key,32.))	
				 when a.admit_diagnosis_cd ne b.admit_diagnosis_cd 	then left(put(a.admit_diagnosis_cd,32.)) 
				 when a.drg_key			 ne b.drg_key   		then left(put(a.drg_key,32.))	
				 when a.bill_type  		 ne b.bill_type   		then a.bill_type
				 when a.discharge_status ne b.discharge_status  then a.discharge_status
				 when a.tin              ne b.tin               then a.tin
				 when a.referral         ne b.referral          then a.referral
				 when a.vMine_kProcessID ne b.vMine_kProcessID  then left(put(a.vMine_kProcessID,32.))
				 else "NULL"															end	as new_val length=32, 														
		    97																				as val_type,
			&validation_type_id.    														as validation_type_id
		  from &in_dataset1. 					                as a,
		       cihold.saswrk_header_detail_&wflow_exec_id. 	as b 
          where a.client_key=b.client_key 
		    and a.member_key=b.member_key
		    and a.practice_key=b.practice_key
		    and a.procedure_code_key=b.procedure_code_key
		    and a.service_date2=b.service_date
			and a.provider_key=b.provider_key
		    and a.mod1=b.mod1
			and a.mod2=b.mod2

            and b.claim_exists_key = 1 
            and a.dq_claim_flag    = 0 
            and a.dq_member_flag   = 0 ;
		quit;

		data edw_claim_validate_change;
			set edw_claim_validate_change;
			if new_val='NULL' and old_val='NULL' then do;
			  new_val='HISTORY';
			  old_val='HISTORY';
			end;
		run;
		
		%let count_change=0;		

		proc sql noprint;
		  select count(*) into: count_change
		  from edw_claim_validate_change;
		quit;

		%if &count_change. ne 0 %then %do;		

			proc sort data = &dsn.;
			  by claim_key ;
			run;

			proc sort data = edw_claim_validate_change  
			          out  = change (keep = claim_key validation_type_id) nodupkey;
			  by claim_key ;
			run;

			data &dsn.;
			  merge &dsn.   (in=a)
			        change  (in=b);
			  by claim_key ;
			  if a;
			  if a and b then do;
			    validation_id = validation_type_id;
				load_flag=0;
				validation_value=new_val;
			  end;
			run;

		%end;
		
		%put NOTE: Counts - Claims validations for the CI program - CHANGE:  &count_change. ;

	%end; 

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CLAIMS WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL %then %do;

	    %put NOTE: Performing EDW - Claims validations for the CI program - CRITICAL ;

		%let cvl=0; 
		%do %while (%scan(&critical_variables_list., &cvl+1) ne );		

			%let cvl=%eval(&cvl+1);
			%let CriticalVar=%scan(&critical_variables_list. ,&cvl); 
			%let CriticalVar=%sysfunc(compress(&CriticalVar,"'"));

			%global &CriticalVar._bpm ; 

				proc sql noprint;
				  select count(*) into: &CriticalVar._bpm
				  from summary_validation
				  where index(upcase(data_validation), 'NOT ACCEPTABLE')  
				    and left(substr(upcase(data_variable),12)) in ("&CriticalVar.") ; /** 4 critical validations **/
				quit;
				

				%if &&&CriticalVar._bpm = 0 %then %let &CriticalVar._bpm=1; /** acceptable = true **/
				%else %let &CriticalVar._bpm=0; /** acceptable = false **/

			%put NOTE: &CriticalVar._bpm = &&&CriticalVar._bpm;

		%end;
		
		/*SASDOC--------------------------------------------------------------------------
		| Adding additional critical issues
		|  1.  update bpm.validdation_type
		|  2.  add values to keep statement
		|  3.  add else if statement for variable to validate
		|  4.  sequence or hierarchy of the if then conditions is crucial
		|      once a condition is met the validation type id is set and remaining
		|      validations are not checked - ALWAYS critical 1st warning 2nd
		|
		|  note:  the critical issues are npi, member, proccd, svcdt
		|         the warning issues are diag1, pos, dob, lname, phone, gender
		+------------------------------------------------------------------------SASDOC*/ 

		data edw_claim_validate_critical;
		    length wflow_exec_id 8. vld_value $32. entity_id 8. old_val new_val $32. val_type validation_type_id 8.;
		    set  &dsn (keep = member_key provider_key service_date procedure_code_key npi proccd memberid
                              diag1 diagnosis_cd1 pos phone sex lname dob claim_key dq_claim_flag dq_member_flag validation_: issue_: ) ;
		    where not (dq_claim_flag = 0 and dq_member_flag = 0);

		    wflow_exec_id = &wflow_exec_id.;
		    vld_value 	  = left(put(&by_variable.,32.));
		    entity_id	  = &by_variable.;
		    old_val	  = &oldval.;
		    val_type  	  = 97;

			/********************** CRITICAL VALIDATIONS ********************************************************/
			if upcase(validation_npi) = "INVALID" then do;
				new_val = left(put(provider_key,32.));
				if npi ne '' then old_val = npi;  /** for key values that are missing or 0 **/
				validation_type_id = 30;
				acceptable=&npi_bpm.; 
			end;
			else if upcase(validation_svcdt) = "INVALID" then do;
				new_val = service_date;
				validation_type_id = 31;
				acceptable=&svcdt_bpm.; 
			end;
			else if upcase(validation_proccd) = "INVALID" then do;
				new_val = left(put(procedure_code_key,32.));
				if proccd ne '' then old_val = proccd;  /** for key values that are missing or 0 **/
				validation_type_id = 32;
				acceptable=&proccd_bpm.; 
			end;
			else if upcase(validation_memberid) = "INVALID" then do;
				new_val = left(put(member_key,32.));
				if memberid ne '' then old_val = memberid;  /** for key values that are missing or 0 **/
				validation_type_id = 33;
				acceptable=&memberid_bpm.; 
			end;
			
			/********************** WARNING VALIDATIONS ********************************************************/
			else if upcase(validation_diag1) = "INVALID" then do;
				new_val = diagnosis_cd1 ;
				if diag1 ne '' then old_val = diag1;  /** for key values that are missing or 0 **/
				validation_type_id = 34;
				acceptable=&diag1_bpm.; 
			end;			
			else if upcase(validation_pos) = "INVALID" then do;
				new_val = pos ;
				if pos ne '' then old_val = pos;  /** for key values that are missing or 0 **/
				validation_type_id = 40;
				acceptable=&pos_bpm.; 
			end;	
			else if upcase(validation_sex) = "INVALID" then do;
				new_val = sex ;
				if sex ne '' then old_val = sex;  /** for key values that are missing or 0 **/
				validation_type_id = 44;
				acceptable=&sex_bpm.; 
			end;
			else if upcase(validation_phone) = "INVALID" then do;
				new_val = phone ;
				if phone ne '' then old_val = phone;  /** for key values that are missing or 0 **/
				validation_type_id = 45;
				acceptable=&phone_bpm.; 
			end;
			else if upcase(validation_lname) = "INVALID" then do;
				new_val = lname ;
				if lname ne '' then old_val = lname;  /** for key values that are missing or 0 **/
				validation_type_id = 46;
				acceptable=&lname_bpm.; 
			end;
			else if upcase(validation_dob) = "INVALID" then do;
				new_val = '' ;
				if dob ne . then old_val = put(dob,mmddyy10.);  /** for key values that are missing or 0 **/
				validation_type_id = 43;
				acceptable=&dob_bpm.; 
			end;

		run;


		/*SASDOC--------------------------------------------------------------------------
		| Reset load and dq claim flag to non-critical 
		|
		+------------------------------------------------------------------------SASDOC*/ 
		
		%let count_critical=0;		

		proc sql noprint;
		  select count(*) into: count_critical
		  from edw_claim_validate_critical;
		quit; 

		%if &count_critical. ne 0 %then %do;
		
			proc sql noprint;
			  select validation_type_id into: reset_load_flag separated by ','
			  from vbpm.validation_type
			  where vld_subject = 4
			    and load_flag = 0 ;
			quit;
			
			%if &facility_indicator. = 1 %then %do;
			  %let reset_load_flag = &reset_load_flag. ,30; /** facility - exclude 30-NPIs **/
			%end;	
			
			
			proc sort data = &dsn.;
			  by claim_key ;
			run;

			proc sort data = edw_claim_validate_critical  
			          out  = critical (keep = claim_key validation_type_id) nodupkey;
			  by claim_key ;
			run;

			data &dsn.;
			  merge &dsn.     (in=a)
			        critical  (in=b);
			  by claim_key ;
			  if a;
			  if a and b then do;
			        validation_id = validation_type_id;
				load_flag=1;
				if validation_type_id in (&reset_load_flag.) then do;
				  load_flag=0;
				  dq_claim_flag=0;
				end;
			  end;
			run;

		%end;

		%put NOTE: Counts - Claims validations for the CI program - CRITICAL:  &count_critical. ;

	%end;

%mend  edw_claim_validations;
