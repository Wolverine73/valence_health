/* program that calls this macro: 
	edw_linking.sas
	edw_member_error.sas
	edw_empi_load.sas
*/
%macro empi_all_patient_key(m_outset,m_client_id=0,m_datasource_id=0);
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table &m_outset. as
		select	*
		from	connection to oledb
			(	select	patient_key
				from	vh_empi.dbo.patient(nolock)
				where	1=1
			  %if &m_client_id. ne 0 %then %do;
				and 	client_key=&m_client_id.
			  %end;
			  %if &m_datasource_id. ne 0 %then %do;
				and		convert(int,substring(right('0000000000000000' + ltrim(rtrim(CONVERT(char(16), patient_key))), 16),3,6))=&m_datasource_id.
			  %end;
			);
	quit;
%mend empi_all_patient_key;
