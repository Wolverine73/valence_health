
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_practice_payer_load.sas
|
| LOCATION: M:\CI\programs\EDW 
|
|
| PURPOSE:                                 
|           
| INPUT:                                        
|
| OUTPUT:                           
|      
| MACROS:  bpm_environment, bpm_process_control, edw_provpracxref_payer_extract, edw_provpracxref_payer_load                                  
+--------------------------------------------------------------------------------
| HISTORY:  01DEC2010 - Winnie Lee - Original
|    
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 H04 M03
|
| 05MAY2012 - Brandon Fletcher - Copied Structure from CI process - Original
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos); 

*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*; 
/*%let sysparm=%str(sk_prcs_ctrl_id=24305 wflow_exec_id=113523 sas_prgm_id=52 client_id=6  practice_id=1332 batch_key=1 sas_mode=test);*/ 

%bpm_environment


%macro edw_practice_payer_load ();

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.        
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START)
	
	
	*SASDOC--------------------------------------------------------------------------
	| TABLE: practice
	| DESC: INSERT SCENARIO - IF TIN DOES NOT EXIST THEN INSERT NEW PRACTICE
	|       UPDATE SCENARIO - IF TIN DOES EXIST THEN CHECK IS_VSOURCE_DATA VALUE
	|                         IF IS_VSOURCE_DATA = 1 THEN UPDATE IS_PAYER_DATA FOR THE MIN(PRACTICE_KEY)
    |							 THERE ARE TINS WITH MULTIPLE PRACTICE_KEYS
	|						  IF IS_VSOURCE_DATA = 0 THEN UPDATE PRACTICE_NAME
	| 
	| NOTE: WHEN PULLING IN THE SOURCE FILE A MAX MUST BE USED
	|		DUE TO MULTIPLE TIN INSTANCES FOR A NPI AND TIN COMBO. ONLY
	| 		THE FIRST TIN INSTANCE IS MARKED AS LOAD_FLAG = 1
	| 		THE NPI IS USED FOR PROV PRAC XREF PORTION
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
	connect to oledb(init_string=&sqlci.);
    create table row_count as select * from connection to oledb
	(
		DECLARE @intErrorCode INT
		BEGIN TRAN

		MERGE CIEDW.dbo.practice AS tgt
		USING (  
			SELECT DISTINCT
			      SOURCE.CLIENT_KEY
				, SOURCE.PAYER_KEY
				, SOURCE.NAME 
				, SOURCE.TIN
				, SOURCE.CREATED_ON   
				, SOURCE.CREATED_BY   
				, SOURCE.UPDATED_ON   
				, SOURCE.UPDATED_BY   
				, SOURCE.WFLOW_EXEC_ID
				, 0 AS IS_VSOURCE_DATA
				, 1 AS IS_PAYER_DATA 
				, SOURCE.practice_validation_Id 
				, SOURCE.load_flag
				, PRAC.MIN_PRACTICE_KEY
			FROM ( SELECT DISTINCT ORIG.CLIENT_KEY
						, ORIG.PAYER_KEY
						, MAX(ORIG.NAME) AS NAME
						, ORIG.TIN
						, MAX(ORIG.CREATED_ON)       AS CREATED_ON  
						, MAX(ORIG.CREATED_BY)       AS CREATED_BY  
						, MAX(ORIG.UPDATED_ON)       AS UPDATED_ON  
						, MAX(ORIG.UPDATED_BY)       AS UPDATED_BY  
						, MAX(ORIG.WFLOW_EXEC_ID)    AS WFLOW_EXEC_ID
						, MAX(GET_LATEST.MAX_PRACTICE_VALIDATION_ID) AS practice_validation_Id  
						, MAX(GET_LATEST.MAX_LOAD_FLAG) 			 AS LOAD_FLAG
				     FROM cihold.dbo.saswrk_practice_payer_src_&client_id. ORIG
					INNER JOIN 
								( SELECT MAX(EFFECTIVE_DATE) AS MAX_EFF_DT        /* GET LATEST PRACTICE NAME BY MAX EFFECTIVE_DATE BY TIN*/
					                  , MAX(LOAD_FLAG) AS MAX_LOAD_FLAG
									  , MAX(PRACTICE_VALIDATION_ID) AS MAX_PRACTICE_VALIDATION_ID
									  , MAX(VALIDATION_ID) AS MAX_VALIDATION_ID 
									  , TIN 
								   FROM cihold.dbo.saswrk_practice_payer_src_&client_id. 
								  WHERE tin IS NOT NULL
								  GROUP BY TIN
								) GET_LATEST
					   ON ORIG.TIN = GET_LATEST.TIN
					  AND COALESCE(ORIG.EFFECTIVE_DATE,'') = COALESCE(GET_LATEST.MAX_EFF_DT, '') 
				GROUP BY ORIG.CLIENT_KEY, ORIG.PAYER_KEY,ORIG.TIN  /* HAVE TO GET MAX NAME IF MORE THAN 1 IDENTICAL EFFECTIVE_DATE*/
			   ) SOURCE
		    LEFT JOIN ( SELECT MIN(PRACTICE_KEY) AS MIN_PRACTICE_KEY  
						   , TIN
						   , CLIENT_KEY
		                FROM CIEDW.dbo.practice
					    GROUP BY TIN, CLIENT_KEY ) PRAC
		      ON SOURCE.TIN = PRAC.TIN
			 and SOURCE.CLIENT_KEY = PRAC.CLIENT_KEY) AS src
		ON (tgt.TIN = src.TIN
			and 
			tgt.CLIENT_KEY = src.CLIENT_KEY
			AND
			tgt.practice_key = src.min_practice_key)
		/*87=insert 88=update */
		WHEN NOT MATCHED and src.load_flag = 1 AND src.practice_validation_Id = 87 THEN INSERT
		     (  CLIENT_KEY
		      , practice_NAME
		      , TIN
		      , CREATED_ON
		      , CREATED_BY
		      , UPDATED_ON
		      , UPDATED_BY
		      , WFLOW_EXEC_ID
		      , IS_VSOURCE_DATA
		      , IS_PAYER_DATA
		    )
		VALUES (   SRC.CLIENT_KEY
		      , SRC.NAME
		      , SRC.TIN
		      , SRC.CREATED_ON
		      , SRC.CREATED_BY
		      , SRC.UPDATED_ON
		      , SRC.UPDATED_BY
		      , SRC.WFLOW_EXEC_ID
		      , SRC.IS_VSOURCE_DATA
		      , SRC.IS_PAYER_DATA
		    )
		/*87=insert 88=update */
		WHEN MATCHED THEN /* VSOURCE DOES NOT EXIST -- DO NOT UPDATE IF SRC COL IS NULL */		   
		UPDATE SET
		        TGT.practice_NAME = CASE WHEN TGT.IS_VSOURCE_DATA = 0 AND src.practice_validation_Id = 88
								 		THEN SRC.NAME
								 		ELSE SRC.NAME 
								 	END
								    
		      , TGT.UPDATED_ON =    CASE WHEN TGT.IS_VSOURCE_DATA = 0 AND src.practice_validation_Id = 88
								 		THEN SRC.UPDATED_ON
								 		ELSE SRC.UPDATED_ON 
								 	END
								    
		      , TGT.UPDATED_BY =    CASE WHEN TGT.IS_VSOURCE_DATA = 0 AND src.practice_validation_Id = 88 
									    THEN SRC.UPDATED_BY
									    ELSE SRC.UPDATED_BY 
							        END
										   
		      , TGT.WFLOW_EXEC_ID = CASE WHEN TGT.IS_VSOURCE_DATA = 0 AND src.practice_validation_Id = 88 
										THEN SRC.WFLOW_EXEC_ID
										ELSE TGT.WFLOW_EXEC_ID 
									END
										   
			  , TGT.IS_PAYER_DATA = CASE WHEN TGT.IS_PAYER_DATA = 0  THEN SRC.IS_PAYER_DATA
										ELSE TGT.IS_PAYER_DATA 
									END				  
		;
		SELECT @@ROWCOUNT;
		
		IF (@intErrorCode <> 0) BEGIN
		    ROLLBACK TRAN
		END
		COMMIT TRAN
	);
	quit;

 			options nomlogic nomprint nosymbolgen; 
			
			 DATA _NULL_;
			 set row_count;
			 call symput('row_count',exprssn);
			 run;

			%put;%put &row_count RECORDS EVALUATED FOR THE CIEDW.dbo.practice MERGE;%put;
			
			%set_error_flag
			%on_error(ACTION=ABORT)
			
 			options mlogic mprint symbolgen; 
	
	%put ;%put NOTE: END MERGE STATEMENT FOR CIEDW.dbo.practice;%put ;

	
	*SASDOC--------------------------------------------------------------------------
	| CIEDW - Insert, update PROVIDER_PRACTICE_XREF table, hold table and no load hold table.        
	+------------------------------------------------------------------------SASDOC*;
	%edw_provpracxref_payer_extract()

	%if &provpracxref_count > 0 %then %do;
		%edw_provpracxref_payer_load()
	%end;

	
	*SASDOC--------------------------------------------------------------------------
	| CIEDW - Insert, update PROVIDER_PRACTICE_ATTRIBUTE table, hold table and no load hold table for TCHP ONLY.
	+------------------------------------------------------------------------SASDOC*;
	
	%if &client_id = 15 %then %do;
	
			%edw_provprac_attribute_extract()
	
		%if &provpracattr_count > 0 %then %do;
			%edw_provprac_attribute_load() 
		%end;
	
	%end;

		
	*SASDOC-------------------------------------------------------------------------- 
	| TABLE: PRACTICE_PAYER
	| DESC: PASS THROUGH SQL
    |       1-GET THE MIN PRACTICE KEY FROM PRACTICE TABLE - SEE NOTE BELOW 
	|       2-CHECK THE MIN PRACTICE KEY AGAINST PRACTICE_PAYER TABLE
	|          INSERT IF PRACTICE_KEY DOES NOT EXIST
	|		   UPDATE IF PRACTICE_KEY DOES EXIST
	| NOTE: THE PRACTICE CAN HAVE MULTIPLE PRACTICES FOR A GIVEN TIN 
	|      SO THE DECISION WAS TO USE THE MIN PRACTICE_KEY PER TIN.
	+------------------------------------------------------------------------SASDOC*; 
		
	proc sql;
        connect to oledb(init_string=&sqlci.);
        create table row_count as select * from connection to oledb
        (
		DECLARE @intErrorCode INT
		BEGIN TRAN
	
		    MERGE CIEDW.dbo.practice_payer AS tgt
         USING (  
               SELECT DISTINCT
                       PRAC.MIN_PRACTICE_KEY
                     , SOURCE.CLIENT_KEY
                     , SOURCE.PAYER_KEY
                     , SOURCE.NAME
                     , SOURCE.TIN
					 , SOURCE.SYSTEM_PRACTICE_ID 
					 , SOURCE.ADDRESS1
					 , SOURCE.ADDRESS2
					 , SOURCE.CITY
					 , SOURCE.STATE
					 , SOURCE.ZIP
					 , SOURCE.COUNTY 
                     , SOURCE.CREATED_ON
                     , SOURCE.CREATED_BY
                     , SOURCE.UPDATED_ON
                     , SOURCE.UPDATED_BY
                     , SOURCE.WFLOW_EXEC_ID
                  FROM  cihold.dbo.saswrk_practice_payer_src_&client_id. SOURCE 
				  LEFT JOIN  
						(SELECT TIN    
			                  , MIN(PRACTICE_KEY) AS MIN_PRACTICE_KEY
							  , CLIENT_KEY
						   FROM CIEDW.dbo.practice
						  WHERE PRACTICE_KEY > 0
					      GROUP BY TIN, CLIENT_KEY
						) PRAC 
				    ON SOURCE.TIN = PRAC.TIN
				   AND SOURCE.CLIENT_KEY = PRAC.CLIENT_KEY
                 WHERE SOURCE.practice_payer_validation_Id in (89,90) /*89=insert 90=update */
                  AND SOURCE.load_flag = 1    /* CONDITION FOR ONLY GOOD TINS*/
                  ) AS src
         ON (tgt.PRACTICE_KEY = src.MIN_PRACTICE_KEY
             AND tgt.CLIENT_KEY = src.CLIENT_KEY
			 AND tgt.PAYER_KEY = src.PAYER_KEY
			 AND tgt.SYSTEM_PRACTICE_ID = src.SYSTEM_PRACTICE_ID)
        WHEN NOT MATCHED THEN INSERT
                 (  PRACTICE_KEY
				  , CLIENT_KEY
                  , NAME
				  , PAYER_KEY
                  , TIN
				  , SYSTEM_PRACTICE_ID 
				  , ADDRESS1
				  , ADDRESS2
				  , CITY
				  , STATE
				  , ZIP
				  , COUNTY 
                  , CREATED_ON
                  , CREATED_BY
                  , UPDATED_ON
                  , UPDATED_BY
                )
         VALUES (   SRC.MIN_PRACTICE_KEY
                  , SRC.CLIENT_KEY
                  , SRC.NAME
				  , SRC.PAYER_KEY
                  , SRC.TIN
				  , SRC.SYSTEM_PRACTICE_ID 
				  , SRC.ADDRESS1
				  , SRC.ADDRESS2
				  , SRC.CITY
				  , SRC.STATE
				  , SRC.ZIP
				  , SRC.COUNTY
                  , SRC.CREATED_ON
                  , SRC.CREATED_BY
                  , SRC.UPDATED_ON
                  , SRC.UPDATED_BY
                )
       WHEN MATCHED /* VSOURCE DOES NOT EXIST -- DO NOT UPDATE IF SRC COL IS 0 */
        THEN UPDATE SET
                    TGT.NAME   				= SRC.NAME
                  , TGT.TIN             	= SRC.TIN
				  , TGT.SYSTEM_PRACTICE_ID 	= SRC.SYSTEM_PRACTICE_ID 
				  , TGT.ADDRESS1 			= SRC.ADDRESS1
				  , TGT.ADDRESS2 			= SRC.ADDRESS2
				  , TGT.CITY 				= SRC.CITY
				  , TGT.STATE 				= SRC.STATE
				  , TGT.ZIP 				= SRC.ZIP
				  , TGT.COUNTY  			= SRC.COUNTY 
				  , TGT.PAYER_KEY 			= SRC.PAYER_KEY
                  , TGT.CREATED_ON      	= SRC.CREATED_ON
                  , TGT.CREATED_BY      	= SRC.CREATED_BY
                  , TGT.UPDATED_ON      	= SRC.UPDATED_ON
                  , TGT.UPDATED_BY      	= SRC.UPDATED_BY

            ;
          SELECT @@ROWCOUNT ;
        IF (@intErrorCode <> 0) BEGIN
                ROLLBACK TRAN
            END
            COMMIT TRAN
        ) ;
        quit;

 			options nomlogic nomprint nosymbolgen; 
			
			 
			 DATA _NULL_;
			 set row_count;
			 call symput('row_count',exprssn);
			 run;

			 %put;%put &row_count RECORDS EVALUATED FOR THE CIEDW.dbo.practice_payer MERGE;%put;
			
			%set_error_flag
			%on_error(ACTION=ABORT) 
		
	*SASDOC--------------------------------------------------------------------------
	| SQL to INSERT EDW.NLHOLD_practice_PAYER TABLE.        
	+------------------------------------------------------------------------SASDOC*; 
 
	proc sql;
        connect to oledb(init_string=&cihold.);
         create table row_count as select * from connection to oledb
        (
		DECLARE @intErrorCode INT
		BEGIN TRAN		 
				 MERGE dbo.NL_HOLD_practice_PAYER AS tgt
				 USING (
							SELECT DISTINCT 
								   CLIENT_KEY
								 , NAME
								 , PAYER_KEY
								 , TIN
								 , SYSTEM_PRACTICE_ID 
								 , ADDRESS1
								 , ADDRESS2
								 , CITY
								 , STATE
								 , ZIP								 
								 , WFLOW_EXEC_ID	 
								 , GETDATE() AS CREATED_ON
								 , CREATED_BY
								 , GETDATE() AS UPDATED_ON
								 , UPDATED_BY
								 , LOAD_FLAG
								 , MAX(VHSTAGE_PAYER_SRC_KEY) as PRACTICE_KEY
								 , VALIDATION_TYPE_ID
							  FROM  cihold.dbo.saswrk_practice_payer_src_&client_id.
							 GROUP BY CLIENT_KEY
								 , NAME
								 , PAYER_KEY
								 , TIN
								 , SYSTEM_PRACTICE_ID 
								 , ADDRESS1
								 , ADDRESS2
								 , CITY
								 , STATE
								 , ZIP								 
								 , WFLOW_EXEC_ID
								 , CREATED_BY
								 , UPDATED_BY
								 , LOAD_FLAG
								 , VALIDATION_TYPE_ID
							) AS src
					 ON ( tgt.TIN = src.TIN
						  AND tgt.CLIENT_KEY = src.CLIENT_KEY 	 
						  AND tgt.PAYER_KEY = src.PAYER_KEY
						  AND tgt.SYSTEM_PRACTICE_ID = src.SYSTEM_PRACTICE_ID)
					WHEN NOT MATCHED AND SRC.LOAD_FLAG = -1 THEN
					INSERT(    CLIENT_KEY
							 , NAME
							 , PAYER_KEY
							 , PRACTICE_KEY
							 , TIN
							 , SYSTEM_PRACTICE_ID 
							 , ADDRESS1
							 , ADDRESS2
							 , CITY
							 , STATE
							 , ZIP							 
							 , WFLOW_EXEC_ID	 
							 , CREATED_ON
							 , CREATED_BY
							 , UPDATED_ON
							 , UPDATED_BY
							 , VALIDATION_TYPE_ID							 
						   )
					VALUES(    SRC.CLIENT_KEY
							 , SRC.NAME
							 , SRC.PAYER_KEY
							 , SRC.PRACTICE_KEY
							 , SRC.TIN
							 , SRC.SYSTEM_PRACTICE_ID 
							 , SRC.ADDRESS1
							 , SRC.ADDRESS2
							 , SRC.CITY
							 , SRC.STATE
							 , SRC.ZIP							 
							 , SRC.WFLOW_EXEC_ID	 
							 , SRC.CREATED_ON
							 , SRC.CREATED_BY
							 , SRC.UPDATED_ON
							 , SRC.UPDATED_BY
							 , SRC.VALIDATION_TYPE_ID
			   );
		SELECT @@ROWCOUNT ;
		IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) ;
		quit;

 			options nomlogic nomprint nosymbolgen; 
			
			 
			 DATA _NULL_;
			 set row_count;
			 call symput('row_count',exprssn);
			 run;

			 %put;%put &row_count RECORDS EVALUATED FOR THE dbo.NL_HOLD_practice_PAYER MERGE;%put;			
			
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint symbolgen; 

		%put ;%put NOTE: END MERGE STATEMENT FOR dbo.NL_HOLD_practice_PAYER;%put ;

		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to complete.        
		+------------------------------------------------------------------------SASDOC*;
		%bpm_process_control(timevar=COMPLETE)
		

%mend edw_practice_payer_load;
%edw_practice_payer_load()
