/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  prov_attr_view_dataformatid_68.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: Extract provider attributes from VHSTAGE_PAYER.dbo.V_TCHP_PROVIDER_ATTRIBUTES                                 
|           
| INPUT:                                     
|
| OUTPUT:                           
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 26JUN2012 - Winnie Lee - Clinical Integration Release v1.4
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro prov_attr_view_dataformatid_68;

/* GET PARENT ATTRIBUTE IF EXIST TO COMPARE TO TARGET TABLE */
	proc sql;
		connect to oledb(init_string=&vh_payer. readbuff=10000);
		create view prov_attr_view_&practice_id. as select * from connection to oledb
		(select	DISTINCT
		        table1.DATA_SOURCE_ID
			  , table1.BATCH_KEY
			  , table1.VHSTAGE_SOURCE_KEY
			  , table1.VHSTAGE_PARENT_SOURCE_KEY
			  , table1.CLIENT_KEY
			  , table1.SYSTEM_PROVIDER_ID
			  ,  coalesce(parent.attribute_value,'0') as parent_attribute_value	   
			  , table1.NPI
			  , table1.SYSTEM_PRACTICE_ID
			  , table1.TIN
			  , table1.ATTRIBUTE_TYPE_KEY
			  , table1.ATTRIBUTE_VALUE
			  , table1.EFFECTIVE_DATE
			  , table1.TERMINATION_DATE
			from	[VHSTAGE_PAYER].[dbo].[V_TCHP_PROVIDER_ATTRIBUTES] table1 
			left outer join VHSTAGE_PAYER.dbo.V_TCHP_PROVIDER_ATTRIBUTES parent
			on parent.VHSTAGE_SOURCE_KEY = table1.vhstage_parent_source_key
			where	table1.data_source_id = &practice_id. and table1.batch_key = &batch_key.
		);
	quit;

%mend prov_attr_view_dataformatid_68;
