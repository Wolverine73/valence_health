%macro dq_report_HOSPITAL(client);

options formdlim = '-' fullstimer;
options noxwait sasautos = ("M:\CI\programs\StandardMacros" sasautos);

LIBNAME OUT 'M:\STLUKES\TESTING\';   /*Majcat to type of serve format*/
libname client 'M:\StLukes\testing\Client_datasets';
libname dw 'm:\dw\formats';

PROC FORMAT CNTLIN=out.revcd2group;RUN;
proc format cntlin = dw.revcode;run;
proc format cntlin = dw.proccd;run;
PROC FORMAT CNTLIN=out.majcat2TOS; RUN;

/*LOADING TAGSET*/
filename temp "\\fs\StLukes\Reports\Adhoc\dq hospital reports\tableeditor\tableeditor.tpl";
ods path(prepend) work.templat(update);
%include temp;

/*SETTING UP CLIENT INFORMATION (LIBRARY NAMES / VARIABLES / OPTIONS)*/
	%if &client = EXEMPLA %then %do;
		%let client = EXEMPLA;
		libname hosp "M:\Exempla\SASDATA\CIETL\hospital\"; /*exempla_hospital / exempla_hospital_cases*/
		/*Dataset to run report on*/
		%let data_IN = hosp.exempla_hospital_cases;
		/*Variables to produce frequencies of missing / nomissing for*/
		%LET VARS = 'DIAG2',	'DIAG3',	'DIAG4',	'DIAG5',	'DIAG6',	'DIAG7', 'ADMDT', 'SVCDT','DIAG8',	'DIAG9',	'DIAG10',	'_MEMBERID',	'ADDRESS1',	'ADDRESS2',	'ADM_FNAME',	'ADM_LNAME',	'ADM_NPI',	'ADM_SOURCE',	'ADMDIAG',	'ATT_FNAME',	'ATT_LNAME',	'ATT_NPI',	'CITY',	'CLMTYPE',	'DIAG1',	'DISDT',	'DOB',	'FAC_TIN',	'FAC_NAME',	'FNAME',	'LINE_ITEM_ID',	'LNAME',	'MAJCAT',	'MEMBERID',	'MNAME',	'MOD1',	'PHONE',	'POS',	'PROCCD',	'REVCD',	'SEX',	'SSN',	'SSNTYPE',	'STATE',	'SYSTEM',	'VISIT_TYPE',	'ZIP';
		%let NumDiags = 10;
	    %let diags = diag1 diag2 diag3 diag4 diag5 diag6 diag7 diag8 diag9 diag10;
		%let remove = '01jan1912'd and '31oct2009'd;
	%end;
	
	%if &client = STLUKES %then %do;
/*		%LET client = STLUKES;*/
		libname hosp 'm:\stlukes\sasdata\cietl\hospital';
		%let data_in = hosp.stlukes_hospital_cases;
		%LET VARS = %str('ADDRESS1',	'ADDRESS2',	'ADM_NPI',	'ADMDT',	'REF_NPI',	'ATT_NPI',	'PROVID',	'CITY',	'CLAIMNUM',	'CLMTYPE',	'DIAG1',	'DIAG2',	'DIAG3',	'DIS_COND',	'DISDT',	'DOB',	'DRG',	'FAC_NAME',	'FAC_TIN',	'FNAME',	'LNAME',	'MEMBERID',	'MOD1',	'PROCCD',	'REVCD',	'SEX',	'SSN',	'STATE',	'SVCDT',	'ZIP');
		%let NumDiags = 3;
		%let diags = diag1 diag2 diag3; 
		%let remove = '01sep1911'd and '31dec2006'd;
	%end;

	%if &client = OHG %then %do;
		%LET CLIENT = OHG;
		libname hosp 'm:\ohg\sasdata\cietl\hospital';
		%let data_in = hosp.ohg_hospital_cases;
		%LET VARS = 'CLAIM_ID',	'ADDRESS1',	'ADDRESS2',	'ADM_SOURCE','ADMDIAG','ADM_PID','ADM_PROVNAME',	'ADM_NPI',	'ADMDT',	'CITY',	'CLMTYPE',	'DIAG1',	'DIAG2',	'DIAG3',	'DIS_COND',	'DISDT',	'DOB',	'DRG',	'FAC_NAME',	'FAC_TIN',	'FNAME',	'LINE_ITEM_ID',	'LNAME',	'MEMBERID',	'MNAME',	'MOD1',	'PROCCD',	'REVCD',	'SEX',	'STATE',	'SVCDT',	'ZIP',	'PLACE_OF_SVC',	'ORD_NPI',	'ORD_PID',	'MAJCAT',	'MRN';
		%let NumDiags = 3;
		%let diags = diag1 diag2 diag3;
		%let remove = '01sep1916'd and '30jun2008'd;
	%end;

	%if &client = PHS %then %do;
		%LET CLIENT = PHS;
		libname hosp 'm:\PHS\sasdata\cietl\hospital';
		%let data_in = hosp.Matchedphs_hospital;
		%LET VARS = 'ADDRESS1',	'ADDRESS2',	'NPI',	'ADMDT',	'CITY',	'CLAIMNUM',	'DIAG1',	'DIAG2',	'DIAG3',	'DIS_COND',	'DISDT',	'DOB',	'DRG',	'FAC_NAME',	'FAC_TIN',	'FNAME',	'LNAME',	'MEMBERID',	'MNAME',	'MOD1',	'PROCCD',	'REVCD',	'SEX',	'SSN',	'STATE',	'SVCDT',	'ZIP',	'MAJCAT',	'PROVNAME',	'PROVID',	'POS';
		%let NumDiags = 3;
		%let diags = diag1 diag2 diag3;
		%let remove = '01feb1960'd and '30nov2006'd;
	%end;

	%if &client = ADVENTIST %THEN %DO;
		%let client = ADVENTIST;
		%LET CLIENT = ADVENTIST;
		libname hosp 'M:\Adventist\sasdata\CIETL\Hospital';
		%let data_in = hosp.matchedhospital;
		%LET VARS = 'ADDRESS1',	'ADDRESS2',	'NPI',	'ADMDT',	'CITY',	'CLAIMNUM',	'DIAG1',	'DIAG2',	'DIAG3',	'DIS_COND',	'DISDT',	'DOB',	'DRG',	'FAC_NAME',	'FAC_TIN',	'FNAME',	'LNAME',	'MEMBERID',	'MNAME',	'MOD1',	'PROCCD',	'REVCD',	'SEX',	'SSN',	'STATE',	'SVCDT',	'ZIP',	'MAJCAT',	'PROVNAME',	'PROVID',	'POS';
		%let NumDiags = 3;
		%let diags = diag1 diag2 diag3;
		%LET remove = '01jan1971'd and '31aug2004'd;
	 %END;

	 %IF &CLIENT = NSAP %THEN %DO;
	 	%let client = NSAP;
		libname hosp 'M:\NSAP\sasdata\CI\CIETL\hospital';
		%let data_in = hosp.nsap_hospital_cases;
		%LET VARS = 'ADDRESS1',	'ADDRESS2',	'ADM_SOURCE',	'ADM_FNAME',	'ADM_LNAME',	'ADMDT',	'ATT_FNAME',	'ATT_LNAME',	'CITY',	'CLAIMNUM',	'CLMTYPE',	'DIAG1',	'DIAG10',	'DIAG2',	'DIAG3',	'DIAG4',	'DIAG5',	'DIAG6',	'DIAG7',	'DIAG8',	'DIAG9',	'DIS_COND',	'DISDT',	'DOB',	'DRG',	'FAC_NAME',	'FNAME',	'LNAME',	'MEMBERID',	'MNAME';
		%let NumDiags = 10;
	    %let diags = diag1 diag2 diag3 diag4 diag5 diag6 diag7 diag8 diag9 diag10;
		%LET remove = '01jAN1970'd and '31jAN1970'd;
	%END;
%PUT NOTE: data_in = &data_in	client = &client   vars = &vars;
	
	 %IF &CLIENT = INGALLS %THEN %DO;
	 	%let client = INGALLS;
		libname hosp 'M:\Ingalls\sasdata\CIETL\hospital';
		%let data_in = hosp.Ingalls_hosp;
		%LET VARS ='ADDRESS1 ',	'ADMDIAG ',	'ADMDT ',	'ADM_FNAME ',	'ADM_LNAME ',	'ADM_NPI ',	'ADM_SOURCE ',	'CITY ',	'CLAIMNUM ',	'CLMTYPE ',	'DISDT ',	'DOB ',	'DRG ',	'DIAG1 ',	'DIAG2 ',	'DIAG3 ',	'DIS_COND ',	'FNAME ',	'FAC_NAME ',	'FAC_TIN ',	'FEDERALID ',	'LNAME ',	'LINE_ITEM_ID ',	'MNAME ',	'MEDRECNO ',	'MOD1 ',	'ORD_FNAME ',	'ORD_LNAME ',	'ORD_NPI ',	'POS ',	'PTNAME ',	'REVCD ',	'STATE ',	'SVCDT ',	'ZIP ',	'FILED ',	'FILENEAM ',	'MAJCAT ',	'MEMBERID ',	'PROCCD ',	'SEX ',	'SYSTEM';
		%let NumDiags = 3;
	    %let diags = DIAG1 DIAG2 DIAG3;
		%LET remove = '01jan2007'd and '30nov2007'd;
	%END;
%PUT NOTE: data_in = &data_in	client = &client   vars = &vars;
	
	


/*BREAKING DOWN HOSPITAL DATASET BY TYPE OF SERVICE AND SENSITVE CLAIMS*/
data inpatient outpatient emergency other &client._sencitive all;
	length TOS $5.;
	set &data_in  (where = (svcdt not between &remove));

	if proccd in ("G0396",	"G0397",	"H0005",	"H0006",	"H0007",	"H0008",	"H0009",	"H0010",	"H0011",	"H0012",	"H0013",	"H0014",	"H0015",
						"H0016",	"H0017",	"H0018",	"H0019",	"H0020",	"H0022",	"H0047",	"H0048",	"H0050",	"H2034",	"H2035",	"H2036",	"T1006",
						"T1007",	"T1012") then do;
								sencitive_proccd = 1; /*HCPCS codes related to Alc/SA Treatment*/
								invalidgroup = "HCPCS codes related to Alc/SA Treatment";
						end;

