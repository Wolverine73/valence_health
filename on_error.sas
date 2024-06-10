
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  on_error.sas
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
| 18NOV2011 - G Liu - Clinical Integration 2.0.01
|			  Added %bpm_additional_validations 
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
+-----------------------------------------------------------------------HEADER*/
 
%macro on_error(action=,err_fl_l=,em_to=,em_cc=,em_subject=,em_msg=,em_attach=, err_standard=0);

   options nosyntaxcheck;
   %global err_fl debug_flag ;
   %local prg_name0;   
   
   %if &err_fl= %then %let err_fl=0;
   %if &err_fl_l= %then %let err_fl_l=&err_fl;
   %if &action= %then %let str_action=CONTINUE;
   %else %let str_action=&action;
   
   %put NOTE: err_fl_l = &err_fl_l. ;
   %put NOTE: err_fl = &err_fl. ;
 
   data _null_;
      length prg_name0 $ 2000 program_name $ 2000;
      prg_name0 =getoption("SYSIN");
      program_name =left(prg_name0);
      call symput('program_name',TRIM(program_name));
      if prg_name0 ne '' then call symput('action',"&action RETURN");
      if program_name='' then call symput('program_name',TRIM(prg_name0)); 
   run;
   
   %if &em_subject= %then %let em_subject=%str(Error in program &program_name);
   %if &em_msg= %then %let em_msg=%str(Error in program &program_name.. &str_ACTION &program_name.. See log for detail.);
   
   %if &err_fl_l=1 %then %do; /*begin err_fl=1 */
   	
   	%put NOTE: action = &action. ;
   	%if &err_standard. = 0 %then %do;
		%bpm_additional_validations(validation_rule=50,validation_count=0);
	%end;

        %bpm_process_control(timevar=&action.);
   
        data _null_;
          put "&str_action &program_name..";
          &action.;
        run;
   
   %end; /*end err_fl=1 */	

%mend on_error;
