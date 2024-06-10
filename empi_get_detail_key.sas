/* wflow_exec_id is used for:
	1. bulkloading to a unique temporary table in cihold 
	2. populating records in person and person_system with a particular created_wflow_exec_id enable us to 
		later upate the CIEDW version of the tables by grabbing only records for those specific wflow
*/
%macro empi_get_detail_key(m9_client_id,m9_inset,m9_desttable,m9_wflow_exec_id,m9_created_by,m9_create_person_system_key=0,m9_return_key=0);
	%macro empi_generate_detail_md5(m_client_id,m_var,m_track=0);
	  %if &m_track. %then %do;  
		&m_var._track=trim(fname)||trim(address1)||trim(ssn)||trim(mname)||trim(dob)||trim(state)||
						trim(lname)||trim(phone)||trim(address3)||trim(sex)||trim("&m_client_id.")||
						trim(address2)||trim(zip)||trim(city);
	  %end;
		format &m_var. $hex32.;
		attrib &m_var. transcode=no;
		&m_var.=md5(trim(fname)||trim(address1)||trim(ssn)||trim(mname)||trim(dob)||trim(state)||
					trim(lname)||trim(phone)||trim(address3)||trim(sex)||trim("&m_client_id.")||
					trim(address2)||trim(zip)||trim(city));
		format temp_text_md5 $32.;
		temp_text_md5=put(&m_var.,$hex32.);
		/* the $hex32 version somehow is not able to match on some values.
			so, for now, use the text version to match back to the incoming dataset, which always works */
	%mend;

	%let m9_dsid=%sysfunc(open(&m9_inset.));
	%let m9_mnm_var=%sysfunc(varnum(&m9_dsid.,mname));
	%let m9_add2_var=%sysfunc(varnum(&m9_dsid.,address2));
	%let m9_add3_var=%sysfunc(varnum(&m9_dsid.,address3));
	%let m9_ph_var=%sysfunc(varnum(&m9_dsid.,phone));
	%let m9_dsrc=%sysfunc(close(&m9_dsid.));
	data &m9_inset.(compress=yes bufsize=128k drop=txti);
		set &m9_inset.(rename=(dob=orgdob));
		%if &m9_mnm_var.=0 %then %do; mname=' '; %end;
		%if &m9_add2_var.=0 %then %do; address2=' '; %end;
		%if &m9_add3_var.=0 %then %do; address3=' '; %end;
		%if &m9_ph_var.=0 %then %do; phone=' '; %end;
		/* compress blanks on each cell first, then load variation */
		array txt(*) ssn fname mname lname sex address1 address2 address3 city state zip phone;
		do txti=1 to dim(txt);
			txt(txti)=compbl(txt(txti));
		end;
		format dob $10.;
		if orgdob ne . then dob=put(orgdob,yymmdd10.);
		%empi_generate_detail_md5(&m9_client_id.,&m9_desttable._detail_md5);
		rename dob=dob_dateformat orgdob=dob;
	run;

	%if %sysfunc(exist(epdk_&m9_desttable._detail)) %then %do; proc sql; drop table epdk_&m9_desttable._detail; quit; %end;
	proc sql;
		create table epdk_&m9_desttable._detail as
		select 	distinct &m9_client_id. as client_key, . as &m9_desttable._detail_key, &m9_desttable._detail_md5, temp_text_md5,
				ssn length 9 format $9., fname length 50 format $50., mname length 30 format $30., lname length 50 format $50., sex length 1 format $1., dob_dateformat as dob, 
				address1 length 250 format $250., address2 length 250 format $250., address3 length 100 format $100., 
				city length 50 format $50., state length 2 format $2., zip length 10 format $10., phone length 25 format $25.
		from	&m9_inset.
		order by &m9_desttable._detail_md5;
	quit;

	%if %sysfunc(exist(cihold.saswrk_bulkload_&m9_wflow_exec_id.)) %then %do; proc sql; drop table cihold.saswrk_bulkload_&m9_wflow_exec_id.; quit; %end;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	create table cihold.dbo.saswrk_bulkload_&m9_wflow_exec_id.
					(	[&m9_desttable._DETAIL_KEY] [int] NULL,
						[&m9_desttable._DETAIL_MD5] [binary](16) NULL,
						[TEMP_TEXT_MD5] [varchar](32) NULL,
						[CLIENT_KEY] [int] NOT NULL,
						[SSN] [char](9) NULL,
						[FNAME] [varchar](50) NULL,
						[MNAME] [varchar](30) NULL,
						[LNAME] [varchar](50) NULL,
						[SEX] [char](1) NULL,
						[DOB] [date] NULL,
						[ADDRESS1] [varchar](250) NULL,
						[ADDRESS2] [varchar](250) NULL,
						[ADDRESS3] [varchar](100) NULL,
						[CITY] [varchar](50) NULL,
						[STATE] [varchar](2) NULL,
						[ZIP] [varchar](10) NULL,
						[PHONE] [varchar](25) NULL
					)
				)
		by oledb;
	quit;

	proc append base=bcphold.saswrk_bulkload_&m9_wflow_exec_id. data=epdk_&m9_desttable._detail force; run;