/*	array diags(*) &diags;*/
/*	do i = 1 to dim(diags);*/
/*		if diags(i) in ("291.0",	"291.1",	"291.2",	"291.3",	"291.4",	"291.5",	"291.8",	"291.81",	"291.82",	"291.89",	"291.9",	"292.0",	"292.1",*/
/*							  "292.11",	"292.12",	"292.2",	"292.81",	"292.82",	"292.83",	"292.84",	"292.85",	"292.89",	"292.9",	"303.0",	"303.00",*/
/*							  "303.01",	"303.02",	"303.03",	"303.9",	"303.90",	"303.91",	"303.92",	"303.93",	"304.0",	"304.00",	"304.01",	"304.02",*/
/*							  "304.03",	"304.1",	"304.10",	"304.11",	"304.12",	"304.13",	"304.2",	"304.20",	"304.21",	"304.22",	"304.23",	"304.3",*/
/*							   "304.30",	"304.31",	"304.32",	"304.33",	"304.4",	"304.40",	"304.41",	"304.42",	"304.43",	"304.5",	"304.50",	"304.51",*/
/*							   "304.52",	"304.53",	"304.6",	"304.60",	"304.61",	"304.62",	"304.63",	"304.7",	"304.70",	"304.71",	"304.72",	"304.73",*/
/*							    "304.8",	"304.80",	"304.81",	"304.82",	"304.83",	"304.9",	"304.9",	"304.91",	"304.92",	"304.93",	"305.0",	"305.00",*/
/*							   "305.01",	"305.02",	"305.03",	"305.2",	"305.20",	"305.21",	"305.22",	"305.23",	"305.3",	"305.30",	"305.31",	"305.32",*/
/*								"305.33",	"305.4",	"305.40",	"305.41",	"305.42",	"305.43",	"305.5",	"305.50",	"305.51",	"305.52",	"305.53",	"305.6",	*/
/*								"305.60",	"305.61",	"305.62",	"305.63",	"305.7",	"305.70",	"305.71",	"305.72",	"305.73",	"305.8",	"305.80",	"305.81",*/
/*								"305.82",	"305.83",	"305.9",	"305.90",	"305.91",	"305.92",	"305.93",	"648.3",	"648.30",	"648.31",	"648.32",	"648.33",*/
/*								"648.34",	"977.3") then sencitive_diag = 1; /*ICD-9 code*/*/
/*	end;*/;

	if proccd in ("80100",	"80101",	"80102",	"80103",	"80154",	"80184",	"80299",	"82055",	"82075",	"82145",	"82205",	"82491",	"82520",	"83840",
						"83925",	"83992",	"65750-2",	"51782-1") then do;
							sencitive_lab = 1; /*Lab Test Codes--Do not display results*/
							invalidgroup = "Lab Test Codes--Do not display results";
						end;

	if sencitive_proccd ge 1 or sencitive_diag ge 1 or sencitive_lab ge 1 then output &client._sencitive;

	majcat2 = STRIP(COMPRESS(put(majcat,$5.)));
	TOS = put(majcat2,$majcat2TOS.);
	if TOS = "." then TOS = "OTHER";
	output all;
	if TOS = 'IP'  then output inpatient;
	else if TOS = 'OP'  then output outpatient;
	else if TOS = 'ER'  then output emergency;
	else do;
		TOS = "OTHER";
		output other;
	end;
run;


/*start client sort*/
proc sort data = all out = visit_IP nodupkey;
	by memberid admdt;
	where admdt ne disdt and not missing(admdt) and not missing(disdt) and tos not in ("ER","OTHER");
run;

proc sort data = all out = visit_OP nodupkey;
	by memberid svcdt;
	where admdt eq disdt and not missing(admdt) and not missing(disdt) and tos not in ("ER","OTHER");
run;

proc sort data = all out = visit_er nodupkey;
	by memberid svcdt;
	where tos in ("ER") and not missing(svcdt);
run;

proc sort data = all out = visit_other nodupkey;
	by memberid svcdt;
	where tos in ("OTHER") and not missing(svcdt);
run;
/*end client sort*/



/*GETTING COUNTS TO DETERMINE NUMBER OF LOOPS LATER*/
proc sql noprint;
	select count(*) into : visit_ip	from visit_ip;
	select count(*) into : visit_op	from visit_op;
	select count(*) into : visit_er	from visit_er;
	select count(*) into : visit_other	from visit_other;	
quit;

%put note : ip = &visit_ip op = &visit_op er = &visit_er other = &visit_other;

/*DEFINING DATASETS TO LOOP THROUGH*/
data visit_loop;
	length data_loop $12;
	IP = &visit_ip; If ip ge 1 then do; data_loop = 'visit_ip'; output; end;
	OP = &visit_op;  if op ge 1 then do;	data_loop = 'visit_op'; output; end;
	ER = &visit_er; if er ge 1 then do; data_loop = 'visit_er'; output; end;
	other = &visit_other; if other ge 1 then do data_loop = 'visit_other';output; end;
run;

data visit_loop;
	set visit_loop end = last;
	num = _n_;
	if last then do;
		call symput('visit_loop', num);
	end;
run;

%put NOTE: visit_loop = &visit_loop;

%macro visittypes(); /*claim_counts_AND_outliers_BY_visittype()*/
	%do i = 1 %to &visit_loop;
		data _null_;
			set visit_loop (where = (num = &i));
			call symputx('visit',data_loop);
		run;
		%put NOTE: data = &visit;

		*claim counts by year month;
		proc freq data = &visit noprint; 
			table svcdt / nocum nopercent out = dates2;
			format svcdt monyy7.;
			where not missing(svcdt);
		run;

		data dates2;
			set dates2;
			array numeric(*) _numeric_;
			do i = 1 to dim(numeric);
				if numeric(i) = . then numeric(i) = 0;
			end;
		run;

		proc means data = dates2 median noprint;
			var count;
			output out = stats (drop = _freq_ _type_) median = middle;
		run;

		*removing counts that sqew outliers, remove if count le half  the median or ge then 2*median;
		*needed due to low claim counts from early month that cause big std or IQR;
		data extreme_&visit;
			if _n_ = 1 then do;
				set stats;
				retain middle;
			end;
			set dates2;
				if (count / middle) le .5 then L_extreme = 1;
				if (middle * 2) le count then U_extreme = 1; 
		run;

		*getting statistics to calculate outliers less the extreme observations;
		proc means data = extreme_&visit q1 q3 median qrange noprint;
			where L_extreme ne 1 and U_extreme ne 1;
			var count;
			output out = stats2 q1 = Lq q3 = Uq qrange = iqr;
		run;

		*finding outliers;
		*outliers = Uq + 1.5*IQR / Lq - 1.5*IQR;
		data visittypes_&visit (rename = (count = &visit._count));
			if _n_ = 1 then do;
				set stats2;
				upperlimit = Uq + 1.5*IQR;
				lowerlimit = Lq - 1.5*IQR;
				retain upperlimit lowerlimit;
			end;
			set extreme_&visit end = last;
				if count ge upperlimit or count le lowerlimit then &visit._outlier = 1;
				if l_extreme ge 1 or u_extreme ge 1 then &visit._outlier = 1;
				svcdt2 = compress(%str(put(svcdt,monyy7.)));
		run;

		proc sort data = visittypes_&visit;
			by svcdt2;
		run;

	%end;
	
	data visittypes;
		merge visittypes_:;
		by svcdt2;
		if visit_ip_count = . then visit_ip_count = 0;
		if visit_op_count = . then visit_op_count = 0; 
		if visit_er_count = . then visit_er_count = 0;
		if visit_other_count = . then visit_other_count = 0;
	run;

%mend visittypes;
%visittypes;


/*GETTING COUNTS TO DETERMINE NUMBER OF LOOPS LATER*/
proc sql noprint;
	select count(*) into : IP_count	from inpatient;
	select count(*) into : OP_count	from outpatient;
	select count(*) into : ER_count	from emergency;
	select count(*) into : other_count	from other;	
quit;

/*DEFINING DATASETS TO LOOP THROUGH*/
data TOS_loop;
	length data_loop $12;
	IP = &IP_count; If ip ge 1 then do; data_loop = 'inpatient'; output; end;
	OP = &OP_count;  if op ge 1 then do;	data_loop = 'outpatient'; output; end;
	ER = &ER_count; if er ge 1 then do; data_loop = 'emergency'; output; end;
	other = &other_count; if other ge 1 then do data_loop = 'other';output; end;
run;

data tos_loop;
	set tos_loop;  	num = _n_;
run;

proc sql noprint;
	select count(*) into : dataset_loops	from TOS_loop; /*NUMBER OF DATSETS TO LOOP THROUGH*/
quit;
%put NOTE: loops = &dataset_loops;

/*proc contents data = &data_in out = sortvars (keep = name)  noprint; run;*/
/**/
/*proc sql noprint;*/
/*	select upcase(name) into : sortvars SEPARATED by " "*/
/*	from sortvars;*/
/*quit;*/

%macro A(); /*claim_counts_AND_outliers_BY_typeOFservice()*/
	%do i = 1 %to &dataset_loops;
		data _null_;
			set TOS_loop (where = (num = &i));
			call symputx('data_run',data_loop);
		run;
		%put NOTE: data = &data_run;

/*		proc sort data = &data_run nodupkey;*/
/*			by &sortvars;*/
/*		run;*/

		*claim counts by year month;
		proc freq data = &data_run noprint; 
			table svcdt / nocum nopercent out = dates2;
			format svcdt monyy7.;
			where not missing(svcdt);
		run;

		data dates2;
			set dates2;
			array numeric(*) _numeric_;
			do i = 1 to dim(numeric);
				if numeric(i) = . then numeric(i) = 0;
			end;
		run;

		proc means data = dates2 median noprint;
			var count;
			output out = stats (drop = _freq_ _type_) median = middle;
		run;

		*removing counts that sqew outliers, remove if count le half  the median or ge then 2*median;
		*needed due to low claim counts from early month that cause big std or IQR;
		data extreme;
			if _n_ = 1 then do;
				set stats;
				retain middle;
			end;
			set dates2;
				if (count / middle) le .5 then L_extreme = 1;
				if (middle * 2) le count then U_extreme = 1; 
		run;

		*getting statistics to calculate outliers less the extreme observations;
		proc means data = extreme q1 q3 median qrange noprint;
			where L_extreme ne 1 and U_extreme ne 1;
			var count;
			output out = stats2 q1 = Lq q3 = Uq qrange = iqr;
		run;

		*finding outliers;
		*outliers = Uq + 1.5*IQR / Lq - 1.5*IQR;
		data stats3_&data_run (rename = (count = &data_run._count));
			if _n_ = 1 then do;
				set stats2;
				upperlimit = Uq + 1.5*IQR;
				lowerlimit = Lq - 1.5*IQR;
				retain upperlimit lowerlimit;
			end;
			set extreme end = last;
				if count = . then count = 0;
				if count ge upperlimit or count le lowerlimit then &data_run._outlier = 1;
				if l_extreme ge 1 or u_extreme ge 1 then &data_run._outlier = 1;
			svcdt2 = compress(%str(put(svcdt,monyy7.)));
		run;

		proc sort data = stats3_&data_run;
			by svcdt2;
		run;

	%end;
%mend A;
%A;

/*SETTING ALL TYPES OF SERVICE DATASETS TO ONE*/
data stats3a;
	format svcdt monyy7.;
	merge stats3_:;
	by svcdt2;
	ip = &IP_count;		op = &op_count;		er = &er_count;		other = &other_count;
	all_claims = sum(emergency_count, other_count, inpatient_count, outpatient_count);
	if IP = 0 then call missing(inpatient_count,inpatient_outlier);
	if op = 0 then call missing(outpatient_count, outpatient_outlier);
	if er = 0 then call missing(emergency_count,emergency_outlier);
	if other= 0 then call missing(other_count,other_outlier);
run;

data stats3a;
	set stats3a;
	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;
run;

proc means data = stats3a median noprint;
	var all_claims;
	output out = allclaims_stats (drop = _freq_ _type_) median = middle;
run;

