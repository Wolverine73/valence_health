

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_vmine_data.sas
|
| LOCATION: M:\PHS\Programs\CIOPS\Guidelines
|
| PURPOSE:  Harvests the ProvSpec and Rank1, Rank2, and Rank3 from the Guideline code and saves them in a file GUIDELINES_SETUPS
|         
|
| INPUT:  Each guideline provids the Macro Varibles Rank1 Rank2 Rank3   
|
| OUTPUT:   GUIDELINES_SETUPS
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 25Jul2011 - Steve Bittner  - Clinical Integration  1.0
| 26Jul2011 - Added exeption for Cataracts PreOp
|             
|
|             
+-----------------------------------------------------------------------HEADER*/


%MACRO GET_MACROS();


   
   *SASDOC--------------------------------------------------------------------------
   | Get the Guideline Name from G6 or G6_a depending on the guideline
   |
   ------------------------------------------------------------------------SASDOC*;
%let _guideline=None;

DATA _NULL_;
format guideline $50.;
SET g6  (OBS=1);
if guideline ne '' then CALL SYMPUT('_GUIDELINE',GUIDELINE);
RUN;

%if "&_guideline"="None" %then %do;
DATA _NULL_;
format guideline $50.;
SET g6_a  (OBS=1);
if guideline ne '' then CALL SYMPUT('_GUIDELINE',GUIDELINE);
RUN;
%end;

   *SASDOC--------------------------------------------------------------------------
   | Get the PovSpec and Rank for the current Guideline
   |
   ------------------------------------------------------------------------SASDOC*;
%if "&guideline_key" = "230.1.1.0.2" %then %do;/** exception is cataracts preop - Needs ranks */;
       %let rank1="49";
	   %let rank2="XXXX";
	   %let rank3="XXXX";
	   %end;

DATA GET_VALUES;
   format client GUIDELINE $50. guideline_key $30. provspec $10. rank 1. ;

   client="&client.";
   guideline="&_guideline";
   guideline_key="&guideline_key";

  %do j=1 %to 3;
   %do i=1 %to %sysfunc(countw(&&rank&j));
	 %let t=&&%scan(&&rank&j.,&i);
     provspec=%scan(%str(&&rank&j.),&i,' ') ;
	 rank=&j.;
	 if substr(provspec,1,1) ne 'X' then output;
   %end;
%end;

run;
   *SASDOC--------------------------------------------------------------------------
   | Appends the current guidelines data onto all previous guidelines.
   |
   ------------------------------------------------------------------------SASDOC*;
%if %sysfunc(exist(TEMP.GUIDELINES_SETUPS)) %then %do;
 data TEMP.GUIDELINES_SETUPS;
  set TEMP.GUIDELINES_SETUPS GET_VALUES;
  run;
%end;
%else %do;
 data TEMP.GUIDELINES_SETUPS;
  set GET_VALUES;
  run;
%END;;
	run;
/* reset all guideline macrovariables */
%let    rank1="XXXXXX";
%let	rank2="XXXXXX";
%let	rank3="XXXXXX";
;

%mend GET_MACROS;
