
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_pgf_data.sas
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

%macro create_pgf_data;   
   
   *SASDOC--------------------------------------------------------------------------
   | Creating parameters for the step 3 pgf looping process as well as
   | for the validation of missing or corrupted files.
   |
   ------------------------------------------------------------------------SASDOC*;
   data job_step_4_today;
     set job_step_4_today ;
	 pgfmacro='%'||left(trim(scan(program_name,1,'.')))||";";
   run;   

   *SASDOC--------------------------------------------------------------------------
   | Creating the macro calls for the various PM Systems and practices  
   |
   ------------------------------------------------------------------------SASDOC*; 
   proc sort data = job_step_4_today 
             out  = step3_pgfmacros (keep = pgfmacro)
             nodupkey;
     by pgfmacro;
   run;
   
   data _null_;
     set step3_pgfmacros end=eof;
     i+1;
     ii=left(put(i,4.));
     call symput('pgfmacro'||ii,trim(pgfmacro));
     if eof then call symput('pgfmacro_total',ii);
   run;
   
   
%mend create_pgf_data;