*removing counts that sqew outliers, remove if count le half  the median or ge then 2*median;
*needed due to low claim counts from early month that cause big std or IQR;
data extreme_all_claims;
	if _n_ = 1 then do;
		set allclaims_stats;
		retain middle;
	end;
	set stats3a;
	if (all_claims / middle) le .5 then all_L_extreme = 1;
	if (all_claims * 2) le count then all_U_extreme = 1; 
run;

data extreme_all_claims;
	set extreme_all_claims;
	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;
run;

*getting statistics to calculate outliers less the extreme observations;
proc means data = extreme_all_claims q1 q3 median qrange noprint;
	where all_L_extreme ne 1 and all_U_extreme ne 1;
	var all_claims;
	output out = stats2 q1 = Lq q3 = Uq qrange = iqr;
run;

*finding outliers;
*outliers = Uq + 1.5*IQR / Lq - 1.5*IQR;
data stats3;
	if _n_ = 1 then do;
		set stats2;
		all_upperlimit = Uq + 1.5*IQR;
		all_lowerlimit = Lq - 1.5*IQR;
		retain all_upperlimit all_lowerlimit;
	end;
	set extreme_all_claims;
	if all_claims ge all_upperlimit or all_claims le all_lowerlimit then all_claims_outlier = 1;
	if l_extreme ge 1 or u_extreme ge 1 then all_claims_outlier = 1;
	if all_claims_outlier ne 1 then do;
		claims_diff = count - lag(count);
	end;
run;
proc sort data = stats3; by svcdt; run;

/*_______________________________________________________________________FREQUENCIES CODE______________________________________________________________*/
proc format;
	value $miss ' ' = 'MISSING'
				   other = 'NONMISSING';
run;

proc format;
	value missn . = 'MISSING'
					other = 'NONMISSING';
run;

/*NEED TO GET VAIABLE TYPE*/
proc contents data = &data_in
	out = vars (keep = name type nobs) 
	noprint; 
run;

/*loops = # of variables to loop through to when getting frequencies*/
data vars;
	set vars;
	name2 = upcase(name);
	drop name; rename name2 = name;
	call symput('datasettotal', nobs);
run;
%put &datasettotal;

/*loops = # of variables to loop through to when getting frequencies*/
data vars;
	length name $20.;	
	set vars (where = (name in(&vars)))  end = last; /*&vars = list of variables determined in client setup macro*/
	num = _n_;
	if last then call symputx('loops',num);
run;
%PUT &LOOPS;


/*GETTING AND CHECKING FOR VALID MAX AND MIN DATES*/
%macro get_dates();
/*GETTING MAXIMUM VALID DATE*/
proc summary data = &data_in;
	var svcdt;
	output out = dates min = mindt max = maxdt;
run;

data temp1;
	set dates;
	_today = today()*1;
	call symput("mindt", mindt);
	call symput("maxdt", maxdt);
	if maxdt gt _today then do;
		call symput('invalidmax',1);
	end;
	else do;
		call symput('invalidmax',0);
	end;
	if mindt <= 0 or mindt le intnx('year',_today,-100) then do;
		call symput('invalidmin',1);
	end;
	else do;
		call symput('invalidmin',0);
	end;
	format _today mmddyy10.;
run;%put NOTE: mindt = &mindt  maxdt = &maxdt  maxflag = &invalidmax  minflag = &invalidmin;

/*CHECKING FOR INVALID FUTURE DATES*/
%if &invalidmax ge 1 %then %do;
proc sql noprint;
	select max(svcdt) into : validmax
	from &data_in
	where svcdt le today();
	create table future_dates as
	select * 
	from &data_in
	where svcdt gt today();
quit; 
/*IF FUTURE DATES FOUND*/
	proc freq data = future_dates noprint;
		table svcdt / list missing nocum nopercent out = tempf;
		format svcdt monyy7.;
	run;
%end;

/*CHECKING FOR INVALID OLD DATES*/
%if &invalidmin eq 1 %then %do;
	data invalidmin;
		set &data_in;
		retain _today;
		if _n_ = 1 then do;
			_today = today()*1;
		end;
		if svcdt <= 0 or svcdt le intnx('year',_today,-100);
		if not missing(svcdt);
	run;
	proc freq data = invalidmin noprint;
		table svcdt / list missing nocum nopercent  out = tempe;
		format svcdt monyy7.;
	run;
%end;

data validdates;
	%if &invalidmin ge 1 and &invalidmax ge 1 %then %do; set tempe tempf; %end;
	%if &invalidmin ge 1 and &invalidmax ne 1 %then  %do; set tempe ;  %end;
	%if &invalidmin ne 1 and &invalidmax ge 1 %then  %do; set tempf;  %end;
	%if &invalidmin ge 1 or &invalidmax ge 1 %then %do;
		call missing(message);
		sort = 0;
		percent2 = count / &datasettotal;
		drop percent;
		rename percent2 = percent;
	%end;
	%if &invalidmin ne 1 and &invalidmax ne 1 %then %do;
		MESSAGE = "There are no date values that occur in the future or over 100 years ago for &data_in.";
		sort = 1;
	%end;
run;

data dateprams_a;
	%if &invalidmax = 1 %then %do;
		maxdt = &validmax*1;
	%end;
	%else %do;
		maxdt = &maxdt*1;
	%end;
	maximum= put(&maxdt,mmddyy10.);
	minimum = put(&mindt,mmddyy10.);
	mindt = &mindt;
	invalidmin = &invalidmin;
	invalidmax = &invalidmax;
run;

%mend get_dates;
%get_dates;

data dateprams;
	set dateprams_a;
	call symput('maximum',maximum);
	call symput('minimum',minimum);
	call symput('maxdt',maxdt);
	call symput('invalidmin',invalidmin);
	call symput('invalidmax',invalidmax);
run;
%put note: max = &maximum  min = &minimum valid max = &maxdt min = &mindt earlydates = &invalidmin  &invalidmax;


/*GETTING TIME PERIOD TO DO FREQUENCIES ON*/
/*IF MAX DATE OVER HALF WAY THROUGH THE MONTH THEN ANALYSIS DONE ON THAT MONTH*/
/*ELSE ANALYSIS DONE ON 1st OF PRIOR MONTH UP TO MAX DATE*/
data test;
	format maxDT stdt2 mmddyy10.;
	set dateprams;
	if day(maxdt) ge 16 then do;
		_month =compress(put(month(maxDT),z2.));
/*		if _month = 12 then do;*/
/*		 	_year_ = year(maxdt);*/
/*			_year = _year_ - 1;*/
/*		end;*/
/*		else do;*/
			_year =  year(maxDT);
/*		end;*/
		stdt = compress(_month||"/"||"01"||"/"||_year);
	end;
	else if day(maxdt) lt 16 then do;
		 _month = put(month(compress(intnx('month', maxDT, -1,'same'))),z2.);
		 if _month = 12 then do;
		 	_year_ = year(maxdt);
			_year = _year_ - 1;
		end;
		else do;
		 	_year = year(maxDT);
		 end;
		 stdt = compress(_month||"/"||"01"||"/"||_year);
	end;
	stdt2 = input(stdt,mmddyy10.);
	call symputx('stdt2',stdt2);
	call symputx('stdt',stdt);
run;

%PUT &STDT &stdt2 &maxDT;

%macro B();		/*variable_frequencies_BY_typeOFservice()*/
	%do i = 1 %to &dataset_loops;
		data _null_;
			set TOS_loop (where = (num = &i));
			call symputx('dataset_run',data_loop);
		run;
		%put NOTE: data = &dataset_run &i &dataset_loops;
		data &dataset_run._&i;
			set &dataset_run;
			where svcdt between &stdt2 and &maxDT;
		run;
		%do j = 1 %to &loops;/*number of vars to do frequencies for*/
/*		%let dataset_run = inpatient;*/
			proc contents data = &dataset_run._&i out = total (keep = nobs) noprint; run;
			data _null_;
				if _n_ = 1 then do;
					set total;
					call symputx('total', nobs);
				end;
				set vars (where = (num = &j));
				call symputx('table',name);
				if type = 2 then do;/*IF variable of character type*/
					c = '$miss';	
					call symputx('format',c);
				end;
				if type = 1 then do;/*IF variable of numeric type*/
					n = 'missn';	
					call symputx('format',n);
				end;
				call symputx('type',type);
			run;

			%put NOTE: variable =  &table FormatTYPE = &format DataTYPE = &type total = &total;

			proc freq data = &dataset_run._&i;
				table &table / list missing nocum nopercent noprint out = freqs;
				format &table &format..;
			run;

			data freqs_&dataset_run._&j (keep = var1 status count_&dataset_run nonmissing_&dataset_run percent_&dataset_run total_&dataset_run);
/*			data freqs_inpatient_1;* (keep = var status count nonmissing percent total);*/
				length var $20. status $10.;
				set freqs;
				type = &type;
				var1 = "&table.";
				total = &total;
				count2 = count*1;
				percent2 = (count2)/total;
				NONMISSING_&dataset_run = total - COUNT2;
				if type = 1 then do
					CHECK = &table*1;
					if CHECK = . then status = 'MISSING';
					else status = 'NONMISSING';
				end;
				if type = 2 then do;	
					STATUS2 = &table;
					if status2 = ' ' then status = 'MISSING';
					else status = 'NONMISSING';
				end;
				/*IF none missing*/
				if count2 = total and status = 'NONMISSING' then do;
					status = 'MISSING';
					count2 = 0;
					percent2 = 0;
				end;
				drop count; rename count2 = count_&dataset_run;
				drop percent; rename percent2 = percent_&dataset_run;
				rename total = total_&dataset_run;
				if status = 'MISSING';
			run;
		%end;

		data all_&dataset_run._freqs;
			length var1 $20.;
			set freqs_&dataset_run._:;
		run;
		
		proc sort data = all_&dataset_run._freqs;
			by var1;
		run;

		proc datasets library = work;
			delete freqs_:;
		quit;
	%end;
%mend B; /*variable_frequencies_BY_typeOFservice*/
%B; /*variable_frequencies_BY_typeOFservice*/

data &client._all;
	merge all_:;
	by var1;
	ip = &IP_count;		op = &op_count;		er = &er_count;		other = &other_count;
	if IP = 0 then call missing(count_inpatient,total_inpatient,percent_inpatient);
	if op = 0 then call missing(count_outpatient,total_outpatient,percent_outpatient);
	if er = 0 then call missing(count_emergency,total_emergency,percent_emergency);
	if other= 0 then call missing(count_other,total_other,percent_other);
	totalmissing = sum(of count_:);
	total = sum(of total_:);
	totalpercent = totalmissing / total;
/*	rename var = var1;*/
/*	total_claims = */
run; 

