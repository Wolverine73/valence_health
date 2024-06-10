/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  ProgramStartTime.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Start time count  
|
| LOGIC:     
|           
| INPUT:              
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 20SEP2011 - Winnie Lee  - Clinical Integration  1.0.01
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro ProgramStartTime();
	/**program start time;*/
	%global startrun startdatetime starttime;

	%let startrun 	   = %sysfunc(datetime(),datetime.);
	%let startdatetime = %sysfunc(datetime());
	%let starttime	   = %sysfunc(time());
	
	%put NOTE: StartRun 	   = &startrun.;
	%put NOTE: StartDateTime = &startdatetime.;
	%put NOTE: StartTime 	   = &starttime.;
	
%mend ProgramStartTime;

