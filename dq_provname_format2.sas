
%macro dq_provname_format2(datain=);

	*SASDOC--------------------------------------------------------------------------
	|	Create list of all unique provider names and NPIs
	------------------------------------------------------------------------SASDOC*;
	proc summary data = &datain. nway missing;
	class raw_lname raw_fname raw_npi provname_up practiceID provname;
	output out = dq_provname1 (drop = _TYPE_ _FREQ_);
	run;


	data dq_provcheck (keep = cln_lname cln_fname cln_npi CIPar provname_up provname);
	set prov.provider;

	cln_lname = upcase(cats(scan(provname,1,",")));
	cln_fname = upcase(cats(scan(provname,2,",")));
	cln_npi = cats(npi);
	provname_up = compress(upcase(compbl(compress(provname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));

	run;

	proc summary data = dq_provcheck nway missing;
	class cln_lname cln_fname cln_npi CIPar provname_up provname;
	output out = dq_provcheck1 (drop = _TYPE_ _FREQ_);
	run;

	*SASDOC--------------------------------------------------------------------------
	|	Join all observations of raw data providers and provider list on NPIs 
	|	to compare provider names
	------------------------------------------------------------------------SASDOC*;
	proc sql;
	CREATE TABLE dq_provnamecheck AS SELECT m.raw_lname, m.raw_fname, m.raw_npi, m.practiceid, m.provname as _provname, 
											i.cln_lname , i.cln_fname, i.cln_npi, i.CIPar, i.provname
	FROM dq_provname1 AS m full outer JOIN  dq_provcheck1 As i ON m.raw_npi = i.cln_npi;

	data matched1 unmatched1;
	set dq_provnamecheck;

	last_vmine = soundex(upcase(compbl(compress(raw_lname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));
	last_prov = soundex(upcase(compbl(compress(cln_lname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));

	first_vmine = soundex(upcase(compbl(compress(raw_fname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));
	first_prov = soundex(upcase(compbl(compress(cln_fname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));

	last_match = spedis(last_vmine,last_prov);
	first_match = spedis(first_vmine,first_prov);
	npi_match = spedis(raw_npi,cln_npi);

	if (last_vmine = '' and first_vmine = '' and raw_npi = '') or (last_prov = '' and first_prov = '' and cln_npi = '') then dq_check = 0; else
	if (last_match = 0 and first_match = 0 and npi_match = 0) then dq_check = 1; else
	dq_check = 2;

	if dq_check = 2 then output matched1;
	if (raw_lname ne '' and cln_lname = '') and (raw_fname ne '' and cln_fname = '') then output unmatched1;
	run;

	*SASDOC--------------------------------------------------------------------------
	|	Join all observations of raw data providers and provider list on provider 
	|	names to compare NPIs
	------------------------------------------------------------------------SASDOC*;

	proc sql;
	CREATE TABLE dq_provnpicheck AS SELECT 	m.raw_lname, m.raw_fname, m.raw_npi, m.provname_up, m.practiceid, m.provname as _provname,
											i.cln_lname, i.cln_fname, i.cln_npi, i.CIPar, i.provname_up, i.provname
	FROM dq_provname1 AS m full outer JOIN  dq_provcheck1 As i ON m.provname_up = i.provname_up;

	data matched2 unmatched2;
	set dq_provnpicheck;

	last_vmine = soundex(upcase(compbl(compress(raw_lname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));
	last_prov = soundex(upcase(compbl(compress(cln_lname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));

	first_vmine = soundex(upcase(compbl(compress(raw_fname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));
	first_prov = soundex(upcase(compbl(compress(cln_fname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"))));

	last_match = spedis(last_vmine,last_prov);
	first_match = spedis(first_vmine,first_prov);
	npi_match = spedis(raw_npi,cln_npi);

	if (last_vmine = '' and first_vmine = '' and raw_npi = '') or (last_prov = '' and first_prov = '' and cln_npi = '') then dq_check = 0; else
	if (last_match = 0 and first_match = 0 and npi_match = 0) then dq_check = 1; else
	dq_check = 2;

	if dq_check = 2 then output matched2;
	if (raw_lname ne '' and cln_lname = '') and (raw_fname ne '' and cln_fname = '') then output unmatched2;
	run;

	*SASDOC--------------------------------------------------------------------------
	|	Determine providers participating in CI, but with name/NPI errors
	------------------------------------------------------------------------SASDOC*;
	data matched;
	set matched1 matched2;
	run;

	proc sort data = matched nodupkey;
	by practiceid raw_lname raw_fname raw_npi;
	run;

	proc sort data = unmatched1;
	by raw_lname raw_fname raw_npi;
	run;

	proc sort data = unmatched2;
	by raw_lname raw_fname raw_npi;
	run;

	data unmatched;
	merge unmatched1 (in = a) unmatched2 (in = b);
	by raw_lname raw_fname raw_npi;
	if a and b then delete;
	else output unmatched;
	run;

	proc sort data = unmatched nodupkey;
	by practiceid raw_lname raw_fname raw_npi;
	run;

	data errors;
	merge unmatched (in = a) matched (in = b);
	by practiceid raw_lname raw_fname raw_npi;
	run;

	proc sort data = errors nodupkey;
	by practiceid raw_lname raw_fname raw_npi;
	run;

%mend dq_provname_format2;
