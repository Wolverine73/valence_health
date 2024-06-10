
/*HEADER------------------------------------------------------------------------
|
| program:  edw_practice_payer_validations.sas
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
| HISTORY:  05MAY2012 - Brandon Fletcher - Copied Structure from CI provider practice process - Original
|             
|           06JUN2012 - Brandon Fletcher - The payer data can join to vsource_data now.
+-----------------------------------------------------------------------HEADER*/


%macro edw_practice_payer_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, by_variable=, by_variable2=, by_variable3=);
       
    %local count_new count_delete count_change ;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW practiceS
	| MUST PERFORM practice AND practice_PAYER TABLE SEPARATELY FOR BPM REPORT
	| 
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;
	    %put ;%put NOTE: Starting &vt_name. validations for the CI program;%put ;
	
        %if %upcase(&in_dataset2.) = PRACTICE %then %do;
	    
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - NEW ;%put ;

		proc sql noprint;
				create table &in_dataset2._validate_new as
				  select distinct
						 &wflow_exec_id. 						as wflow_exec_id,
						 strip(src.&by_variable.) 				as vld_value,
						 min(src.&by_variable2.)				as entity_id,
						 min(src.&by_variable2.) 				as &by_variable2., 
						 src.&by_variable. 						as TIN,
						 ''		    							as old_val length=50,
						 max(src.name)    						as new_val length=50,
						 97 									as val_type,
						 &validation_type_id.    				as validation_type_id
					from &in_dataset1. as src 
					left join ciedw.&in_dataset2. as tgt 
					  on src.&by_variable. = tgt.&by_variable. 
					 and src.client_key = tgt.client_key 
					 and tgt.practice_key > 0
					where missing(tgt.&by_variable.)
					group by src.&by_variable.
				;
			quit;
			
			%let count_new=0;

			proc sql noprint;
				select 
					count(*) into: count_new
				from &in_dataset2._validate_new ;
			quit;
			
			%if &count_new. ne 0 %then %do;		

				proc sort data = &in_dataset1.;
				by &by_variable. &by_variable2.;
				run;

				proc sort data = &in_dataset2._validate_new  
						  out  = new (keep = &by_variable. &by_variable2. validation_type_id);
				by &by_variable. &by_variable2.;
				run;

				/* FLAG APPLICABLE RECORDS FROM THE ORIGINAL DATASET WITH NEW INDICATOR */
				
				data &in_dataset1.;
				merge &in_dataset1. (in=a)
					  new           (in=b);
				by &by_variable. &by_variable2.;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;

			%end; 

			%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - NEW:  &count_new. ;%put ;
			
        %end; /* NEW - practice IF */
		
		%else %if %upcase(&in_dataset2.) = PRACTICE_PAYER %then %do;
		
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - NEW ;%put ;

			proc sql noprint;
				create table &in_dataset2._validate_new as
					select distinct
						&wflow_exec_id. 				as wflow_exec_id,
						strip(src.&by_variable.)			as vld_value,
						src.&by_variable3. 				as entity_id,						
						src.&by_variable. 				as TIN,
						src.&by_variable2. 				as system_practice_id,
						src.&by_variable3. 				as &by_variable3.,
						''	    						as old_val length=50,
						src.name    						as new_val length=50,
						97 								as val_type,
						&validation_type_id.    		as validation_type_id
					from &in_dataset1. as src 
					left join ciedw.&in_dataset2. as tgt  
					  on src.&by_variable. = tgt.&by_variable.
					  and coalesce(src.&by_variable2.,'') = coalesce(tgt.&by_variable2.,'')
					 and src.payer_key = tgt.payer_key
					 and src.client_key = tgt.client_key
				    where missing(tgt.&by_variable.)
				;
			quit;
			
			%let count_new=0;

			proc sql noprint;
				select 
					count(*) into: count_new
				from &in_dataset2._validate_new ;
			quit;
			
			%if &count_new. ne 0 %then %do;		

				proc sort data = &in_dataset1.;
				by &by_variable. &by_variable2.;
				run;

				proc sort data = &in_dataset2._validate_new  
						  out  = new (keep = &by_variable. &by_variable2. &by_variable3. validation_type_id);
				by &by_variable. &by_variable2.;
				run;

				data &in_dataset1.;
				merge &in_dataset1. (in=a)
					  new           (in=b);
				by &by_variable. &by_variable2.;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;

			%end; /* COUNT_NEW IF */

				%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - NEW:  &count_new. ;%put ;
			
		%end; /*  NEW - practice_PAYER IF */
	%end; /* NEW IF */
	
	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED practiceS
	| MUST CHECK practice AND practice_PAYER TABLE SEPARATELY 
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE %then %do;
	          %put ;%put NOTE: Starting &vt_name. validations for the CI program;%put ;
			  
        %if %upcase(&in_dataset2.) = PRACTICE %then %do;
	    
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - CHANGE ;%put ;
		
		/*SASDOC-------------------------------------------------------------------------- 
		|   1) SELECT ONLY COMMON RECORDS VIA INNER JOIN 
		|   2) PERFORM AN EXCEPT(LEFT JOIN) ON ALL BUSINESS COLUMNS POPULATED 
		|   3) ONLY RETURN CHANGED BUSINESS COLUMNS
		+------------------------------------------------------------------------SASDOC*/
			proc sql noprint;
					create table &in_dataset2._vldt_change as

						   SELECT distinct 
								  SRC.TIN
								, SRC.CLIENT_KEY
								, SRC.NAME
								, &wflow_exec_id. 						as wflow_exec_id 
								, 99									as val_type
								, SRC.&by_variable2.					as entity_id
								, &by_variable2.
								, &validation_type_id.  				as validation_type_id
								, SRC.NAME								AS NEW_VALUE
								, TGT.PRACTICE_NAME						AS OLD_VALUE
								
						  FROM &in_dataset1.  								SRC
						 INNER JOIN ciedw.&in_dataset2.  					TGT 
							ON SRC.&by_variable. = TGT.&by_variable.
						   AND SRC.client_key = TGT.client_key
						   AND SRC.&in_dataset2._validation_id  NE 79  /* DON'T CHECK NEW RECORDS */ 
						   AND TGT.IS_VSOURCE_DATA = 0  /* CANNOT UPDATE VSOURCE PRACTICE NAME */
						   
					EXCEPT 
						
					   SELECT TGT.TIN
							, TGT.client_key
							, TGT.PRACTICE_NAME 					as NAME
							, &wflow_exec_id. 						as wflow_exec_id 
							, 99									as val_type
							, SRC.&by_variable2.					as entity_id
							, &by_variable2.
							, &validation_type_id.  				as validation_type_id
							, SRC.NAME								AS NEW_VALUE
							, TGT.PRACTICE_NAME						AS OLD_VALUE
						  FROM &in_dataset1.  								SRC
						 INNER JOIN ciedw.&in_dataset2.  					TGT 
							ON SRC.&by_variable. = TGT.&by_variable.
						   AND SRC.client_key = TGT.client_key
						   AND SRC.&in_dataset2._validation_id  NE 87  /* DON'T CHECK NEW RECORDS */ 
						   AND TGT.IS_VSOURCE_DATA = 0 /* CANNOT UPDATE VSOURCE PRACTICE NAME */
					;
				quit;		
			
			%let count_change=0;		

			proc sql noprint;
			select 
				count(*) into: count_change
			from &in_dataset2._vldt_change;
			quit;
		
			%if &count_change. ne 0 %then %do;		


				proc sort data = practice_payer_src_&client_id;
				by &by_variable. &by_variable2.;
				run;

				proc sort data = &in_dataset2._vldt_change  
						  out  = change (keep = &by_variable. &by_variable2. validation_type_id);
				by &by_variable. &by_variable2.;
				run;

				data practice_payer_src_&client_id;
				merge practice_payer_src_&client_id (in=a)
					  change 		   (in=b);
				by &by_variable. &by_variable2. ;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;
			
			%end; /* COUNT_CHANGE IF */
			
			%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - CHANGE:  &count_change. ;%put ;
			
		%end; /* CHANGE-practice IF*/

			
		
        %else %if %upcase(&in_dataset2.) = PRACTICE_PAYER %then %do;
	    
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - CHANGE ;%put ;
			
		/*SASDOC-------------------------------------------------------------------------- 
		|   1) SELECT ONLY COMMON RECORDS VIA INNER JOIN WHERE IS_VSOURCE_DATA IS ZERO
		|      a) CANNOT UPDATE VSOURCE DATA
		|   2) PERFORM AN EXCEPT(LEFT JOIN) ON ALL BUSINESS COLUMNS POPULATED 
		|   3) ONLY RETURN CHANGED BUSINESS COLUMNS
		+------------------------------------------------------------------------SASDOC*/		
	
			 proc sql noprint;
					create table &in_dataset2._vldt_change as

						SELECT  distinct SRC.TIN
							 , SRC.CLIENT_KEY
							 , SRC.NAME
							 , SRC.ADDRESS1
							 , SRC.ADDRESS2
							 , SRC.CITY    
							 , SRC.STATE   
							 , SRC.ZIP     
							 , SRC.COUNTY
							 , SRC.SYSTEM_PRACTICE_ID
							 , &wflow_exec_id. 			as wflow_exec_id 
							 , 99						as val_type
							 , SRC.&by_variable3. 		as entity_id
							 , SRC.&by_variable3. 		as &by_variable3.
							 , &validation_type_id.  	as validation_type_id
							 , CASE WHEN SRC.NAME          		NE TGT.NAME 				THEN SRC.NAME
									WHEN SRC.ADDRESS1      		NE TGT.ADDRESS1     		THEN SRC.ADDRESS1
									WHEN SRC.ADDRESS2      		NE TGT.ADDRESS2     		THEN SRC.ADDRESS2
									WHEN SRC.CITY          		NE TGT.CITY         		THEN SRC.CITY    
									WHEN SRC.STATE         		NE TGT.STATE        		THEN SRC.STATE   
									WHEN SRC.ZIP           		NE TGT.ZIP          		THEN SRC.ZIP     
									WHEN SRC.COUNTY        		NE TGT.COUNTY       		THEN SRC.COUNTY
									WHEN SRC.SYSTEM_PRACTICE_ID NE TGT.SYSTEM_PRACTICE_ID	THEN SRC.SYSTEM_PRACTICE_ID
									ELSE ''
								END AS NEW_VALUE
							, CASE  WHEN SRC.NAME          		NE TGT.NAME 				THEN TGT.NAME
									WHEN SRC.ADDRESS1      		NE TGT.ADDRESS1     		THEN TGT.ADDRESS1
									WHEN SRC.ADDRESS2      		NE TGT.ADDRESS2     		THEN TGT.ADDRESS2
									WHEN SRC.CITY          		NE TGT.CITY         		THEN TGT.CITY    
									WHEN SRC.STATE         		NE TGT.STATE        		THEN TGT.STATE   
									WHEN SRC.ZIP           		NE TGT.ZIP          		THEN TGT.ZIP     
									WHEN SRC.COUNTY        		NE TGT.COUNTY       		THEN TGT.COUNTY
									WHEN SRC.SYSTEM_PRACTICE_ID NE TGT.SYSTEM_PRACTICE_ID	THEN TGT.SYSTEM_PRACTICE_ID
									ELSE ''									
								END AS OLD_VALUE				
						  FROM &in_dataset1.  								SRC
						 INNER JOIN ciedw.&in_dataset2.   					TGT 
							ON SRC.&by_variable. = TGT.&by_variable.
						   AND coalesce(SRC.&by_variable2.,'') = coalesce(TGT.&by_variable2.,'')
						   AND SRC.client_key = TGT.client_key
						   AND SRC.payer_key = TGT.payer_key
						   AND SRC.&in_dataset2._validation_id  NE 89  /* DON'T CHECK NEW RECORDS */ 
					
					EXCEPT 
						
						SELECT TGT.TIN
							 , TGT.client_key
							 , TGT.NAME
							 , TGT.ADDRESS1
							 , TGT.ADDRESS2
							 , TGT.CITY    
							 , TGT.STATE   
							 , TGT.ZIP     
							 , TGT.COUNTY
							 , TGT.SYSTEM_PRACTICE_ID
							 , &wflow_exec_id. 				as wflow_exec_id 
							 , 99   		 				as val_type
							 , SRC.&by_variable3. 			as entity_id
							 , SRC.&by_variable3. 			as &by_variable3.
							 , &validation_type_id.  		as validation_type_id
							 , CASE WHEN SRC.NAME          		NE TGT.NAME 				THEN SRC.NAME
									WHEN SRC.ADDRESS1      		NE TGT.ADDRESS1     		THEN SRC.ADDRESS1
									WHEN SRC.ADDRESS2      		NE TGT.ADDRESS2     		THEN SRC.ADDRESS2
									WHEN SRC.CITY          		NE TGT.CITY         		THEN SRC.CITY    
									WHEN SRC.STATE         		NE TGT.STATE        		THEN SRC.STATE   
									WHEN SRC.ZIP           		NE TGT.ZIP          		THEN SRC.ZIP     
									WHEN SRC.COUNTY        		NE TGT.COUNTY       		THEN SRC.COUNTY
									WHEN SRC.SYSTEM_PRACTICE_ID	NE TGT.SYSTEM_PRACTICE_ID	THEN SRC.SYSTEM_PRACTICE_ID
									ELSE ''									
							   END AS NEW_VALUE
							 , CASE WHEN SRC.NAME          		NE TGT.NAME 				THEN TGT.NAME
									WHEN SRC.ADDRESS1      		NE TGT.ADDRESS1     		THEN TGT.ADDRESS1
									WHEN SRC.ADDRESS2      		NE TGT.ADDRESS2     		THEN TGT.ADDRESS2
									WHEN SRC.CITY          		NE TGT.CITY         		THEN TGT.CITY    
									WHEN SRC.STATE         		NE TGT.STATE        		THEN TGT.STATE   
									WHEN SRC.ZIP           		NE TGT.ZIP          		THEN TGT.ZIP     
									WHEN SRC.COUNTY        		NE TGT.COUNTY       		THEN TGT.COUNTY
									WHEN SRC.SYSTEM_PRACTICE_ID	NE TGT.SYSTEM_PRACTICE_ID	THEN TGT.SYSTEM_PRACTICE_ID
									ELSE ''											
							   END AS OLD_VALUE	
						  FROM &in_dataset1.  								SRC
						 INNER JOIN ciedw.&in_dataset2.   					TGT 
							ON SRC.&by_variable. = TGT.&by_variable.
						   AND coalesce(SRC.&by_variable2.,'') = coalesce(TGT.&by_variable2.,'')
						   AND SRC.client_key = TGT.client_key
						   AND SRC.payer_key = TGT.payer_key
						   AND SRC.&in_dataset2._validation_id  NE 89  /* DON'T CHECK NEW RECORDS */ 
					;
				quit;	
			
			%let count_change=0;		

			proc sql noprint;
			select 
				count(*) into: count_change
			from &in_dataset2._vldt_change;
			quit;
		
			%if &count_change. ne 0 %then %do;		


				proc sort data = practice_payer_src_&client_id;
				by &by_variable. &by_variable2.;
				run;

				proc sort data = &in_dataset2._vldt_change  
						  out  = change (keep = &by_variable. &by_variable2. &by_variable3. validation_type_id);
				by &by_variable. &by_variable2.;
				run;

				data practice_payer_src_&client_id;
				merge practice_payer_src_&client_id (in=a)
					  change 		   (in=b);
				by &by_variable. &by_variable2.;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;
			
			%end; /* COUNT CHANGE IF */
			
		%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - CHANGE:  &count_change. ;%put ;	
		
		%end; /* CHANGE practice_PAYER ELSE IF*/		
		
	%end; /* CHANGE ELSE IF */

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR practiceS WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL %then %do;

			 %put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - CRITICAL ;%put ;
			
			/* APPEND ALL NEW AND CHANGED DATASETS */
			data practice_validate_critical_a;
			set  &in_dataset2._validate_new			(in=a keep=&by_variable.)
				 &in_dataset2._payer_validate_new	(in=b keep=&by_variable.)
				 &in_dataset2._vldt_change 			(in=c keep=&by_variable. )
				 &in_dataset2._payer_vldt_change 	(in=d keep=&by_variable.);
			run;
			
			proc sort data=practice_validate_critical_a;
			by &by_variable. ;
			run;

			proc sort data=&in_dataset1.;
			by &by_variable. ;
			run;
			
			
			%let varexist_id=%sysfunc(open(&in_dataset1.));
			%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
			%let varexist_rc=%sysfunc(close(&varexist_id.));

			%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;
		
			/* FLAG ANY RECORDS THAT HAVE INVALID tin OR practice NAME */
			data practice_validate_critical (keep=wflow_exec_id tin vld_value entity_id  old_val new_val val_type validation_type_id);
			merge practice_validate_critical_a (in=a)/*practice_validate_critical_c (in=a)*/
			  &in_dataset1.					   (in=b %if &varexist_ind. > 0 %then %do; drop=validation_type_id %end;);
			by &by_variable. ;
			if a then do;
			length wflow_exec_id 8. vld_value $30. entity_id 8. old_val new_val $50. val_type validation_type_id 8.;
			wflow_exec_id = &wflow_exec_id.;
			vld_value 	  = left(put(&by_variable.,30.));
			entity_id	  = &by_variable2.;
			old_val		  = "NULL";
			new_val		  = "NULL";
			validation_type_id = .;
			if client_key = &client_id. then do;
				if name = "" then do;
					new_val = name;
					validation_type_id = 91;
				end;
				else if missing(tin) /* missing value */
				        or length(tin) ne 9  
						or anyalpha(tin) NE 0 /* char value */ then do;
					new_val = tin;
					validation_type_id = 92;
				end;
			end;
			val_type = 99;
			if validation_type_id ne . then output;
			end;
			run;
				
			%let count_critical=0;		

			proc sql noprint;
				select 
					count(*) into: count_critical
				from practice_validate_critical;
			quit;
			
				/*IF CRITICAL RECORDS ARE FOUND THEN FLAG SOURCE DATASET */
			%if &count_critical. ne 0 %then %do;		


				proc sort data = practice_payer_src_&client_id;
				by &by_variable. ;
				run;

				proc sort data = practice_validate_critical  
						  out  = critical (keep = &by_variable.  validation_type_id);
				by &by_variable. ;
				run;
                 
				data practice_payer_src_&client_id;
				merge practice_payer_src_&client_id (in=a)
					  critical 		   (in=b);
				by &by_variable. ;
				if a and b then do;
					validation_id = validation_type_id;
				end;
				run;
			%end; /* COUNT_CRITICAL IF */
		
			%put ;%put NOTE: Counts - practices validations for the CI program - CRITICAL:  &count_critical. ;%put ;

		%end; /* CRITICAL ELSE IF */

%mend  edw_practice_payer_validations;
