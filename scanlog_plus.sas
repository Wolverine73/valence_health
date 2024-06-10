
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  scanlog_plus.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Scan the logs for errors, warnings, and uninitializes
|
| INPUT:    Log file
|
| OUTPUT:   Datasets - Error, Warning, Uninitialized
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             Created and updated Code to Business Requirements Specifiation for NSAP
|
|             
+-----------------------------------------------------------------------HEADER*/


%macro scanlog_plus(infile=, logcheck=);

		%put NOTE: Performing %upcase(&logcheck) scan log checks ;

		options nonotes nosymbolgen nomlogic nomprint;

		*** Scan Log for Errors/Warnings/uninitialized ***;
		%global toterr totwarn totunin ;
		
		%let toterr  = NO;
		%let totwarn = NO;
		%let totunin = NO;

		data LogErrors LogWarnings LogUninitialized ;
		   infile "&infile." missover length=lg;
		   input @;
		   input @ 1 fullline $varying250. lg;
		   if index(fullline,'ERROR:') then do;
		       output LogErrors;
		   end;
		   %do b = 1 %to 9;
			   else if index(fullline,"ERROR &b.") then do;
			       output LogErrors;
			   end;
		   %end;
		   else if index(fullline,'WARNING:') then do;
		       output LogWarnings;
		   end;
		   else if index(fullline,'uninitialized') then do;
		       output LogUninitialized;
		   end;
		run;

		data LogWarnings;
		  set LogWarnings;
		  x= index(fullline, "Multiple lengths");
		  xx= index(fullline, "was not found on DATA file.");
		  if x > 0 then delete;
		  if xx > 0 then delete;
		  drop x xx;
		run;

		data LogErrors;
		  set LogErrors;
		  x= index(fullline, "UTILITY");
		  xx= index(fullline, "These two ranges overlap");
		  if x > 0 then delete;
		  if xx > 0 then delete;
		  drop x xx;
		run;

		data _null_;
		  set LogErrors (obs=1) nobs=numobs;
		  call symput('toterr',put(numobs,8.));
		run;

		data _null_;
		  set LogWarnings (obs=1) nobs=numobs;
		  call symput('totwarn',put(numobs,8.));
		run;	
   
		%if %upcase(&logcheck.) eq ALL %then %do;
	        data _null_;
	          set LogUninitialized (obs=1) nobs=numobs;
	          call symput('totunin',put(numobs,8.));
	        run;
		%end;

		
        options notes mprint nosymbolgen nomlogic ;
        
	    %put NOTE: *****************************************************************************;
        %if &toterr ne NO %then %do;
           %put NOTE: ERRORS EXIST IN THE LOG FILE : &toterr ERRORS FOUND;
           %let err_fl=1;
        %end; 
        %else %do;
         %put NOTE: NO ERRORS IN THE LOG FILE : &toterr ERRORS FOUND;
        %end;        
   
        %if &totwarn ne NO %then %do;
           %put NOTE: WARNINGS EXIST IN THE LOG FILE : &totwarn WARNINGS FOUND;
        %end;  
        %else %do;
         %put NOTE: NO WARNINGS IN THE LOG FILE : &totwarn WARNINGS FOUND;
        %end;
        
        %if &totunin ne NO %then %do;
           %put NOTE: UNINITIALIZED VARIABLES EXIST IN THE LOG FILE : &totunin UNINITIALIZED VARIABLES FOUND;
        %end;  
        %else %do;
         %put NOTE: NO UNINITIALIZED VARIABLES IN THE LOG FILE : &totunin UNINITIALIZED VARIABLES FOUND;
        %end; 
        %put NOTE: *****************************************************************************;
        
        data x;x=1;run;

%mend scanlog_plus;

%**scanlog_plus(infile=c:\brian\bss.log, logcheck=ALL);
