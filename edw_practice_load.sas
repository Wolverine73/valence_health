/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_practice_load.sas
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
| 12JUL2012 - Winnie lee - Clinical Integration Release 1.3 H01
|			1. Incorporate change to handle not only vSource populating the tables
|				but payer data as well.
|
+-----------------------------------------------------------------------HEADER*/

/*SASDOC-----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*/ 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

/*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+-------------------------------------------------------------------------SASDOC*/
/*%let sysparm = %str(sk_prcs_ctrl_id=10029 wflow_exec_id=48865 sas_prgm_id=4 client_id=6 sas_mode=test);*/
%bpm_environment;


%macro edw_practice_load ();

	%put _all_;

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.        
	+-------------------------------------------------------------------------SASDOC*/ 
	%bpm_process_control(timevar=START);


	/*SASDOC--------------------------------------------------------------------------
	| SQL - UPDATE EDW PRACTICE TABLE EDW PRACTICE TABLE BASED IF
	| VSOURCE PRACTICE RECORDS ALREADY EXISTS BASED ON POPULATED VSOURCE_PRACTICE_KEY
	+-------------------------------------------------------------------------SASDOC*/ 
    proc sql;
    connect to oledb(init_string=&sqlci.);
    execute
    (
		DECLARE @intErrorCode INT
		BEGIN TRAN
		MERGE [CIEDW].[dbo].[PRACTICE]       AS T
		USING [CIHold].[dbo].[HOLD_PRACTICE] AS S
		ON T.VSOURCE_PRACTICE_KEY IS NOT NULL and T.VSOURCE_PRACTICE_KEY = S.VSOURCE_PRACTICE_KEY
		WHEN MATCHED and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[LOAD_FLAG] = 1 THEN 
		UPDATE SET 
			T.[PRACTICE_NAME]		  = S.[PRACTICE_NAME],
			T.[PRACTICE_MGT_KEY]	  = S.[PRACTICE_MGT_KEY],
			T.[TIN]					  = S.[TIN],
			T.[TIN_NAME]			  = S.[TIN_NAME],
			T.[NPI2]				  = S.[NPI2],
			T.[DATA_CATEGORY]		  = S.[DATA_CATEGORY],
			T.[VMINE_INSTALLED_SCHED] = S.[VMINE_INSTALLED_SCHED],
			T.[VMINE_INSTALLED_DATE]  = S.[VMINE_INSTALLED_DATE],
			T.[VMINE_INSTALLER_NAME]  = S.[VMINE_INSTALLER_NAME],
			T.[VMINE_STATUS]		  = S.[VMINE_STATUS],
			T.[PRACTICE_EFF_DATE]	  = S.[PRACTICE_EFF_DATE],
			T.[PRACTICE_EXP_DATE]	  = S.[PRACTICE_EXP_DATE],
			T.[CI_STATUS]			  = S.[CI_STATUS],
			T.[DATA_CMPLT_IND]		  = S.[DATA_CMPLT_IND],
			T.[WFLOW_EXEC_ID]		  = S.[WFLOW_EXEC_ID],
			T.[UPDATED_ON]			  = S.[UPDATED_ON],
			T.[UPDATED_BY]			  = S.[UPDATED_BY],
			T.[VSOURCE_PRACTICE_KEY]  = S.[VSOURCE_PRACTICE_KEY],
			T.[IS_VSOURCE_DATA]		  = S.[IS_VSOURCE_DATA]
		;
		IF (@intErrorCode <> 0) BEGIN
			ROLLBACK TRAN
		END
		COMMIT TRAN
    ) by oledb;
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	/*SASDOC--------------------------------------------------------------------------
	| SQL - INSERT AND UPDATE EDW PRACTICE TABLE EDW PRACTICE TABLE BASED ON
	| TIN AND PRACTICE_NAME
	+-------------------------------------------------------------------------SASDOC*/ 
    proc sql;
    connect to oledb(init_string=&sqlci.);
    execute
    (
		DECLARE @intErrorCode INT
		BEGIN TRAN
		MERGE [CIEDW].[dbo].[PRACTICE]       AS T
		USING [CIHold].[dbo].[HOLD_PRACTICE] AS S
		ON COALESCE(T.TIN,'') = COALESCE(S.TIN,'') AND T.PRACTICE_NAME = S.PRACTICE_NAME
		WHEN NOT MATCHED BY TARGET and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[load_flag] = 1 THEN
		INSERT
		(
			[CLIENT_KEY],
			[PRACTICE_NAME],
			[PRACTICE_MGT_KEY],
			[TIN],
			[TIN_NAME],
			[NPI2],
			[DATA_CATEGORY],
			[VMINE_INSTALLED_SCHED],
			[VMINE_INSTALLED_DATE],
			[VMINE_INSTALLER_NAME],
			[VMINE_STATUS],
			[PRACTICE_EFF_DATE],
			[PRACTICE_EXP_DATE],
			[CI_STATUS],
			[DATA_CMPLT_IND],
			[WFLOW_EXEC_ID],
			[CREATED_ON],
			[CREATED_BY],
			[UPDATED_ON],
			[UPDATED_BY],
			[VSOURCE_PRACTICE_KEY],
			[IS_VSOURCE_DATA],
			[IS_PAYER_DATA]
		)
		VALUES
		(
		ABS(S.[CLIENT_KEY]),
			S.[PRACTICE_NAME],
			S.[PRACTICE_MGT_KEY],
			S.[TIN],
			S.[TIN_NAME],
			S.[NPI2],
			S.[DATA_CATEGORY],
			S.[VMINE_INSTALLED_SCHED],
			S.[VMINE_INSTALLED_DATE],
			S.[VMINE_INSTALLER_NAME],
			S.[VMINE_STATUS],
			S.[PRACTICE_EFF_DATE],
			S.[PRACTICE_EXP_DATE],
			S.[CI_STATUS],
			S.[DATA_CMPLT_IND],
			S.[WFLOW_EXEC_ID],
			S.[CREATED_ON],
			S.[CREATED_BY],
			S.[UPDATED_ON],
			S.[UPDATED_BY],
			S.[VSOURCE_PRACTICE_KEY],
			S.[IS_VSOURCE_DATA],
			S.[IS_PAYER_DATA]
		)
		WHEN MATCHED and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[LOAD_FLAG] = 1 and T.VSOURCE_PRACTICE_KEY IS NULL THEN 
		UPDATE SET 
			T.[PRACTICE_MGT_KEY]	  = S.[PRACTICE_MGT_KEY],
			T.[TIN_NAME]			  = S.[TIN_NAME],
			T.[NPI2]				  = S.[NPI2],
			T.[DATA_CATEGORY]		  = S.[DATA_CATEGORY],
			T.[VMINE_INSTALLED_SCHED] = S.[VMINE_INSTALLED_SCHED],
			T.[VMINE_INSTALLED_DATE]  = S.[VMINE_INSTALLED_DATE],
			T.[VMINE_INSTALLER_NAME]  = S.[VMINE_INSTALLER_NAME],
			T.[VMINE_STATUS]		  = S.[VMINE_STATUS],
			T.[PRACTICE_EFF_DATE]	  = S.[PRACTICE_EFF_DATE],
			T.[PRACTICE_EXP_DATE]	  = S.[PRACTICE_EXP_DATE],
			T.[CI_STATUS]			  = S.[CI_STATUS],
			T.[DATA_CMPLT_IND]		  = S.[DATA_CMPLT_IND],
			T.[WFLOW_EXEC_ID]		  = S.[WFLOW_EXEC_ID],
			T.[UPDATED_ON]			  = S.[UPDATED_ON],
			T.[UPDATED_BY]			  = S.[UPDATED_BY],
			T.[VSOURCE_PRACTICE_KEY]  = S.[VSOURCE_PRACTICE_KEY],
			T.[IS_VSOURCE_DATA]		  = S.[IS_VSOURCE_DATA]
		;
		IF (@intErrorCode <> 0) BEGIN
			ROLLBACK TRAN
		END
		COMMIT TRAN
    ) by oledb;
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	/*SASDOC----------------------------------------------------------------------------
	| SQL - INSERT NON-LOADABLE HOLD_PRACTICE RECORDS INTO CIHOLD.NL_HOLD_PRACTICE TABLE
	+---------------------------------------------------------------------------SASDOC*/

	proc sql;
    connect to oledb(init_string=&cihold.);
    execute
    (
		DECLARE @intErrorCode INT

		BEGIN TRAN
			INSERT INTO [dbo].[NL_HOLD_PRACTICE]
			(
				[CLIENT_KEY],
				[PRACTICE_NAME],
				[PRACTICE_MGT_KEY],
				[TIN],
				[TIN_NAME],
				[NPI2],
				[DATA_CATEGORY],
				[VMINE_INSTALLED_SCHED],
				[VMINE_INSTALLED_DATE],
				[VMINE_INSTALLER_NAME],
				[VMINE_STATUS],
				[PRACTICE_EFF_DATE],
				[PRACTICE_EXP_DATE], 
				[CI_STATUS],
				[DATA_CMPLT_IND],
				[WFLOW_EXEC_ID],
				[LOAD_FLAG],
				[CREATED_ON],
				[CREATED_BY],
				[UPDATED_ON],
				[UPDATED_BY],
				[VSOURCE_PRACTICE_KEY],
				[IS_VSOURCE_DATA],
				[IS_PAYER_DATA]
			)
			SELECT 
			ABS(A.[CLIENT_KEY]),
				A.[PRACTICE_NAME],
				A.[PRACTICE_MGT_KEY],
				A.[TIN],
				A.[TIN_NAME],
				A.[NPI2],
				A.[DATA_CATEGORY],
				A.[VMINE_INSTALLED_SCHED],
				A.[VMINE_INSTALLED_DATE],
				A.[VMINE_INSTALLER_NAME],
				A.[VMINE_STATUS],
				A.[PRACTICE_EFF_DATE],
				A.[PRACTICE_EXP_DATE],
				A.[CI_STATUS],
				A.[DATA_CMPLT_IND],
				A.[WFLOW_EXEC_ID], 
				A.[LOAD_FLAG],
				A.[CREATED_ON],
				A.[CREATED_BY],
				A.[UPDATED_ON],
				A.[UPDATED_BY],
				A.[VSOURCE_PRACTICE_KEY],
				A.[IS_VSOURCE_DATA],
				A.[IS_PAYER_DATA]
			FROM [dbo].[HOLD_PRACTICE] as A
			WHERE A.[LOAD_FLAG] = 0;

		IF (@intErrorCode <> 0) BEGIN
			ROLLBACK TRAN
		END

		COMMIT TRAN

	) by oledb;
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	/*DELETE CIHOLD.HOLD_PRACTICE TABLE*/
	proc sql;
	  delete *
	  from cihold.hold_practice
	  where client_key in (&client_id.,-&client_id.);
	quit; 

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	/*SASDOC--------------------------------------------------------------------------
	| CIEDW - DELETE and REFRESH PRACTICE_MGT_SYSTEM TABLE        
	+-------------------------------------------------------------------------SASDOC*/

	/*DELETE CIEDW.PRACTICE_MGT_SYSTEM TABLE*/
	proc sql;
	  delete *
	  from ciedw.practice_mgt_system
	quit; 

	%set_error_flag;
  	%on_error(ACTION=ABORT);

	/*PULL PRACTICE MANAGEMENT SYSTEMS FROM vMine.dbo.Version and vMine.dbo.Status*/
	proc sql;
	connect to oledb(init_string=&ids.);
	create table PRACTICE_MGT_SYSTEM as select * from connection to oledb
	(
	select distinct
		[VersionID]											as PRACTICE_MGT_KEY,
		[Name]												as PRACTICE_MGT_NAME,
		[VersionName]										as PRACTICE_MGT_SYSTEM_VERSION,
		case when upper([Category]) = 'VMINE' then 'Y'	
		else 'N'										end as VMINE_CAPABLE_IND
	from [dbo].[PMSystemStatus]
	);
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);

	data null;
	date=put(today(),date9.);
	call symput('date',date);
	run;

	proc sql;
	create table PRACTICE_MGT_SYSTEM as
	select a.* ,  
		input("&date."||put(time(),time16.6),datetime22.3) as CREATED_ON format datetime22.3,
		"BPM - SAS" as CREATED_BY, 
		input("&date."||put(time(),time16.6),datetime22.3) as UPDATED_ON format datetime22.3,
		"BPM - SAS" as UPDATED_BY  
		from PRACTICE_MGT_SYSTEM as a  ; 
	quit;

	proc sql;
	insert into ciedw.PRACTICE_MGT_SYSTEM
	(
		PRACTICE_MGT_KEY,
		PRACTICE_MGT_NAME,
		PRACTICE_MGT_SYSTEM_VERSION,
		VMINE_CAPABLE_IND,    	
		CREATED_ON,  			
		CREATED_BY,  			
		UPDATED_ON,  			
		UPDATED_BY  			
	)
	select
		PRACTICE_MGT_KEY,
		PRACTICE_MGT_NAME,
		PRACTICE_MGT_SYSTEM_VERSION,
		VMINE_CAPABLE_IND,    	
		CREATED_ON,  			
		CREATED_BY,  			
		UPDATED_ON,  			
		UPDATED_BY    
	from PRACTICE_MGT_SYSTEM;
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	/*SASDOC---------------------------------------------------------------------------
	| CIEDW - Insert, update practice address table, hold table and no load hold table.        
	+--------------------------------------------------------------------------SASDOC*/
	%edw_practice_addr_extract();	
	%edw_practice_addr_load();	


	/*SASDOC---------------------------------------------------------------------------------
	| CIEDW - Insert, update PROVIDER_PRACTICE_XREF table, hold table and no load hold table.        
	+--------------------------------------------------------------------------------SASDOC*/
	%edw_providerpracticexref_extract();
	%edw_providerpracticexref_load();


	/*SASDOC--------------------------------------------------------------------------
	| CIEDW - Call stored procedures       
	+-------------------------------------------------------------------------SASDOC*/

	proc sql;
		connect to oledb(init_string=&ciedw.);
		select * from connection to oledb
		(
			exec dbo.usp_SET_PROVIDER_PRIMARY_SPECIALTY &client_id.
		);
	quit;

	proc sql;
		connect to oledb(init_string=&ciedw.);
		select * from connection to oledb
		(
			exec dbo.usp_SET_PRACTICE_SPECIALTY_LIST &client_id.
		);
	quit;


	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*;
	%bpm_process_control(timevar=COMPLETE);	
		

%mend edw_practice_load;
%edw_practice_load;