data &client._all1 summary_ALL1 (keep = summary var1 change vchange direction vdirection totalpercent ptotalpercent valence_average
												  rename = (var1 = variable totalpercent = current ptotalpercent = prior));
	merge &client._all (in = a)
				client.&client._all1 (in = b keep = var1 /*totalmissing*/ total totalpercent rename = (/*totalmissing = ptotalmissing*/ total = ptotal totalpercent = ptotalpercent))
				client.valence_&client._all (in = c);
	by var1;

	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;

	change = totalpercent - ptotalpercent;
	if abs(change) ge .08 then outlier = 1;
	if outlier ge 1 then do;
		if change ge 0 then direction = 'u';
		else direction = 'd';
	end;
	vchange = totalpercent - valence_average;
	if abs(vchange) ge .08 then voutlier = 1;
		if voutlier ge 1 then do;
		if vchange ge 0 then vdirection = 'u';
		else vdirection = 'd';
	end;
	change = abs(change);
	vchange = abs(vchange);
	if (voutlier ge 1 or outlier ge 1) and (a or b) and (direction = 'u' or vdirection = 'u') then do;	
		summary = "VARIABLE ANALYSIS";
		output summary_ALL1;
	end;
	if a or b then output &client._all1;
run;

proc sort data = &client._all1 out = &client._all1 nodupkey;
	by var1;
run;

proc freq data = &client._sencitive noprint;
	table svcdt*proccd*invalidgroup / list missing nocum out = sencitive;
	format svcdt monyy7.;
run;

proc contents data = &data_in out = t (keep = nobs)  noprint; run;

data sencitive;
	if _n_ = 1 then do;
		retain total;
		set t;
		total = nobs;
	end;
	set sencitive;
	desc = put(proccd,$cpt.);
	percent = count / total;
run;
proc sort data = sencitive; by descending svcdt descending count; run;

/*SUBSETTING DATA_IN TO report on current month*/
proc sql noprint;
/*	create table subset_prev as*/
	create table subset as
	select a.* from &data_in a
	where svcdt between (&stdt2) and (&maxDT);
	select count(*) into : subtotal
/*	from subset_prev;*/
	from subset;
quit;

%put &subtotal;

proc sql noprint;
	create table subsetmember as
	select distinct memberid, dob, sex
	from subset;
	select count(*) into : subtotal_mem
	from subsetmember;
quit;

/*GROUPING PROCEDURE CODES*/
data proccd (drop = proccdn);
	set subset (keep = proccd) end = last;
	proccdn = proccd*1;
	if proccd = "" then proccd_missing + 1;
	if proccdn ge 10021 and proccdn le 69990 and length(proccd) = 5 then Proccd_10021to69990 + 1; /*SURGICAL*/
	if proccdn ge 99281 and proccdn le 99288 and length(proccd) = 5 then Proccd_99281to99288 + 1; /*Special ER*/
	if proccdn ge 00100 and proccdn le 01999 and length(proccd) = 5 then Proccd_00100to01999 + 1;/*Anesthesia*/
	if proccdn ge 70010 and proccdn le 79999 and length(proccd) = 5 then Proccd_70010to79999 + 1; /*RADIOLOGY*/
	if proccdn ge 80047 and proccdn le 84999 and length(proccd) = 5 then Proccd_80047to84999 + 1; /*Chemistry Procedures*/
	if proccdn ge 85000 and proccdn le 85999 and length(proccd) = 5 then Proccd_85000to85999 + 1; /*Hematology and Coagulation Procedures*/
	if proccdn ge 86000 and proccdn le 86849 and length(proccd) = 5 then Proccd_86000to86849 + 1; /*Immunology Procedures*/
	if proccdn ge 86850 and proccdn le 86999 and length(proccd) = 5 then Proccd_86850to86999 + 1; /*Transfusion Medicine Procedures*/
	if proccdn ge 87000 and proccdn le 87999 and length(proccd) = 5 then Proccd_87000to87999 + 1; /*Microbiology Procedures*/
	if proccdn ge 88000 and proccdn le 88099 and length(proccd) = 5 then Proccd_88000to88099 + 1; /*Anatomic Pathology Procedures*/
	if proccdn ge 88100 and proccdn le 88199 and length(proccd) = 5 then Proccd_88104to88199 + 1; /*Cytopathology Procedures*/
	if proccdn ge 88300 and proccdn le 89240 and length(proccd) = 5 then Proccd_88300to89240 + 1; /*Pathology*/
	if proccdn ge 89250 and proccdn le 89399 and length(proccd) = 5 then Proccd_89250to89399 + 1; /*Reproductive Medicine Procedures*/
	if proccdn ge 90281 and proccdn le 90799 and length(proccd) = 5 then Proccd_90281to90799 + 1; /*Vaccines and Immunizations*/
	if proccdn ge 90800 and proccdn le 90899 and length(proccd) = 5 then Proccd_90800to90899 + 1; /*Psychiatry Services and Procedures*/
	if proccdn ge 90900 and proccdn le 90999 and length(proccd) = 5 then Proccd_90900to90999 + 1; /*Dialysis*/
	if proccdn ge 91000 and proccdn le 92499 and length(proccd) = 5 then Proccd_91000to92499 + 1; /*Gastroenterology / Ophthalmology*/
	if proccdn ge 92500 and proccdn le 92700 and length(proccd) = 5 then Proccd_92500to92700 + 1; /*Otorhinolaryngologic Services and Procedures*/
	if proccdn ge 92950 and proccdn le 93799 and length(proccd) = 5 then Proccd_92950to93799 + 1; /*Cardiovascular Procedures*/
	if proccdn ge 93800 and proccdn le 93990 and length(proccd) = 5 then Proccd_93800to93990 + 1; /*Non-Invasive Vascular Diagnostic Studies*/
	if proccdn ge 94000 and proccdn le 94799 and length(proccd) = 5 then Proccd_94000to94799 + 1; /*Pulmonary Procedures*/
	if proccdn ge 95000 and proccdn le 95199 and length(proccd) = 5 then Proccd_95000to95199 + 1; /*Allergy and Clinical Immunology Procedures*/
	if proccdn ge 95250 and proccdn le 96020 and length(proccd) = 5 then Proccd_95250to96020 + 1; /*Neurology and Neuromuscular Procedures*/
	if proccdn ge 96101 and proccdn le 96125 and length(proccd) = 5 then Proccd_96101to96125 + 1; /*Central Nervous System Assessments/Tests (eg, Neuro-Cognitive, Mental Status, Speech Testing)*/
	if proccdn ge 96150 and proccdn le 96549 and length(proccd) = 5 then Proccd_96150to96549 + 1; /*Health and Behavior Assessment*/
	if proccdn ge 96567 and proccdn le 96571 and length(proccd) = 5 then Proccd_96567to96571 + 1; /*Photodynamic Therapy Procedures*/
	if proccdn ge 96567 and proccdn le 96999 and length(proccd) = 5 then Proccd_96567to96999 + 1; /*Special Dermatological Procedures*/
	if proccdn ge 97000 and proccdn le 97799 and length(proccd) = 5 then Proccd_97000to97799 + 1; /*Physical Medicine and Rehabilitation Evaluations*/
	if proccdn ge 97800 and proccdn le 99607 and length(proccd) = 5 then Proccd_97800to99607 + 1; /*Therapy / Consultation SERVICES*/
	if substr(proccd,5,1) = 'F' then proccd_0001Fto7025F + 1;/*SURGICAL / Diagnostic*/
	if substr(proccd,5,1) = 'T' then proccd_0019Tto0290T + 1;/*/*Anesthesia*/*/;
	prevline = lag(sum(of proccd_:));
	if sum(of proccd_:) = prevline then proccd_other + 1;
	drop prevline;
	if last then output;
run;

proc transpose data = proccd out = proccdT (rename = (_name_ = codeRange col1 = count)) ; run;

data proccdT;
	length _group group $55. range $25.;
	set proccdT;
	if codeRange = "proccd_missing" then do; _group = "missing"; RANGE = "CODE MISSING";end;
	if codeRange = "Proccd_10021to69990" then do; _group = "SURGICAL"; RANGE = "10021 - 69990";end;
	if codeRange = "Proccd_99281to99288" then do; _group = "Special ER"; RANGE = "99281 - 99288";end;
	if codeRange = "Proccd_00100to01999" then do; _group = "Anesthesia"; RANGE = "00100 - 01999";end;
	if codeRange = "Proccd_70010to79999" then do; _group = "RADIOLOGY"; RANGE = "70010 - 79999";end;
	if codeRange = "Proccd_80047to84999" then do; _group = "Chemistry Procedures"; RANGE = "80047 - 84999";end;
	if codeRange = "Proccd_85000to85999" then do; _group = "Hematology and Coagulation Procedures"; RANGE = "85000 - 85999";end;
	if codeRange = "Proccd_86000to86849" then do; _group = "Immunology Procedures"; RANGE = "86000 - 86849";end;
	if codeRange = "Proccd_86850to86999" then do; _group = "Transfusion Medicine Procedures"; RANGE = "86850 - 86999";end;
	if codeRange = "Proccd_87000to87999" then do; _group = "Microbiology Procedures"; RANGE = "87000 - 87999";end;
	if codeRange = "Proccd_88000to88099" then do; _group = "Anatomic Pathology Procedures"; RANGE = "88000 - 88099";end;
	if codeRange = "Proccd_88104to88199" then do; _group = "Cytopathology Procedures"; RANGE = "88104 - 88199";end;
	if codeRange = "Proccd_88300to89240" then do; _group = "Pathology"; RANGE = "88300 - 89240";end;
	if codeRange = "Proccd_89250to89399" then do; _group = "Reproductive Medicine Procedures"; RANGE = "89250 - 89399";end;
	if codeRange = "Proccd_90281to90799" then do; _group = "Vaccines and Immunizations"; RANGE = "90281 - 90799";end;
	if codeRange = "Proccd_90800to90899" then do; _group = "Psychiatry Services and Procedures"; RANGE = "90800 - 90899";end;
	if codeRange = "Proccd_90900to90999" then do; _group = "Dialysis"; RANGE = "90900 - 90999";end;
	if codeRange = "Proccd_91000to92499" then do; _group = "Gastroenterology / Ophthalmology"; RANGE = "91000 - 92499";end;
	if codeRange = "Proccd_92500to92700" then do; _group = "Otorhinolaryngologic Services and Procedures"; RANGE = "92500 - 92700";end;
	if codeRange = "Proccd_92950to93799" then do; _group = "Cardiovascular Procedures"; RANGE = "92950 - 93799";end;
	if codeRange = "Proccd_93800to93990" then do; _group = "Non-Invasive Vascular Diagnostic Studies"; RANGE = "93800 - 93990";end;
	if codeRange = "Proccd_94000to94799" then do; _group = "Pulmonary Procedures"; RANGE = "94000 - 94799";end;
	if codeRange = "Proccd_95000to95199" then do; _group = "Allergy and Clinical Immunology Procedures"; RANGE = "95000 - 95199";end;
	if codeRange = "Proccd_95250to96020" then do; _group = "Neurology and Neuromuscular Procedures"; RANGE = "95250 - 96020";end;
	if codeRange = "Proccd_96101to96125" then do; _group = "Central Nervous System Assessments/Tests"; RANGE = "96101 - 96125";end;
	if codeRange = "Proccd_96150to96549" then do; _group = "Health and Behavior Assessment"; RANGE = "96150 - 96549";end;
	if codeRange = "Proccd_96567to96571" then do; _group = "Photodynamic Therapy Procedures"; RANGE = "96567 - 96571";end;
	if codeRange = "Proccd_96567to96999" then do; _group = "Special Dermatological Procedures"; RANGE = "96567 - 96999";end;
	if codeRange = "Proccd_97000to97799" then do; _group = "Physical Medicine and Rehabilitation Evaluations"; RANGE = "97000 - 97799";end;
	if codeRange = "Proccd_97800to99607" then do; _group = "Therapy / Consultation SERVICES"; RANGE = "97800 - 99607";end;
	if codeRange = "proccd_0001Fto7025F" then do; _group = "SURGICAL / Diagnostic"; RANGE = "0001F - 7025F";end;
	if codeRange = "proccd_0019Tto0290T" then do; _group = "Anesthesia"; RANGE = "0019T - 0290T";end;
	if codeRange = "proccd_other" then do; _group = "other"; RANGE = "OTHER CODES";end;
	group = upcase(_group);
	total = &subtotal;
	percent = count / total;
	drop _group;
