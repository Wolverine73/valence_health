
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  isnull.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  
|                        
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/


%MACRO ISNULL(MVARNAME)/PBUFF;

  %LET MVARNAME=%UPCASE(%SYSFUNC(COMPRESS(&SYSPBUFF,%STR(()))));

  %*SASDOC======================================================================
  %* Determine whether the macro variables are null (or %str()).  If the macro
  %* variable does not exist, it is considered to be NULL.  All "null" macro
  %* variables are tallied in &ISNULL.
  %*====================================================================SASDOC*;

  %IF &MVARNAME^= %THEN %DO;

    %*** Scope the macro variables... ***;

    %GLOBAL ISNULL;
    %LOCAL  MVAR I;

    %*** Initialize... ***;

    %LET ISNULL=0;
    %LET I=1;

    %*** Process every macro variable name provided... ***;

    %DO %WHILE(%SCAN("&MVARNAME",&I," ,")^=%STR( ));

      %LET MVAR=%SCAN("&MVARNAME",&I," ,");

      %GLOBAL &MVAR._ISNULL;
      %LET &MVAR._ISNULL=0;

      %*** If the var exists, then check to see if it is null... ***;

      %MVAREXIST(&MVAR);
      %IF &MVAREXIST %THEN %LET &MVAR._ISNULL=%EVAL(%TRIM("%bquote(&&&MVAR)")="");
      %ELSE %LET &MVAR._ISNULL=1;

      %*** If the var is null, then say so and increment &ISNULL... ***;

      %IF &&&MVAR._ISNULL %THEN %DO;
        %LET ISNULL=%EVAL(&ISNULL+1);
        %IF &MVAREXIST %THEN %PUT NOTE: (ISNULL): &MVAR is NULL.;
        %ELSE %PUT NOTE: (ISNULL): &MVAR is not defined and is considered to be NULL.;
      %END;
      %ELSE %PUT NOTE: (ISNULL): &MVAR is NOT NULL.;

      %LET I=%EVAL(&I+1);
    %END;
  %END;
  %ELSE %PUT ERROR: (ISNULL): NO MACRO VARIABLE NAME SPECIFIED.;
%MEND ISNULL;
