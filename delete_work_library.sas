 
%macro delete_work_library ;

   proc datasets lib=work kill nolist ;
   run;
   quit;
   
%mend delete_work_library;