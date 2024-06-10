
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_practice_addr_load.sas
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
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
/*options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos); */


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*; 
/*%let sysparm=%str(sk_prcs_ctrl_id=75 wflow_exec_id=31 sas_prgm_id=24 client_id=4 sas_mode=test); */
*%let test_case = 1; *UPDATE FOR TEST CASES;

/*%bpm_environment;*/
/*%bpm_initialize_variables;*/


%macro edw_practice_addr_load ();

	*SASDOC--------------------------------------------------------------------------
	| SQL to INSERT AND UPDATE EDW.practice_addr TABLE.        
	+------------------------------------------------------------------------SASDOC*; 
	    proc sql;
        connect to oledb(init_string=&sqlci.);
        execute
        (
			DECLARE @intErrorCode INT
			BEGIN TRAN
			MERGE [CIEDW].[dbo].[PRACTICE_ADDR]       AS T
			USING [CIHold].[dbo].[HOLD_PRACTICE_ADDR] AS S
			ON (T.PRACTICE_ADDR_KEY  = S.PRACTICE_ADDR_KEY ) 
			WHEN NOT MATCHED BY TARGET and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[LOAD_FLAG] = 1
			    THEN INSERT( 
							[PRACTICE_ADDR_KEY],
							[PRACTICE_KEY],
							[CLIENT_KEY],
							[ADDR_LINE_1],
							[ADDR_LINE_2],
							[CITY],
							[STATE],
							[ZIP_CODE],
							[COUNTY],
							[DATA_CMPLT_IND],
							[PRIM_ADDR_IND],
							[WFLOW_EXEC_ID],
							[CREATED_ON],
							[CREATED_BY],
							[UPDATED_ON],
							[UPDATED_BY] ) 
                VALUES( 
							S.[PRACTICE_ADDR_KEY],
							S.[PRACTICE_KEY],
							S.[CLIENT_KEY],
							S.[ADDR_LINE_1],
							S.[ADDR_LINE_2],
							S.[CITY],
							S.[STATE],
							S.[ZIP_CODE],
							S.[COUNTY],
							S.[DATA_CMPLT_IND],
							S.[PRIM_ADDR_IND],
							S.[WFLOW_EXEC_ID],
							S.[CREATED_ON],
							S.[CREATED_BY],
							S.[UPDATED_ON],
							S.[UPDATED_BY]) 
			WHEN MATCHED and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[LOAD_FLAG] = 1 THEN UPDATE SET 
							T.[ADDR_LINE_1]=S.[ADDR_LINE_1],
							T.[ADDR_LINE_2]=S.[ADDR_LINE_2],
							T.[CITY]=S.[CITY],
							T.[STATE]=S.[STATE],
							T.[ZIP_CODE]=S.[ZIP_CODE],
							T.[COUNTY]=S.[COUNTY],
							T.[DATA_CMPLT_IND]=S.[DATA_CMPLT_IND],
							T.[PRIM_ADDR_IND]=S.[PRIM_ADDR_IND],
							T.[WFLOW_EXEC_ID]=S.[WFLOW_EXEC_ID],
							T.[UPDATED_ON]=S.[UPDATED_ON],
							T.[UPDATED_BY]=S.[UPDATED_BY];

			IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) by oledb;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		/*INSERT NON-LOADABLE HOLD_PRACTICE_ADDR RECORDS INTO CIHOLD.NL_HOLD_PRACTICE_ADDR TABLE*/


		proc sql;
        connect to oledb(init_string=&cihold.);
        execute
        (
			DECLARE @intErrorCode INT

			BEGIN TRAN
				INSERT INTO [dbo].[NL_HOLD_PRACTICE_ADDR]
					(
					[PRACTICE_ADDR_KEY],
					[PRACTICE_KEY],
					[CLIENT_KEY],
					[WFLOW_EXEC_ID],
					[ADDR_LINE_1],
					[ADDR_LINE_2],
					[CITY],
					[STATE],
					[ZIP_CODE],
					[COUNTY],
					[DATA_CMPLT_IND],
					[PRIM_ADDR_IND],
					[LOAD_FLAG],
					[CREATED_ON],
					[CREATED_BY],
					[UPDATED_ON],
					[UPDATED_BY]
					)
				SELECT 
					A.[PRACTICE_ADDR_KEY],
					A.[PRACTICE_KEY],
					A.[CLIENT_KEY],
					A.[WFLOW_EXEC_ID], 
					A.[ADDR_LINE_1],
					A.[ADDR_LINE_2],
					A.[CITY],
					A.[STATE],
					A.[ZIP_CODE],
					A.[COUNTY],
					A.[DATA_CMPLT_IND],
					A.[PRIM_ADDR_IND],
					A.[LOAD_FLAG],
					A.[CREATED_ON],
					A.[CREATED_BY],
					A.[UPDATED_ON],
					A.[UPDATED_BY]
				FROM [dbo].[HOLD_PRACTICE_ADDR] as A
				WHERE A.[LOAD_FLAG] = 0;
			IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END

			COMMIT TRAN

		) by oledb;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);



		/*DELETE CIHOLD.HOLD_PRACTICE_ADDR TABLE*/
		proc sql;
		delete *
		from cihold.hold_practice_addr;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

%mend edw_practice_addr_load;
