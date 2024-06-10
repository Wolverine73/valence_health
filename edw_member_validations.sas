
/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_validations.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose: Create the validation information for the Member process and
|          load the BPMMetadata tables
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
| 10DEC2010 - Robyn Stellman  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro edw_member_validations(in_dataset2=,in_dataset1=,by_variable=, oldval=,newval=);

%if &oldval = %then %let oldval=%str(" ");
%if &newval = %then %let newval=%str(" ");


    *SASDOC--------------------------------------------------------------------------
  | Determine the new records
  |
  +------------------------------------------------------------------------SASDOC*; 

proc sql;
  create table edw_member_validate_new as select
      &wflow_exec_id. 			         	as wflow_exec_id,
			a.&by_variable. 				as entity_id,  
		    &oldval.    					as old_val length=255,
		    put(&newval.,16.) 		    	as new_val length=255,
		    51								as val_type,
		    19					    		as validation_type_id
		  from &in_dataset1. as a
		  left join &in_dataset2. as b
		  on a.&by_variable. = b.&by_variable. 
          where b.&by_variable. = . 
            and a.&by_variable. ne .
            and &newval. ne 0;
quit;


    *SASDOC--------------------------------------------------------------------------
  | Determine the changed records
  |
  +------------------------------------------------------------------------SASDOC*; 

proc sql;
  create table edw_member_validate_change as select
      &wflow_exec_id. 			         	as wflow_exec_id,
			a.&by_variable. 				as entity_id,  
		case when a.ssn        ne   b.ssn      then a.ssn
		     when a.fname      ne   b.fname    then a.fname
			 when a.lname      ne   b.lname    then a.lname
			 when a.address1   ne   b.address1 then a.address1
			 when a.address2   ne   b.address2 then a.address2
			 when dhms(a.dob,0,0,0)        ne   b.dob      then put(dhms(a.dob,0,0,0),datetime.)
			 when a.city       ne   b.city     then a.city
			 when a.state      ne   b.state    then a.state
			 when a.zip        ne   b.zip      then a.zip
			 when a.sex        ne   b.sex      then a.sex
			 when a.phone      ne   b.phone    then a.phone
			 else "NULL"
												end as new_val length=255,

		case when a.ssn        ne   b.ssn      then b.ssn
		     when a.fname      ne   b.fname    then b.fname
			 when a.lname      ne   b.lname    then b.lname
			 when a.address1   ne   b.address1 then b.address1
			 when a.address2   ne   b.address2 then b.address2
			 when dhms(a.dob,0,0,0)        ne   b.dob      then put(b.dob,datetime.)
			 when a.city       ne   b.city     then b.city
			 when a.state      ne   b.state    then b.state
			 when a.zip        ne   b.zip      then b.zip
			 when a.sex        ne   b.sex      then b.sex
			 when a.phone      ne   b.phone    then b.phone
			 else "NULL"
            	    					        end as old_val length=255,
		    52 								as val_type,
		    20					    		as validation_type_id
		  from &in_dataset1. as a
		  left join &in_dataset2. as b
		  on a.&by_variable. = b.&by_variable. 
          where  b.&by_variable. ne . and
           (a.ssn ne b.ssn             or
            a.fname ne b.fname         or
            a.lname ne b.lname         or
			dhms(a.dob,0,0,0) ne b.dob or
            a.address1 ne b.address1   or
            a.address2 ne b.address2   or
            a.city     ne b.city       or
            a.state    ne b.state      or
		a.zip      ne b.zip        or
            a.sex      ne b.sex        or
            a.phone    ne b.phone );
quit;


    *SASDOC--------------------------------------------------------------------------
  | Determine the critical (no member_key) records
  |
  +------------------------------------------------------------------------SASDOC*; 
proc sql;
  create table edw_member_validate_critical as select
      &wflow_exec_id. 			         	as wflow_exec_id,
			case when a.&by_variable.=0 then 999999999999
			      else a.&by_variable. end
                                            as entity_id,  
		    53 								as val_type,
			case when ((length(a.ssn) < 9) and dob ne .) then 35
			     when ((length(a.ssn) = 9) and dob = .) then 36
				 when ((length(a.ssn) < 9) and dob = .) then 37 
                 else 21 end	    		as validation_type_id,
			"NULL"							as old_val length=255,
			"NULL"							as new_val length=255
		  from &in_dataset1. as a
          where /**dq_member_flag = 1*/ member_key=0 ;
quit;

%let count_new =0;
%let count_change=0;
%let count_critical=0;


    *SASDOC--------------------------------------------------------------------------
  | Get counts for the BPMMetadata tables
  |
  +------------------------------------------------------------------------SASDOC*; 

proc sql noprint;
  select count(*) into: count_new
  from edw_member_validate_new  ;

  select count(*) into: count_change
  from edw_member_validate_change ;

  select count(*) into: count_critical
  from edw_member_validate_critical ;
quit;

%put NOTE: Counts - Member validations for the CI program - NEW: &count_new. ;	
%put NOTE: Counts - Member validations for the CI program - CHANGE: &count_change. ;
%put NOTE: Counts - Member validations for the CI program - CRITICAL: &count_critical. ;

%mend edw_member_validations;


