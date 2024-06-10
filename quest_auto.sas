
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  quest_auto.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  To check if a quest data files is available for processing                        
|
| INPUT:   
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| Last Update - 25MAR2010 - Brandon Barber
| Last Update - 06APR2010 - Winnie Lee             
| Last Update - 19MAY2010 - Tara Kalra
| Last Update - 13SEP2010 - Erin Murphy
|				Added code for PHS
| Last Update - 06Jun2011 - Added filename to the Global list
|             
+-----------------------------------------------------------------------HEADER*/
%macro quest_auto(Client=,questFolder=,ClientFolder=, fileindex=);

	%global LabDataCard logday today LogName filename;
	options noxwait;

	*SASDOC--------------------------------------------------------------------------
	| Create date parameters                                                  
	------------------------------------------------------------------------SASDOC*;
	data _null_;
	month  = put(today(),yymmn6.);
	today  = put(today(),yymmn8.);
	yymon	 = put(intnx('month',today(),-1),yymmn4.);
	logday = put(day(today()),z2.);
	monyr = put(intnx('month',today(),-1),monyy7.);
	call symputx('month',month);
	call symputx('yymon',yymon);
	call symputx('today',today);
	call symputx('logday',logday);
	call symputx('monyr',monyr);
	run;

	%put NOTE: &logday.;
	%put NOTE: &today.;
	%put NOTE: &month.;
	%put NOTE: &yymon.;
	%put NOTE: &monyr.;


	*SASDOC--------------------------------------------------------------------------
	| Create data list of files                                                  
	------------------------------------------------------------------------SASDOC*;
	%if "&Client." = "PHS" %then %do;
		data _null_;
		x dir /b  "&questFolder." > "&ClientFolder.\ListOfFilesInFS.txt";
		run;
	%end;

	%else %do;	
		data _null_;
		x dir /b  "&ClientFolder." > "&ClientFolder.\ListOfFilesInFS";
		run;
	%end;

	*SASDOC--------------------------------------------------------------------------
	| Read in data list of files and determine if file exist for today                                                 
	------------------------------------------------------------------------SASDOC*;
	%let filename=X;
	%if "&Client." = "PHS" %then %do;
		data Files;
		  length filename filenamenew $50.;* String1 $20. String2 $25. String3 $6.;
		  infile "&ClientFolder.\ListOfFilesInFS.txt" lrecl=100 truncover;
		  input filename $1-100;
		  	  if index(filename,"&fileindex.") not in (.,0) and index(upcase(filename),"&monyr.") not in (.,0) then do;
				filenamenew = filename;
				output;
				call symputx('filename',trim(filename));
				call symputx('filenamenew',trim(filenamenew));
		  end;
		run;
	%end;

	%else %do;
	data Files;
	  length filename filenamenew $50.;* String1 $20. String2 $25. String3 $6.;
	  infile "&ClientFolder.\ListOfFilesInFS" lrecl=100 truncover;
	  input filename $1-100;
		  if index(filename,"&fileindex.") not in (.,0) and index(filename,"&yymon.") not in (.,0) then do;
			filenamenew = filename;
			output;
			call symputx('filename',trim(filename));
			call symputx('filenamenew',trim(filenamenew));
		  end;
	  run;
	%end;	

	*SASDOC--------------------------------------------------------------------------
	| If file exists for today then execute quest program,
	| and email user when completed 
	------------------------------------------------------------------------SASDOC*;
	%if &filename. = X %then %do;
	
		%put NOTE: No data files are available for quest - &Filename. ;

		data _null_;
		  abort return;
		run;
		
	%end;	
	%else %if "&Client." = "PHS" and %sysfunc(fileexist(&questFolder.\&filename.)) %then %do;
		%let LabDataCard=%str(&ClientFolder.\&filenamenew.);
		%let LogName=%str(&Client._quest_auto_&logday..log);

		%put NOTE: Data files are being processed for quest - &filenamenew. ;	
		%put NOTE: Filename    - &filename.;
		%put NOTE: FilenameNew - &filenamenew.;
		%put NOTE: LabDataCard - &LabDataCard.;
		%put NOTE: LogName     - &LogName.;

		%if %sysfunc(fileexist(&questFolder.\&filename.)) = 1 and %sysfunc(fileexist(&ClientFolder.\&filename.)) = 0 %then %do;
			data _null_;
			  x "copy &questFolder.\&filename. &ClientFolder.\&filename." ;
			run;
		%end;
		%else %do;
			%put NOTE: No data files are available for quest - &Filename. ;
				data _null_;
				  abort return;
				run;
		%end;
	%end;
	%else %if %sysfunc(fileexist(&ClientFolder.\&filename.)) %then %do;
		%let LabDataCard=%str(&ClientFolder.\&filenamenew.);
		%let LogName=%str(&Client._quest_auto_&logday..log);

		%put NOTE: Data files are being processed for quest - &filenamenew. ;	
		%put NOTE: Filename    - &filename.;
		%put NOTE: FilenameNew - &filenamenew.;
		%put NOTE: LabDataCard - &LabDataCard.;
		%put NOTE: LogName     - &LogName.;
	%end;
%mend quest_auto;
