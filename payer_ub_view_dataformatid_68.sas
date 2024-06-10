/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_ub_view_dataformatid_68.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: 	Extract TCHP Payer UB from VHSTAGE_PAYER.dbo.V_TCHP_MEDICAL_CLAIMS_UB
|           
| INPUT:    VH_STAGE_PAYER TCHP_MEDICAL table, UB claims                                 
|
| OUTPUT:        
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 27JUN2012 - G Liu - Clinical Integration Release 1.4.01 TCHP
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_ub_view_dataformatid_68(m_batch_key,m_datasource_id);
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create view payer_ub_view as 
		select 	* 
		from 	connection to oledb
				(	select	*
					from	vhstage_payer.dbo.v_tchp_medical_claim_ub
					where	batch_key = &m_batch_key.
				);
	quit;
	
	data payer_ub_data(drop=date_of_birth service_date admission_date discharge_date pddt chkdt
					   rename=(revenue_code=revcd discharge_status=dis_cond
							   admitting_diagnosis_code=admdiag major_category=majcat sub_major_category=subcat
							   diagnosis_code_1=diag1 diagnosis_code_2=diag2 diagnosis_code_3=diag3 diagnosis_code_4=diag4 diagnosis_code_5=diag5
							   diagnosis_code_6=diag6 diagnosis_code_7=diag7 diagnosis_code_8=diag8 diagnosis_code_9=diag9
							   surgical_code_1=surg1 surgical_code_2=surg2 surgical_code_3=surg3 surgical_code_4=surg4 surgical_code_5=surg5 surgical_code_6=surg6							   
						));
		set payer_ub_view(rename=(claimnumber=claimnum line_number=linenum claim_source_unique_id=maxprocessid
								  procedure_code=proccd mod_1=mod1 mod_2=mod2 dob=date_of_birth
								  paid_date=pddt check_date=chkdt));
		dob=input(date_of_birth,yymmdd10.);
		memberid=ssn;
		svcdt=input(service_date,yymmdd10.);
		admdt=input(admission_date,yymmdd10.);
		disdt=input(discharge_date,yymmdd10.);
		paid_date=input(pddt,yymmdd10.);
		check_date=input(chkdt,yymmdd10.);
		sbdate=admission_date;
		sedate=discharge_date;
		start_date=.;
		moddt=paid_date;
		filedt=.; filed='';
		practice_id=&m_datasource_id.;
		provname='';
		payorid1=''; payorname1='TCHP';
		submit=billed_amt;
	run;
%mend payer_ub_view_dataformatid_68;
