/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_rx_reversal_dataformat68.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE: Create reversal logic for TCHP                               
|           
| INPUT:                                        
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 09JUL2012 - Winnie Lee - Clinical Integration
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_rx_reversal_dataformat68 (m_payer_key, m_wflow_exec_id);
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table ciedw_rx (index = (tablekey = (person_system_key rx_fill_date ndc_key is_reversal))) as
			select	*
			from	connection to oledb
					(	select	rx.person_pharmacy_key, p.person_system_key, rx.rx_fill_date, rx.ndc_key, rx.is_reversal
						from	ciedw.dbo.person_pharmacy rx inner join 
								ciedw.dbo.person p on rx.person_key=p.person_key and rx.payer_key = &m_payer_key.
						where	ndc_key is not null
					)
		;
	quit;
	%set_error_flag;
  	%on_error(ACTION=ABORT);

	data ciedw_rx_pos (index = (tablekey = (person_system_key rx_fill_date ndc_key dupcnt)))
		 ciedw_rx_neg (index = (tablekey = (person_system_key rx_fill_date ndc_key dupcnt)));
		set ciedw_rx;
		by person_system_key rx_fill_date ndc_key is_reversal;
		if first.is_reversal then dupcnt = 1;
		else dupcnt + 1;
		if is_reversal = 0 then output ciedw_rx_pos;
		else output ciedw_rx_neg;
	run;

	proc sql;
		create table ciedw_rx_flip_deleted as
			select	
				pos.person_pharmacy_key
			from	ciedw_rx_pos pos, 
					ciedw_rx_neg neg 
			where	pos.person_system_key=neg.person_system_key
			and		pos.rx_fill_date=neg.rx_fill_date
			and		pos.ndc_key=neg.ndc_key
			and		pos.dupcnt=neg.dupcnt
		;
	quit;

	%bulkload_to_cio(&m_wflow_exec_id.,ciedw_rx_flip_deleted);
	%set_error_flag;
  	%on_error(ACTION=ABORT);

	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update	ciedw.dbo.person_pharmacy
					set		is_deleted = 1, 
							updated_wflow_exec_id = &m_wflow_exec_id., 
							updated_on = getdate(), 
							updated_by = 'payer reversal'
					from	ciedw.dbo.person_pharmacy a, 
							cihold.dbo.saswrk_bulkload_&m_wflow_exec_id. b
					where	a.person_pharmacy_key=b.person_pharmacy_key
				)
		by oledb;
	quit;
	%set_error_flag;
  	%on_error(ACTION=ABORT);

	%if %sysfunc(exist(cihold.saswrk_bulkload_&m_wflow_exec_id.)) %then %do; 
		proc sql; 
			drop table cihold.saswrk_bulkload_&m_wflow_exec_id.; 
		quit; 
	%end;
%mend payer_rx_reversal_dataformat68;
