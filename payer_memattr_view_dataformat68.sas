%macro payer_memattr_view_dataformat68(m_batch_key);
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create view payer_member_attribute as
		select	system_member_id, attribute_type_key, attribute_value, 
				input(effective_date,yymmdd10.) as effective_date, input(termination_date,yymmdd10.) as termination_date
		from	connection to oledb
				(	select	system_member_id, attribute_type_key, attribute_value, effective_date, termination_date
					from	vhstage_payer.dbo.v_tchp_member_attributes
					where	batch_key=&m_batch_key.
				)
		order by system_member_id, attribute_type_key, attribute_value, effective_date, termination_date
		;
	quit;
%mend payer_memattr_view_dataformat68;
