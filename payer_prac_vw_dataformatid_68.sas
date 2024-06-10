/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_prac_vw_dataformatid_68.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: Extract payer provider from VHSTAGE_PAYER database                                
|                   
| INPUT:                                     
|
| OUTPUT:                           
|          
| NOTE:  PRACTICE RECORDS ARE SUPPOSED TO BE UNIQUE BY TIN AND SYSTEM_PRACTICE_ID.  HOWEVER,
|        THAT IS NOT THE CASE.  WITH THAT BEING SAID, WITHIN THE RECORD SET THERE IS ONLY 1 VALID RECORD
|		 IT IS UNSURE IF THIS ARE ACTUAL DATA ISSUES OR THE WAY THE FILE WILL ALWAYS COME.   
|
|        QUERY ONE: ELIMINATES WHERE NPI and PRACTICE_NAME IS NULL.
|        QUERY TWO: APPENDS WHERE THERE IS NOT A GOOD RECORD IN THE RECORD SET SO THE
|		 RECORDS CAN BE INSERTED INTO NL_HOLD_PRACTICE_PAYER TABLE
|                                         
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 27JUN2012 - Brandon Fletcher - Clinical Integration Release v1.3.H01
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_prac_vw_dataformatid_68;


PROC SQL;
        CREATE TABLE PRACTICE_payer_src_&client_id as
            SELECT  DISTINCT
                    PRACTICE_NAME       AS NAME
                  , DATA_SOURCE_ID
                  , 4                   AS PAYER_KEY                    /* MISSING IN VIEW */
                  , PROVIDER_KEY        AS VHSTAGE_PAYER_SRC_KEY
                  , BATCH_KEY
                  , STRIP(TIN)          AS TIN length=9
                  , NPI                 AS NPI1                         /* NEED TO KEEP FOR PROV PRAC XREF JOIN */
                  , 0                   AS validation_id
                  , &wflow_exec_id.     AS wflow_exec_id
                  , 'NONPAR'            AS CI_STATUS                    /* used for edw.provider only */
                  , CLIENT_KEY      AS CLIENT_KEY
                  , .                   AS PRACTICE_validation_id       /* USED FOR VALIDATION MACROS -- COLUMNS CREATED BY EDW_PRACTICE_PAYER_VALIDATION IN_DATASET2 MACRO */
                  , .                   AS PRACTICE_PAYER_validation_id /* USED FOR VALIDATION MACROS */
                  , .                   AS validation_type_id           /* USED FOR VALIDATION MACROS */
                  , EFFECTIVE_DATE
                  , TERMINATION_DATE
                  , SYSTEM_PRACTICE_ID
                  , ADDRESS1
                  , ADDRESS2
                  , CITY
                  , STATE
                  , ZIP
                  , COUNTY
              FROM vh_payer.V_TCHP_PROVIDER
            WHERE DATA_SOURCE_ID = &practice_id. and BATCH_KEY = &batch_key. 
        ;
    QUIT;

%mend payer_prac_vw_dataformatid_68;
