/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_hcfa_view_dataformatid_68.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: 	Extract TCHP Payer HCFA from VHSTAGE_PAYER.dbo.V_TCHP_MEDICAL_CLAIMS_HCFA
|           
| INPUT:    VH_STAGE_PAYER TCHP_MEDICAL table, HCFA claims                                
|
| OUTPUT:        
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 05JUL2012 - G Liu - Clinical Integration Release 1.4.01 TCHP
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_hcfa_view_dataformatid_68(m_batch_key,m_datasource_id);
	proc sql;
		connect to oledb(init_string=&vh_payer. readbuff=10000);
		create view payer_hcfa_view as 
		select 	* 
		from 	connection to oledb
				(	select	*
					from	[VHSTAGE_PAYER].[dbo].[V_TCHP_MEDICAL_CLAIM_HCFA]
					where	batch_key = &m_batch_key.
				);
	quit;

	data payer_hcfa_data(drop=date_of_birth service_date pddt chkdt
						rename=(major_category=majcat sub_major_category=subcat
								diagnosis_code_1=diag1 diagnosis_code_2=diag2 diagnosis_code_3=diag3 diagnosis_code_4=diag4 diagnosis_code_5=diag5
							    diagnosis_code_6=diag6 diagnosis_code_7=diag7 diagnosis_code_8=diag8 diagnosis_code_9=diag9
						));
		set payer_hcfa_view(rename=(claimnumber=claimnum line_number=linenum claim_source_unique_id=maxprocessid
									procedure_code=proccd mod_1=mod1 mod_2=mod2 dob=date_of_birth
									paid_date=pddt check_date=chkdt));
		dob=input(date_of_birth,yymmdd10.);
		memberid=ssn;
		svcdt=input(service_date,yymmdd10.);
		paid_date=input(pddt,yymmdd10.);
		check_date=input(chkdt,yymmdd10.);
		filed='';
		practice_id=&m_datasource_id.;
		payorname1='TCHP';
		practice_id=&m_datasource_id.;
		submit=billed_amt;
	run;
%mend payer_hcfa_view_dataformatid_68;
