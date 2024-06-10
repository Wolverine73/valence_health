
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_providerpracticexref_load.sas
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


%macro edw_providerpracticexref_load ();

	*SASDOC--------------------------------------------------------------------------
	| SQL to INSERT AND UPDATE EDW.PROVIDER_PRACTICE_XREF TABLE.        
	+------------------------------------------------------------------------SASDOC*; 
	    proc sql;
        connect to oledb(init_string=&sqlci.);
        execute
        (
			DECLARE @intErrorCode INT
			BEGIN TRAN
			MERGE [CIEDW].[dbo].[PROVIDER_PRACTICE_XREF]       AS T
			USING [CIHold].[dbo].[HOLD_PROVIDER_PRACTICE_XREF] AS S
			ON (T.PRACTICE_KEY = S.PRACTICE_KEY and
				T.PROVIDER_KEY = S.PROVIDER_KEY) 
			WHEN NOT MATCHED BY TARGET and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[LOAD_FLAG] = 1
			    THEN INSERT( 
							[PRACTICE_KEY],
							[PROVIDER_KEY],
							[CLIENT_KEY],
							[PRIMARY_PRACTICE_IND],
							[EFF_DT],
							[EXP_DT],
							[WFLOW_EXEC_ID],
							[CREATED_ON],
							[CREATED_BY],
							[UPDATED_ON],
							[UPDATED_BY] ) 
                VALUES( 
							S.[PRACTICE_KEY],
							S.[PROVIDER_KEY],
						ABS(S.[CLIENT_KEY]),
							S.[PRIMARY_PRACTICE_IND],
							S.[EFF_DT],
							S.[EXP_DT],
							S.[WFLOW_EXEC_ID],
							S.[CREATED_ON],
							S.[CREATED_BY],
							S.[UPDATED_ON],
							S.[UPDATED_BY]) 
			WHEN MATCHED and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[LOAD_FLAG] = 1 THEN UPDATE SET 
							T.[PRACTICE_KEY]=S.[PRACTICE_KEY],
							T.[PROVIDER_KEY]=S.[PROVIDER_KEY],
							T.[CLIENT_KEY]=ABS(S.[CLIENT_KEY]),
							T.[PRIMARY_PRACTICE_IND]=S.[PRIMARY_PRACTICE_IND],
							T.[EFF_DT]=S.[EFF_DT],
							T.[EXP_DT]=S.[EXP_DT],
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

		/*INSERT NON-LOADABLE HOLD_PROVIDER_PRACTICE_XREF RECORDS INTO CIHOLD.NL_HOLD_PROVIDER_PRACTICE_XREF TABLE*/


		proc sql;
        connect to oledb(init_string=&cihold.);
        execute
        (
			DECLARE @intErrorCode INT

			BEGIN TRAN
				INSERT INTO [dbo].[NL_HOLD_PROVIDER_PRACTICE_XREF]
					(
					[PRACTICE_KEY],
					[PROVIDER_KEY],
					[CLIENT_KEY],
					[PRIMARY_PRACTICE_IND],
					[EFF_DT],
					[EXP_DT],
					[WFLOW_EXEC_ID],
					[LOAD_FLAG],
					[CREATED_ON],
					[CREATED_BY],
					[UPDATED_ON],
					[UPDATED_BY]
					)
				SELECT 
					A.[PRACTICE_KEY],
					A.[PROVIDER_KEY],
				ABS(A.[CLIENT_KEY]),
					A.[PRIMARY_PRACTICE_IND], 
					A.[EFF_DT],
					A.[EXP_DT],
					A.[WFLOW_EXEC_ID],
					A.[LOAD_FLAG],
					A.[CREATED_ON],
					A.[CREATED_BY],
					A.[UPDATED_ON],
					A.[UPDATED_BY]
				FROM [dbo].[HOLD_PROVIDER_PRACTICE_XREF] as A
				WHERE A.[LOAD_FLAG] = 0;
			IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END

			COMMIT TRAN

		) by oledb;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);



		/*DELETE CIHOLD.HOLD_PROVIDER_PRACTICE_XREF TABLE*/
		proc sql;
		delete *
		from cihold.hold_provider_practice_xref;
		where client_key in (&client_id.,-&client_id.);
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

%mend edw_providerpracticexref_load;