run;

proc sort data = proccdT; by coderange; run;
proc sort data = client.&client._proccd; by coderange; run;

data &client._proccd  summary_PROCCD (keep = summary coderange change vchange direction vdirection percent ppercent valence_average
												         rename = (coderange = variable percent = current ppercent = prior));
	merge proccdT (in = a)
				client.&client._proccd ( in = b rename = (/*count = pcount*/ percent = pPercent total = ptotal))
				client.valence_proccd (in = c);
	by coderange;

	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;

	change = percent - ppercent;
	if abs(change) ge .08 then outlier = 1;
	if outlier ge 1 then do;
		if change ge 0 then direction = 'u';
		else direction = 'd';
	end;
	vchange = percent - valence_average;
	if abs(vchange) ge .08 then voutlier = 1;
		if voutlier ge 1 then do;
		if vchange ge 0 then vdirection = 'u';
		else vdirection = 'd';
	end;
	change = abs(change);
	vchange = abs(vchange);
	if (voutlier ge 1 or outlier ge 1) and (a or b)  /*and (direction = 'u' or vdirection = 'u')*/ then do;	
		summary = "PROCCD";
		output summary_PROCCD;
	end;
	
	if a or b then output &client._proccd;
run;	%put &client;

proc freq data = subset noprint;
	table majcat / list missing nocum out = &client._majcats;
run;

data majcats2  summary_MAJCAT (keep = summary majcat2 change vchange direction vdirection percent ppercent valence_average
												         rename = (majcat2 = variable percent = current ppercent = prior));
	merge &client._majcats (in = a)
				client.&client._Majcats2 (in = b rename = (total = ptotal /*count = Pcount*/ percent = pPercent))
				client.valence_majcats (in = c);
	by majcat;

	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;

	percent = percent / 100;
	total = &subtotal;
	change = percent - ppercent;
	if abs(change) ge .08 then outlier = 1;
	if outlier ge 1 then do;
		if change ge 0 then direction = 'u';
		else direction = 'd';
	end;
	vchange = percent - valence_average;
	if abs(vchange) ge .08 then voutlier = 1;
		if voutlier ge 1 then do;
		if vchange ge 0 then vdirection = 'u';
		else vdirection = 'd';
	end;
	change = abs(change);
	vchange = abs(vchange);
	if (voutlier ge 1 or outlier ge 1) and (a or b)  /*and (direction = 'u' or vdirection = 'u')*/ then do;	
		summary = "MAJCAT";
		majcat2 = put(majcat,$10.);
		output summary_MAJCAT;
	end;
	if a or b then output MAJCATS2;
run;

proc freq data = subsetmember noprint;
	table sex / list missing nocum out = &client._gender;
run;

data gender summary_gender  (keep = summary sex change vchange direction vdirection percent ppercent valence_average
												         rename = (sex = variable percent = current ppercent = prior));
	LENGTH SEX $10.;
	merge &client._gender (in = a) 
				client.&client._gender (in = b rename = (total = ptotal /*count = pcount*/ percent = pPercent))
				client.valence_gender (in = c);
	by sex;
	
	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;
	IF MISSING(SEX) THEN SEX = 'MISSING';
	percent = percent / 100;
	total = &subtotal_mem;
	change = percent - ppercent;
	if abs(change) ge .08 then outlier = 1;
	if outlier ge 1 then do;
		if change ge 0 then direction = 'u';
		else direction = 'd';
	end;
	vchange = percent - valence_average;
	if abs(vchange) ge .08 then voutlier = 1;
		if voutlier ge 1 then do;
		if vchange ge 0 then vdirection = 'u';
		else vdirection = 'd';
	end;
	change = abs(change);
	vchange = abs(vchange);
	if (voutlier ge 1 or outlier ge 1) and (a or b)  /*and (direction = 'u' or vdirection = 'u')*/ then do;	
		summary = "SEX";
		output summary_gender;
	end;
	if a or b then output gender;
run;

data typeOFservice (keep = IP OP ER OTHER);
/*	set subset_prev end = last;*/
	set subset (keep = majcat) end = last;
	majcat2 = STRIP(COMPRESS(put(majcat,$5.)));
	TOS = put(majcat2,$majcat2TOS.);
	if TOS = "IP" then IP + 1;
	else if TOS = "OP" then OP + 1;
	else if TOS = "ER" then ER + 1;
/*	else if TOS = "OTHER" then OTHER + 1;*/
	else other + 1;
	if last then do;
		output;
	end;
run;

proc transpose data = typeOFservice out = typeOFservice2 (rename = (_name_ = POS col1 = count)); run;

proc sort data = typeOFservice2; by POS; run;

data &client._POS summary_POS (keep = summary pos change vchange direction vdirection percent ppercent valence_average
												                         rename = (pos = variable percent = current ppercent = prior));
	merge typeOFservice2 (in = a)
				client.&client._POS (in = b rename = (total = ptotal percent = ppercent /*count = pcount*/))
				client.valence_pos (in = c);
	by pos;

	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;

	retain total;
	if _n_ = 1 then total = &subtotal;
	percent = count / total;
	change = percent - ppercent;
	if abs(change) ge .08 then outlier = 1;
	if outlier ge 1 then do;
		if change ge 0 then direction = 'u';
		else direction = 'd';
	end;
	vchange = percent - valence_average;
	if abs(vchange) ge .08 then voutlier = 1;
		if voutlier ge 1 then do;
		if vchange ge 0 then vdirection = 'u';
		else vdirection = 'd';
	end;
	change = abs(change);
	vchange = abs(vchange);
	if (voutlier ge 1 or outlier ge 1) and (a or b)  /*and (direction = 'u' or vdirection = 'u')*/ then do;	
		summary = "POS";
		output summary_POS;
	end;
	if a or b then output &client._POS;
run;

data revcd1;
	length desc $100.;
	set subset (keep = revcd);
	revcd2 = compress(put(revcd,$5.));
	desc = put(revcd2,$revcd2group.);
	if desc = "UNKNOWN" then do;
		desc2 = put(revcd2,$revcode.);
		desc = strip("NO GROUP DEFINED FOR"||" - "||revcd2||" - "||desc2);
	end;
run;

proc freq data = revcd1 noprint;
	table desc / list missing nocum out = &client._revcd;
run;

data revcd summary_REVCD (keep = summary desc change vchange direction vdirection percent ppercent valence_average
												                         rename = (desc = variable percent = current ppercent = prior));
	merge &client._revcd (in = a)
				client.&client._revcd (in = b rename = (/*count = pcount*/ percent = pPercent total = ptotal))
				client.valence_revcd (in = c);
	by desc;

	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;

	total = &subtotal;
	percent = percent / 100;
	change = percent - ppercent;
	if abs(change) ge .08 then outlier = 1;
	if outlier ge 1 then do;
		if change ge 0 then direction = 'u';
		else direction = 'd';
	end;
	vchange = percent - valence_average;
	if abs(vchange) ge .08 then voutlier = 1;
		if voutlier ge 1 then do;
		if vchange ge 0 then vdirection = 'u';
		else vdirection = 'd';
	end;
	change = abs(change);
	vchange = abs(vchange);
	if (voutlier ge 1 or outlier ge 1) and (a or b) /*and (direction = 'u' or vdirection = 'u')*/ then do;	
		summary = "REVCODE";
		output summary_revcd;
	end;
	if a or b then output revcd;
run;

/*/*GETTING ONLY DIAGS THAT HAVE SENSITIVE CLAIM LINES ASSOCIATED WIHT THEM*/*/
/*data sensitive;*/
/*	array diags(*) $ &diags;*/
/*	array allmiss(&NumDiags) $ (&NumDiags*'true');*/
/*	length list $ 100;*/
/*	set &client._sensitive (keep =svcdt &diags) end=end;*/
/*	do i=1 to dim(diags);*/
/*	if diags(i) ne '' then allmiss(i)='false';*/
/*	end;*/
/*	if end=1 then*/
/*	do i= 1 to dim(diags);*/
/*		if allmiss(i) ='false' then do;*/
/*			list=catx(' ',list,vname(diags(i)));*/
/*		end;*/
/*	end;*/
/*	call symput('mlist',list);*/
/*run;*/
/**/
/*%put &mlist;*/
/**/
/*data test9;*/
/*	set sensitive;*/
/*	keep svcdt &mlist;*/
/*run;*/;

data age_range;
	length agerange $20.;
	set subsetmember (keep = dob);
	age = round((today() - dob)/365.23,.1);
	if missing(dob) then 	agerange = 'MISSING DOB';
	if dob gt today() then agerange = 'INVALID FUTURE BIRTHDATE';
	if age ge 100 then agerange = 'F - AGE >= 1OO';
	if 0 le age and age lt 3 then agerange = 'A - 0 to 2'; 
	if 3 le age and age lt 19 then agerange = 'B - 3 to 18'; 
	if 19 le age and age lt 46 then agerange = 'C - 19 to 45'; 
	if 46 le age and age lt 56 then agerange = 'D - 46 to 55';
	if age ge 56 then agerange = 'E - 56 +';
run;

proc freq data = age_range NOPRINT;
	table agerange / list missing nocum out = agerange;
run;

data &client._agerange summary_AGERANGE (keep = summary display change vchange direction vdirection percent ppercent valence_average
												                         rename = (display = variable percent = current ppercent = prior));
	length display $20.;
	merge agerange (in = a)
				client.&client._agerange (in = b rename = (total = ptotal /*count = pcount*/ percent = pPercent))
				client.valence_agerange (in = c);
	percent = percent / 100;
	by agerange;

	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;
	total = &subtotal_mem;
	if agerange = 'MISSING DOB' then display = 'MISSING DOB';
	if agerange = 'A - 0 to 2' then display = '0 to 2';
	if agerange = 'B - 3 to 18' then display = '3 to 18'; 
	if agerange = 'C - 19 to 45' then display = '19 to 45';
	if agerange = 'D - 46 to 55' then display = '46 to 55'; 
	if agerange = 'E - 56 +' then display = '56 +'; 
	if agerange = 'F - AGE >= 100' THEN display = 'AGE >= 100'; 

	change = percent - ppercent;
	if abs(change) ge .08 then outlier = 1;
	if outlier ge 1 then do;
		if change ge 0 then direction = 'u';
		else direction = 'd';
	end;
	vchange = percent - valence_average;
	if abs(vchange) ge .08 then voutlier = 1;
		if voutlier ge 1 then do;
		if vchange ge 0 then vdirection = 'u';
		else vdirection = 'd';
	end;
	change = abs(change);
	vchange = abs(vchange);
	if (voutlier ge 1 or outlier ge 1) and (a or b) /*and (direction = 'u' or vdirection = 'u')*/ then do;	
		summary = "AGE RANGES";
		output summary_AGERANGE;
	end;
	if a or b then 	output &client._agerange;
