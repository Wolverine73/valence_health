/* Identify whether a client key has any DataSourceID that is client's EMPI
   If client has no EMPI, both output global macro variables will be set to 0

	Input  - parameter: m_client_id = client key
	Output - global macro variable: client_with_empi_indicator and empi_datasource_id
*/
%macro client_empi_check(m_client_id);
	%global client_with_empi_indicator empi_datasource_id;
	%let client_with_empi_indicator=0;
	%let empi_datasource_id=0;
	proc sql noprint;
		select	DataSourceID, count(*)
		into	:empi_datasource_id, :client_with_empi_indicator
		from	ids.datasource a left join
				ids.dataformattogroup b on a.DataFormatID=b.DataFormatID
		where	a.clientid=&m_client_id.
		and		b.DataFormatGroupID=5
		group by 1
		having	DataSourceID=min(DataSourceID);
	quit;

	%let client_with_empi_indicator=&client_with_empi_indicator.;
	%let empi_datasource_id=&empi_datasource_id.;

	%put NOTE: Client with EMPI indicator = &client_with_empi_indicator.;
	%put NOTE: Client EMPI DataSourceID = &empi_datasource_id.;
%mend client_empi_check;
