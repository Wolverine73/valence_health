
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_provprac_attr_load.sas
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
| HISTORY:  28JUN2012 - Winnie Lee - Original
|   
+-----------------------------------------------------------------------HEADER*/

/*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
/*options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos); */

*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
+------------------------------------------------------------------------SASDOC*; 
/*%let sysparm=%str(sk_prcs_ctrl_id=10057 wflow_exec_id=48883 sas_prgm_id=50 client_id=6 sas_mode=test practice_id=1332 batch_key=1); */

/*%bpm_environment;*/

%macro edw_provprac_attribute_load();

	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.        
	+-------------------------------------------------------------------------SASDOC*/ 
	%bpm_process_control(timevar=START);
	options nomlogic nomprint; 
		
	/*SASDOC--------------------------------------------------------------------------
	| TABLE: PROVIDER_PRACTICE_ATTRIBUTE PARENT ATTRIBUTES 
	| DESC: PASS THROUGH SQL to INSERT WHEN AN EXISTING RECORD DOES NOT EXIST
	| 		OR UPDATE EDW.PROVIDER_PRACTICE_ATTRIBUTE TABLE WHEN RECORD EXISTS.
	|       - LOAD THE PARENT ATTRIBUTE RECORDS THEN LOAD CHILD ATTRIBUTES ALLOWING 
	|         THE CHILD RECORD TO CONTAIN THE PARENT KEY
	+-------------------------------------------------------------------------SASDOC*/ 
	proc sql;
	connect to oledb(init_string=&sqlci.);
	create table row_count as select * from connection to oledb
	(
		DECLARE @intErrorCode INT
		BEGIN TRAN

		MERGE CIEDW.dbo.PROVIDER_PRACTICE_ATTRIBUTE AS TGT
		USING 
		(				  
	     select distinct 
		        prov_prctc_xref_key
			  , ATTRIBUTE_TYPE_KEY
			  , ATTRIBUTE_VALUE
			  , effective_date
			  , termination_date
			  , created_wflow_exec_id
			  , created_On
			  , created_by
			  , updated_wflow_exec_id
			  , updated_on
			  , updated_by
		   from cihold.dbo.saswrk_provprac_attr_&wflow_exec_id.
		  where ATTRIBUTE_TYPE_KEY = 5 and load_flag = 1
		) AS SRC ON (TGT.prov_prctc_xref_key = SRC.prov_prctc_xref_key and 
					 TGT.attribute_type_key  = SRC.attribute_type_key and
					 TGT.attribute_value 	 = SRC.attribute_value and
					 TGT.effective_date 	 = SRC.effective_date)
		WHEN NOT MATCHED THEN 
			INSERT
			(     
				prov_prctc_xref_key,
				attribute_type_key,
				attribute_value,
				effective_date,
				termination_date,
				created_wflow_exec_id,
				created_on,
				created_by,
				updated_wflow_exec_id,
				updated_on,
				updated_by
			)
		 	VALUES 
			(   
				SRC.prov_prctc_xref_key,
				SRC.attribute_type_key,
				SRC.attribute_value,
				SRC.effective_date,
				SRC.termination_date,
				SRC.created_wflow_exec_id,
				SRC.created_on,
				SRC.created_by,
				SRC.updated_wflow_exec_id,
				SRC.updated_on,
				SRC.updated_by
			)
		WHEN MATCHED THEN 
			UPDATE SET
			  TGT.termination_date 		= SRC.termination_date
			, TGT.updated_wflow_exec_id = SRC.updated_wflow_exec_id
			, TGT.updated_on 			= SRC.updated_on
			, TGT.updated_by 			= SRC.updated_by 
		;
		SELECT @@ROWCOUNT ;
		IF (@intErrorCode <> 0) BEGIN
			ROLLBACK TRAN
		END
		COMMIT TRAN
    );
		quit;		
		
		/* DISPLAY SQL RESULT ROWCOUNT */
			DATA _NULL_;
				set row_count;
				call symput('row_count',exprssn);
			RUN;

			 %put;%put &row_count PARENT ATTRIBUTE RECORDS EVALUATED FOR THE CIEDW.dbo.PROVIDER_PRACTICE_ATTRIBUTE MERGE;%put; 
			 
			%set_error_flag
			%on_error(ACTION=ABORT) 
			
	/* PROVIDER_PRACTICE_ATTRIBUTE CHILD ATTRIBUTES */
	
	proc sql;
	connect to oledb(init_string=&sqlci.);
	create table row_count as select * from connection to oledb
	(
		DECLARE @intErrorCode INT
		BEGIN TRAN

		MERGE CIEDW.dbo.PROVIDER_PRACTICE_ATTRIBUTE AS TGT
		USING 
		(				  
			select distinct source.prov_prctc_xref_key
				  , target.prov_prctc_attribute_key AS PARENT_PROV_PRCTC_ATTRIBUTE_KEY
				  , source.ATTRIBUTE_TYPE_KEY
				  , source.ATTRIBUTE_VALUE
				  , source.effective_date
				  , source.termination_date
				  , source.created_wflow_exec_id
				  , source.created_On
				  , source.created_by
				  , source.updated_wflow_exec_id
				  , source.updated_on
				  , source.updated_by 
			   FROM cihold.dbo.saswrk_provprac_attr_&wflow_exec_id. source
			  INNER JOIN 
					cihold.dbo.saswrk_provprac_attr_&wflow_exec_id. parent
				 ON source.VHSTAGE_PARENT_SOURCE_KEY = parent.vhstage_payer_src_key
			  INNER JOIN 
					CIEDW.dbo.PROVIDER_PRACTICE_ATTRIBUTE           target
				 ON source.prov_prctc_xref_key = target.prov_prctc_xref_key
				AND parent.attribute_value     = target.attribute_value
				AND source.effective_date between target.effective_date AND target.TERMINATION_DATE
				AND target.PARENT_PROV_PRCTC_ATTRIBUTE_KEY  IS NULL  /* PARENT or target.ATTRIBUTE_TYPE_KEY = 5 */
				AND source.VHSTAGE_PARENT_SOURCE_KEY IS NOT NULL     /* child  or source.ATTRIBUTE_TYPE_KEY in (1,2,3,4) */
			) AS SRC ON (TGT.prov_prctc_xref_key      			= SRC.prov_prctc_xref_key and 
						 TGT.attribute_type_key       			= SRC.attribute_type_key and
						 TGT.attribute_value 	      			= SRC.attribute_value and
						 TGT.PARENT_PROV_PRCTC_ATTRIBUTE_KEY 	= SRC.PARENT_PROV_PRCTC_ATTRIBUTE_KEY AND
						 TGT.effective_date 	      			= SRC.effective_date)
			WHEN NOT MATCHED THEN 
				INSERT
				(     
					prov_prctc_xref_key,
					PARENT_PROV_PRCTC_ATTRIBUTE_KEY,
					attribute_type_key,
					attribute_value,
					effective_date,
					termination_date,
					created_wflow_exec_id,
					created_on,
					created_by,
					updated_wflow_exec_id,
					updated_on,
					updated_by
				)
				VALUES 
				(   
					SRC.prov_prctc_xref_key,
					SRC.PARENT_PROV_PRCTC_ATTRIBUTE_KEY,
					SRC.attribute_type_key,
					SRC.attribute_value,
					SRC.effective_date,
					SRC.termination_date,
					SRC.created_wflow_exec_id,
					SRC.created_on,
					SRC.created_by,
					SRC.updated_wflow_exec_id,
					SRC.updated_on,
					SRC.updated_by
				)
			WHEN MATCHED THEN 
				UPDATE SET
				  TGT.termination_date 		= SRC.termination_date
				, TGT.updated_wflow_exec_id = SRC.updated_wflow_exec_id
				, TGT.updated_on 			= SRC.updated_on
				, TGT.updated_by 			= SRC.updated_by 
			;

		SELECT @@ROWCOUNT ;
		IF (@intErrorCode <> 0) BEGIN
			ROLLBACK TRAN
		END
		COMMIT TRAN
    );
	quit;
	
		/* DISPLAY SQL RESULT ROWCOUNT */
			DATA _NULL_;
				set row_count;
				call symput('row_count',exprssn);
			RUN;

			 %put;%put &row_count CHILD ATTRIBUTE RECORDS EVALUATED FOR THE CIEDW.dbo.PROVIDER_PRACTICE_ATTRIBUTE MERGE;%put; 
			  
			%set_error_flag
			%on_error(ACTION=ABORT) 
		
	/*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+-------------------------------------------------------------------------SASDOC*/
	%bpm_process_control(timevar=COMPLETE);
		

%mend edw_provprac_attribute_load;
