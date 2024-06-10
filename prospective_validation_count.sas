
/*HEADER----------------------------------------------------------------------------------------
|
| program:  prospective_validation_count.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Give counts on Prospective Data Set Output
+------------------------------------------------------------------------------------------------
| *HISTORY:  
| 07SEP2012 - LS Original Program: This macro is designed for the CIO Prospective Process.
|			  Everytime a Client has a prospective run the distinct member_key/condition or member_key/care_element
|			  counts will be compared to the prior run.  This will help in the validation step of pushing from
|			  stage to production.
| HISTORY*
+-------------------------------------------------------------------------------------------------*/
%let dmart = %str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=dmart1prd;Initial Catalog=DM_&client.;" ); 

%macro prospective_validation_count;

	proc sql noprint;
	connect to oledb(init_string=&dmart.);
	create table prior_ce as select * from 
		(select * from connection to oledb  
			(select * from dbo.care_elements 
				where client_key = &client_key. 
				and portal_display = 1))
					order by member_key , care_element;
	disconnect from oledb;
	quit;

	proc sql noprint;
	connect to oledb(init_string=&dmart.);
	create table prior_registry as select * from 
		(select * from connection to oledb  
			(select * from dbo.registry 
				where client_key = &client_key.
				and display = 1 ))
					order by member_key , condition ;
	disconnect from oledb;
	quit;

	proc sql;
	create table current_registry as select * from registry.registry_final
	where display = 1 
	order by member_key, condition;
	quit;

	proc sql;
	create table current_ce as select * from registry.prospective_Final
	where portal_display = 1
	order by member_key, care_element;
	quit;

	data inboth_reg
		inoldnotnew_reg
		innewnotold_reg;
	merge prior_registry (in = a) current_registry (in = b);
	by member_key condition;
	if a and b then output inboth_reg;
	else if a and not b then output inoldnotnew_reg;
	else if b and not a then output innewnotold_reg;
	run;

	data inboth_ce
		inoldnotnew_ce
		innewnotold_ce;
	merge prior_ce (in = a) current_ce (in = b);
	by member_key care_element;
	if a and b then output inboth_ce;
	else if a and not b then output inoldnotnew_ce;
	else if b and not a then output innewnotold_ce;
	run;

	proc sql noprint;
	select count(*) into: current_reg from current_registry;
	select count(*) into: prior_reg from prior_registry;
	select count(*) into: current_ce from current_ce;
	select count(*) into: prior_ce from prior_ce;
	select count(*) into: reg_gain from innewnotold_reg;
	select count(*) into: reg_loss from inoldnotnew_reg;
	select count(*) into: ce_gain from innewnotold_ce;
	select count(*) into: ce_loss from inoldnotnew_ce;
	quit;

	
	data update_log;
	length clientid $30. run_date $9. is_incremental $3.;
	clientid = "&client." ;
	run_date = substr(&p_enddt.,1,9);
	is_incremental = "&update.";
	Current_Registry_Cnt = &current_reg.;
	Prior_Registry_Cnt = &prior_reg.;
	Registry_gain = &reg_gain.;
	Registry_loss = &reg_loss.;
	Current_CE_Cnt = &current_ce.;
	Prior_CE_Cnt = &prior_ce.;
	CE_gain = &ce_gain.; 
	CE_loss = &ce_loss.;
	run;


	proc sql noprint;
	insert into control.Prospective_Count_Check
	select distinct clientid, run_date, is_incremental, Current_Registry_Cnt,Prior_Registry_Cnt, Registry_gain,
					Registry_loss, Current_CE_Cnt, Prior_CE_Cnt,CE_gain,CE_loss from update_log;
	quit;

%mend prospective_validation_count;
