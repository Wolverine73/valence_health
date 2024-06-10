
/*HEADER------------------------------------------------------------------------
|
| program:  dq_validate_content.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Validate the contents of data sets for the data quality process
|
| logic:    
|
| input:         
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01APR2010 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
| 24AUG2011 - Nick Williams - Clinical Integration 1.0.02
|             Added New NPI CI Participation variable.
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_validate_content(datain=, validate=);

  %if &validate = variables %then %do;

	%local datain dq_variables dq_total;
	%global  assessvariables keepvariables;

	*--------------------------------------------------------------------------------
	| List of Variables to Validate 
	+------------------------------------------------------------------------------*;	         
	%let assessvariables=MEMBERID NPI SVCDT DIAG1 PROCCD FNAME LNAME DOB SEX PHONE ADDRESS1 CITY STATE ZIP POS NPICIPAR;
	                  
	%createvarloop(list=&assessvariables., suffix=IND);
        %global  &IND.;	                  

	proc sql noprint;
	 select quote(trim(upcase(data_quality))) into: dq_variables separated by ","
	 from history.data_threshold;
	quit;

	%put dq_variables = &dq_variables;

	**intialize the variables as NO;
	data _null_;
	 set history.data_threshold end=eof;
	 indicator=upcase(trim(data_quality))||"IND" ;
	 intializevalue='NO';
         i+1;
         ii=left(put(i,4.));	 
	 call symput(indicator, intializevalue);
         call symput('dq'||ii,trim(indicator));
         if eof then call symput('dq_total',ii);	 
	run;
	
	proc contents data = &datain. 
	              out  = contents01 (keep = name) noprint;
	run; 

	proc sql noprint;
	  create table contents02 as
	  select *
	  from contents01
	  where upcase(name) in (&dq_variables.);
	quit;
	
	proc sql noprint;
	 select trim(name) into: keepvariables separated by " "
	 from contents02;
	quit;
	
	%put NOTE: keepvariables = &keepvariables.;

	data _null_;
	 set contents02 ;
	 name=upcase(name);
	 value='YES';
	 call symput(upcase(trim(name))||"IND",TRIM(LEFT(value)));
	run;
	
  %end;	
  %else %if &validate = filename %then %do;
  
	%global filename_where filename timestart timeend;
	%local datain ;

	proc contents data = &datain. out = contents01 (keep = name) noprint;
	run; 

	%let filename_cnt = 0;
	%let filename_where= ;

	proc sql noprint;
	  select count(*) into: filename_cnt
	  from contents01
	  where upcase(name) = 'FILENAME';
	quit;

	%put NOTE: filename_cnt = &filename_cnt. ;

	%if &filename_cnt. ne 0 and &practice ne 0 %then %do;

		proc sort data = &datain. 
		          out = filename    (keep=filename) nodupkey;
		  by descending filename;
		run;

		data _null_;
		  set filename (obs=1);
		  filename_where="(where=(filename='"||left(trim(filename))||"'))";
		  call symput('filename_where',trim(filename_where));
		  call symput('filename',trim(filename));
		run;
		
		data determine_date;
		  file="&filename."; 
		  datepart=substr(scan(file,2,'-'),1,8);
		  dateentered=input(datepart,yymmdd8.);
		  timeend=date();
		  timeendc=compress(timeend);
		  timeendn=put(timeend,date9.);
		  timestart=intnx('month1.1',dateentered,-2)+14;
		  timestartc=compress(timestart);
		  timestartn=put(timestart,date9.);
		  call symput('timestartn',timestartn);
		  call symput('timeendn',timeendn);
		  call symput('timestart',timestartc);
		  call symput('timeend',timeendc);
		run;

	%end;
	%else %if &filename_cnt. ne 0 and &practice = 0 %then %do;

		proc sort data = &datain. 
		          out = filename    (keep=filename svcdt) nodupkey;
		  by descending svcdt filename;
		run;

		data filename;
		  set filename (obs=1);
		  filename_where="(where=(filename='"||left(trim(filename))||"'))";
		  call symput('filename_where',trim(filename_where));
		  call symput('filename',trim(filename));
		run;
		
		data determine_date;
		  set filename;
		  file="&filename."; 
		  dateentered=svcdt;
		  timeend=date();
		  timeendc=compress(timeend);
		  timeendn=put(timeend,date9.);
		  timestart=intnx('month1.1',dateentered,-1);
		  timestartc=compress(timestart);
		  timestartn=put(timestart,date9.);
		  call symput('timestartn',timestartn);
		  call symput('timeendn',timeendn);
		  call symput('timestart',timestartc);
		  call symput('timeend',timeendc);
		run;
	%end;	
	%else %if &filename_cnt. = 0 and &practice = 0 %then %do;
	
		data filename;
		 set &datain.  (keep=svcdt filed ) ;
		run;	

		proc sort data =  filename nodupkey;
		  by descending svcdt filed;
		run;

		data filename;
		  set filename (obs=1);
		  filename_where="(where=(filed='"||left(trim(filed))||"'))";
		  call symput('filename_where',trim(filename_where));
		  call symput('filename',trim(filed));
		run;
		
		data determine_date;
		  set filename;
		  file="&filename."; 
		  dateentered=today();
		  timeend=date();
		  timeendc=compress(timeend);
		  timeendn=put(timeend,date9.);
		  timestart=intnx('month1.1',dateentered,-1);
		  timestartc=compress(timestart);
		  timestartn=put(timestart,date9.);
		  call symput('timestartn',timestartn);
		  call symput('timeendn',timeendn);
		  call symput('timestart',timestartc);
		  call symput('timeend',timeendc);
		run;
	%end;		
	

	%put NOTE: filename_where = &filename_where. ; 
	%put NOTE: filename = &filename. ; 
	%put NOTE: timestart = &timestartn. ; 
	%put NOTE: timeend = &timeendn. ; 
	
  %end;

%mend dq_validate_content;
