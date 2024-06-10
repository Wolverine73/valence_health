
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

%macro edw_provpracxref_payer_load ();
    options nomlogic nomprint;
	
	*SASDOC--------------------------------------------------------------------------
	| SQL to INSERT AND UPDATE EDW.PROVIDER_PRACTICE_XREF TABLE.        
	+------------------------------------------------------------------------SASDOC*; 
	    proc sql;
        connect to oledb(init_string=&sqlci.);
       create table row_count as select * from connection to oledb
        (
			DECLARE @intErrorCode INT
			BEGIN TRAN
			MERGE [CIEDW].[dbo].[PROVIDER_PRACTICE_XREF]       AS T
			USING [CIHold].[dbo].[saswrk_hld_provpracx_pyr_&client_id.] AS S
			ON (T.PRACTICE_KEY = S.PRACTICE_KEY and
				T.PROVIDER_KEY = S.PROVIDER_KEY) 
			WHEN NOT MATCHED BY TARGET and S.[LOAD_FLAG] = 1
			    THEN INSERT( 
							[PRACTICE_KEY],
							[PROVIDER_KEY],
							[CLIENT_KEY],
							[WFLOW_EXEC_ID],
							[CREATED_ON],
							[CREATED_BY],
							[UPDATED_ON],
							[UPDATED_BY] ) 
                VALUES( 
							S.[PRACTICE_KEY],
							S.[PROVIDER_KEY],
						ABS(S.[CLIENT_KEY]),
							S.[WFLOW_EXEC_ID],
							S.[CREATED_ON],
							S.[CREATED_BY],
							S.[UPDATED_ON],
							S.[UPDATED_BY]);
			SELECT @@ROWCOUNT ;
			IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        );
		quit;		 
		
		DATA _NULL_;
			 set row_count;
			 call symput('row_count',exprssn);
			 run;

			 %put;%put &row_count RECORDS EVALUATED FOR THE dbo.PROVIDER_PRACTICE_XREF MERGE;%put;
		
		%set_error_flag;
  		%on_error(ACTION=ABORT);

		
%mend edw_provpracxref_payer_load;
