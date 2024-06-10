%include 'M:\CI\programs\Development\StandardMacros\saslog_error_parser.sas';

%let client_id=8;
%let report_from_date=20120328;
%let report_thru_date=20120330;
%let report_log_folder=\\fs\exempla\reports\Logs\;

filename indata pipe "dir /b &report_log_folder.*.log"; 

data logfilesinfolder; 
	length filename $50. filedate $8. wflow_exec_id $8. client_key $3.;
	infile indata truncover;
	input File_Extract $100.;
	filename=File_Extract;
	filedate=scan(filename,-4,'._');
	if length(filedate)=8 and filedate=:'201' then do;
		wflow_exec_id=scan(filename,-3,'._');
		client_key=scan(filename,-2,'._');
		if client_key=:"&client_id." and "&report_from_date." le filedate le "&report_thru_date." then output;
	end;
run;

%let dsn_id=%sysfunc(open(logfilesinfolder));
%let dsn_nobs=%sysfunc(attrn(&dsn_id.,nobs));
%let dsn_rc=%sysfunc(close(&dsn_id.));

options mprint nosymbolgen nomlogic;
%macro dodo;
	%if &dsn_nobs. %then %do;
		%if %sysfunc(exist(report_all_error)) %then %do;
			proc datasets nolist; delete report_all_error; quit;
		%end;

		%do f=1 %to &dsn_nobs.;
			data _null_;
				set logfilesinfolder(firstobs=&f. obs=&f.);
				call symput('logfilename',filename);
			run;

			%saslog_error_parser(log_filepath=&report_log_folder.&logfilename.,print_result=0,output_dataset=outerrrpt);

			proc append base=report_all_error data=outerrrpt; run;
		%end;
	%end;
%mend dodo;
%dodo;

proc print data=report_all_error; 
	where error_rank lt 5 and index(upcase(logfilename),'GUIDELINE')=0;
run;

data critical_errors;
	set report_all_error;
	where error_rank lt 5;
run;