run;

data ssn (drop = client);
	client = &client;
	if client = 'INGALLS' then do;
		set subset (rename = (memberid = ssn));
	end;
	else do;
		set subset (keep = ssn);
	end;
	if length(compress(ssn)) ne 9 then do;
		invalid_length = 1;
		badtype = ssn||' - INVALID LENGTH';
	end;
	if anyalpha(ssn) ge 1 or ssn in ('111111111','222222222','333333333','444444444','555555555','666666666',
															'777777777','888888888','999999999','123456789') then do;
		invalid_value = 1;
		badtype = ssn||' - INVALID VALUES';
	end;
	if  then do;
	if invalid_length ge 1 or invalid_value ge 1;
run;

proc freq data = ssn NOPRINT;
	table badtype / list missing nocum nopercent out = ssn1;* (drop = percent); 
run;

proc contents data = ssn1 out = b_ssn (keep = nobs) noprint ; run;
data _NULL_;
	set b_ssn;
	call symput('ssnOBS', nobs);
run;
%put &ssnOBS;
proc sort data = ssn1;
	by descending count;
run;

%macro range();
%if &invalidmax ge 1 or &invalidmin ge 1 %then %do;
	proc sql;
		create table stats3 as
		select a.*
		from stats3 a
		where svcdt not in (select svcdt from validdates);
	quit;
%end;
%mend range;
%range;

/*merging claims counts to visit counts (keeping only the valid dates (if b))*/
proc sort data = stats3; by svcdt2; run;
data claims;
	merge visittypes (in = a)
				stats3 (in = b);
	by svcdt2;
	ip = &visit_ip;		op = &visit_op;		er = &visit_er;		other = &visit_other;
	if IP = 0 then call missing(visit_ip_count, visit_ip_outlier);
	if op = 0 then call missing(visit_op_count, visit_op_outlier);
	if er = 0 then call missing(visit_er_count, visit_er_outlier);
	if other= 0 then call missing(visit_other_count, visit_other_outlier);
	DIVIDER = "+";
	array numeric(*) _numeric_;
	do i = 1 to dim(numeric);
		if numeric(i) = . then numeric(i) = 0;
	end;
	if b;
run;

proc sort data = claims;
	by svcdt;
run;

/*STACKING ALL SUMMAY TABLES*/
data summary;
	length summary $50.;
	length variable $75.;
	set summary_:;
run;

proc sql noprint;
	select count(*) into : stats3 from stats3;
	select count(*) into : validdates from validdates;
	select count(*) into : all1 from &client._all1;
	select count(*) into : gender from gender;
	select count(*) into : agerange from &client._agerange;
	select count(*) into : majcats2 from majcats2;
	select count(*) into : revcd from revcd;
	select count(*) into : proccd from &client._proccd;
	select count(*) into : pos from &client._pos;
	select count(*) into : sencitive from sencitive;
quit;
data error;
	MESSAGE = "An error has occured when processing this tab please review  the log";
run;

/*REPORT SETUPS*/
data _null_;
	maxdt = &maxDT*1;
	name1 = "&data_in"; client1 = "&client";
	name = upcase(SCAN(name1,2,'.'));
	client = upcase(client1);
	TITLE_ = client||" HOSPITAL REPORT FOR " || name;
	_month =compress(put(month(maxDT),z2.));
	_year =  year(maxDT);
	_day = day(maxDT);
	maxDT2 = compress(_month||"/"||_day||"/"||_year);
	rdate = today()*1;
	reportdate = put(rdate,WORDDATE.);
	call symputx('reportdate',reportdate);
	call symputx('main_title',title_);
	call symputx('maxDT2',maxdt2);
run;
%put NOTE: main title = &main_title  &maxDT2   &reportdate; 
%PUT &STDT;

ods results off;
ods listing close;
ods html close;

%macro report();

ods tagsets.tableeditor file="m:\&client\Programs\CIETL\hospital\DQ_hospital_report\&client._HOSPITAL_DQ_REPORT_&reportdate..html" /*style = SASWeb*/

options(
/*Formatting HTML page*/
web_tabs = "RECORD & VISIT COUNTS, SVCDT ANALYSIS, VARIABLE ANALYSIS,  SEX, AGE RANGES, MAJCAT, REVCODE,PROCCD,
						TYPE OF SERVICE, INVALID SSN, SENSITIVE CLAIMS, OUTLIER SUMMARY"
rowheader_bgcolor="#808080"
rowheader_fgcolor="black"
header_bgcolor="gray"
header_fgcolor="BLACK"
background_color="#333333"
data_bgcolor="#C0C0C0"
gridline="YES"
title_size="20pt"
highlight_color="yellow"
BUTTON_TEXT = "Generate Graph"

/*EXCEL FEATURES*/
sheet_name = "Sheet1"
EXCEL_TABLE_MOVE = "1"
excel_autofilter="yes"
excel_frozen_headers="yes"
EMBEDDED_TITLES="yes"
macro="'m:\\stlukes\\testing\\Gmacro.xlsm'!Gmacro"
/*doc = 'help'*/
); 
	title c="#C0C0C0" h=1.75 j=r BCOLOR= "#333333" font = bold "REPORT CREATE DATE &SYSDATE.";
	title2 c="#C0C0C0" BCOLOR= "#333333" "&main_title";
%if &stats3 ge 1 %then %do;
	title3 c="#C0C0C0"  j = C BCOLOR= "#333333" "EXPORT TO VIEW GRAPH";
	title4 c="#C0C0C0" BCOLOR= "#333333" "HIGHLIGHTED ROWS INDICATE CLAIM COUNT OUTLIERS";
	title5 c="#C0C0C0"  BCOLOR= "#333333" "CLAIM COUNTS BY MONTH          +          UNIQUE VISIT COUNTS BY MONTH";
	title6 c="#333333" bcolor = "#333333" " ";
	title7 c="#C0C0C0"  BCOLOR= "#333333" H=2 font = bold "OUTLIER:  ANY VALUE GREATERTHAN OR LESSTHAN 1.5*(IQR)";
	proc report data = claims nowd headline ;
		column svcdt2 	inpatient_count inpatient_outlier outpatient_count outpatient_outlier emergency_count emergency_outlier	other_count other_outlier  all_claims all_claims_outlier
									divider visit_ip_count visit_ip_outlier visit_op_count visit_op_outlier visit_er_count visit_er_outlier visit_other_count visit_other_outlier;
		define svcdt2 / 'MONTH - YEAR' display ;
		compute svcdt2;
			call define(_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD  FOREGROUND = BLACK]") ;
		endcomp;
		%if &ip_count ge 1 %then %do;
			define inpatient_count / 'IP RECORDS' display;
			define inpatient_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &ip_count = 0 %then %do;
			define inpatient_count / 'IP RECORDS' display noprint;
		%end;
		%if &OP_count ge 1 %then %do;
			define outpatient_count / 'OP RECORDS' display;
			define outpatient_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &OP_count = 0 %then %do;
			define outpatient_count / 'OP RECORDS' display noprint;
		%end;
		%if &ER_count ge 1 %then %do;
			define emergency_count / 'ER RECORDS' display;
			define emergency_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &ER_count = 0 %then %do;
			define emergency_count / 'ER RECORDS' display noprint;
			define emergency_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &other_count ge 1 %then %do;
			define other_count / 'OTHER RECORDS' display;
			define other_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &other_count = 0 %then %do;
			define other_count / 'OTHER RECORDS' display noprint;
			define other_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		define all_claims / 'TOTAL RECORDS' display;
		define all_claims_outlier / display noprint;
		compute all_claims_outlier;
			if (all_claims_outlier ge 1 or all_claims = 0) then call define('all_claims', 'style', 'style=[background=light red]');
		endcomp;
		compute inpatient_outlier;
			if (inpatient_outlier ge 1 or inpatient_count = 0) then call define ('inpatient_count','style', 'style=[background=light red]');
		endcomp;
		compute outpatient_outlier;
			if (outpatient_outlier ge 1 or outpatient_count = 0 ) then call define ('outpatient_count','style', 'style=[background=light red]');
		endcomp;
		compute emergency_outlier;
			if (emergency_outlier ge 1 or emergency_count = 0) then call define ('emergency_count','style', 'style=[background=light red]');
		endcomp;
		compute other_outlier;
			if (other_outlier ge 1 or other_count = 0) then call define ('other_count','style', 'style=[background=light red]');
		endcomp;
		
		define divider / "+" display;
		COMPUTE DIVIDER;
			call define ('DIVIDER','style', 'style=[background=black]');
		endcomp;

		%if &visit_ip ge 1 %then %do;
			define visit_ip_count / 'IP ADMIT COUNTS' display;
			define visit_ip_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &visit_ip = 0 %then %do;
			define visit_ip_count / 'IP VISIT COUNTS' display noprint;
		%end;
		%if &visit_op ge 1 %then %do;
			define visit_op_count / 'OP VISIT COUNTS' display;
			define visit_op_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &visit_op = 0 %then %do;
			define visit_ip_count / 'OP VISIT COUNTS' display noprint;
		%end;
		%if &visit_er ge 1 %then %do;
			define visit_er_count / 'ER VISIT COUNTS' display;
			define visit_er_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &visit_er = 0 %then %do;
			define visit_er_count / 'ER VISIT COUNTS' display noprint;
			define visit_er_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &visit_other ge 1 %then %do;
			define visit_other_count / 'OTHER VISIT COUNTS' display;
			define visit_other_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		%if &visit_other = 0 %then %do;
			define visit_other_count / 'OTHER VISIT COUNTS' display noprint;
			define visit_other_outlier / 'OUTLIER' CENTER STYLE = {JUST = C} display noprint;
		%end;
		
		compute visit_op_outlier;
			if (visit_op_outlier ge 1 or visit_op_count = 0) then call define ('visit_op_count','style', 'style=[background=light red]');
		endcomp;
		compute visit_ip_outlier;
			if (visit_ip_outlier ge 1 or visit_ip_count = 0) then call define ('visit_ip_count','style', 'style=[background=light red]');
		endcomp;
		compute visit_er_outlier;
			if (visit_er_outlier ge 1 or visit_er_count = 0) then call define ('visit_er_count','style', 'style=[background=light red]');
		endcomp;
		compute visit_other_outlier;
			if (visit_other_outlier ge 1 or visit_other_count = 0) then call define ('visit_other_count','style', 'style=[background=light red]');
		endcomp;
	run;
	title6;
	title7;
