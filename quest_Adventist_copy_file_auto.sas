
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  quest_Adventist_copy_file_auto.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  To automate the loading of Quest Lab data
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - Winnie Lee - Clinical Integration  1.0.01
|             
+-----------------------------------------------------------------------HEADER*/

%macro quest_adventist(questFolder=,ClientFolder=,FilePrefix=);

	%global LabDataCard;
	options noxwait;
	
	*SASDOC--------------------------------------------------------------------------
	| Create data parameters                                                  
	------------------------------------------------------------------------SASDOC*;
	data null01;
	month  = put(today(),yymmn6.);
	today  = put(intnx('month',today(),-1),yymmn4.);
	yymon	 = put(intnx('month',today(),-1),yymmn4.);
	logday = put(day(today()),z2.);
	call symputx('month',month);
	call symputx('yymon',yymon);
	call symputx('today',today);
	call symputx('logday',logday);
	run;

	%put NOTE: &logday.;
	%put NOTE: &today.;
	%put NOTE: &month.;

	*SASDOC--------------------------------------------------------------------------
	| Create data list of files                                                  
	------------------------------------------------------------------------SASDOC*;
	data _null_;
		x dir /b /s "c:\HyperSend Inbox" > "\\fs\Adventist\data\Quest\ListOfSavFiles";
	run;

	data Files1;
	infile "\\fs\Adventist\data\Quest\ListOfSavFiles" length=ln;
	input file $varying200. ln;
	if index(file,'AHNI2') not in (.,0);
	call symputx('file',file);
	run;

	%put &file.;

	*SASDOC--------------------------------------------------------------------------
	| Read in data list of files and determine if file exist for today                                                 
	------------------------------------------------------------------------SASDOC*;
	data Files;
	length filename $200. oldfilename $15. filenamedt $4.;
	infile "&QuestFolder.\ListOfSavFiles" dsd;
	input filename ;
	oldfilename = reverse(scan(reverse(compress(filename,' ')),1,'\'));
	filenamedt = substr(oldfilename,6,4);
	filenamenew= "&FilePrefix." || filenamedt || ".txt"; 
	if filenamedt = &today.;
	call symputx('filename',trim(filename));
	call symputx('filenamenew',trim(filenamenew));
	run;

	%let LabDataCard=%str(&QuestFolder.\&filenamenew.);

	%put NOTE: &filename.;
	%put NOTE: &filenamenew.;
	%put NOTE: &LabDataCard.;	

	*SASDOC--------------------------------------------------------------------------
	| If file exists for today then move file, execute quest program,
    | and email user when completed 
	------------------------------------------------------------------------SASDOC*;
	%if %sysfunc(fileexist(&file.)) %then %do;

		data _null_;
		  x copy "&file." "&QuestFolder.\&filenamenew." ;
		run;

	%end;

%mend quest_adventist;


options sasautos = ("M:\CI\programs\StandardMacros" sasautos);
%quest_adventist(questFolder	= %str(\\fs\adventist\data\quest),
                 ClientFolder	= %str(\\Fs\adventist\data\quest),
                 FilePrefix 	= ssnahni);