/*
	%bulkload_to_cio(&m9_wflow_exec_id.,epdk_&m9_desttable._detail,m_isdate=dob);
*/
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute (	declare @interrorcode int
					begin tran
						insert into vh_empi.dbo.&m9_desttable._detail
							(	client_key, &m9_desttable._detail_md5, ssn, fname, mname, lname, sex, dob, 
								address1, address2, address3, city, state, zip, phone, created_wflow_exec_id, created_by)
						select	a.client_key, a.&m9_desttable._detail_md5, a.ssn, a.fname, a.mname, a.lname, a.sex, a.dob, 
								a.address1, a.address2, a.address3, a.city, a.state, a.zip, a.phone, &m9_wflow_exec_id., &m9_created_by.
						from	cihold.dbo.saswrk_bulkload_&m9_wflow_exec_id. a left join
								vh_empi.dbo.&m9_desttable._detail b on a.client_key=b.client_key and a.&m9_desttable._detail_md5=b.&m9_desttable._detail_md5
						where	b.client_key is null
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				)
		by oledb;
	quit;
	%set_error_flag;
	%on_error(ACTION=ABORT);

  %IF &m9_return_key. %THEN %DO;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update	cihold.dbo.saswrk_bulkload_&m9_wflow_exec_id.
					set		&m9_desttable._detail_key=b.&m9_desttable._detail_key
					from	cihold.dbo.saswrk_bulkload_&m9_wflow_exec_id. a, vh_empi.dbo.&m9_desttable._detail(nolock) b
					where	a.client_key=b.client_key and a.&m9_desttable._detail_md5=b.&m9_desttable._detail_md5
				)
		by oledb;
	quit;

	%if %sysfunc(exist(epdk_&m9_desttable._mapping)) %then %do; proc sql; drop table epdk_&m9_desttable._mapping; quit; %end;
	proc sql;
		create table epdk_&m9_desttable._mapping as
		select	temp_text_md5 as &m9_desttable._detail_md5, &m9_desttable._detail_key
		from	cihold.saswrk_bulkload_&m9_wflow_exec_id.;
	quit;

	%if &m9_create_person_system_key. %then %do;
		%let dsid=%sysfunc(open(&m9_inset.));
		%let dsperssysvar=%sysfunc(varnum(&dsid.,person_system_key));
		%let dsrc=%sysfunc(close(&dsid.));
	%end;

	data &m9_inset.(compress=yes bufsize=128k drop=&m9_desttable._detail_md5 dob_dateformat temp_text_md5);
		if _n_=0 then set epdk_&m9_desttable._mapping;
		declare hash h_d(dataset:"epdk_&m9_desttable._mapping");
		h_d.definekey("&m9_desttable._detail_md5");
		h_d.definedata("&m9_desttable._detail_key");
		h_d.definedone();
		call missing(&m9_desttable._detail_key, &m9_desttable._detail_md5);

		do while (not lstobs);
			&m9_desttable._detail_key=.;
			set &m9_inset. end=lstobs;
		  %if &m9_create_person_system_key. %then %do;
			  %if &dsperssysvar.=0 %then %do;
				person_system_key=.;
			  %end;
		  %end;
			if h_d.find(key:temp_text_md5)=0 then output;
			else output;
		end;
		stop;
	run;
  %END;

	proc sql;
		drop table cihold.saswrk_bulkload_&m9_wflow_exec_id.;
	quit;
%mend empi_get_detail_key;
