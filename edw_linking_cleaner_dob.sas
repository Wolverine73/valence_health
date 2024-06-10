
 
%macro edw_linking_cleaner_dob(prefix);
	%if %symexist(client_id) %then %do;
		%if &client_id.=6 %then %do;
			%let cleaner_dob_nullout='30DEC1899'd,'01JAN1900'd,'01JAN1901'd,'01JAN1920'd;
		%end;
		%else %do;
			%let cleaner_dob_nullout='01JAN1900'd;
		%end;
	%end;
	%else %do;
		%let cleaner_dob_nullout='01JAN1900'd;
	%end;

	%if "&prefix." = "mem" %then %do;
		if &prefix.dob gt today() or &prefix.dob in (&cleaner_dob_nullout.) then &prefix.dob = .;
	%end;
	%else %do;
		if int((svcdt - &prefix.dob) / 365.25) ge 150 or &prefix.dob gt today() or &prefix.dob in (&cleaner_dob_nullout.) then &prefix.dob = .;
	%end;

%mend edw_linking_cleaner_dob;
