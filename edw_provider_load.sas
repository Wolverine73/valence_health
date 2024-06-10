
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_provider_extract.sas
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
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);



*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*; 
/*%let sysparm=%str(sk_prcs_ctrl_id=10028 wflow_exec_id=48865 sas_prgm_id=3 client_id=6 sas_mode=test); */


%bpm_environment;


%macro edw_provider_load ();

	%put _all_;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.        
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);


	*SASDOC--------------------------------------------------------------------------
	| SQL to INSERT AND UPDATE EDW.PROVIDER TABLE.        
	+------------------------------------------------------------------------SASDOC*; 
    proc sql;
    connect to oledb(init_string=&sqlci.);
    execute
    (
		DECLARE @intErrorCode INT
		BEGIN TRAN
		MERGE [CIEDW].[dbo].[PROVIDER]       AS T
		USING [CIHold].[dbo].[HOLD_PROVIDER] AS S
		ON ((T.VSOURCE_PROVIDER_KEY = S.VSOURCE_PROVIDER_KEY and T.VSOURCE_PROVIDER_KEY IS NOT NULL) OR
			(T.NPI1 = S.NPI1 AND T.CLIENT_KEY = ABS(S.CLIENT_KEY)))
		WHEN NOT MATCHED BY TARGET and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[load_flag] = 1 THEN 
		INSERT
		( 
			[CLIENT_KEY],
			[PROVIDER_NAME],
			[PROVIDER_TITLE],
			[NETWORK_STATUS],
			[CI_STATUS],
			[CLNCL_INT_EFF_DT],
			[CLNCL_INT_EXP_DT],
			[NETWORK_EFF_DT],
			[NETWORK_EXP_DT],
			[DEA],
			[NPI1],
			[DATA_CMPLT_IND],
			[MANUAL_RPT_IND], 
			[WFLOW_EXEC_ID],
			[CREATED_ON],
			[CREATED_BY],
			[UPDATED_ON],
			[UPDATED_BY],
			[SAS_PROV_ID],
			[IS_ATTRIBUTABLE],
			[VSOURCE_PROVIDER_KEY],
			[IS_VSOURCE_DATA],
			[IS_PAYER_DATA]
		) 
        VALUES
		( 
		ABS(S.[CLIENT_KEY]),
			S.[PROVIDER_NAME],
			S.[PROVIDER_TITLE],
			S.[NETWORK_STATUS],
			S.[CI_STATUS],
			S.[CLNCL_INT_EFF_DT],
			S.[CLNCL_INT_EXP_DT],
			S.[NETWORK_EFF_DT],
			S.[NETWORK_EXP_DT],
			S.[DEA],
			S.[NPI1],
			S.[DATA_CMPLT_IND],
			S.[MANUAL_RPT_IND], 
			S.[WFLOW_EXEC_ID],
			S.[CREATED_ON],
			S.[CREATED_BY],
			S.[UPDATED_ON],
			S.[UPDATED_BY],
			S.[SAS_PROV_ID],
			S.[IS_ATTRIBUTABLE],
			S.[VSOURCE_PROVIDER_KEY],
			S.[IS_VSOURCE_DATA],
			S.[IS_PAYER_DATA]
		) 
		WHEN MATCHED and S.WFLOW_EXEC_ID = &wflow_exec_id. and S.[load_flag] = 1 THEN 
		UPDATE SET 
			T.[PROVIDER_NAME]		 = S.[PROVIDER_NAME],
			T.[PROVIDER_TITLE]		 = S.[PROVIDER_TITLE],
			T.[NETWORK_STATUS]		 = S.[NETWORK_STATUS],
			T.[CI_STATUS]			 = S.[CI_STATUS],
			T.[CLNCL_INT_EFF_DT]	 = S.[CLNCL_INT_EFF_DT],
			T.[CLNCL_INT_EXP_DT]	 = S.[CLNCL_INT_EXP_DT],
			T.[NETWORK_EFF_DT]		 = S.[NETWORK_EFF_DT],
			T.[NETWORK_EXP_DT]		 = S.[NETWORK_EXP_DT],
			T.[DEA]					 = S.[DEA],
			T.[NPI1]				 = S.[NPI1],
			T.[DATA_CMPLT_IND]		 = S.[DATA_CMPLT_IND],
			T.[MANUAL_RPT_IND]		 = S.[MANUAL_RPT_IND], 
			T.[WFLOW_EXEC_ID]		 = S.[WFLOW_EXEC_ID],
			T.[UPDATED_ON]			 = S.[UPDATED_ON],
			T.[UPDATED_BY]			 = S.[UPDATED_BY],
			T.[SAS_PROV_ID]			 = S.[SAS_PROV_ID],
			T.[IS_ATTRIBUTABLE]		 = S.[IS_ATTRIBUTABLE],
			T.[VSOURCE_PROVIDER_KEY] = S.[VSOURCE_PROVIDER_KEY],
			T.[IS_VSOURCE_DATA]		 = S.[IS_VSOURCE_DATA]
		;

		IF (@intErrorCode <> 0) BEGIN
			ROLLBACK TRAN
		END
		COMMIT TRAN
    ) by oledb;
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


	/*INSERT NON-LOADABLE HOLD_PROVIDER RECORDS INTO CIHOLD.NL_HOLD_PROVIDER TABLE*/

	proc sql;
    connect to oledb(init_string=&cihold.);
    execute
    (
		DECLARE @intErrorCode INT

		BEGIN TRAN
			INSERT INTO [dbo].[NL_HOLD_PROVIDER]
				(
					[WFLOW_EXEC_ID],
					[CLIENT_KEY],
					[VALIDATION_TYPE_ID],
					[PROVIDER_NAME],
					[PROVIDER_TITLE],
					[NETWORK_STATUS],
					[CI_STATUS],
					[CLNCL_INT_EFF_DT],
					[CLNCL_INT_EXP_DT],
					[NETWORK_EFF_DT],
					[NETWORK_EXP_DT],
					[DEA],
					[NPI1],
					[DATA_CMPLT_IND],
					[MANUAL_RPT_IND], 
					[LOAD_FLAG],
					[CREATED_ON],
					[CREATED_BY],
					[UPDATED_ON],
					[UPDATED_BY],
					[SAS_PROV_ID],
					[IS_ATTRIBUTABLE],
					[VSOURCE_PROVIDER_KEY],
					[IS_VSOURCE_DATA],
					[IS_PAYER_DATA],
					[DATA_SOURCE_ID]
				)
			SELECT 
				A.[WFLOW_EXEC_ID],
			ABS(A.[CLIENT_KEY]),
				A.[VALIDATION_TYPE_ID],
				A.[PROVIDER_NAME],
				A.[PROVIDER_TITLE],
				A.[NETWORK_STATUS],
				A.[CI_STATUS],
				A.[CLNCL_INT_EFF_DT],
				A.[CLNCL_INT_EXP_DT],
				A.[NETWORK_EFF_DT],
				A.[NETWORK_EXP_DT],
				A.[DEA],
				A.[NPI1],
				A.[DATA_CMPLT_IND],
				A.[MANUAL_RPT_IND], 
				A.[LOAD_FLAG],
				A.[CREATED_ON],
				A.[CREATED_BY],
				A.[UPDATED_ON],
				A.[UPDATED_BY],
				A.[SAS_PROV_ID],
				A.[IS_ATTRIBUTABLE],
				A.[VSOURCE_PROVIDER_KEY],
				A.[IS_VSOURCE_DATA],
				A.[IS_PAYER_DATA],
				A.[DATA_SOURCE_ID]
			FROM [dbo].[HOLD_PROVIDER] as A
			WHERE A.[LOAD_FLAG] = 0;

		

		IF (@intErrorCode <> 0) BEGIN
			ROLLBACK TRAN
		END

		COMMIT TRAN

	) by oledb;
	quit;

	%set_error_flag;
  	%on_error(ACTION=ABORT);


		/** UPDATE CIEDW.SPECIALTY TABLE - MOVED TO PROVIDER EXTRACT PROGRAM**/
