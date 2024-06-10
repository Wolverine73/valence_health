
%macro text_message(Developer_Initials);

	data email;
	  format initials $2. emailaddress $40.;
	  initials='bs';
	  emailaddress='8472170212@txt.att.net';
	  output;
	run;

	data _null_;
	  set email end=eof;
	  where initials = "&Developer_Initials.";
	  i+1;
	  ii=left(put(i,4.));
	  call symput('email'||ii,emailaddress);
	  if eof then call symput('total',ii);
	run;

	%put total = &total. ;
	%do i = 1 %to &total;
		filename out&i  email "&&email&i." subject = "COMPLETE: SAS Process for Valence Health";
		data _null_;
		   file out&i;
		   put #1 "The SAS program is complete.";
		   put #2 "Verify log for any problems or data issues.";
		run;
	%end;

%mend text_message;