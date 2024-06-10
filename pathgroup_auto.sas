
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  pathgroup_auto.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  To check if a pathgroup data file is available for processing                        
|
| INPUT:   
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| Original - 07SEP2010 - Erin Murphy
|             
+-----------------------------------------------------------------------HEADER*/
%macro pathgroup_auto(Client=,pathgroupFolder=,ClientFolder=, fileindex=);
	%global LabDataCard logday today LogName;
	options noxwait;

	*SASDOC--------------------------------------------------------------------------
	| Create date parameters                                                  
	------------------------------------------------------------------------SASDOC*;
	data _null_;
	month  = put(today(),yymmn6.);
	today  = put(intnx('day',today(),0),yymmddn8.);
/*	yymon	 = put(intnx('month',today(),-1),yymmn4.);*/
	logday = put(day(today()),z2.);
	tdate = put(today(),worddate.);
	tmonth = put(month(today()),z2.);
	call symputx('month',month);
/*	call symputx('yymon',yymon);*/
	call symputx('today',today);
	call symputx('logday',logday);
	call symput ('tdate',tdate);
	call symput ('tmonth',tmonth);
	run;

	%put NOTE: &logday.;
	%put NOTE: &today.;
	%put NOTE: &month.;
/*	%put NOTE: &yymon.;*/
	%put NOTE: Day = &tdate.;
	%put NOTE: month = &tmonth.;

/*%let pathgroupFolder=%str(\\ftp\pathgroup);*/
/*%let ClientFolder=%str(\\fs\PHS\Data\Labs\PathGroup);*/
/*%let fileindex=PATHGROUP;*/
/*%let Client=PHS;*/

*SASDOC--------------------------------------------------------------------------
| Read in files on fs                                                  
------------------------------------------------------------------------SASDOC*;
	filename indata pipe "dir &ClientFolder.\*.* /b";

	Data procfiles (compress=yes) ;
		length filed $6.;
		infile indata truncover ;
		input File_Extract $100.;
		fil2read="&ClientFolder\" || File_Extract;
		infile dummy filevar=fil2read;
		filename = File_Extract;
		filed = put(input(substr(scan(File_Extract,2,"_"),1,6),yymmn6.),yymmn6.);
	run;

	proc sort data = procfiles nodupkey;
	by filed;
	run;

	data _null_;
	 set procfiles;
		by filed;
		if last.filed then do;
			call symput ('filed',filed);
			call symput ('file_name',filename);
			call symput ('latestfile',scan(substr(File_Extract,11),1,"."));

		end;
	run;
	%put &filed.;
	%put &file_name.;
	%put &latestfile;

*SASDOC--------------------------------------------------------------------------
| Read in files on ftp                                                  
------------------------------------------------------------------------SASDOC*;
	filename inftp pipe "dir &pathgroupFolder.\*.* /b";

	Data ftpfiles (compress=yes) ;
		length filedftp $6.;
		infile inftp truncover ;
		input FileExtract $100.;
		fil2read="&pathgroupFolder\" || FileExtract;
		infile dummy filevar=fil2read;
		filenameftp = FileExtract;
		filedftp = put(input(substr(scan(FileExtract,2,"_"),1,6),yymmn6.),yymmn6.);
	run;

	proc sort data = ftpfiles nodupkey;
	by filedftp;
	run;

	data _null_;
	 set ftpfiles;
		by filedftp;
		if last.filedftp then do;
			call symput ('filedftp',filedftp);
			call symput ('latestftpmonth',input(scan(substr(FileExtract,11),1,"."),yymmdd8.));
			call symput ('latestfileftp',scan(substr(FileExtract,11),1,"."));
			call symput ('ftpmonth',put(month(input(scan(substr(FileExtract,11),1,"."),yymmdd8.)),z2.));
		end;
	run;
	%put &filedftp.;
	%put &latestftpmonth;
	%put &latestfileftp;
	%put &ftpmonth;


	%if &filed. ^= &filedftp. and &ftpmonth. = &tmonth. %then %do;

	data _null_;
	 set ftpfiles;
		by filedftp;
		if last.filedftp then do;
			call symput('filename',trim(filenameftp));
			call symput('filenamenew',trim(scan(filenameftp,1,".")));
		end;
	run;	

	*SASDOC--------------------------------------------------------------------------
	| If file exists for today then execute pathgroup program,
	| and email user when completed 
	------------------------------------------------------------------------SASDOC*;
		%let LabDataCard=%str(&ClientFolder.\&filename.);
		%let LogName=%str(&Client._pathgroup_auto_&logday..txt);

		%put NOTE: Data files are being processed for pathgroup - &filenamenew. ;	
		%put NOTE: Filename    - &filename.;
		%put NOTE: FilenameNew - &filenamenew.;
		%put NOTE: LabDataCard - &LabDataCard.;
		%put NOTE: LogName     - &LogName.;
		%put NOTE: pathgroupFolder - &pathgroupFolder.;
		%put NOTE: ClientFolder - &ClientFolder.;

		data _null_;
		  x "copy &pathgroupFolder.\&filename. &ClientFolder.\&filename." ;
		run;

	%end;

	%else %if &filed. = &filedftp. %then %do;
	%put NOTE: No data files are available for pathgroup;

		data _null_;
		  abort return;
		run;
		
	%end;
%mend pathgroup_auto;

