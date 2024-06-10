
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  insert_ci_history.sas
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

%macro insert_ci_history(cihiststepid=, practice=, system=);

	data null;
	  date=put(today(),date9.);
	  call symput('date',date);
	run;

	data insert_ci_history;
	  format start_ts DATETIME22.3 issue_description $100. file_name $50.;
	  set job_4_today (keep = stepid clientid step_description);
	  where stepid=&cihiststepid.; 
	  yearmonthid=put(today(),yymmn6.);
	  %if &system. ne %then %do;
        systemid=&system.;
	  %end;
	  %else %do;
	    systemid=.;
	  %end;
	  %if &practice. ne %then %do;
	    practiceid=&practice.;
	  %end;
	  %else %do;
	    practiceid=.;
	  %end;
	  issueid=1;
	  file_name="";
	  issue_description="Start";
	  dataset_cnts=0;
	  complete_indicator=1;
	  start_ts=INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME22.3);
	run;

	proc append base = ciref.clinical_integration_history
	            data = insert_ci_history force;
	run;

%mend insert_ci_history;






