
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_formats.sas
|
| LOCATION: M:\CI\programs\ClientMacros
|
| PURPOSE:  To create the formats for CI
|           
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             
+-----------------------------------------------------------------------HEADER*/

%macro create_formats(datain=, dataout=, where=, fmtname=, type=, label=, start_length=, label_length=, start=, obs=, date=);

   %if &obs=  %then %let obs=25;
   %if &type= %then %let type=C;
   %if &date= %then %let date=N;
  
   %if &label. = YN %then %do ;
	data &dataout. (keep = START LABEL TYPE FMTNAME );
		LENGTH FMTNAME $8. TYPE $1 label $1. start $10.;
	   set &datain.;
	   &where. ;
	    KEEP START LABEL TYPE FMTNAME ;
	   RETAIN FMTNAME "&fmtname."  TYPE 'C';
	   if &start NE "" then do;
	        start = &start;
		label = 'Y';
		output;
	   end;
	   if _n_ = 1 then do;
	    start = "other";
	    label = 'N';
	    output;
	   end;
	run;   
   %end;
   %else %do;
   	data &dataout. (keep = START LABEL TYPE FMTNAME );
   	   length FMTNAME $8. TYPE $1 start $ &start_length.. label %if &date = Y %then %do ;
   	                                         &label_length.. 
   	                                    %end;
					    %else %if &date = N %then %do ;
   	                                         $ &label_length.. 
   	                                    %end; ;
   	   retain FMTNAME "&fmtname."  TYPE "&type.";
   	   set &datain. ; 
		&where.; 
   	   if &start NE "" then do; 
   	   
		%if &date = Y %then %do ;
		 start = &start; 
		%end;
		%else %if &date = N %then %do ;
		 start = cats(&start); 
		%end; ;   	   
   		  start = cats(&start);
   		  label = &label;
   		  output;
   	   end;
   	   if _n_ = 1 then do;
   		  start = "other";
   		  label = '';
   		  output;
   	   end;
   	run;
   %end;
  
   proc sort data=&dataout.  nodupkey;
      by start;
   run;
   
   proc print data=&dataout. (obs=&obs);
   run;
   
   proc format cntlin=&dataout. ;
   run;
   
   proc contents data=&dataout. ;
   run;

%mend create_formats;
