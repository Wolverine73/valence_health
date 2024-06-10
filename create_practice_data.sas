
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_practice_data.sas
|
| LOCATION: M:\CI\programs\ClientMacros
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

%macro create_practice_data;

   %global fspipe fsdirectory sqllog;

   *SASDOC--------------------------------------------------------------------------
   | Create data set of the PM System and practice information 
   |
   ------------------------------------------------------------------------SASDOC*; 
   data step2_pmsystem;
      set step2_vmine;
      where systemid=&system and practice="&practice.";
   run;
   
   proc sort data = step2_pmsystem nodupkey;
      by vminemacro;
   run;
   
   proc sql noprint;
      select count(*) into: pmsystem_cnt
      from step2_pmsystem;
   quit;
   
   %put NOTE: pmsystem_cnt = &pmsystem_cnt. ;
   
   data _null_;
      set step2_pmsystem ;
      call symput('fspipe',trim(left(fspipe))); **in1;
      call symput('fsdirectory',trim(left(fsdirectory))); **in2;
      call symput('sqllog',trim(left(sqllog))); **sql;
      put "NOTE: " client " - " SystemID " - " systemname  ;
   run;
   
   %put NOTE: fspipe = &fspipe. ;
   %put NOTE: fsdirectory = &fsdirectory. ;
   %put NOTE: sqllog = &sqllog. ;

%mend create_practice_data; 