
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  labcorp_auto.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  To check if a labcorp data files is available for processing                        
|
| INPUT:   
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| Last Update - 25MAR2010 - Brandon Barber
| Last Update - 09JUN2010 - Brandon Barber
| Edited Code - 22JUN2010 - Erin Murphy
|				Changed file path for infiling 'ListOfFile.log' for Adventist from 
| 				"M:\adventist\programs\Auto\Logs\ListOfFiles.log" to "\\Fs\adventist\data\LabCorp"
| Addition    - 07SEP2010 - Erin Murphy
|				Added PHS to conditional logic regarding fileprefix macro
|Addition = 12DEC10-Tara Kalra
|				StLukes has same date convention as PHS so code modified to use PHS date
|             
+-----------------------------------------------------------------------HEADER*/

%macro labcorp_auto(LabcorpFolder=,ClientFolder=,FilePrefix=);

	%global LabDataCard logday today LogName;
	options noxwait;

	*SASDOC--------------------------------------------------------------------------
	| Create date parameters                                                  
	------------------------------------------------------------------------SASDOC*;
	data _null_;
	  month  = put(today(),$yymmn6.);
	  today  = put(intnx('day',today(),0),$yymmdd6.);
	  phstoday  = put(intnx('day',today(),0),$mmddyy6.);
	  monyy  = put(intnx('month',today(),-1),$monyy7.);
	  logday = put(day(today()),z2.);
	  call symputx('month',month);
	  call symputx('monyy',monyy);
	  call symputx('today',today);
	  call symputx('phstoday',phstoday);
	  call symputx('logday',logday);
	run;	

	%put NOTE: &logday.;
	%put NOTE: &today.;
	%put NOTE: &phstoday.;
	%put NOTE: &month.;
	%put NOTE: &monyy.;

	*SASDOC--------------------------------------------------------------------------
	| Create data list of files                                                  
	------------------------------------------------------------------------SASDOC*;
/*%let LabcorpFolder=%str(\\fs\ssh\LabCorp);*/
/*%let ClientFolder=%str(\\fs\PHS\Data\Labs\Labcorp);*/
/*%let FilePrefix=PHS;*/

	data _null_;
	  x "dir /b  &LabcorpFolder.\* >  &ClientFolder.\ListOfFiles.log";
	run;

	*SASDOC--------------------------------------------------------------------------
	| Read in data list of files and determine if file exist for today                                                 
	------------------------------------------------------------------------SASDOC*;

%if "&FilePrefix." = "STLUKES" %then %let infile = \\fs\stlukes\Data\Labs\Labcorp\ListOfFiles.log;
%else %if "&FilePrefix." = "PHS" %then %let infile = \\fs\PHS\Data\Labs\Labcorp\ListOfFiles.log;
%else %let infile = \\fs\Adventist\data\LabCorp\ListOfFiles.log;

	%let filename=X;
	data Files;
	  length filename filenamenew $200 String1 $50 String2 $50 String3 $6;
	  infile "&infile." lrecl=32767;
	  input filename ;
	  string1 = scan(filename,1,"_");
	  string2 = scan(filename,2,"_");
	  string3 = substr(String2,1,6);
	  if upcase(string1) = "ADVENTS" then filenamenew=trim(left(string1))||"_&monyy._"||trim(left(string2)); 
	  else filenamenew=trim(left(string1))||"_&month._"||trim(left(string2)); 
	  if (string1 = "&FilePrefix." and string3 = "&phstoday.");
	  call symputx('filename',trim(filename));
	  call symputx('filenamenew',trim(filenamenew));
	run;	


	*SASDOC--------------------------------------------------------------------------
	| If file exists for today then copy file, execute labcorp program,
	| and email user when completed 
	------------------------------------------------------------------------SASDOC*;
	%if &filename. = X %then %do;
	
		%put NOTE: No data files are available for Labcorp - &FilePrefix. ;

		data _null_;
		  abort return;
		run;
		
	%end;	
	%else %if %sysfunc(fileexist(\\fs\ssh\LabCorp\&filename.)) %then %do;
		
		%let LabDataCard=%str(&ClientFolder.\&filenamenew.);
		%let LogName=%str(&FilePrefix._labcorp_auto_&logday..log);

		%put NOTE: Data files are being processed for Labcorp - &FilePrefix. ;	
		%put NOTE: Filename    - &filename.;
		%put NOTE: FilenameNew - &filenamenew.;
		%put NOTE: LabDataCard - &LabDataCard.;
		%put NOTE: LogName     - &LogName.;

		data _null_;
		  x "copy &LabcorpFolder.\&filename. &ClientFolder.\&filenamenew." ;
		run;

	%end;

%mend labcorp_auto;



