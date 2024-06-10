/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_rx_view_dataformatid_67.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: Extract payer pharmacy from VHSTAGE_PAYER.dbo.V_MMO_PHARMACY_CLAIMS                                 
|           
| INPUT:                                     
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 03JUN2012 - Winnie Lee - Clinical Integration Release v1.3.H01
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_rx_view_dataformatid_67;

	proc sql;
		connect to oledb(init_string=&vh_payer. readbuff=10000);
		create table payer_rx_view_&do_practice_id. as select * from connection to oledb
		(	select	*
			from	[VHSTAGE_PAYER].[dbo].[V_MMO_PHARMACY_CLAIM]
			where	batch_key = &batch_key.
		);
	quit;
	data payer_rx_view_&do_practice_id.;
		set payer_rx_view_&do_practice_id.;
		if substr(zip,6,5)='-0000' then zip=substr(zip,1,5);
		else if substr(zip,6,1)='-' then zip=substr(zip,1,5)||substr(zip,7);
		else zip=zip;
	run;

%mend payer_rx_view_dataformatid_67;
