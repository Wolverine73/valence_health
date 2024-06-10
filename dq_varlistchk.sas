/*HEADER------------------------------------------------------------------------
|
| program:  DQ_VARLISTCHK.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Validate the fields in data sets create asterik and space list 
|           
| logic:    
|
| input:         
|                        
| output:    
|
| usage:    
| %VARLIST (DATA=_11.claims_51,varchk=%str(PROVNAME NPI UPIN PROVID TIN NPI2));
|
+--------------------------------------------------------------------------------
| history:  
|
| 04MAY2011 - Nick Williams - Clinical Integration  1.0.01 - Original
|             
|
+-----------------------------------------------------------------------HEADER*/
%MACRO DQ_VARLISTCHK
       (DATA
       ,VARCHK=
       )
       ;

    *---------------------------------------------------------------*
    | Prepare local and global symbol table, RC, and DEFINE
    *---------------------------------------------------------------*;
   %LOCAL RC VAR DSID I;
   %GLOBAL MACVARLISTRC VARLIST VARLIST2;
   %LET MACVARLISTRC = 0;   
   %LET VARLIST=%STR();
   %LET VARLIST2=%STR();
   %LET VLIST=%STR();
   %LET VAR=%STR();
   

    *------------------------------------------------*
    | CHECK TO SEE IF DATASET EXISTS OR NOT          |
    *------------------------------------------------*;
   %IF NOT %SYSFUNC(EXIST(&DATA)) %THEN %DO;
      %PUT ERROR: Dataset input to VARLIST does not exist;
      %LET MACVARLISTRC = 8;      
      %GOTO EXIT;
   %END;

    *------------------------------------------------*
    | OPEN THE DATASET AND CREATE VARLIST THAT HAS   |
    | THE FIRST VARIABLE NAME                        |
    *------------------------------------------------*;
   %LET DSID    = %SYSFUNC(OPEN(&DATA,I));
   %IF &DSID = 0 %THEN %DO;
      %PUT ERROR: Unable to open input dataset to VARLIST macro;
      %LET MACVARLISTRC = 8;      
      %GOTO EXIT;
   %END;

    *------------------------------------------------*
    | SPIN THROUGH THE REST OF THE VARIABLES AND     |
    | CREATE THE ENTIRE LIST                         |
    *------------------------------------------------*;
   %DO I = 1 %TO %SYSFUNC(ATTRN(&DSID,NVARS));
       %LET VAR = %SYSFUNC(VARNAME(&DSID,&I));
	   %put &var ;
       %LET VLIST = %upcase(&VLIST) %upcase(&VAR);
   %END ;


	%let i=1;

	%DO %WHILE (%QSCAN(&VARCHK, &I, %STR( )) NE %STR());
	    %LET WORD=%QSCAN(&VARCHK, &I, %STR( ));
		%PUT WORDNAME: &WORD ;
				
		%IF %INDEX (%STR(&VLIST), %STR (&WORD)) %THEN %DO;
			%IF &VARLIST EQ %STR() %THEN %LET VARLIST =  &VARLIST&WORD;
			%ELSE %LET VARLIST = &VARLIST%STR(*)&WORD;

			%LET VARLIST2 = &VARLIST2 &WORD; *** WILL CREATE SPACE-DELIMITED LIST;
		%END;

		%PUT varlist in loop: &VARLIST ;
		%LET I=%EVAL(&I+1);

	%END;

    *------------------------------------------------*
    | CLOSE THE DATASET                              |
    *------------------------------------------------*;
   %LET MACVARLISTRC = %SYSFUNC(CLOSE(&DSID));

   %EXIT:

   %put Note: Intial vlist: &VLIST ;

   %put Note: Final Variable list: &VARLIST ;
   %put Note: Final Variable list2: &VARLIST2 ;



%MEND DQ_VARLISTCHK;
