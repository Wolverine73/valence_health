
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  check_libname.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:   
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             Created and updated Code to Business Requirements Specifiation for NSAP
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro check_libname(lib=,dir=) ; 
   %local rc fileref ; 
   %let rc = %sysfunc(filename(fileref,&dir)) ; 
   %if %sysfunc(fexist(&fileref))  %then %do;
      libname &lib "&dir" ; 
   %end;
   %else %do ; 
      %put NOTE: Libname does not exist: &lib. - &dir. ;
   %end ; 
   %let rc=%sysfunc(filename(fileref)) ; 
%mend check_libname ;
