/* TCHP member and member eligibility view 
	For requirements, see edw_member_extract.sas header
*/
%macro payer_member_view_dataformat68(m_batch_key);
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table payer_member_and_elig as
		select	system_member_id, 
				ssn, fname, mname, lname, sex, input(dob,yymmdd10.) as dob,
				address1, address2, city, state, zip, county, phone, race,
				input(enrollment_eff_date,yymmdd10.) as elig_effective_date, input(enrollment_term_date,yymmdd10.) as elig_termination_date,
				product as product_type, plan_code,
				relationship_code as relationship_code_pfkey,
				case when rx_eligibility_ind='Y' then 1
					 when rx_eligibility_ind='N' then 0
					 else .
				end as is_drug_eligible
		from	connection to oledb
				(	select	*
					from	vhstage_payer.dbo.v_tchp_member
					where	batch_key=&m_batch_key.
				)
		;
	quit;
%mend payer_member_view_dataformat68;
