
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  set_error_flag.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  To determine if a critical error has occurred durning the process
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

%macro set_error_flag(err_fl_l=,syserr_l=);

   options obs=max nosyntaxcheck nonotes;
   
   %if &err_fl_l= %then %let err_fl_l=&err_fl;
   %if &syserr_l= %then %let syserr_l=&syserr;
   
   data _null_;
      length err_fl err_fl_l syserr sqlrc sqlxrc 8;
      err_fl=&err_fl;
      err_fl_l=&err_fl_l; 
      sqlrc=0;
      sqlxrc=0;
      syserr=&SYSERR_l;  
      if syserr > 6 then syserr = syserr;
      else syserr=0;
      if getoption('obs')=0 then err_fl=1;
      err_fl=MAX(0, ABS(err_fl), ABS(err_fl_l), ABS(syserr), ABS(sqlrc), ABS(sqlxrc));
      err_fl=(err_fl >= 1);
      call symput('err_fl',TRIM(LEFT(err_fl))); 
   run;
   
   options notes;
   %put NOTE: err_fl = &err_fl;
   
%mend set_error_flag;