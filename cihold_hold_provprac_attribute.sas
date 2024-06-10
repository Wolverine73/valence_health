/*HEADER------------------------------------------------------------------------
|
| program:  cihold_hold_provprac_attribute.sas
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
| 28JUN2012 - Winnie Lee - Original
|             
+-----------------------------------------------------------------------HEADER*/

%macro cihold_hold_provprac_attribute (in_dataset=);

	%local count_hold condition_validation_type_id;
    %global provpracattr_count; /* used in practice_payer_load call for provpracxref_payer_load flag*/
	%let count_hold=0;

    proc sql;
		connect to oledb(init_string=&cihold);
		execute 
		(
			IF EXISTS
			(
				SELECT *
				FROM sys.tables
				WHERE name = %str(%')saswrk_provprac_attr_&wflow_exec_id.%str(%') AND schema_id = SCHEMA_ID('dbo'))								

				DROP TABLE cihold.dbo.saswrk_provprac_attr_&wflow_exec_id.;						
			)					
		by oledb;
	quit;

	%let varexist_id=%sysfunc(open(&in_dataset.));
	%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_id));
	%let varexist_rc=%sysfunc(close(&varexist_id.));

		%let provpracxref_count=&count_hold;
	
	%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;	

	%if &varexist_ind. > 0 %then %do; 
	    proc sql noprint;
		  select count(*) into: count_hold
		  from &in_dataset.
	      where validation_id ne 0;
		quit;
	%end;
     
    %let provpracattr_count=&count_hold;
	%put NOTE: Provider Hold Count: &count_hold. ;
    
	%if &count_hold. ne 0 %then %do;	

		%let src_record_cnt=&count_hold.;
		%let tgt_record_cnt=&count_hold.;
		
		proc sql noprint;
		  select validation_type_id into: condition_validation_type_id separated by ','
		  from vbpm.validation_type
		  where load_flag=1;
		quit;
		
		%put NOTE: condition_validation_type_id = &condition_validation_type_id;

		data hold_provprac_attribute (drop=src_:);
		set &in_dataset.;
		where validation_id ne 0;
		if validation_id in (&condition_validation_type_id.) then load_flag = 1;  /** new, term, change  **/
		else load_flag = 0;                              /** critical           **/
		run;

		PROC APPEND BASE = bcphold.saswrk_provprac_attr_&wflow_exec_id.
		DATA = hold_provprac_attribute FORCE;
		run;

		options nomlogic nomprint; 
		%set_error_flag
		%on_error(ACTION=ABORT)
		options mlogic mprint; 
	%end;

%mend cihold_hold_provprac_attribute;
