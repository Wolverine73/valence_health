/* User Macro Variables 
	LOG_Filepath - Enter file path of the SAS log.
	Result_folder (optional) - Enter the folder location where you want the parser result to be saved. The resulting html output
								will have the format of (Filename)_log_parser.html. If not specified, result will be saved in
								the same folder as the original LOG file.

   To invoke the macro, you can write macro in the following 2 ways: 

		%saslog_error_parser(log_filepath=M:\dw\Programs\Auto\Log Sasbi\PFKJanuaryvquestlog.log,result_folder=C:\Users\gliu\Documents\);

		%saslog_error_parser(log_filepath=M:\dw\Programs\Auto\Log Sasbi\PFKJanuaryvquestlog.log);
*/

%macro saslog_error_parser(log_filepath=,result_folder=,output_dataset=,print_result=1);
	%let result_folder=&result_folder.;
	%if %str(&output_dataset.)= %then %do;
		%let output_dataset=input_errors;
	%end;
	data _null_;
		if upcase(scan("&log_filepath.",-1,'./\')) not in ('LOG','TXT','PRN') then log_filename=scan("&log_filepath.",-1,'./\');
		else log_filename=scan("&log_filepath.",-2,'./\');
		call symput('log_filename',trim(left(log_filename)));

		if "&result_folder."="" then call symput('result_folder',substr("&log_filepath.",1,length("&log_filepath.")-length(scan("&log_filepath.",-1,'/\'))));
		else if substr("&result_folder.",length("&result_folder."),1) not in ('/','\') then call symput('result_folder',"&result_folder."||'\');
	run;

	data input_logfile;
		infile "&log_filepath." dsd lrecl=136 truncover;
		input original_logtext $136.;
		logtext=upcase(original_logtext);
		loglinenum=_n_;
		if logtext ne '';
	run;

	data &output_dataset.(keep=logfilename loglinenum original_logtext error_rank);
		format logfilename $50.;
		label logfilename='Log Filename' loglinenum='Log Line #' original_logtext='Log Text';
		set input_logfile;
		logfilename="&log_filename.";
		outind=0;
		if logtext=:'WARNING' then do;
			error_rank=5;
			if index(logtext,'CREATE TABLE STATEMENT RECURSIVELY REFERENCES THE TARGET') then ;
			else if index(logtext,'LIMIT SET BY ERRORS= OPTION REACHED') then;
			else outind=1;
			if index(logtext,'INCOMPLETE') then error_rank=error_rank-1;
			if index(logtext,'STOPPED') then error_rank=error_rank-1;
			if index(logtext,'NOT RESOLVED') then error_rank=error_rank-1;
		end;
		else if logtext=:'ERROR' then do;
			error_rank=1;
			outind=1;
		end;
		else if index(logtext,'REPEATS ') then do;
			error_rank=3;
			outind=1;
		end;
		else if index(logtext,'UNINITIALIZED') then do;
			error_rank=9;
			outind=1;
		end;

		if outind;
	run;

	%if &print_result. %then %do;
		options ls=196 pageno=1;
		proc print data=&output_dataset. nobs; 
		run;
	%end;
%mend saslog_error_parser;
