
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  vlink_create_provider_formats.sas
|
| LOCATION: M:\CI\programs\ClientMacros
|
| PURPOSE:  To create the provider formats
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
|             Created and updated Code to Business Requirements Specifiation for NSAP
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro vlink_create_provider_formats(datain=, dataout=, where=, fmtname=, type=, label=, length=, start=, obs=);

   %if &obs= %then %let obs=50;
   %if &type= %then %let type=C;
   
   %if &label = Y %then %do;
   	data &dataout. (keep = START LABEL TYPE FMTNAME );
   	   length FMTNAME $8. TYPE $1 label $ &length.. ;
   	   retain FMTNAME "&fmtname."  TYPE "&type.";
   	   set &datain. ;
   	   &where.;  
   	   if &start NE "" then do;
   		  start = &start;
   		  label = "Y";
   		  output;
   	   end;
   	   if _n_ = 1 then do;
   	       start = "other";
   	       label = "N";
   	       output;
   	   end;
   	run;
   %end;
   %else %do;
   	data &dataout. (keep = START LABEL TYPE FMTNAME );
   	   length FMTNAME $8. TYPE $1 label $ &length.. ;
   	   retain FMTNAME "&fmtname."  TYPE "&type.";
   	   set &datain. (&where. keep = &start &label npi);  
   	   if &start NE "" then do;
   		  start = &start;
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
   
	%if "&fmtname."="provtype" %then %do;
		proc sort data=	&dataout. nodupkey;
     			by start descending label;
   		run;
	%end;


   proc sort data=&dataout. nodupkey;
      by start;
   run;
   
   proc print data=&dataout. (obs=&obs);
   run;
   
   proc format cntlin=&dataout. ;
   run;
   
   proc contents data=&dataout. ;
   run;

%mend vlink_create_provider_formats;
