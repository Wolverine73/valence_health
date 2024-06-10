/*HEADER------------------------------------------------------------------------
|
| program:  vitals_claims_query.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Macro to pull down EDW V_GUIDELINE_INPUT_VITAL for each client.
|
+--------------------------------------------------------------------------------
| *HISTORY:  
| 14SEP2012 - EM original
| HISTORY*  
+-----------------------------------------------------------------------HEADER*/

%macro vitals_claims_query;
	%let ciedw  =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=CIEDW;"); 
	libname ciedw   oledb init_string=&ciedw.  	preserve_tab_names=yes insertbuff=10000 readbuff=10000;	

	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table edw_vitals as
			select	 CLIENT_KEY format 3.
					,MEMBER_KEY format 16. length 8 as memberid
					,DATA_SOURCE_ID format 3.
					,datepart(SVCDT2) format mmddyy10. length 4 as svcdt 
					,SBP format 3.
					,SBP_OOR format 3.
					,DBP format 3.
					,DBP_OOR format 3.
					,PULSE format 3.
					,PULSE_OOR format 3.
					,WEIGHT format 7.2
					,WEIGHT_OOR format 3.
					,HEIGHT format 7.2
					,HEIGHT_OOR format 3.
					,BMI format 7.2
					,BMI_OOR format 3.
					,TEMPERATURE format 7.2
					,TEMPERATURE_OOR format 3.
					,RESPIRATIONS format 3.
					,RESPIRATIONS_OOR format 3.
					,O2_SATURATION format 7.2
					,O2_SATURATION_OOR format 3.
					,SBP_SIT format 3.
					,SBP_SIT_OOR format 3.
					,DBP_SIT format 3.
					,DBP_SIT_OOR format 3.
					,SBP_STAND format 3.
					,SBP_STAND_OOR format 3.
					,DBP_STAND format 3.
					,DBP_STAND_OOR format 3.
					,ENCOUNTER_TYPE
					,EM_FLAG format 3.
					,PROVID
					,datepart(LAST_MOD_DATE) format mmddyy10. length 4 as LAST_MOD_DATE
				from
					(select * from connection to oledb
						(select  CLIENT_KEY
								,MEMBER_KEY
								,DATA_SOURCE_ID
								,SVCDT2
								,SBP
								,SBP_OOR
								,DBP
								,DBP_OOR
								,PULSE
								,PULSE_OOR
								,WEIGHT
								,WEIGHT_OOR
								,HEIGHT
								,HEIGHT_OOR
								,BMI
								,BMI_OOR
								,TEMPERATURE
								,TEMPERATURE_OOR
								,RESPIRATIONS
								,RESPIRATIONS_OOR
								,O2_SATURATION
								,O2_SATURATION_OOR
								,SBP_SIT
								,SBP_SIT_OOR
								,DBP_SIT
								,DBP_SIT_OOR
								,SBP_STAND
								,SBP_STAND_OOR
								,DBP_STAND
								,DBP_STAND_OOR
								,ENCOUNTER_TYPE
								,EM_FLAG
								,PROVID
								,LAST_MOD_DATE
									from dbo.V_GUIDELINE_INPUT_VITAL
										where (	client_key = &client_key.
												and last_mod_date >= &p_stdt.
												and member_key not in (-99))
										order by member_key
												,svcdt2
						)
					);
		disconnect from oledb;
	quit; 

%mend;
