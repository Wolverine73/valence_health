
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_provider_payer_load.sas
|
| LOCATION: M:\CI\programs\EDW 
|
| PURPOSE:                                 
|           
| INPUT:                                        
|
| OUTPUT:                           
|                                            
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
/*%let sysparm=%str(sk_prcs_ctrl_id=10057 wflow_exec_id=48883 sas_prgm_id=50 client_id=6 sas_mode=test practice_id=1332 batch_key=1); */
 

%bpm_environment;

%macro edw_provider_payer_load();

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.        
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);

	
	*SASDOC--------------------------------------------------------------------------
	| TABLE: PROVIDER
	| DESC: PASS THROUGH SQL to INSERT WHEN AN EXISTING RECORD DOES NOT EXIST BY CLIENT_KEY
	| 		OR UPDATE EDW.PROVIDER TABLE WHEN IS_VSOURCE IS NULL.
	| 		IF VSOURCE DATA EXIST FOR A GIVEN NPI DO NOT TOUCH
	| 		ONLY 1 NPI IS LOADED PER CLIENT_KEY SO THE MAX SYSTEM_PROVIDER_KEY IS USED TO CAPTURE 
	|       THE PROVIDER NAME USED IN EDW. PROVIDER_PAYER WIL CAPTURE BOTH
	| 1. WLEE - 20120611 modified to include CI_STATUS
	+------------------------------------------------------------------------SASDOC*; 
	    proc sql;
        connect to oledb(init_string=&sqlci.);
        create table row_count as select * from connection to oledb
        (
		DECLARE @intErrorCode INT
		BEGIN TRAN
	
		MERGE CIEDW.dbo.PROVIDER AS TGT
		USING (				  
				SELECT  DISTINCT 
					  CLIENT_KEY
					, PROVIDER_NAME
					, CI_STATUS
					, MAIN.NPI1
					, DEA				 
					, WFLOW_EXEC_ID 
					, 0 AS IS_VSOURCE_DATA
					, 1 as IS_PAYER_DATA
					, CREATED_ON
					, CREATED_BY
					, UPDATED_ON
					, UPDATED_BY
				FROM cihold.dbo.saswrk_provider_payer_src_&client_id.  main
		    	inner join
				(select npi1
				      , max(system_provider_Id) as system_provider_id
				   from cihold.dbo.saswrk_provider_payer_src_&client_id.
				  group by npi1) sub_main
				on main.npi1 = sub_main.npi1 
			   and main.system_provider_id = sub_main.system_provider_id
		    	WHERE load_flag = 1    /* CONDITION FOR ONLY GOOD NPIS*/ 
			   ) AS SRC ON (TGT.NPI1 = SRC.NPI1 and TGT.CLIENT_KEY = SRC.CLIENT_KEY)
		WHEN NOT MATCHED THEN 
			INSERT
				(     
					  CLIENT_KEY
					, PROVIDER_NAME	
					, CI_STATUS 
					, DEA
					, NPI1
					, WFLOW_EXEC_ID
					, CREATED_ON
					, CREATED_BY
					, UPDATED_ON
					, UPDATED_BY
					, IS_VSOURCE_DATA
					, IS_PAYER_DATA
		        )
		 	VALUES 
				(   
					SRC.CLIENT_KEY
				  , SRC.PROVIDER_NAME
				  , SRC.CI_STATUS
				  , SRC.DEA
				  , SRC.NPI1
				  , SRC.WFLOW_EXEC_ID
				  , SRC.CREATED_ON
				  , SRC.CREATED_BY
				  , SRC.UPDATED_ON
				  , SRC.UPDATED_BY
				  , SRC.IS_VSOURCE_DATA	
				  , SRC.IS_PAYER_DATA	  
				)
	   WHEN MATCHED  /* VSOURCE DOES NOT EXIST -- DO NOT UPDATE IF SRC COL IS NULL */
	    and PROVIDER_KEY <> 31927  /* INVALID PROD DUP */
	   THEN UPDATE SET
			  TGT.IS_PAYER_DATA = SRC.IS_PAYER_DATA
			, TGT.PROVIDER_NAME = CASE WHEN TGT.IS_VSOURCE_DATA = 0 
									   THEN SRC.PROVIDER_NAME
									   ELSE TGT.PROVIDER_NAME END
			, TGT.DEA = CASE WHEN TGT.IS_VSOURCE_DATA = 0 
							 THEN SRC.DEA
							 ELSE TGT.DEA END
			, TGT.WFLOW_EXEC_ID = CASE WHEN TGT.IS_VSOURCE_DATA = 0 
									   THEN SRC.WFLOW_EXEC_ID
									   ELSE TGT.WFLOW_EXEC_ID END
			, TGT.UPDATED_ON = SRC.UPDATED_ON
			, TGT.UPDATED_BY = SRC.UPDATED_BY 
			;
	      SELECT @@ROWCOUNT;
		IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) ;
		quit;
		
		options nomlogic nomprint nosymbolgen;
			%set_error_flag
			%on_error(ACTION=ABORT)
		 
			
			 DATA _NULL_;
			 set row_count;
			 call symput('row_count',exprssn);
			 run;
			 
	options nomlogic nomprint nosymbolgen;
	%put ;%put NOTE: END MERGE STATEMENT FOR CIEDW.dbo.PROVIDER;%put;%put &row_count RECORDS EVALUATED FOR THE CIEDW.PROVIDER MERGE;%put ;
		
	*SASDOC-------------------------------------------------------------------------- 
	| TABLE: PROVIDER_PAYER
	| DESC: PASS THROUGH SQL to INSERT WHEN AN EXISTING RECORD DOES NOT EXIST
	| 		OR UPDATE EDW.PROVIDER_PAYER TABLE WHEN IS_VSOURCE IS NULL   
	| 1. WLEE - 20120611 modified table schema to include created and updated WFLOW_EXEC_ID	
	+------------------------------------------------------------------------SASDOC*; 

	   proc sql;
        connect to oledb(init_string=&sqlci.);
       create table row_count as select * from connection to oledb
        (
		DECLARE @intErrorCode INT
		BEGIN TRAN
		  MERGE  ciedw.dbo.PROVIDER_PAYER  AS tgt
         USING (		 
				SELECT    DISTINCT 
				       PROV.PROVIDER_KEY
		             , PROV.CLIENT_KEY
					 , SOURCE.PAYER_KEY  
					 , SOURCE.LAST_NAME
					 , SOURCE.FIRST_NAME
					 , SOURCE.MIDDLE_INITIAL
					 , SOURCE.SYSTEM_PROVIDER_ID
					 , SOURCE.DEA
					 , SOURCE.NPI1  
					 , SOURCE.CREATED_ON					  
					 , SOURCE.CREATED_BY
					 , SOURCE.UPDATED_ON					  
					 , SOURCE.UPDATED_BY 
					 , SOURCE.WFLOW_EXEC_ID	 
				  FROM  cihold.dbo.saswrk_provider_payer_src_&client_id. SOURCE
				 INNER JOIN CIEDW.dbo.PROVIDER PROV
				    ON SOURCE.NPI1 = PROV.NPI1
				   AND PROV.CLIENT_KEY= &client_id.
				   AND PROV.PROVIDER_KEY <> 31927 /* INVALID PROD DUP */				   
			     WHERE SOURCE.provider_payer_validation_Id in (81,82) /*1 =insert 3=update */ 
				  and SOURCE.load_flag = 1    /* CONDITION FOR ONLY GOOD NPIS*/ 
                ) AS src
         ON ( tgt.NPI1 = src.NPI1
		      and tgt.SYSTEM_PROVIDER_ID = src.SYSTEM_PROVIDER_ID
		      and tgt.CLIENT_KEY = src.CLIENT_KEY
			  and tgt.PAYER_KEY = src.PAYER_KEY)
		WHEN NOT MATCHED THEN
		INSERT(  PROVIDER_KEY
			   , CLIENT_KEY
			   , PAYER_KEY
			   , LAST_NAME
			   , FIRST_NAME
			   , MIDDLE_INITIAL
			   , SYSTEM_PROVIDER_ID
			   , NPI1
			   , DEA
			   , CREATED_ON
			   , CREATED_BY
			   , UPDATED_ON
			   , UPDATED_BY
			   , CREATED_WFLOW_EXEC_ID
			   )
		 VALUES(
		         src.PROVIDER_KEY
			   , src.CLIENT_KEY
			   , src.PAYER_KEY
			   , src.LAST_NAME
			   , src.FIRST_NAME
			   , src.MIDDLE_INITIAL
			   , SYSTEM_PROVIDER_ID
			   , src.NPI1
			   , src.DEA
			   , src.CREATED_ON
			   , src.CREATED_BY
			   , src.CREATED_ON
			   , src.CREATED_BY
			   , src.WFLOW_EXEC_ID
			   )
		WHEN MATCHED
		 THEN UPDATE SET
				 tgt.PROVIDER_KEY				= src.PROVIDER_KEY	
			   , tgt.CLIENT_KEY                 = src.CLIENT_KEY
			   , tgt.PAYER_KEY					= src.PAYER_KEY
			   , tgt.LAST_NAME              	= src.LAST_NAME 
			   , tgt.FIRST_NAME             	= src.FIRST_NAME 
			   , tgt.MIDDLE_INITIAL             = src.MIDDLE_INITIAL 
			   , tgt.SYSTEM_PROVIDER_ID			= src.SYSTEM_PROVIDER_ID
			   , tgt.NPI1                       = src.NPI1
			   , tgt.DEA                		= src.DEA
			   , tgt.CREATED_ON     	        = src.CREATED_ON 
			   , tgt.CREATED_BY					= src.CREATED_BY
			   , tgt.UPDATED_ON 	            = src.CREATED_ON 
			   , tgt.UPDATED_BY					= src.CREATED_BY 
			   , tgt.UPDATED_WFLOW_EXEC_ID		= src.WFLOW_EXEC_ID 
		;
		SELECT @@ROWCOUNT;
		
		IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) ;
		quit;

			%set_error_flag
			%on_error(ACTION=ABORT)
		 
			
			 DATA _NULL_;
			 set row_count;
			 call symput('row_count',exprssn);
			 run;

		options nomlogic nomprint nosymbolgen;	
		
		%put ;%put NOTE: END MERGE STATEMENT FOR  ciedw.dbo.PROVIDER_PAYER;%put;%put &row_count RECORDS EVALUATED FOR THE CIEDW.PROVIDER_PAYER MERGE;%put;
		
	*SASDOC--------------------------------------------------------------------------
	| SQL to INSERT EDW.NL_HOLD_PROVIDER_PAYER TABLE.
	| 1. WLEE - 20120611 modified to insert into the NL_HOLD_PROVIDER_PAYER table only 
	+------------------------------------------------------------------------SASDOC*; 
	/* INSERT ONLY */   
	

		proc sql;
        connect to oledb(init_string=&cihold.);
         create table row_count as select * from connection to oledb
        (
		DECLARE @intErrorCode INT
		BEGIN TRAN		 
				 MERGE dbo.NL_HOLD_PROVIDER_PAYER AS tgt
				 USING (
							SELECT DISTINCT 
								   WFLOW_EXEC_ID
								 , VHSTAGE_PAYER_SRC_KEY
								 , PAYER_KEY
								 , CLIENT_KEY
								 , LTRIM(RTRIM(LAST_NAME)) AS LAST_NAME
								 , LTRIM(RTRIM(FIRST_NAME)) AS FIRST_NAME
								 , LTRIM(RTRIM(MIDDLE_INITIAL)) AS MIDDLE_INITIAL
								 , SYSTEM_PROVIDER_ID
								 , DEA	
								 , NPI1 
								 , CREATED_ON
								 , CREATED_BY
								 , UPDATED_ON
								 , UPDATED_BY
								 , LOAD_FLAG
								 , VALIDATION_TYPE_ID
							  FROM cihold.dbo.saswrk_provider_payer_src_&client_id. 
							) AS src
					 ON ( COALESCE(tgt.NPI1,'') = COALESCE(src.NPI1,'')
						  AND tgt.CLIENT_KEY = src.CLIENT_KEY 	 
						  AND tgt.PAYER_KEY = src.PAYER_KEY)
					WHEN NOT MATCHED AND SRC.load_flag = -1 THEN
					INSERT(     WFLOW_EXEC_ID
							  , PROVIDER_KEY
							  , PAYER_KEY
							  ,	CLIENT_KEY
							  , LAST_NAME
							  , FIRST_NAME
							  , MIDDLE_INITIAL
							  , SYSTEM_PROVIDER_ID
							  , DEA
							  , NPI1
							  , CREATED_ON
							  , CREATED_BY
							  , UPDATED_ON
							  , UPDATED_BY
							  , VALIDATION_TYPE_ID
						   )
					VALUES(    SRC.WFLOW_EXEC_ID
							 , SRC.VHSTAGE_PAYER_SRC_KEY
							 , SRC.PAYER_KEY
							 , SRC.CLIENT_KEY
							 , SRC.LAST_NAME
							 , SRC.FIRST_NAME
							 , SRC.MIDDLE_INITIAL
							 , SRC.SYSTEM_PROVIDER_ID
							 , SRC.DEA	
							 , SRC.NPI1 
							 , SRC.CREATED_ON		 
							 , SRC.CREATED_BY
							 , SRC.UPDATED_ON
							 , SRC.UPDATED_BY
							 , SRC.VALIDATION_TYPE_ID
			   );

			   SELECT @@ROWCOUNT;
			   
		IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) ;
		quit;

		%set_error_flag
  		%on_error(ACTION=ABORT)

		DATA _NULL_;
			 set row_count;
			 call symput('row_count',exprssn);
		run;
		
		%put ;%put NOTE: END MERGE STATEMENT FOR dbo.NL_HOLD_PROVIDER_PAYER;%put;%put &row_count RECORDS EVALUATED FOR THE CIEDW.NL_HOLD_PROVIDER_PAYER MERGE;%put;
		
		*SASDOC--------------------------------------------------------------------------
		| TABLE: PROVIDER_SPEC_XREF
		| DESC:  IF PROVIDER_KEY DOES NOT EXIST              - INSERT AS PRIMARY        - FIRST MERGE
		|        IF PROVIDER_KEY DOES EXIST AND <> SPECIALTY - INSERT NEW AS NONPRIMARY - SECOND MERGE
		| 		 IF PROVIDER_KEY DOES EXIST AND  = SPECIALTY - NO ACTION 
		|	     ONLY 1 NPI IS LOADED PER CLIENT_KEY SO THE MAX SYSTEM_PROVIDER_KEY IS USED TO CAPTURE 
	    |        THE XREF SPECIALTY USED IN EDW.  FOR TCHP, THE HAVE VALID SYSTEM_PROVIDER_IDs
		| NOTE:  HAD TO CREATE TWO MERGE STATEMENTS DUE TO MERGE RESTRICTIONS - IE, ONLY ALLOWS 1 INSERT 
		|        and CANNOT INSERT FROM A MATCHED CLAUSE
		+------------------------------------------------------------------------SASDOC*; 
		proc sql;
        connect to oledb(init_string=&sqlci.);
        execute
        (
		DECLARE @intErrorCode INT
		BEGIN TRAN
			MERGE  ciedw.dbo.PROVIDER_SPECIALTY_XREF  AS tgt
				USING 
				(		 
				  SELECT DISTINCT 
						 PROV.PROVIDER_KEY
					   , SOURCE.SPECIALTY_KEY
					   , COALESCE(XREF.PROVIDER_KEY, 0) AS PROVIDER_EXIST
					FROM cihold.dbo.saswrk_provider_payer_src_&client_id.         SOURCE 
		    	   INNER JOIN
							(select npi1
								  , max(system_provider_Id) as system_provider_id
							   from cihold.dbo.saswrk_provider_payer_src_15
							  group by npi1) sub_main
							on SOURCE.npi1 = sub_main.npi1 
						   and SOURCE.system_provider_id = sub_main.system_provider_id 
				   INNER JOIN CIEDW.dbo.PROVIDER 							      PROV 	 
					  ON SOURCE.NPI1 = PROV.NPI1 AND PROV.CLIENT_KEY= &client_id. 
					LEFT JOIN ciedw.dbo.PROVIDER_SPECIALTY_XREF 				  XREF 	 
					  ON PROV.PROVIDER_KEY = XREF.PROVIDER_KEY 
				   WHERE SOURCE.provider_validation_Id in (79,80) /*1 =insert 3=update */ 
							and SOURCE.load_flag = 1    /* CONDITION FOR ONLY GOOD NPIS FROM CRITICAL CHECK*/ 	
							AND SOURCE.SPECIALTY_KEY IS NOT NULL /* DO NOT LOAD NULL SPEC KEYS */
							AND PROV.PROVIDER_KEY <> 31927 /* INVALID PROD DUP */
				) AS src
			ON ( tgt.PROVIDER_KEY = src.PROVIDER_KEY AND tgt.SPECIALTY_KEY = src.SPECIALTY_KEY)
			WHEN NOT MATCHED AND SRC.PROVIDER_EXIST = 0 THEN 
			INSERT
			( 
				  PROVIDER_KEY
				, SPECIALTY_KEY
				, isPrimary 
			)
			VALUES
			( 
				  src.PROVIDER_KEY
				, src.SPECIALTY_KEY
				, '1'
			)
			;
		
		IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) by oledb;
		quit;

		%set_error_flag
  		%on_error(ACTION=ABORT)
		
		%put ;%put NOTE: END FIRST MERGE STATEMENT FOR ciedw.dbo.PROVIDER_SPECIALTY_XREF;%put ;	
		
		proc sql;
        connect to oledb(init_string=&sqlci.);
        execute
        (
		DECLARE @intErrorCode INT
		BEGIN TRAN
		
			MERGE  ciedw.dbo.PROVIDER_SPECIALTY_XREF  AS tgt
				USING 
				(		 
					SELECT DISTINCT 
						PROV.PROVIDER_KEY
					  , SOURCE.SPECIALTY_KEY
					  , COALESCE(XREF.PROVIDER_KEY, 0) AS PROVIDER_EXIST
					FROM  cihold.dbo.saswrk_provider_payer_src_&client_id.        SOURCE 
		    	   INNER JOIN
							(select npi1
								  , max(system_provider_Id) as system_provider_id
							   from cihold.dbo.saswrk_provider_payer_src_15
							  group by npi1) sub_main
							on SOURCE.npi1 = sub_main.npi1 
						   and SOURCE.system_provider_id = sub_main.system_provider_id 
				   INNER JOIN CIEDW.dbo.PROVIDER 							      PROV   
				      ON SOURCE.NPI1 = PROV.NPI1 AND PROV.CLIENT_KEY= &client_id. 
					LEFT JOIN ciedw.dbo.PROVIDER_SPECIALTY_XREF 				  XREF   
					  ON PROV.PROVIDER_KEY = XREF.PROVIDER_KEY 
				   WHERE SOURCE.provider_validation_Id in (79,80) /*1 =insert 3=update */ 
							and SOURCE.load_flag = 1    /* CONDITION FOR ONLY GOOD NPIS FROM CRITICAL CHECK*/ 
							AND SOURCE.SPECIALTY_KEY IS NOT NULL  /* DO NOT LOAD NULL SPEC KEYS */
							AND PROV.PROVIDER_KEY <> 31927 /* INVALID PROD DUP */							
				) AS src 
			ON ( tgt.PROVIDER_KEY = src.PROVIDER_KEY 
			     AND tgt.SPECIALTY_KEY = src.SPECIALTY_KEY)
			WHEN NOT MATCHED AND SRC.PROVIDER_EXIST > 0 THEN 
			INSERT
			( 
				PROVIDER_KEY
				, SPECIALTY_KEY
				, isPrimary 
			)
			VALUES
			( 
				src.PROVIDER_KEY
				, src.SPECIALTY_KEY
				, '0'
			)
			;
		
		IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) by oledb;
		quit;
		
			%set_error_flag
			%on_error(ACTION=ABORT)
 			options mlogic mprint symbolgen; 

		%put ;%put NOTE: END LAST MERGE STATEMENT FOR ciedw.dbo.PROVIDER_SPECIALTY_XREF;%put ;		

		
		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to complete.        
		+------------------------------------------------------------------------SASDOC*;
		%bpm_process_control(timevar=COMPLETE);
		

%mend edw_provider_payer_load;
%edw_provider_payer_load()
