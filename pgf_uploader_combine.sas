
/*HEADER------------------------------------------------------------------------
|
| program:  pgf_uploader_combine.sas
|
| location: M:\CI\programs\standardmacros
|
| purpose:  Concatenate all the PGF Uploader datasets into 1 SAS dataset
|
| logic:    Two parmater variables
|             1.  libname_in  = the libname for the PGF uploader datasets 
|             2.  libname_out = the libname for the one concatenated uploader dataset 
|
|           Example:
|             libname uploader "M:\Adventist\sasdata\CIETL\Claims\PGF\uploader";
|             %pgf_uploader_combine(libname_in=uploader, libname_out=work);
|
| input:    PGF Uploader accepted SAS datasets
|
| output:   One SAS dataset for all the clients PGF uploader files.
|
|
+--------------------------------------------------------------------------------
| history:
|
| 25FEF2011 - Nicholas Williams  - Clinical Integration  1.0.01
|             Original
|
|
+-----------------------------------------------------------------------HEADER*/


%macro pgf_uploader_combine(libname_in=, libname_out=);
	
	proc datasets library=work nolist;
	  delete claims_pgfuploader;
	run;

	proc datasets library=&libname_out. nolist;
	  delete claims_pgfuploader;
	run;

	data list (keep=libname memname);
	  set sashelp.vtable;
	  where upcase(libname)= "%upcase(&libname_in.)"  and substr(upcase(memname),1,2) = "PM";
	run;

	data list;
	  set list ;
	run;

	data t; *_null_;
	  set list end=eof;
	  i+1;
	  ii=left(put(i,4.));
	  call symput('memname'||ii,left(trim(memname))); 
	  if eof then call symput('memname_total',ii);
	run;
	
	data claims_pgfuploader;
	  set %do z = 1 %to &memname_total;
	        &libname_in..&&memname&z   
	      %end;;
	run;

	proc contents data = claims_pgfuploader 
                  out  = contents noprint;
	run;

	proc sql noprint;
	 select name into: dropvars separated by ' '
	 from contents
	 where substr(upcase(name),1,6)='ISSUE_'
	    or substr(upcase(name),1,11)='VALIDATION_'
        or substr(upcase(name),1,1)='_';
	quit;

	%put NOTE: dropvars = &dropvars. ;


	*SASDOC --------------------------------------------------------------------
	| Diagnosis Cleansing - Exempla (pushed the code to pgf.sas)
	+--------------------------------------------------------------------SASDOC*;
 	%macro diagnosis_edits (var);
		if  index(&var.,".") ge 1 or substr(&var.,1,1) in ('V','G','E') then do;
			&var._check=1;
			&var.=&var.;
			end;
			else do;
			&var._check=0;
		end;
		if &var._check=0 then do;
			&var.x=&var.;
			if length(&var.) = 4 then &var.x = compress(&var.||"0") ;
			else if length(&var.) = 3 then &var.x = compress(&var.||"00");
			else if length(&var.) = 2 then &var.x = compress(&var.||"000");
			first_&var.=substr(&var.x,1,3);
			second_&var.=substr(&var.x,4,2);
			&var.test=compress(first_&var.||"."||second_&var.);
			&var.=&var.test;
		end;
	%mend diagnosis_edits;


	*SASDOC --------------------------------------------------------------------
	| Additional Cleansing - Exempla (pushed the code to pgf.sas)
	+--------------------------------------------------------------------SASDOC*;
	%macro cleansing;
	data claims_pgfuploader (rename = (units_a=units));
	  set claims_pgfuploader;

	  _diag1=substr((compress(diag1,'/')),1,5);
	  _diag2=substr((compress(diag2,'/')),1,5);
	  _diag3=substr((compress(diag3,'/')),1,5);

		if index(_diag1,'.') = 4 then diag1=_diag1;
		else if trim(substr(_diag1,1,1)) in ('E') then do;
		  diag1=compress(_diag1,'.'); 
		end;
		else if trim(substr(_diag1,1,1)) in ('0','1','2','3','4','5','6','7','8','9','V') then do;
			_diag1=compress(_diag1,' ');
			if length(_diag1)>3 then do;
				d1=trim(substr(_diag1,1,3));
				d2=trim(substr(_diag1,4));
			end;
			else if length(_diag1)<=3 then diag1=_diag1;
			if d1 ne "" and d2 ne "" then diag1=trim(d1)||"."||trim(d2);
			else diag1=compress(_diag1,' ');
		end;	
		else do;
			diag1=compress(_diag1,' ');
		end;

		if index(_diag2,'.') = 4 then diag2=_diag2;
		else if trim(substr(_diag2,1,1)) in ('E') then do;
		  diag2=compress(_diag2,'.'); 
		end;
		else if trim(substr(_diag2,1,1)) in ('0','1','2','3','4','5','6','7','8','9','V') then do;
			_diag2=compress(_diag2,' ');
			if length(_diag2)>3 then do;
				d1=trim(substr(_diag2,1,3));
				d2=trim(substr(_diag2,4));
			end;
			else if length(_diag2)<=3 then diag2=_diag2;
			if d1 ne "" and d2 ne "" then diag2=trim(d1)||"."||trim(d2);
			else diag2=compress(_diag2,' ');
		end;	
		else do;
			diag2=compress(_diag2,' ');
		end;

		if index(_diag3,'.') = 4 then diag3=_diag3;
		else if trim(substr(_diag3,1,1)) in ('E') then do;
		  diag3=compress(_diag3,'.'); 
		end;
		else if trim(substr(_diag3,1,1)) in ('0','1','2','3','4','5','6','7','8','9','V') then do;
			_diag3=compress(_diag3,' ');
			if length(_diag3)>3 then do;
				d1=trim(substr(_diag3,1,3));
				d2=trim(substr(_diag3,4));
			end;
			else if length(_diag3)<=3 then diag3=_diag3;
			if d1 ne "" and d2 ne "" then diag3=trim(d1)||"."||trim(d2);
			else diag3=compress(_diag3,' ');
		end;	
		else do;
			diag3=compress(_diag3,' ');
		end;

	  if substr(diag1,index(diag1,".")+1,1) = "" then diag1 = compress(diag1,".");
	  if substr(diag2,index(diag2,".")+1,1) = "" then diag2 = compress(diag2,".");
	  if substr(diag3,index(diag3,".")+1,1) = "" then diag3 = compress(diag3,".");

	  if upcase(units)='UNITS'  then units='';
	  units_a=units*1;
	run;	

	%mend cleansing;


	*SASDOC --------------------------------------------------------------------
	| Sorting logic for removing of duplicate claims
	+--------------------------------------------------------------------SASDOC*;
	data claims_pgfuploader;
	  set claims_pgfuploader;
	  drop &dropvars.;
	run;

	%let byvars = %str(memberid lname fname dob svcdt proccd mod1 descending filename descending units);

	proc sort data=claims_pgfuploader;
		by &byvars.;
	run;


	*SASDOC --------------------------------------------------------------------
	| Apply sorting logic and save final SAS dataset
	+--------------------------------------------------------------------SASDOC*;
	data &libname_out..claims_pgfuploader 
		 dups;
	  set claims_pgfuploader;
	  by  &byvars. ;
	  if first.mod1 and last.mod1 then dupcount=.;
	  else if first.mod1 then dupcount =0 ;
	  else dupcount = 1;

	  if first.mod1 then output &libname_out..claims_pgfuploader;
	  if dupcount ne . then output dups;
	run;

%mend pgf_uploader_combine ;





	


