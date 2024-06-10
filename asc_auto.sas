
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  asc_auto.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  To check if an asc data file is available for processing                        
|
| INPUT:   
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| Original - 10SEP2010 - Erin Murphy
|             
+-----------------------------------------------------------------------HEADER*/
%macro asc_auto(Client=,ascFolder=,ClientFolder=, fileindex=);
	%global LabDataCard logday today month filemonth LogName tdate;
	options noxwait;

	*SASDOC--------------------------------------------------------------------------
	| Create date parameters                                                  
	------------------------------------------------------------------------SASDOC*;
	data _null_;
	month  = put(today(),yymmn6.);
	today  = put(intnx('day',today(),0),yymmddn8.);
	filemonth  = put(intnx('month',today(),-1),yymmn6.);
/*	yymon	 = put(intnx('month',today(),-1),yymmn4.);*/
	logday = put(day(today()),z2.);
	tdate = put(today(),worddate.);
	call symputx('month',month);
/*	call symputx('yymon',yymon);*/
	call symputx('today',today);
	call symputx('filemonth',filemonth);
	call symputx('logday',logday);
	call symput ('tdate',tdate);
	run;

	%put NOTE: &logday.;
	%put NOTE: &today.;
	%put NOTE: &month.;
	%put NOTE: &filemonth.;
	%put NOTE: Day = &tdate.;
/*	%put NOTE: &yymon.;*/

	*SASDOC--------------------------------------------------------------------------
	| Create data list of files                                                  
	------------------------------------------------------------------------SASDOC*;

/*%let ascFolder=%str(\\ftp\HHCS3);*/
/*%let ClientFolder=%str(\\fs\PHS\Data\Hospital\ASC\Current);*/
/*%let fileindex=HHCS_ASC;*/
/*%let Client=PHS;*/

	data _null_;
	x dir /b  "&ascFolder." > "&ClientFolder.\ListOfFiles.log";
	run;

	*SASDOC--------------------------------------------------------------------------
	| Read in data list of files and determine if file exist for today                                                 
	------------------------------------------------------------------------SASDOC*;
	%let filename=X;
	data Files;
	  length filename filenamenew $50.;* String1 $20. String2 $25. String3 $6.;
	  infile "&ClientFolder.\ListOfFiles.log" lrecl=100 truncover;
	  input filename;
	  if substr(filename,1,8) = "&fileindex." and substr(filename,10,6) = "&filemonth." then do;
		filenamenew = scan(filename,1,".");
		output;
		call symputx('filename',trim(filename));
		call symputx('filenamenew',trim(filenamenew));
	  end;
	run;	

	*SASDOC--------------------------------------------------------------------------
	| If file exists for today then execute asc program,
	| and email user when completed 
	------------------------------------------------------------------------SASDOC*;
	%if (&filename. = X) or (%sysfunc(fileexist(&ascFolder.\&filename.)) = 1 and %sysfunc(fileexist(&ClientFolder.\&filename.)) = 1) %then %do;
	
		%put NOTE: No data files are available for asc;

		data _null_;
		  abort return;
		run;
		
	%end;

	%else %if %sysfunc(fileexist(&ascFolder.\&filename.)) %then %do;
		%let LabDataCard=%str(&ClientFolder.\&filename.);
		%let LogName=%str(&Client._asc_auto_&logday..txt);

		%put NOTE: Data files are being processed for asc - &filenamenew. ;	
		%put NOTE: Filename    - &filename.;
		%put NOTE: FilenameNew - &filenamenew.;
		%put NOTE: LabDataCard - &LabDataCard.;
		%put NOTE: LogName     - &LogName.;
		%put NOTE: ascFolder - &ascFolder.;
		%put NOTE: ClientFolder - &ClientFolder.;

		data _null_;
		  x "copy &ascFolder.\&filename. &ClientFolder.\&filename." ;
		run;

	%end;
%mend asc_auto;

