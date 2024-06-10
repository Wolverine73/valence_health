 
%macro bpm_additional_validations(validation_rule=,validation_count=);

	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute ( 
					insert into [BPMMetaData].[dbo].[VALIDATIONS]
					(
						wflow_exec_id, 
						sk_prcs_ctrl_id,
						vld_value, 
						validation_type_id, 
						acceptable, 
						created_on, 
						created_by, 
						updated_on, 
						updated_by
					)
					values
					(	
						&wflow_exec_id., 
						&sk_prcs_ctrl_id., 
						&validation_count., 
						&validation_rule., 
						0, 
						getdate(), 
						'BPM - SAS', 
						getdate(), 
						'BPM - SAS'
					)
				)
		by oledb;
	quit;

%mend bpm_additional_validations;