%end;
%if &stats3 le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;
	title3 c="#C0C0C0"  BCOLOR= "#333333" "SVCDT ANALYSIS";
	title4 c="#C0C0C0"  BCOLOR= "#333333" "MAX SVCDT = &maximum        MIN SVCDT = &minimum";
	
	%IF &invalidmax ge 1 or &invalidmin ge 1 %then %do;
		proc report data = validdates nowd;
			column svcdt count percent;
			define svcdt / 'INVALID SVCDT VALUE' display;
			compute svcdt;
				call define (_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
			endcomp;
			define count / 'INVALID DATE COUNT' display;
			define percent / 'INVALID DATE %' display format=percent7.0;
		run;
	%end;

	%if &invalidmax ne 1 and &invalidmin ne 1 %then %do;
		proc report data = validdates nowd;
			column message;
			define message / 'MESSAGE' display STYLE = {JUST = C};
		run;
	%end;

	title3 c="#C0C0C0"  BCOLOR= "#333333" "VARIABLE POPULATION ANALYSIS MISSING COUNTS & PERCENTS";
	title4 c="#C0C0C0"  BCOLOR= "#333333" "CURRENT PERIOD &STDT.  TO &MAXdt2.";
	title5 BCOLOR= "#333333" c="#333333" " ";
	title6 c="#C0C0C0"  BCOLOR= "#333333" H=2 font = bold "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";
%if &all1 ge 1 %then %do;
	proc report data = &client._all1 nowd;
		column var1 direction vdirection outlier voutlier
					  count_inpatient /*total_inpatient*/ percent_inpatient
					  count_outpatient /*total_outpatient*/ percent_outpatient
					  count_emergency /*total_emergency*/ percent_emergency
					  count_other /*total_other*/ percent_other
					  totalmissing total totalpercent
					  /*ptotalmissing*/ ptotalpercent 
					  change
					  valence_average 
					  vchange;

		define var1 / 'VARIABLE' display;
		compute var1;
			call define(_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]") ;
		endcomp;
		%if &ip_count ge 1 %then %do;
			define count_inpatient / 'IP MISSING COUNT' display;
/*			define total_inpatient / 'IP TOTAL' display;*/
			define percent_inpatient / 'IP MISSING %' display FORMAT=percent7.0;
			compute count_inpatient;
				call define(_col_, "style", "style = [background = #9999FF]") ;
			endcomp;
/*			compute total_inpatient;*/
/*				call define(_col_, "style", "style = [background = #9999FF]") ;*/
/*			endcomp;*/
			compute percent_inpatient;
				call define(_col_, "style", "style = [background = #9999FF]") ;
			endcomp;
		%end;
		%if &ip_count = 0 %then %do;
			define count_inpatient / 'IP' display NOPRINT;
/*			define total_inpatient / 'IP TOTAL' display NOPRINT;*/
			define percent_inpatient / 'IP %' display NOPRINT;
		%end;
		%if &op_count ge 1 %then %do;
			define count_outpatient / 'OP MISSING COUNT' display;
/*			define total_outpatient / 'OP TOTAL' display;*/
			define percent_outpatient / 'OP MISSING %' display FORMAT=percent7.0;
			compute count_outpatient;
				call define(_col_, "style", "style = [background = LIGHTGREEN]") ;
			endcomp;
/*			compute total_outpatient;*/
/*				call define(_col_, "style", "style = [background = LIGHTGREEN]") ;*/
/*			endcomp;*/
			compute percent_outpatient;
				call define(_col_, "style", "style = [background = LIGHTGREEN]") ;
			endcomp;
		%end;
		%if &op_count = 0 %then %do;
			define count_outpatient / 'OP' display NOPRINT;
/*			define total_outpatient / 'OP TOTAL' display NOPRINT;*/
			define percent_outpatient / 'OP %' display NOPRINT;
		%end;
		%if &ER_count ge 1 %then %do;
			define count_emergency / 'ER MISSING COUNT' display;
/*			define total_emergency / 'ER TOTAL' display;*/
			define percent_emergency / 'ER MISSING %' display FORMAT=percent7.0;
			compute count_emergency;
				call define(_col_, "style", "style = [background = #00FFFF]") ;
			endcomp;
/*			compute total_emergency;*/
/*				call define(_col_, "style", "style = [background = #00FFFF]") ;*/
/*			endcomp;*/
			compute percent_emergency;
				call define(_col_, "style", "style = [background = #00FFFF]") ;
			endcomp;
		%end;
		%if &ER_count = 0 %then %do;
			define count_emergency / 'ER' display NOPRINT;
/*			define total_emergency / 'ER TOTAL' display NOPRINT;*/
			define percent_emergency / 'ER %' display NOPRINT;
		%end;
		%if &other_count ge 1 %then %do;
			define count_other / 'OTHER MISSING COUNT' display;
/*			define total_other / 'OTHER TOTAL' display;*/
			define PERCENT_other / 'OTHER MISSING %' display FORMAT=percent7.0;
			compute count_other;
				call define(_col_, "style", "style = [background = #CCFFCC]") ;
			endcomp;
/*			compute total_other;*/
/*				call define(_col_, "style", "style = [background = #CCFFCC]") ;*/
/*			endcomp;*/
			compute PERCENT_other;
				call define(_col_, "style", "style = [background = #CCFFCC]") ;
			endcomp;
		%end;
		%if &other_count = 0 %then %do;
			define count_other / 'OTHER' display NOPRINT;
/*			define total_other / 'OTHER' display NOPRINT;*/
			define percent_other / 'OTHER %' display NOPRINT ;
		%end;

		define TOTALMISSING / 'OVERALL MISSING COUNT' display;
		define total / 'TOTAL' display ;
		define TOTALPERCENT / 'CURRENT OVERALL MISSING %' display FORMAT=percent7.0;
/*		define ptotalmissing / 'PRIOR' display noprint;*/
		define ptotalpercent / 'PRIOR OVERALL MISSING %' display format=percent7.0;
		define outlier / 'OUTLIER' display noprint;
		define valence_average / 'VALENCE AVERAGE' display format=percent7.0;
		define voutlier / 'VALENCE OUTLIER' display noprint;
		define change / 'CLIENT % DIFF' display format=percent7.0;
		compute change;
			if outlier ge 1 then do;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=green]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define vchange / 'VALENCE % DIFF' display  format=percent7.0;
		compute vchange;
			if voutlier ge 1 then do;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=green]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define direction / noprint;
		define vdirection / noprint;
	run;
%end;
%if &all1 le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;

	title3 c="#C0C0C0"  BCOLOR= "#333333" "GENDER ANALYSIS PERIOD COUNTS AND PERCENTS";
	title4 c="#C0C0C0" BCOLOR= "#333333"  "CURRENT PERIOD &STDT.  TO &MAXdt2.";
	title5 BCOLOR= "#333333" c="#333333" " ";
	title6 c="#C0C0C0"  BCOLOR= "#333333" h=2 font = bold "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";

