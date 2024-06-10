
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  proc_format.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  To create a format for the specific data set.
|
| LOGIC:    
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
+-----------------------------------------------------------------------HEADER*/

%macro proc_format(datain=);

   %if %sysfunc(exist(&datain.))=1 %then %do ;  ** 1=yes 0=no;
      proc format cntlin=&datain.; 
      run;   
   %end;
   %else %do; 
     %put WARNING:  Format data set &datain. does not exist.;
   %end;

%mend proc_format;

