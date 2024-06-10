
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  mvarexist.sas
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

%MACRO MVAREXIST(MVARNAME)/PBUFF;

  %LET MVARNAME=%UPCASE(%SYSFUNC(COMPRESS(&SYSPBUFF,%STR(()))));

  %*SASDOC======================================================================
  %* Check for the existence of the macro variable in SASHELP.VMACRO.  The
  %* %SYSFUNC macro function is used to execute SCL functions in order to
  %* retrieve the desired information while maintaining the calling programs
  %* datastep or proc boundaries.  The value of &MVAREXIST is set to the total
  %* number of macro variables (from &SYSPBUFF) that do exist.
  %*====================================================================SASDOC*;

  %IF "&MVARNAME"^="" %THEN %DO;

    %*** Scope the macro variables... ***;

    %GLOBAL MVAREXIST;
    %LOCAL DSID MVAR RC I;

    %*** Initialize... ***;

    %LET MVAREXIST=0;
    %LET I=1;

    %*** Process every macro variable provided... ***;

    %DO %WHILE(%SCAN("&MVARNAME",&I," ,")^=%STR( ));

      %*** Initialize loop vars... ***;

      %LET MVAR=%SCAN("&MVARNAME",&I," ,");
      %GLOBAL &MVAR._MVAREXIST;

      %LET DSID=0;
      %LET &MVAR._MVAREXIST=0;
      %LET RC=0;

      %*** Determine whether the current macvar is in SASHELP.VMACRO... ***;

      %LET DSID=%SYSFUNC(OPEN(SASHELP.VMACRO(WHERE=(NAME="%UPCASE(&MVAR)"))));
      %LET &MVAR._MVAREXIST=%EVAL(%SYSFUNC(FETCH(&DSID))+1);
      %LET RC=%SYSFUNC(CLOSE(&DSID));

      %*** Report the findings to the log, tally &MVAREXIST if necessary... ***;

      %IF &&&MVAR._MVAREXIST  %THEN %DO;
        %LET MVAREXIST=%EVAL(&MVAREXIST+1);
        %PUT NOTE: (MVAREXIST): &MVAR does exist.;
      %END;
      %ELSE %PUT NOTE: (MVAREXIST): &MVAR does NOT exist.;
      %LET I=%EVAL(&I+1);
    %END;
  %END;
  %ELSE %PUT ERROR: (MVAREXIST): NO MACRO VARIABLE NAME SPECIFIED.;
%MEND MVAREXIST;