/*		proc sql;*/
/*			connect to oledb(init_string=&vlink.);*/
/*		  	create table dw_specialty as select * from connection to oledb*/
/*			(	*/
/*				select */
/*					provspec					as specialty_code,*/
/*					provspecdesc				as specialty_description,*/
/*					getdate()	as created_on,*/
/*					'BPM - SAS'					as created_by,*/
/*					getdate()	as updated_on,*/
/*					'BPM - SAS'					as updated_by*/
/*				from dbo.vDWProvSpec*/
/*				order by provspec*/
/*			);*/
/*		quit;*/
/**/
/*		proc sql;*/
/*			connect to oledb(init_string=&ciedw.);*/
/*			create table dw_specialty_edw as select * from connection to oledb*/
/*			(*/
/*				select */
/*					SPECIALTY_CODE,*/
/*					SPECIALTY_DESCRIPTION,*/
/*					CREATED_ON,*/
/*					CREATED_BY,*/
/*					UPDATED_ON,*/
/*					UPDATED_BY*/
/*				from CIEDW.dbo.SPECIALTY*/
/*				order by SPECIALTY_CODE*/
/*			);*/
/*		quit;*/
/**/
/*		data dw_specialty_update;*/
/*		merge dw_specialty 		(in=a)*/
/*			  dw_specialty_edw 	(in=b keep=specialty_code);*/
/*		by specialty_code;*/
/*		if a and not b;*/
/*		run;*/
/**/
/*		proc sql;*/
/*			insert into ciedw.SPECIALTY*/
/*				(*/
/*				SPECIALTY_CODE,*/
/*				SPECIALTY_DESCRIPTION,*/
/*				CREATED_ON,*/
/*				CREATED_BY,*/
/*				UPDATED_ON,*/
/*				UPDATED_BY 			*/
/*				)*/
/*			select*/
/*				SPECIALTY_CODE,*/
/*				SPECIALTY_DESCRIPTION,*/
/*				CREATED_ON,*/
/*				CREATED_BY,*/
/*				UPDATED_ON,*/
/*				UPDATED_BY*/
/*			from dw_specialty_update;*/
/*		quit;*/



		/*SASDOC--------------------------------------------------------------------------
		| PULL EDW.PROVIDER.provider_key, FIND ALL CORRESPONDING SPECIALTIES FROM 
		|	vSOURCE, FIND SPECIALTY_KEY, DELETE CIEDW.PROVIDER_SPECIALTY_XREF,INSERT 
		|	AND UPDATE        
		+------------------------------------------------------------------------SASDOC*/ 
		proc sql;
		  connect to oledb(init_string=&ciedw.);
		  create table provider_key as select * from connection to oledb
		  (select distinct
				provider_key,
				vsource_provider_key
			from [dbo].[Provider]
			where client_key = &client_id.
			order by provider_key
		  );
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
		  connect to oledb(init_string=&vlink.);
		  create table provider_specialty as select * from connection to oledb
		  (select
				s.[ProviderID]								 as vsource_provider_key,
				s.[S-SpecialtyID]							 as specialty_code,
				case when s.[S-Primary] = 0 then s.[S-Primary]
					 else 1								 end as isPrimary
			from [dbo].[tblSpecialty] as s left outer join
				 [dbo].[tblProvider] as p on s.[ProviderID]=p.[ProviderID]
			where p.[ClientID] = &client_id.
		  );
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
		  connect to oledb(init_string=&ciedw.);
		  create table specialty_key_lookup as select * from connection to oledb
		  (select 
				[SPECIALTY_KEY],
				[SPECIALTY_CODE]
			from [dbo].[Specialty]
			order by [SPECIALTY_CODE]
		  );
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		proc sql;
		create table provider_specialty_xref as
		select 
			a.provider_key,
			c.specialty_key,
			b.isprimary
		from provider_key 			as a inner join
			 provider_specialty 	as b on a.vsource_provider_key=b.vsource_provider_key left outer join
			 specialty_key_lookup 	as c on b.specialty_code=c.specialty_code
		order by provider_key;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

