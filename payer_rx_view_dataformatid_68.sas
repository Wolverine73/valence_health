/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_rx_view_dataformatid_68.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: Extract payer pharmacy from VHSTAGE_PAYER.dbo.V_TCHP_PHARMACY_CLAIMS                                 
|           
| INPUT:                                     
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 05JUL2012 - Winnie Lee - Clinical Integration
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_rx_view_dataformatid_68;

	proc sql;
		connect to oledb(init_string=&vh_payer. readbuff=10000);
		create view payer_rx_view_&do_practice_id. as select * from connection to oledb
		(	select	*
			from	[VHSTAGE_PAYER].[dbo].[V_TCHP_PHARMACY_CLAIM] (nolock)
			where	batch_key = &batch_key.
		);
	quit;

%mend payer_rx_view_dataformatid_68;
