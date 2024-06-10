/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_prov_vw_dataformatid_68.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: Extract payer provider from VHSTAGE_PAYER database                                
|           
| INPUT:                                     
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 26JUN2012 - Brandon Fletcher - Clinical Integration Release v1.3.H01
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_prov_vw_dataformatid_68;

	PROC SQL;
		CREATE TABLE provider_payer_src_&client_id. as				 
			SELECT  DISTINCT																									
			    CASE WHEN NOT MISSING(LAST_NAME) AND NOT MISSING(FIRST_NAME) THEN CATX(', ',LAST_NAME, FIRST_NAME)   								
					 WHEN NOT MISSING(LAST_NAME)  THEN STRIP(LAST_NAME)
					 WHEN NOT MISSING(FIRST_NAME) THEN STRIP(FIRST_NAME)
					 ELSE ''																					
				END						AS PROVIDER_NAME
			  , DATA_SOURCE_ID
			  , BATCH_KEY
			  , MAX(PROVIDER_KEY) 			AS VHSTAGE_PAYER_SRC_KEY
			  , LAST_NAME
			  , FIRST_NAME
			  , '' AS MIDDLE_INITIAL
			  , NPI AS NPI1
			  , '' AS DEA
			  , MAX(VH_SPECIALTY_KEY)	AS SPECIALTY_KEY
			  , SYSTEM_PROVIDER_ID
			  , 0						AS validation_id
			  , &wflow_exec_id.			AS wflow_exec_id
			  , 4						AS PAYER_KEY 	/* MISSING IN VIEW */
			  , 'NONPAR' 				AS CI_STATUS	/* used for edw.provider only */
			  , CLIENT_KEY				AS CLIENT_KEY
			  , . 						AS PROVIDER_validation_id /* USED FOR VALIDATION MACROS -- COLUMNS CREATED BY EDW_PROVIDER_PAYER_VALIDATION IN_DATASET2 MACRO */
			  , . 						AS PROVIDER_PAYER_validation_id  /* USED FOR VALIDATION MACROS */
			  , . 						AS validation_type_id  /* USED FOR VALIDATION MACROS */
			FROM vh_payer.V_TCHP_PROVIDER 
			WHERE DATA_SOURCE_ID = &practice_id. and BATCH_KEY = &batch_key.
			GROUP BY 
		          DATA_SOURCE_ID
			    , BATCH_KEY 			 
			    , LAST_NAME              
			    , FIRST_NAME 
			    , NPI 		 	 
			    , CLIENT_KEY
				, SYSTEM_PROVIDER_ID
		;
	QUIT; 

%mend payer_prov_vw_dataformatid_68;