/*		proc sql;*/
/*		  delete **/
/*		  from ciedw.provider_specialty_xref*/
/*		  where provider_key > 0;*/
/*		quit;*/

/*		%set_error_flag;*/
/*  	%on_error(ACTION=ABORT);*/

/*		proc sql;*/
/*		  insert into ciedw.provider_specialty_xref*/
/*			(*/
/*			provider_key,*/
/*			specialty_key,*/
/*			isprimary*/
/*			)*/
/*		  select */
/*			provider_key,*/
/*			specialty_key,*/
/*			isprimary*/
/*		  from provider_specialty_xref ;*/
/*		quit;*/

/*		%set_error_flag;*/
/*  	%on_error(ACTION=ABORT);*/

		proc sql;
		connect to oledb(init_string=&cihold);
		execute 
		(
			if exists
			(
				select *
				from sys.tables
				where name = %str(%')saswrk_provspec_&wflow_exec_id.%str(%') and schema_id = schema_id('dbo'))								

				drop table cihold.dbo.saswrk_provspec_&wflow_exec_id.;						
			)					
		by oledb;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);

		%bulkload_to_cio(m_wflow=&wflow_exec_id.,m_inputset=provider_specialty_xref);

		/*SASDOC--------------------------------------------------------------------------
		| FOR PRIMARY SPECIALTY - INSERT and UPDATE     
		+------------------------------------------------------------------------SASDOC*/ 

		proc sql;
        connect to oledb(init_string=&sqlci.);
        execute
        (
			DECLARE @intErrorCode INT
			BEGIN TRAN
			MERGE [CIEDW].[dbo].[PROVIDER_SPECIALTY_XREF] AS T
			USING 
				(SELECT *
				 FROM [CIHold].[dbo].[SASWRK_BULKLOAD_&wflow_exec_id.]
				 WHERE ISPRIMARY = 1) AS S
			ON (T.PROVIDER_KEY = S.PROVIDER_KEY AND
				T.ISPRIMARY = S.ISPRIMARY)
			WHEN NOT MATCHED BY TARGET THEN 
			INSERT
			( 
				[PROVIDER_KEY],
				[SPECIALTY_KEY],
				[ISPRIMARY]
			) 
			VALUES
			( 
				S.[PROVIDER_KEY],
				S.[SPECIALTY_KEY],
				S.[ISPRIMARY]
			) 
			WHEN MATCHED THEN UPDATE SET 
				T.[SPECIALTY_KEY] = S.[SPECIALTY_KEY]
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
		| FOR NON-PRIMARY SPECIALTY - INSERT ONLY     
		+------------------------------------------------------------------------SASDOC*/ 

		proc sql;
        connect to oledb(init_string=&sqlci.);
        execute
        (
			DECLARE @intErrorCode INT
			BEGIN TRAN
			MERGE [CIEDW].[dbo].[PROVIDER_SPECIALTY_XREF] AS T
			USING 
				(SELECT *
				 FROM [CIHold].[dbo].[SASWRK_BULKLOAD_&wflow_exec_id.]
				 WHERE ISPRIMARY <> 1) AS S
			ON (T.PROVIDER_KEY = S.PROVIDER_KEY AND
				T.SPECIALTY_KEY = S.SPECIALTY_KEY)
			WHEN NOT MATCHED BY TARGET THEN 
			INSERT
			( 
				[PROVIDER_KEY],
				[SPECIALTY_KEY],
				[ISPRIMARY]
			) 
			VALUES
			( 
				S.[PROVIDER_KEY],
				S.[SPECIALTY_KEY],
				S.[ISPRIMARY]
			) 
			;
			IF (@intErrorCode <> 0) BEGIN
				ROLLBACK TRAN
			END
			COMMIT TRAN
        ) by oledb;
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);


		proc sql;
		connect to oledb(init_string=&cihold);
			execute 
			(	
				drop table cihold.dbo.saswrk_bulkload_&wflow_exec_id.
			) 
			by oledb;
		quit;

		/*DELETE CIHOLD.HOLD_PROVIDER TABLE*/
		proc sql;
		  delete *
		  from cihold.hold_provider
		  where client_key in (&client_id.,-&client_id.);
		quit;

		%set_error_flag;
  		%on_error(ACTION=ABORT);


		*SASDOC--------------------------------------------------------------------------
		| PULL EDW.PROVIDER.provider_key, FIND ALL CORRESPONDING DEPARTMENTS FROM 
		|	vSOURCE, FIND DEPARTMENT_KEY, DELETE CIEDW.PROVIDER_DEPARTMENT_XREF, INSERT 
		|	ALL NEW RECORDS        
		+------------------------------------------------------------------------SASDOC*; 
		%edw_prov_dept_xref;

		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to complete.        
		+------------------------------------------------------------------------SASDOC*;
		%bpm_process_control(timevar=COMPLETE);	
		

%mend edw_provider_load;
%edw_provider_load;
