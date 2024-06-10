
/*HEADER------------------------------------------------------------------------
|
| program:  edw_provider_cleansing_rules.sas
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/


%macro edw_provider_cleansing_rules(in_dataset1=);

	%if %sysfunc(exist(&in_dataset1.))=1 %then %do ;  ** 1=yes 0=no;

		data &in_dataset1. ;
		  set &in_dataset1. ;	  

			if SPECIALTY_CODE = '' then SPECIALTY_CODE = '99';

			if &client_id. = 6 then do;
				if ci_status = 'PAR' then do;
					if clncl_int_eff_dt = . then do;
						if network_eff_dt ne . then clncl_int_eff_dt = network_eff_dt;
						else clncl_int_eff_dt = input(put('01jun2009'd,date.)||put(0,time16.6),datetime22.3);
					end;
				end;
				if ci_status = 'NONPAR' then do;
					if network_exp_dt ne . then clncl_int_exp_dt = network_exp_dt;
					else if clncl_int_eff_dt ne . then clncl_int_exp_dt = clncl_int_eff_dt - 1;
					else if network_eff_dt ne . then clncl_int_exp_dt = network_eff_dt - 1;
				end;
			end;

			if &client_id. = 5 then do;
				if clncl_int_eff_dt = . then clncl_int_eff_dt = input(put('01jan2007'd,date.)||put(0,time16.6),datetime22.3);
			end;

		run;

	%end;

%mend  edw_provider_cleansing_rules;
