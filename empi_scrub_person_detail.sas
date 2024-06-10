/* Currently we do not use mname, address2, or address3 for linking. So, not scrubbing those columns. 
	We haven't developed any scrubbing logic anyway. 
*/

/* wflow_exec_id is solely used for bulkloading to a unique temporary table in cihold */
%macro empi_scrub_person_detail(m_client_id,m_wflow_exec_id,m_inset=);
%if %sysfunc(exist(espd_pending_to_scrub)) %then %do; proc sql; drop table espd_pending_to_scrub; quit; %end;
proc sql;
	connect to oledb(init_string=&sqlci.);
	create table espd_pending_to_scrub as
	select	person_detail_key, 
			ssn, fname, lname, sex, input(dob,yymmdd10.) format yymmdd10. as dob, address1, city, state, zip, phone
	from	connection to oledb
			(	select	person_detail_key, 
						ssn, fname, lname, sex, dob, address1, city, state, zip, phone
				from	vh_empi.dbo.person_detail(nolock)
				where	client_key=&m_client_id.
				and		scrubbed_flag=0
			);
quit;

%let ds_id=%sysfunc(open(espd_pending_to_scrub));
%let ds_obs=%sysfunc(attrn(&ds_id.,nobs));
%let ds_rc=%sysfunc(close(&ds_id.));

%if &ds_obs. %then %do;
	proc format cntlin=fmt.NickName; 
	proc format cntlin=fmt.fnameGender; 
	proc format cntlin=fmt.zipcodes; 
	proc format cntlin=fmt.cio_zipcode;
	proc format cntlin=fmt.cio_cityalias; run;

	%if %sysfunc(exist(espd_scrubbed_person_detail)) %then %do; proc sql; drop table espd_scrubbed_person_detail; quit; %end;
	data espd_scrubbed_person_detail(keep=person_detail_key scrubbed:);
		set espd_pending_to_scrub(rename=(dob=memdob));
		%ssntest; if ssnTYPE = "VALID" then; else ssn='';
		%edw_linking_cleaner_fls();
		/* scrubbing cannot be dependent on svcdt, so, use the "mem" version */
		%edw_linking_cleaner_dob(mem);
		%edw_linking_cleaner_addr();
		%edw_linking_cleaner_cityzip();
		%edw_linking_cleaner_state();
		%edw_linking_cleaner_phone();
		rename 	ssn=scrubbed_ssn fname=scrubbed_fname lname=scrubbed_lname sex=scrubbed_sex memdob=scrubbed_dob
				address1=scrubbed_address1 city=scrubbed_city state=scrubbed_state zip=scrubbed_zip phone=scrubbed_phone;
	run;

	%bulkload_to_cio(&m_wflow_exec_id.,espd_scrubbed_person_detail);

	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update vh_empi.dbo.person_detail
					set		scrubbed_flag=1,
							scrubbed_ssn=b.scrubbed_ssn, 
							scrubbed_fname=b.scrubbed_fname, 
							scrubbed_lname=b.scrubbed_lname,
							scrubbed_sex=b.scrubbed_sex,
							scrubbed_dob=b.scrubbed_dob,
							scrubbed_address1=b.scrubbed_address1,
							scrubbed_city=b.scrubbed_city,
							scrubbed_state=b.scrubbed_state,
							scrubbed_zip=b.scrubbed_zip,
							scrubbed_phone=b.scrubbed_phone,
							scrubbed_on=getdate()
					from	vh_empi.dbo.person_detail a, cihold.dbo.saswrk_bulkload_&m_wflow_exec_id. b
					where	a.person_detail_key=b.person_detail_key
				)
		by oledb;

		execute (	drop table cihold.dbo.saswrk_bulkload_&m_wflow_exec_id.
				)
		by oledb;
	quit;
%end;

%if %quote(&m_inset) ne %then %do;
	proc sql;
		create table espd_person_detail as
		select	distinct person_detail_key
		from	&m_inset.;
	quit;
	%bulkload_to_cio(&m_wflow_exec_id.,espd_person_detail);

	proc sql;
		connect to oledb(init_string=&sqlci.);
		create table espd_dl_person_detail as
		select	person_detail_key,
				scrubbed_ssn length 9 format $9., scrubbed_fname length 15 format $15., scrubbed_mname length 15 format $15., scrubbed_lname length 25 format $25., 
				scrubbed_sex length 1 format $1., input(scrubbed_dob,yymmdd10.) format mmddyy10. as scrubbed_dob,
				scrubbed_address1 length 50 format $50., scrubbed_address2 length 50 format $50., scrubbed_city length 25 format $25., 
				scrubbed_state length 2 format $2., scrubbed_zip length 5 format $5., scrubbed_phone length 10 format $10.
		from	connection to oledb
				(	select	a.person_detail_key, 
							scrubbed_ssn, scrubbed_fname, scrubbed_mname, scrubbed_lname, scrubbed_sex, scrubbed_dob,
							scrubbed_address1, scrubbed_address2, scrubbed_city, scrubbed_state, scrubbed_zip, scrubbed_phone
					from	cihold.dbo.saswrk_bulkload_&m_wflow_exec_id. a, vh_empi.dbo.person_detail b
					where	a.person_detail_key=b.person_detail_key
				);

		drop table cihold.saswrk_bulkload_&m_wflow_exec_id.;
	quit;

	data &m_inset.(compress=yes bufsize=128k);
		if _n_=0 then set espd_dl_person_detail;
		declare hash h_d(dataset:"espd_dl_person_detail");
		h_d.definekey("person_detail_key");
		h_d.definedata('scrubbed_ssn','scrubbed_fname','scrubbed_mname','scrubbed_lname','scrubbed_sex','scrubbed_dob',
					   'scrubbed_address1','scrubbed_address2','scrubbed_city','scrubbed_state','scrubbed_zip','scrubbed_phone');
		h_d.definedone();
		call missing(person_detail_key,scrubbed_ssn, scrubbed_fname, scrubbed_mname, scrubbed_lname, scrubbed_sex, scrubbed_dob,
					 scrubbed_address1, scrubbed_address2, scrubbed_city, scrubbed_state, scrubbed_zip, scrubbed_phone);

		do while (not lstobs);
			call missing(scrubbed_ssn, scrubbed_fname, scrubbed_mname, scrubbed_lname, scrubbed_sex, scrubbed_dob,
						 scrubbed_address1, scrubbed_address2, scrubbed_city, scrubbed_state, scrubbed_zip, scrubbed_phone);
			set &m_inset. end=lstobs;
			if h_d.find()=0 then output;
			else output;
		end;
		stop;
	run;
%end;
%mend empi_scrub_person_detail;
