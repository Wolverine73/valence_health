
/*HEADER------------------------------------------------------------------------
|
| program:  edw_provpracref_cleansing_rules.sas
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


%macro edw_provpracxref_cleansing_rules(in_dataset1=);

	%if %sysfunc(exist(&in_dataset1.))=1 %then %do ;  ** 1=yes 0=no;

		data &in_dataset1.;
		set &in_dataset1.;	  
		if practice_key in (12740,12741,12743) then delete; /*Remove dummy practice records*/
		run;

	%end;

%mend edw_provpracxref_cleansing_rules;
