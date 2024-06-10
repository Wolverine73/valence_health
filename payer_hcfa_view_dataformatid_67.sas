/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_hcfa_view_dataformatid_67.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: 	Extract MMO Payer HCFA from VHSTAGE_PAYER.dbo.V_MMO_MEDICAL_CLAIMS_HCFA
|           
| INPUT:    VH_STAGE_PAYER MMO_MEDICAL table, HCFA claims                                
|
| OUTPUT:        
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 13JUN2012 - G Liu - Clinical Integration Release 1.3.01 H01
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_hcfa_view_dataformatid_67(m_batch_key,m_datasource_id);
	proc sql;
		connect to oledb(init_string=&vh_payer. readbuff=10000);
		create view payer_hcfa_view as 
		select 	* 
		from 	connection to oledb
				(	select	*
					from	[VHSTAGE_PAYER].[dbo].[V_MMO_MEDICAL_CLAIM_HCFA]
					where	batch_key = &m_batch_key.
				);
	quit;

	data payer_hcfa_data(drop=date_of_birth service_begin_date
						rename=(diagnosis_code_1=diag1 diagnosis_code_2=diag2 diagnosis_code_3=diag3 diagnosis_code_4=diag4 diagnosis_code_5=diag5));
		set payer_hcfa_view(rename=(claimnumber=claimnum line_number=linenum claim_source_unique_id=maxprocessid
									procedure_code=proccd mod_1=mod1 mod_2=mod2 dob=date_of_birth));
		memberid=ssn;
		dob=input(date_of_birth,yymmdd10.);
		if substr(zip,6,5)='-0000' then zip=substr(zip,1,5);
		else if substr(zip,6,1)='-' then zip=substr(zip,1,5)||substr(zip,7);
		else zip=zip;

		svcdt=input(service_begin_date,yymmdd10.);
		mod1=compress(mod1,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','k');
		mod2=compress(mod2,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','k');
		filed='';

		practice_id=&m_datasource_id.;
	run;
%mend payer_hcfa_view_dataformatid_67;
