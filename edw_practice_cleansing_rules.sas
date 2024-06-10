
/*HEADER------------------------------------------------------------------------
|
| program:  edw_practice_cleansing_rules.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:   
|
| logic:     
|           
|
| input:               
|
| output:    
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/


%macro edw_practice_cleansing_rules(in_dataset1=);

	%if %sysfunc(exist(&in_dataset1.))=1 %then %do ;  ** 1=yes 0=no;

		data &in_dataset1.;
		set &in_dataset1.;	  
		TIN = substr(compress(TIN,'(-) '),1,9); 

		%if &client_id. = 3 %then %do; /*** STLUKES ***/
				 if tin = '741613878 SDU'  then tin = '741613878';
			else if tin = '741613878 NEUR' then tin = '741613878';
			else if tin = '741613878 FP'   then tin = '741613878';
			else if tin = '741613878 OTO'  then tin = '741613878';
			else if tin = '741613878 PMR'  then tin = '741613878';
			else if tin = '741613878 PLS'  then tin = '741613878';
		%end;

		run;

	%end;

%mend  edw_practice_cleansing_rules;
