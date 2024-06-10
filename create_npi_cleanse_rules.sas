
/*HEADER------------------------------------------------------------------------
|
| program:  create_npi_cleanse_rules.sas
|
| location: M:\CI\programs\EDW\standardmacros 
|
| purpose:  Create NPI cleansing rules for CIO
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/


%macro create_npi_cleanse_rules;

	data npi_cleanse_rules;
	  set cihold.npi_cleanse_rules;
	  %if %symexist(client_id) = 1 %then %do;
	    if client_key = &client_id. ;
	  %end;
	run;

	proc contents data = npi_cleanse_rules 
		      out  = contents_rules (keep=name varnum type) 
		      noprint;
	run;

	proc sort data = contents_rules;
	  by varnum;
	run;

	data contents_rules;
		set contents_rules;
		loop=scan(name,1,'_');
		variable=substr(name,8,'_');
		if upcase(loop) in ('SOURCE','TARGET');
	run;

	data _null_;
		set contents_rules end=eof;
		i+1;
		ii=left(put(i,4.));
		call symput('name'||ii, trim(name));
		call symput('var'||ii, trim(variable));
		call symput('type'||ii, trim(type));
		call symput('name_total',ii);
	run;

	data npi_cleanse_rules;
		format ifstring thenstring ifthenstring $500. ;
		set npi_cleanse_rules;
		%do rulei = 1 %to %eval(&name_total./2) ;
		  if ifstring='' then do;
			if &&name&rulei ne '' then do;
				ifstring= 
				%if &&type&rulei = 1 %then %do; 
				"if &&var&rulei= "||left(trim(&&name&rulei))||" ";
				%end;
				%else %do;
				"if &&var&rulei='"||trim(&&name&rulei)||"' ";
				%end;
			end;
		  end;
		  else do;
			if &&name&rulei ne '' then do;
				ifstring= trim(ifstring)||
				%if &&type&rulei = 1 %then %do; 
				" and &&var&rulei= "||left(trim(&&name&rulei))||" ";
				%end;
				%else %do;
				" and &&var&rulei='"||trim(&&name&rulei)||"' ";
				%end;
			end;
		  end;
		%end;
		%do rulei =  %eval(&name_total./2) %to &name_total. ;
			if &&name&rulei ne '' then do;
				thenstring= 
				%if &&type&rulei = 1 %then %do; 
				  " then &&var&rulei= "||left(&&name&rulei)||";";
				%end;
				%else %do;
				  " then &&var&rulei='"||trim(&&name&rulei)||"' ; ";
				%end;
			end;
		%end;
		ifthenstring=left(trim(ifstring))||trim(thenstring);
	run;

	data _null_;
		set npi_cleanse_rules;
		file "&cistage.\npi_cleanse_rules_&wflow_exec_id..txt";
		put ifthenstring ;
	run;

%mend create_npi_cleanse_rules;
