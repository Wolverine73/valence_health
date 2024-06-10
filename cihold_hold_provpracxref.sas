
/*HEADER------------------------------------------------------------------------
|
| program:  cihold_hold_provpracxref.sas
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

%macro cihold_hold_provpracxref (in_dataset=);

	%local count_hold ;

	%let count_hold=0;

    proc sql noprint;
	  delete *
	  from cihold.hold_provider_practice_xref
	  where wflow_exec_id = &wflow_exec_id. ;
	quit;	

	%let varexist_id=%sysfunc(open(&in_dataset.));
	%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_id));
	%let varexist_rc=%sysfunc(close(&varexist_id.));

	%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;	

	%if &varexist_ind. > 0 %then %do; 
	    proc sql noprint;
		  select count(*) into: count_hold
		  from vsource_provpracxref
	      where validation_id ne 0;
		quit;
	%end;

	%put NOTE: Provider Practice XREF Hold Count: &count_hold. ;

	%if &count_hold. ne 0 %then %do;	

		%let src_record_cnt=&count_hold.;
		%let tgt_record_cnt=&count_hold.;

	    data hold_provpracxref;
		  set &in_dataset.;
	      where validation_id > 0 and validation_id ne .;
		  if validation_id in (24,25) then load_flag = 1;  	/** new, term, change  **/
		  else load_flag = 0;                              		/** critical           **/
		run;

		proc sql;
		  insert into cihold.hold_provider_practice_xref
		   (	practice_key,
				provider_key,
				client_key,
				wflow_exec_id,  		
				primary_practice_ind,
				eff_dt,	
				exp_dt,
				load_flag,  		
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by  			
		   )
			  select
				practice_key,
				provider_key,
				client_key,
				wflow_exec_id,  		
				primary_practice_ind,
				eff_dt,	
				exp_dt,
				load_flag,  		
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by   		
			  from hold_provpracxref ;
			quit;

	%end;

%mend cihold_hold_provpracxref;
