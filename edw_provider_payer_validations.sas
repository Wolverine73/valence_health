
/*HEADER------------------------------------------------------------------------
|
| program:  edw_provider_validations.sas
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
| 01JUN2012 - Brandon Fletcher  - Brian Stropich created the original design called edw_provider_validations
|             
| 21JUN2012 - Brandon Fletcher - Excluded provider_key = 31927 from all input record sets - invalid dup in CIEDW.PROVIDER
+-----------------------------------------------------------------------HEADER*/


%macro edw_provider_payer_validations(vt_name=, validation_type_id=, in_dataset1=, in_dataset2=, oldval=, newval=, by_variable=, by_variable2=, by_variable3=);
       
    %local count_new count_delete count_change ;  
	  
	%if &oldval = %then %let oldval=%str(" ");
	%if &newval = %then %let newval=%str(" ");


	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR NEW PROVIDERS
	| MUST PROVIDER AND PROVIDER_PAYER TABLE SEPARATELY
	| 
	+------------------------------------------------------------------------SASDOC*/ 

	%if %upcase(&vt_name.) = NEW %then %do;
	    %put ;%put NOTE: Starting &vt_name. validations for the CI program;%put ;
	
        %if %upcase(&in_dataset2.) = PROVIDER %then %do;
	    
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - NEW ;%put ;

			proc sql noprint;
				create table &in_dataset2._validate_new as
					select 
						&wflow_exec_id. 					as wflow_exec_id,
						strip(a.&by_variable.) 				as vld_value,  
						strip(put(a.&by_variable3.,30.)) 	as entity_id,
						a.&by_variable3.					as VHSTAGE_PAYER_SRC_KEY,   
						a.&by_variable2. 					as SYSTEM_PROVIDER_ID,
						a.&by_variable. 					as NPI1,
						&oldval.    						as old_val length=50,
						&newval.    						as new_val length=50,
						97 									as val_type,
						&validation_type_id.    			as validation_type_id
					from &in_dataset1. as a left join 
						 (
							SELECT &by_variable., client_key 
						    FROM ciedw.&in_dataset2.
						   	WHERE NPI1 IS NOT NULL and PROVIDER_KEY > 0 
							  and CLIENT_KEY = &client_id.
							  and provider_key NE 31927 /* INVALID DUP */
						 ) as b on a.&by_variable. = b.&by_variable. and 
								   a.client_key = b.client_key 
					where missing(b.&by_variable.)
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
				by &by_variable. &by_variable3.;
				run;

				proc sort data = &in_dataset2._validate_new  
						  out  = new (keep = &by_variable. &by_variable3. validation_type_id);
				by &by_variable. &by_variable3.;
				run;

				/* FLAG APPLICABLE RECORDS FROM THE ORIGINAL DATASET WITH NEW INDICATOR */
				
				data &in_dataset1.;
				merge &in_dataset1. (in=a)
					  new           (in=b);
				by &by_variable.  &by_variable3.;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;

			%end; 

			%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - NEW:  &count_new. ;%put ;
			
        %end; /* NEW - PROVIDER IF */
		
		%else %if %upcase(&in_dataset2.) = PROVIDER_PAYER %then %do;
		
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - NEW ;%put ;

			proc sql noprint;
				create table &in_dataset2._validate_new as
					select 
						&wflow_exec_id. 					as wflow_exec_id,
						strip(a.&by_variable.) 				as vld_value,  
						strip(put(a.&by_variable3.,30.)) 	as entity_id,
						a.&by_variable3.					as VHSTAGE_PAYER_SRC_KEY,   
						a.&by_variable2. 					as SYSTEM_PROVIDER_ID,
						a.&by_variable. 					as NPI1,						
						&oldval.    						as old_val length=50,
						&newval.    						as new_val length=50,
						97 									as val_type,
						&validation_type_id.    			as validation_type_id
					from &in_dataset1. 		 as a left join 
						 ciedw.&in_dataset2. as b on a.&by_variable. = b.&by_variable.  and 
													 a.&by_variable2. = b.&by_variable2. and 
													 a.payer_key = b.payer_key and 
													 a.client_key = b.client_key													 
				    where missing(b.&by_variable.) 
					  and b.provider_key NE  31927 /* INVALID DUP */
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
				by &by_variable. &by_variable2. &by_variable3.;
				run;

				proc sort data = &in_dataset2._validate_new  
						  out  = new (keep = &by_variable.  &by_variable2. &by_variable3. validation_type_id);
				by &by_variable.  &by_variable2. &by_variable3.;
				run;
					
				/* flag source data with new records */
				data &in_dataset1.;
				merge &in_dataset1. (in=a)
					  new           (in=b);
				by &by_variable.  &by_variable2. &by_variable3.;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;

			%end; /* COUNT_NEW IF */

				%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - NEW:  &count_new. ;%put ;
			
		%end; /*  NEW - PROVIDER_PAYER IF */
	%end; /* NEW IF */
	
	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR CHANGED PROVIDERS
	| MUST PROVIDER AND PROVIDER_PAYER TABLE SEPARATELY 
	+------------------------------------------------------------------------SASDOC*/ 	

	%else %if %upcase(&vt_name.) = CHANGE %then %do;
	          %put ;%put NOTE: Starting &vt_name. validations for the CI program;%put ;
			  
        %if %upcase(&in_dataset2.) = PROVIDER %then %do;
	    
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - CHANGE ;%put ;
			
		/*SASDOC--------------------------------------------------------------------------/* 
		|   1) SELECT COMMON RECORDS VIA INNER JOIN 
		|   2) PERFORM AN EXCEPT(LEFT JOIN) ON ALL BUSINESS COLUMNS POPULATED 
		|   3) ONLY RETURN CHANGED BUSINESS COLUMNS
		|   4) DO NOT TOUCH IS_VSOURCE_DATA = 1 
		+------------------------------------------------------------------------SASDOC*/ 	
			proc sql noprint;
				create table &in_dataset2._vldt_change as

					SELECT SRC.NPI1
						 , SRC.CLIENT_KEY
						 , SRC.dea 
						 , SRC.PROVIDER_NAME
						 , SRC.SPECIALTY_KEY
						 , strip(put(SRC.&by_variable3.,30.)) as entity_id
						 , SRC.&by_variable2.				as SYSTEM_PROVIDER_ID  
						 , SRC.&by_variable3. 				as VHSTAGE_PAYER_SRC_KEY 
						 , 99								as val_type
						 , &validation_type_id.  			as validation_type_id
						 , SRC.WFLOW_EXEC_ID
						 , CASE WHEN SRC.DEA = TGT.DEA THEN SRC.PROVIDER_NAME  
						        ELSE SRC.DEA
						   END AS NEW_VALUE
						 , CASE WHEN SRC.DEA = TGT.DEA THEN TGT.PROVIDER_NAME
						        ELSE TGT.DEA
						   END AS OLD_VALUE							 
					  FROM &in_dataset1.  		SRC INNER JOIN 
						   ciedw.&in_dataset2. 	TGT ON SRC.&by_variable. = TGT.&by_variable. AND 
													   SRC.client_key = TGT.client_key AND 
													   SRC.provider_validation_id  NE 79 AND /* DON'T CHECK NEW RECORDS */
					   								   TGT.IS_VSOURCE_DATA NE 1 AND
													   TGT.PROVIDER_KEY > 0 AND
													   TGT.provider_key  NE 31927 /* INVALID DUP */
				
				EXCEPT 
					
					SELECT put(TGT.npi1, $10.) as npi1
						 , TGT.client_key
						 , TGT.dea
						 , TGT.provider_name
						 , SPEC_XREF.specialty_key
						 , strip(put(SRC.&by_variable3.,30.)) 				as entity_id
						 , SRC.&by_variable2.				as SYSTEM_PROVIDER_ID  
						 , SRC.&by_variable3. 				as VHSTAGE_PAYER_SRC_KEY 
						 , 99								as val_type
						 , &validation_type_id.  			as validation_type_id
						 , SRC.WFLOW_EXEC_ID
						 , CASE WHEN SRC.DEA = TGT.DEA THEN SRC.PROVIDER_NAME  
						        ELSE SRC.DEA
						   END AS NEW_VALUE
						 , CASE WHEN SRC.DEA = TGT.DEA THEN  TGT.PROVIDER_NAME
						        ELSE TGT.DEA
						   END AS OLD_VALUE
					  FROM &in_dataset1.  				 	 SRC 
					 INNER JOIN ciedw.&in_dataset2.  		 TGT 
					    ON SRC.&by_variable. = TGT.&by_variable. AND 
							SRC.client_key = TGT.client_key      AND 
							SRC.provider_validation_id  NE 79    AND
							TGT.PROVIDER_KEY > 0 				 AND
							TGT.provider_key NE 31927 /* INVALID DUP */
					 INNER JOIN ciedw.provider_specialty_xref SPEC_XREF /* DON'T CHECK NEW RECORDS */ 
						ON TGT.provider_key = SPEC_XREF.provider_key /* QUESTION should this be an left join instead - need to DOUBLE CHECK THIS */
				;
			quit;		
			
			%let count_change=0;		

			proc sql noprint;
			select 
				count(*) into: count_change
			from &in_dataset2._vldt_change;
			quit;
		
			%if &count_change. ne 0 %then %do;		


				proc sort data = provider_payer_src_&client_id;
				by &by_variable. &by_variable3.;
				run;

				proc sort data = &in_dataset2._vldt_change  
						  out  = change (keep = &by_variable. &by_variable3. validation_type_id);
				by &by_variable. &by_variable3.;
				run;

				data provider_payer_src_&client_id;
				merge provider_payer_src_&client_id (in=a)
					  change 		   (in=b);
				by &by_variable. &by_variable3.;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;
			
			%end; /* COUNT_CHANGE IF */
			
			%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - CHANGE:  &count_change. ;%put ;
			
		%end; /* CHANGE-PROVIDER IF*/

			
		
        %else %if %upcase(&in_dataset2.) = PROVIDER_PAYER %then %do;
	    
			%put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - CHANGE ;%put ;
		
		/* 
		   1) SELECT COMMON RECORDS VIA INNER JOIN 
		   2) PERFORM AN EXCEPT(LEFT JOIN) ON ALL BUSINESS COLUMNS POPULATED 
		   3) ONLY RETURN CHANGED BUSINESS COLUMNS
		*/
			 proc sql noprint;
					create table &in_dataset2._vldt_change as

						SELECT SRC.NPI1
						     , SRC.SYSTEM_PROVIDER_ID
							 , SRC.CLIENT_KEY
							 , SRC.dea 
							 , SRC.LAST_NAME
							 , SRC.FIRST_NAME
							 , SRC.MIDDLE_INITIAL
							 , strip(put(SRC.&by_variable3.,30.))				 as entity_id
							 , SRC.&by_variable3.				 as VHSTAGE_PAYER_SRC_KEY
							 , 99								 as val_type
							 , &validation_type_id.  			 as validation_type_id
							 , SRC.WFLOW_EXEC_ID
							 , CASE WHEN SRC.DEA NE TGT.DEA 							  THEN SRC.DEA
									WHEN SRC.LAST_NAME NE TGT.LAST_NAME 				  THEN SRC.LAST_NAME
									WHEN SRC.FIRST_NAME NE TGT.FIRST_NAME 				  THEN SRC.FIRST_NAME
									WHEN SRC.MIDDLE_INITIAL NE TGT.MIDDLE_INITIAL 		  THEN SRC.MIDDLE_INITIAL
									ELSE ''
							   END AS NEW_VALUE
							 , CASE WHEN SRC.DEA NE TGT.DEA 							  THEN TGT.DEA
									WHEN SRC.LAST_NAME NE TGT.LAST_NAME 				  THEN TGT.LAST_NAME
									WHEN SRC.FIRST_NAME NE TGT.FIRST_NAME 				  THEN TGT.FIRST_NAME
									WHEN SRC.MIDDLE_INITIAL NE TGT.MIDDLE_INITIAL 		  THEN TGT.MIDDLE_INITIAL
									ELSE '' 
							   END AS OLD_VALUE	
						  FROM &in_dataset1.  								SRC
						 INNER JOIN ciedw.&in_dataset2.   					TGT 
							ON SRC.&by_variable. = TGT.&by_variable.
						   AND SRC.&by_variable2. = TGT.&by_variable2.
						   AND SRC.payer_key = TGT.payer_key
						   AND SRC.client_key = TGT.client_key
						   AND SRC.provider_payer_validation_id  NE 81  /* DON'T CHECK NEW RECORDS */ 
						   AND TGT.provider_key NE 31927  /* INVALID DUP */
					
					EXCEPT 
						
						SELECT TGT.npi1
							 , TGT.SYSTEM_PROVIDER_ID
							 , TGT.client_key
							 , TGT.dea
							 , TGT.LAST_NAME
							 , TGT.FIRST_NAME
							 , TGT.MIDDLE_INITIAL
							 , strip(put(SRC.&by_variable3.,30.)) 				 as entity_id
							 , SRC.&by_variable3.				 as VHSTAGE_PAYER_SRC_KEY
							 , 99   		 					 as val_type
							 , &validation_type_id.  			 as validation_type_id
							 , SRC.WFLOW_EXEC_ID
							 , CASE WHEN SRC.DEA NE TGT.DEA 							  THEN SRC.DEA
									WHEN SRC.LAST_NAME NE TGT.LAST_NAME 				  THEN SRC.LAST_NAME
									WHEN SRC.FIRST_NAME NE TGT.FIRST_NAME 				  THEN SRC.FIRST_NAME
									WHEN SRC.MIDDLE_INITIAL NE TGT.MIDDLE_INITIAL 		  THEN SRC.MIDDLE_INITIAL
									ELSE '' 
							   END AS NEW_VALUE
							 , CASE WHEN SRC.DEA NE TGT.DEA 							  THEN TGT.DEA
									WHEN SRC.LAST_NAME NE TGT.LAST_NAME 				  THEN TGT.LAST_NAME
									WHEN SRC.FIRST_NAME NE TGT.FIRST_NAME 				  THEN TGT.FIRST_NAME
									WHEN SRC.MIDDLE_INITIAL NE TGT.MIDDLE_INITIAL 		  THEN TGT.MIDDLE_INITIAL
									ELSE '' 
							   END AS OLD_VALUE	
						  FROM &in_dataset1.  								SRC
						 INNER JOIN ciedw.&in_dataset2.   					TGT 
							ON SRC.&by_variable. = TGT.&by_variable.
						   AND SRC.&by_variable2. = TGT.&by_variable2.
						   AND SRC.payer_key = TGT.payer_key
						   AND SRC.client_key = TGT.client_key
						   AND SRC.provider_payer_validation_id  NE 81  /* DON'T CHECK NEW RECORDS */ 
						   AND TGT.provider_key NE 31927  /* INVALID DUP */
					;
				quit;	
			
			%let count_change=0;		

			proc sql noprint;
			select 
				count(*) into: count_change
			from &in_dataset2._vldt_change;
			quit;
		
			%if &count_change. ne 0 %then %do;		


				proc sort data = provider_payer_src_&client_id;
				by &by_variable. &by_variable2. &by_variable3.;
				run;

				proc sort data = &in_dataset2._vldt_change  
						  out  = change (keep = &by_variable. &by_variable2.  &by_variable3. validation_type_id);
				by &by_variable. &by_variable2.  &by_variable3.;
				run;

				data provider_payer_src_&client_id;
				merge provider_payer_src_&client_id (in=a)
					  change 		   (in=b);
				by &by_variable. &by_variable2.  &by_variable3.;
				if a and b then do;
					&in_dataset2._validation_id = validation_type_id;
				end;
				run;
			
			%end; /* COUNT CHANGE IF */
			
		%put ;%put NOTE: Counts - &in_dataset2. validations for the CI program - CHANGE:  &count_change. ;%put ;	
		
		%end; /* CHANGE PROVIDER_PAYER ELSE IF*/		
		
	%end; /* CHANGE ELSE IF */

	/*SASDOC--------------------------------------------------------------------------
	| EDW - VALIDATIONS FOR PROVIDERS WITH CRITICAL ISSUES
	|
	+------------------------------------------------------------------------SASDOC*/ 

	%else %if %upcase(&vt_name.) = CRITICAL %then %do;

			 %put ;%put NOTE: Performing EDW - &in_dataset2. validations for the CI program - CRITICAL ;%put ;
			
			/* APPEND ALL NEW AND CHANGED DATASETS */
			data provider_validate_critical_a;
			set  &in_dataset2._validate_new			(in=a keep=&by_variable. &by_variable2. &by_variable3.)
				 &in_dataset2._payer_validate_new	(in=b keep=&by_variable. &by_variable2. &by_variable3.)
				 &in_dataset2._vldt_change 			(in=c keep=&by_variable. &by_variable2. &by_variable3.)
				 &in_dataset2._payer_vldt_change 	(in=d keep=&by_variable. &by_variable2. &by_variable3.);
			run;

			/* RUN LUHN NPI CHECK */
			data provider_validate_critical_b;
			set provider_validate_critical_a;
			%luhn_npi_check (&by_variable. );
			run;


			%let count_critical=0;		

			proc sql noprint;
				select 
					count(*) into: count_critical
				from provider_validate_critical_b;
			quit;
				 
			%let varexist_id=%sysfunc(open(&in_dataset1.));
			%let varexist_ind=%sysfunc(varnum(&varexist_id.,validation_type_id));
			%let varexist_rc=%sysfunc(close(&varexist_id.));

			%put NOTE: Macro Variable - varexist_ind = &varexist_ind.;
		    
			PROC SORT DATA=&in_dataset1.;
			    BY &by_variable. &by_variable2. &by_variable3.;
			RUN;
			
			PROC SORT DATA=provider_validate_critical_b;
				BY &by_variable. &by_variable2.  &by_variable3.;
			RUN;
			
			/* FLAG ANY RECORDS THAT HAVE INVALID NPI OR PROVIDER NAME */
			data provider_validate_critical (keep=wflow_exec_id &by_variable. &by_variable2.  &by_variable3. vld_value entity_id  old_val new_val val_type validation_type_id);
			merge provider_validate_critical_b 	(in=a)
				  &in_dataset1.					(in=b %if &varexist_ind. > 0 %then %do; drop=validation_type_id %end;);
			by &by_variable. &by_variable2.  &by_variable3.;
			if a then do;
				length wflow_exec_id 8. vld_value $30. entity_id old_val new_val $50. val_type validation_type_id 8.;
				wflow_exec_id = &wflow_exec_id.;
				vld_value 	  = &by_variable.;
				entity_id	  = left(put(&by_variable3.,30.));
				old_val		  = "NULL";
				new_val		  = "NULL";
				validation_type_id = .;
				if client_key = &client_id. then do;
					if provider_name = "" then do;
						new_val = provider_name;
						validation_type_id = 83;
					end;
					else if npi1 = "" or length(npi1) ne 10 or npi_valid ne 1 then do;
						new_val = npi1;
						validation_type_id = 84;
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
					from provider_validate_critical;
				quit;
				
				/*IF CRITICAL RECORDS ARE FOUND THEN FLAG SOURCE DATASET */
				%if &count_critical. ne 0 %then %do;
					proc sort data = provider_payer_src_&client_id;
					by &by_variable. &by_variable2.  &by_variable3.;
					run;

					proc sort data = provider_validate_critical  
							  out  = critical (keep = &by_variable. &by_variable2.  &by_variable3. validation_type_id);
					by &by_variable. &by_variable2.  &by_variable3.;
					run;
                     
					data provider_payer_src_&client_id;
					merge provider_payer_src_&client_id (in=a)
						  critical 		   				(in=b);
					by &by_variable. &by_variable2.  &by_variable3.;
					if a and b then do;
						validation_id = validation_type_id;
					end;
					run;
				%end; /* COUNT_CRITICAL IF */
			
			%put ;%put NOTE: Counts - Providers validations for the CI program - CRITICAL:  &count_critical. ;%put ;

		%end; /* CRITICAL ELSE IF */

%mend  edw_provider_payer_validations;
