/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  ProgramEndTime.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  End time count  
|
| LOGIC:     
|           
| INPUT:              
|
| OUTPUT:   Time output onto log
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 20SEP2011 - Winnie Lee  - Clinical Integration  1.0.01
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro ProgramEndTime();

	%global endrun endtime enddatetime seconds minutes hours runtime;

	/**program end time;*/
	%let endrun		 = %sysfunc(datetime(),datetime.);
	%let enddatetime = %sysfunc(datetime());
	%let endtime	 = %sysfunc(time());

	%put EndRun 	 = &endrun.;
	%put EndDateTime = &enddatetime.;
	%put EndTime 	 = &endtime.;

	/**time for program to run;*/
	data _null; 
		seconds=&enddatetime.-&startdatetime.;
		minutes=seconds/60;
		hours=minutes/60;
		call symputx('seconds', seconds);
		call symputx('minutes', minutes);
		call symputx('hours', hours);

		runtime = put((&endtime. - &starttime.),time.);
		call symputx('runtime',runtime);
	run;
	run;

	%put NOTE: StartDateTime = &startrun.   EndDateTime = &endrun.;
	%put NOTE: RUNTIME HH:MM:SS = &runtime.;
	%put NOTE: HOURS = &hours.   MINUTES = &minutes.   SECONDS = &seconds.;

%mend ProgramEndTime;