%if &gender ge 1 %then %do;
	proc sort data = gender OUT = G; by descending count ; run;
	proc report data = G nowd;
		column sex  outlier voutlier direction vdirection count percent /*pcount*/ ppercent change valence_average vchange;
		define sex / 'SEX' display;
		compute sex;
			call define (_col_, "style", "Style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
		endcomp;
		define count / 'CURRENT COUNT' display;
		define percent / 'CURRENT %' display format=percent7.0;
/*		define pcount / 'PRIOR' display NOPRINT;*/
		define ppercent / 'PRIOR %'  display format=percent7.0;
		define outlier / 'OUTLIER' display noprint;
		define valence_average / 'VALENCE AVERAGE' display format=percent7.0;
		define voutlier / 'VALENCE OUTLIER' display noprint;
				define change / 'CLIENT % DIFF'  display format=percent7.0;
		compute change;
			if outlier ge 1 then do;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define vchange / 'VALENCE % DIFF' display  format=percent7.0;
		compute vchange;
			if voutlier ge 1 then do;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define direction / noprint;
		define vdirection / noprint;
	run;
%end;
%if &gender le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;
	title3 c="#C0C0C0"  BCOLOR= "#333333" "AGE RANGE ANALYSIS PERIOD COUNTS AND PERCENTS";
	title4 c="#C0C0C0" BCOLOR= "#333333"  "CURRENT PERIOD &STDT.  TO &MAXdt2.";
	title5 BCOLOR= "#333333" c="#333333" " ";
	title6 c="#C0C0C0"  BCOLOR= "#333333" h=2 font = bold "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";

%if &agerange ge 1 %then %do;
	proc report data = &client._agerange nowd;
		column DISPLAY outlier voutlier direction vdirection count percent ppercent change valence_average vchange;
		define DISPLAY / 'AGE GROUPING' display;
		compute DISPLAY;
			call define (_col_, "style", "Style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
		endcomp;
		define count / 'CURRENT AGE GROUPING COUNT' display;
		define percent / 'CURRENT AGE GROUPING %' display format=percent7.0;
		define ppercent / 'PRIOR AGE GROUPING %' display format=percent7.0;
		define outlier / 'OUTLIER' display noprint;
		define valence_average / 'VALENCE AVERAGE' display format=percent7.0;
		define voutlier / 'VALENCE OUTLIER' display noprint;
				define change / 'CLIENT % DIFF'  display format=percent7.0;
		compute change;
			if outlier ge 1 then do;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define Vchange / 'VALENCE % DIFF'  display  format=percent7.0;
		compute vchange;
			if voutlier ge 1 then do;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define direction / noprint;
		define vdirection / noprint;
	run;
%end;
%if &agerange le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;
	title3 c="#C0C0C0"  BCOLOR= "#333333" "MAJCAT ANALYSIS PERIOD COUNTS AND PERCENTS";
	title4 c="#C0C0C0"  BCOLOR= "#333333" "CURRENT PERIOD &STDT.  TO &MAXdt2.";
	title5 BCOLOR= "#333333" c="#333333" " ";
	title6 c="#C0C0C0"  BCOLOR= "#333333" h=2 font = bold "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";
%if &majcats2 ge 1 %then %do;
	proc sort data = majcats2 OUT = M; by descending count ; run;
	proc report data = M nowd;
		column majcat outlier voutlier direction vdirection count percent /*pcount*/ ppercent change valence_average vchange;
		define majcat / 	'MAJCAT' display;
		compute majcat;
			call define(_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
		endcomp;
		define count / order order=freq 'CURRENT COUNT' display;
		define percent / 'CURRENT %' display format=percent7.0;
/*		define pcount / 'PRIOR' display noprint;*/
		define ppercent / 'PRIOR %' display format=percent7.0;
		define outlier / 'OUTLIER' display noprint;
		define valence_average / 'VALENCE AVERAGE' display format=percent7.0;
		define voutlier / 'VALENCE OUTLIER' display noprint;
				define change / 'CLIENT % DIFF'  display format=percent7.0;
		compute change;
			if outlier ge 1 then do;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define Vchange / 'VALENCE % DIFF'  display  format=percent7.0;
		compute vchange;
			if voutlier ge 1 then do;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define direction / noprint;
		define vdirection / noprint;
	run;
%end;
%if &majcats2 le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;
	title3 c="#C0C0C0"  BCOLOR= "#333333" "MAJCAT ANALYSIS PERIOD GROUP COUNTS AND PERCENTS";
	title4 c="#C0C0C0" BCOLOR= "#333333"  "CURRENT PERIOD &STDT.  TO &MAXdt2.";
	title5 BCOLOR= "#333333" c="#333333" " ";
	title6 c="#C0C0C0"  BCOLOR= "#333333" h=2 font = bold "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";
%if &revcd ge 1 %then %do;
	proc sort data = revcd OUT = R; by descending count; run;
	proc report data = R nowd;
		column desc outlier voutlier direction vdirection count percent /*pcount*/ ppercent change valence_average vchange;
		define desc / 'REVCODE GROUP' display;
		compute desc;
			call define (_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
		endcomp;
		define count / 'CURRENT COUNT' display;
		define percent / 'CURRENT %' display format=percent7.0;
/*		define pcount / 'PRIOR' display NOPRINT;*/
		define ppercent / 'PRIOR %' display format=percent7.0;
		define outlier / 'OUTLIER' display noprint;
		define valence_average / 'VALENCE AVERAGE' display format=percent7.0;
		define voutlier / 'VALENCE OUTLIER' display noprint;
				define change / 'CLIENT % DIFF'  display format=percent7.0;
		compute change;
			if outlier ge 1 then do;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define Vchange / 'VALENCE % DIFF'  display  format=percent7.0;
		compute vchange;
			if voutlier ge 1 then do;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define direction / noprint;
		define vdirection / noprint;
	run;
%end;
%if &revcd le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;
	title3 c="#C0C0C0" BCOLOR= "#333333"  "PROCEDURE CODE ANALYSIS PERIOD RANGE COUNTS AND PERCENTS";
	title4 c="#C0C0C0"  BCOLOR= "#333333" "CURRENT PERIOD &STDT.  TO &MAXdt2.";
	title5 BCOLOR= "#333333" c="#333333" " ";
	title6 c="#C0C0C0"  BCOLOR= "#333333" h =2 font = bold "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";
%if &proccd %then %do;
	proc report data = &client._proccd nowd;
		where count ge 1;
		column range outlier voutlier direction vdirection group count percent ppercent change valence_average vchange;
		define range / 'CODE RANGE' display;
		compute range;
			call define (_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
		endcomp;
		define group / 'CODE RANGE GROUPING' display;
		define count / 'CURRENT CODE COUNT' display;
		define percent / 'CURRENT CODE %'  format=percent7.0 display;
		define ppercent / 'PRIOR CODE %' format=percent7.0 display;
		define outlier / 'OUTLIER' display noprint;
		define valence_average / 'VALENCE AVERAGE' display format=percent7.0;
		define voutlier / 'VALENCE OUTLIER' display noprint;
				define change / 'CLIENT % DIFF'  display format=percent7.0;
		compute change;
			if outlier ge 1 then do;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define Vchange / 'VALENCE % DIFF'  display  format=percent7.0;
		compute vchange;
			if voutlier ge 1 then do;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define direction / noprint;
		define vdirection / noprint;
	run;
%end;
%if &proccd le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;
	title3 c="#C0C0C0"  BCOLOR= "#333333" "PLACE OF SERVICE ANALYSIS PERIOD COUNTS AND PERCENTS";
	title4 c="#C0C0C0" BCOLOR= "#333333"  "CURRENT PERIOD &STDT.  TO &MAXdt2.";
	title5 BCOLOR= "#333333" c="#333333" " " ;
	title6 c="#C0C0C0"  BCOLOR= "#333333" h=2 font = bold "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";
%if &pos ge 1 %then %do;
	proc report data = &client._pos nowd;
		column pos outlier voutlier direction vdirection count percent /*pcount*/ ppercent change valence_average vchange;
		define pos / 'TYPE OF SERVICE' display;
		compute pos;
			call define (_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
		endcomp;
		define count / 'CURRENT COUNT' display;
		define percent / 'CURRENT %' format=percent7.0 display;
/*		define pcount / 'PRIOR' display noprint;*/
		define ppercent / 'PRIOR %' display format=percent7.0;
		define outlier / 'OUTLIER' display noprint;
 		define valence_average / 'VALENCE AVERAGE' display format=percent7.0;
		define voutlier / 'VALENCE OUTLIER' display noprint;
				define change / 'CLIENT % DIFF'  display format=percent7.0;
		compute change;
			if outlier ge 1 then do;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define Vchange / 'VALENCE % DIFF'  display  format=percent7.0;
		compute vchange;
			if voutlier ge 1 then do;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
			end;
		endcomp;
		define direction / noprint;
		define vdirection / noprint;
	run;
%end;
%if &pos le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;
	%if &ssnOBS ge 1 %then %do;
		title3 c="#C0C0C0"  BCOLOR= "#333333" "SSN VALIDATION";
		title4 c="#C0C0C0" BCOLOR= "#333333"  "UNIQUE NUMBER OF INVALID SSN = &ssnOBS";
		title5 c="#C0C0C0" BCOLOR= "#333333"  "CURRENT PERIOD &STDT.  TO &MAXdt2.";
		proc report data = SSN1 nowd;
			column badtype count percent;
			define badtype / 'INVALID VALUE AND TYPE' display;
			define count / 'COUNT' display;
			define percent / 'PERCENT' DISPLAY FORMAT = percent7.0;
			compute percent;
				percent = count / &subtotal;
			endcomp;
		run;
	%end;

	%else %if &ssnOBS le 0 %then %do;
		title3 c="#C0C0C0" BCOLOR= "#333333"  "SSN VALIDATION";
		title4 c="#C0C0C0" BCOLOR= "#333333"  "UNIQUE NUMBER OF INVALID SSN = &ssnOBS";
		title5 c="#C0C0C0" BCOLOR= "#333333"  "CURRENT PERIOD &STDT.  TO &MAXdt2.";
		data ssnNOTE;
			message = "THERE ARE NO SSN VALUSE WITH INVALID LENGTHS OR CHARACTERS";
		RUN;
		proc report data = ssnNote nowd;
			column message;
			define message / 'MESSAGE'  style = {just = c} display;
		run;
	%END;
		title3 c="#C0C0C0" BCOLOR= "#333333"  "SENCITIVE PROCCD VALIDATION";
		title4 c="#C0C0C0"  BCOLOR= "#333333" "SENCITIVE PROCCD COUNTS AND PERCENTS BY MONTH";
		title5;
%if &sencitive ge 1 %then %do;
		proc report data = sencitive nowd;
			column svcdt proccd desc invalidgroup count percent;
			define svcdt / 'MONTH YEAR' display;
			compute svcdt;
				call define (_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
			endcomp;
			define proccd / 'PROCCD' display;
			define desc / 'PROCCD DESCRIPTION' display;
			define invalidgroup / 'INVALID GROUPING' display;
			define count / 'PROCCD COUNT' display;
			define percent / 'PROCCD %' display format=percent7.0;
		run;
%end;
%if &sencitive le 0 %then %do;
	proc report data = error nowd;
		column message;
		define message / 'MESSAGE'  style = {just = c} display;
	run;
%end;

	title3 c="#C0C0C0" BCOLOR= "#333333"  "OUTLIER SUMMARY BY TAB";
	title4 BCOLOR= "#333333" c="#333333" " ";
	title5 c="#C0C0C0"  BCOLOR= "#333333" h = 3 "OUTLIER:  ABS(CURRENT % - PRIOR %) >= 8% OR ABS(CURRENT % - VALENCE %) >= 8%";
	proc report data = summary nowd;
		column summary variable current prior valence_average direction vdirection change vchange;
		define summary / "OUTLIER CATEGORY" group ;
		compute summary;
			call define (_col_, "style", "style = [background = gray FONT_WEIGHT = BOLD FOREGROUND = BLACK]");
		endcomp;
		define variable / "OUTLIER VARIABLE / GROUPING" display;
		define current / "CURRENT %"  format = percent7.0 display;
		define prior / "PRIOR %" format = percent7.0 display;
		define valence_average / "VALENCE AVERAGE" format = percent7.0 display;
		define direction / noprint;
		define vdirection / noprint;
		define change / 'CLIENT % DIFF'  format = percent7.0 display;
		define Vchange / 'VALENCE % DIFF'  format = percent7.0 display;
		compute vchange;
				if (vdirection = 'd') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (vdirection = 'u') then 	call define ('vchange','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
		endcomp;
		compute change;
				if (direction = 'd') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
				if (direction = 'u') then 	call define ('change','style',  'style=[FONT_WEIGHT = BOLD foreground=red]');
		endcomp;
	run;

%mend;
%report;
ods _all_ close;
ods listing;
ods results on;


/*IF NO ERRORS THEN UPDATE CLIENT DATASETS and VALENCE AVERAGES*/
%if &stats3 ge 1 and &validdates ge 1 and &all1 ge 1 and &gender ge 1 and &agerange ge 1 and &majcats2 ge 1 &revcd ge 1 
	  and &proccd ge 1 and &pos ge 1 and &sencitive ge 1 %then %do;

	  data client.&client._all1 (KEEP = VAR1 TOTAL totalPERCENT);
	  	set &client._all;
	  run;

	  data client.&client._proccd (KEEP = coderange TOTAL PERCENT);
	  	set &client._proccd;
	  run;

	  data client.&client._majcats2 (KEEP = MAJCAT TOTAL PERCENT);
	  	set majcats2;
	  run;

	  data client.&client._gender (KEEP = SEX TOTAL PERCENT);
	  	set gender;
	  run;

	  data client.&client._pos (KEEP = POS TOTAL PERCENT);
	  	set &client._pos;
	  run;

	  data client.&client._revcd (KEEP = DESC TOTAL PERCENT);
	  	set revcd;
	  run;

	  data client.&client._agerange (KEEP = AGERANGE TOTAL PERCENT);
	  	set &client._agerange;
	  run;
/**/
	  data _null_;
	  	updated = 1;
	  	call symput('updated', updated);
	   run;
%end;
%else %do;
	data _null_;
		updated = 0;
		call symput('updated',updated);
	run;
%end;

%let emailfile=%str(M:\StLukes\programs\Auto\logs\BJC\&sysdate..log);

data _null_;
file "&emailfile." lrecl=3000;
put;
put "To: &client Analyst,";
put;
put "The &client Hospital data has been loaded.  Please review the report listed below.";
put;
put "NOTE: This report must be viewed in Internet Explorer.  Please follow the exact link below.";
put;
put "m:\&client\Programs\CIETL\hospital\DQ_hospital_report\&client._HOSPITAL_DQ_REPORT_&reportdate..html";
put;
put "-The Task Manager-";
run;

/*%let d = %str(\\sas2\&client\Programs\CIETL\hospital\DQ_hospital_report\&client._HOSPITAL_DQ_REPORT_&reportdate..html);*/
data _null_;
		rdate = today()*1;
	reportdate = put(rdate,WORDDATE.);
	call symputx('reportdate',reportdate);
run;


%email_parms(em_to=&sysuserid.@valencehealth.com,
	                    em_subject=&client. dq hosptial report,
                 	   em_msg_file=&emailfile.,
                    em_from=&sysuserid.@valencehealth.com);


		data _null_;
		x "del &emailfile.";
		run;


%if &updated ge 1 %then %do;
		  %include "M:\StLukes\testing\valence_averages.sas";
%end;
%mend dq_report_hospital;





/*%dq_report_HOSPITAL(INGALLS);*/
/*%dq_report_HOSPITAL(SLEH);*/
/*%dq_report_HOSPITAL(PHS);*/
/*%dq_report_HOSPITAL(OHG);*/
/*%dq_report_HOSPITAL(ADVENTIST);*/
