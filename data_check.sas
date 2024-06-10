/*HEADER------------------------------------------------------------------------
|
| program:  data_check.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Abort Skelta process if zero records are called for needed datasets
+--------------------------------------------------------------------------------
| *HISTORY:  
| 02AUG2011 - LS Original Program: This macro is designed for the Skelta Process
|			  that runs the Prospective & Retrospective guidelines.  If no results
|			  are produced for our major datasets that are needed for our process to run,
|			  then abort the SAS/Skelta run.  
| HISTORY*
+--------------------------------------------------------------------------------*/


%macro data_check (dsn = );

proc sql noprint;
select count(*) into: ds_count from &dsn.;
quit;
%put &ds_count.;

%if &ds_count. <= 0 %then %do;
	%let err_fl=1;
	%set_error_flag;
	%on_error(ACTION=ABORT);
%end;

%mend data_check;
