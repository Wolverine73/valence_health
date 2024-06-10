
/*HEADER------------------------------------------------------------------------
|
| program:  edw_practice_addr_cleansing_rules.sas
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


%macro edw_practiceaddr_cleansing_rules(in_dataset1=);

	%if %sysfunc(exist(&in_dataset1.))=1 %then %do ;  ** 1=yes 0=no;

		data &in_dataset1.;
		set &in_dataset1.;	  
		/*NO CLEANSING RULES YET*/
		run;

	%end;

%mend edw_practiceaddr_cleansing_rules;
