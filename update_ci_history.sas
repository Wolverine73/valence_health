
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  update_ci_history.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:   
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

%macro update_ci_history(cihiststepid=, datasetcount=, filename=, practice=, system=, failure=);

	options obs=max;
	
	data null;
	  date=put(today(),date9.);
	  call symput('date',date);
	run;	
	
	%let datacount= 0;
	%if &failure  = %then %let failure=&err_fl.;
	%if &system   = %then %let system=0;
	%if &practice = %then %let practice=0; 
	%if &datasetcount = %then %let datacount=0;

	%if &datasetcount ne and &failure. = 0 %then %do;
		proc sql noprint;
		select count(*) into: datacount
		from &datasetcount.;
		quit;
	%end;
	
	%if &failure. = 1 %then %do;
	
		data _null_;
		 set job_4_today ;
		 where stepid=&cihiststepid.;
		 fn=left(scan(step_description,2,"-"));
		 call symput('filename',trim(fn));
		run;		 
	
		data update_ci_history;
		  format complete_ts DATETIME22.3 ;
		  set insert_ci_history ;
		  where stepid=&cihiststepid.; 
		  issueid=0;
		  systemid=&system.;
		  practiceid=&practice.;
		  file_name="&filename.";
		  issue_description="Failure";
		  dataset_cnts=&datacount.;
		  complete_indicator=1;
		  complete_ts=INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME22.3);
		run;
	%end;	
	%else %if (&cihiststepid = 2 or &cihiststepid = 3 ) and &failure. = 0 %then %do;
		data update_ci_history;
		  format complete_ts DATETIME22.3 ;
		  set insert_ci_history ;
		  where stepid=&cihiststepid.; 
		  issueid=0;
		  systemid=&system.;
		  practiceid=&practice.;
		  file_name="&filename.";
		  issue_description="Complete";
		  dataset_cnts=&datacount.;
		  complete_indicator=0;
		  complete_ts=INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME22.3);
		run;
	%end;
	%else %do;
	
		data _null_;
		 set job_4_today ;
		 where stepid=&cihiststepid.;
		 fn=left(scan(step_description,2,"-"));
		 call symput('filename',trim(fn));
		run;
		
		data update_ci_history;
		  format complete_ts DATETIME22.3 ;
		  set insert_ci_history ;
		  where stepid=&cihiststepid.; 
		  issueid=0;
		  systemid=0;
		  practiceid=0;	  
		  file_name="&filename.";
		  issue_description="Complete";
		  file_name="&filename.";
		  dataset_cnts=&datacount.;
		  complete_indicator=0;
		  complete_ts=INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME22.3);
		run;
	%end;	

	data _null_;
	  set update_ci_history end=eof; 
	  start_ts_reformat="'"||left(trim(PUT(start_ts,DATETIME22.3)))||"'dt";
	  yearmonth_reformat="'"||left(trim(yearmonthid))||"'";
	  call symput('cihistclientid',left(trim(clientid)));
	  call symput('cihiststartts',left(trim(start_ts_reformat)));
	  call symput('cihistyearmonth',left(trim(yearmonth_reformat))); 
	run;

	proc sql noprint;
	update ciref.clinical_integration_history a
	set 
	dataset_cnts =     
	  (select b.dataset_cnts
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid),
	complete_ts = 
	  (select b.complete_ts
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid),
	complete_indicator= 
	  (select b.complete_indicator
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid),
	issueid= 
	  (select b.issueid
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid),
	file_name= 
	  (select b.file_name
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid),
	systemid= 
	  (select b.systemid
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid),
	practiceid= 
	  (select b.practiceid
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid),
	issue_description= 
	  (select b.issue_description
	   from update_ci_history b
	   where b.clientid=a.clientid
	   and b.stepid=a.stepid
	   and b.start_ts=a.start_ts
	   and b.yearmonthid=a.yearmonthid)

	where a.clientid=&cihistclientid.
	  and a.stepid=&cihiststepid.
	  and a.start_ts=&cihiststartts.
	  and a.yearmonthid=&cihistyearmonth. ;
	quit;

%mend update_ci_history;

		






