
/*HEADER------------------------------------------------------------------------
|
| program:  cihold_hold_practice_addr.sas
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

%macro cihold_hold_practice_addr (in_dataset=);

	%local count_hold ;

	%let count_hold=0;

    proc sql noprint;
	  delete *
	  from cihold.hold_practice_addr
	  where wflow_exec_id = &wflow_exec_id. ;
	quit;	

	%let varexist_id=%sysfunc(open(&in_dataset.));
	%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_id));
	%let varexist_rc=%sysfunc(close(&varexist_id.));

	%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;	

	%if &varexist_ind. > 0 %then %do; 
	    proc sql noprint;
		  select count(*) into: count_hold
		  from vsource_practice_addr
	      where validation_id ne 0;
		quit;
	%end;

	%put NOTE: practice address Hold Count: &count_hold. ;

	%if &count_hold. ne 0 %then %do;	

		%let src_record_cnt=&count_hold.;
		%let tgt_record_cnt=&count_hold.;

	    data hold_practice_addr (drop=src_:);
		  set &in_dataset.;
	      where validation_id > 0 and validation_id ne .;
		  if validation_id in (22,23) then load_flag = 1;  	/** new, term, change  **/
		  else load_flag = 0;                              		/** critical           **/
		run;

		proc sql;
			insert into cihold.hold_practice_addr
			(	
				practice_addr_key,
				practice_key,
				client_key,
				wflow_exec_id, 
				addr_line_1,
				addr_line_2,	
				city,
				state,  		
				zip_code,  		
				county,  			
				data_cmplt_ind,  		
				prim_addr_ind,
				load_flag, 
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by  			
			)
			select distinct
				practice_addr_key,
				practice_key,
				client_key,
				wflow_exec_id,
				addr_line_1,
				addr_line_2,	
				city,
				state,  		
				zip_code,  		
				county,  			
				data_cmplt_ind,  		
				prim_addr_ind,
				load_flag, 
				created_on,  			
				created_by,  			
				updated_on,  			
				updated_by   		
			from hold_practice_addr ;
		quit;

	%end;

%mend cihold_hold_practice_addr;
