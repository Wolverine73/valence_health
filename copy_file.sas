
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  copy_file.sas
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

%macro copy_file(originalfile=, copyfile=) ;
   options noxwait; 
   %local rc fileref ; 
   %let rc = %sysfunc(filename(fileref,&originalfile)) ; 
   %if %sysfunc(fexist(&fileref))  %then %do;
      x copy  &originalfile. &copyfile. ;
   %end;
   %else %do ; 
      %put NOTE: Log file does not exist: &originalfile. ;
   %end ; 
   %let rc=%sysfunc(filename(fileref)) ; 
%mend copy_file ;
