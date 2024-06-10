/* MMO member and eligibility view
	For requirements, see edw_member_extract.sas header
*/
%macro payer_member_view_dataformat67(m_batch_key);
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table payer_member_and_elig as
		select	system_member_id, 
				ssn, fname, mname, lname, sex, input(dob,yymmdd10.) as dob,
				address1, address2, city, state, 
				/* Since CCCPP already has a lot of data, and we always keep only 5-digit zip for CI data,
					even though payer data has -0000, it adds no value to our EMPI database, so, we scrub
					these variation of zip codes here. */
				case when substr(zip,6,5)='-0000' then substr(zip,1,5)
					 when substr(zip,6,1)='-' then substr(zip,1,5)||substr(zip,7)
					 else zip end as zip, 
				phone,
				subscriber_ssn, input(enrollment_eff_date,yymmdd10.) as elig_effective_date, input(enrollment_term_date,yymmdd10.) as elig_termination_date,
				employer_name, scan(employer_name,-1,'[]') as employer_id, product as product_type, policy_number, 
				case when rx_eligibility_ind='Y' then 1
					 when rx_eligibility_ind='N' then 0
					 else .
				end as is_drug_eligible, 
				relationship_code . as relationship_code_pfkey
		from	connection to oledb
				(	select	*
					from	vhstage_payer.dbo.v_mmo_member
					where	batch_key=&m_batch_key.
				);
	quit;
%mend payer_member_view_dataformat67;
