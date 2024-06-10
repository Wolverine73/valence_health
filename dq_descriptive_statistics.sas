
/*HEADER------------------------------------------------------------------------
|
| program:  dq_descriptive_statistics.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create the descriptive statistics report for the data quality process
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
|
| 01NOV2010 - Brian Stropich
|             Added the practice file count dataset and macro 
|             variable (practice_files_cnt) to the DQ process.
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_descriptive_statistics;

	%global practice_files_cnt;
	
	*--------------------------------------------------------------------------------
	| Descriptive Statistics Report - Content
	+------------------------------------------------------------------------------*;	
	data ds00a;
	 length textvalue textdesc $70 ;
	 textvalue="&clientid. - &clientname.";
	 textdesc="Client";
	run;
	
	data ds00b;
	 length textvalue textdesc $70 ;
	 textvalue="&systemid. - &systemname.";
	 textdesc="System";
	run;
	
	data ds00c;
	 length textvalue textdesc $70 ;
	 textvalue="&practiceid. - &practicename.";
	 textdesc="Practice";
	run;
	
	data ds00cc;
	 length textvalue textdesc $70 ;
	 textvalue="&vlink_id.";
	 if textvalue = '&vlink_id.' then textvalue = '';
	 textdesc="Group IDs";
	run;
	
	data ds00d;
	 length textvalue textdesc $70 ;
	 textvalue="&filename.";
	 textdesc="File Validated";
	run;
	
	data ds00e;
	 length textvalue textdesc $70 ;
	 textvalue="&filename_last.";
	 if textvalue = '&filename_last.' then textvalue = "&filename.";
	 textdesc="File Expected";
	run;
	
	proc sql noprint; 
	 create table ds01a as
	 select put(count(*),10.) as textvalue,
	        "Total Monthly Observations" as textdesc format=$70.
	 from pm_&practice.;
	quit;	
	
	proc sql noprint; 
	 create table ds01aa as
	 select put(count(*),10.) as textvalue,
	        "Total All Observations" as textdesc format=$70.
	 from &datasetin.;
	quit;
	
	proc contents data = pm_&practice. 
	              out  = tempvars (keep=name) noprint;
	run;
	
	data tempvars;
	 set tempvars;
	 if upcase(name) in ('MEMBERID');
	run;
	
	proc sql noprint;
	 select count(*) into: tempvars
	 from tempvars;
	quit;
	
	%if &tempvars ne 0 %then %do;	
		proc sql noprint; 
		 create table ds01b as
		 select put(count(distinct(MEMBERID)),10.) as textvalue,
			"Total Members" as textdesc format=$70.
		 from pm_&practice.;
		quit;
	%end;
	%else %do;
		data ds01b ;
		 length textvalue textdesc $70 ;
		 textvalue="DNE";
		 textdesc="Total Members";
		run;	
	%end;
	
	proc sql noprint; 
	 create table ds01c as
	 select put(count(distinct(&var_npi.)),10.) as textvalue,
	        "Total Providers" as textdesc format=$70.
	 from pm_&practice.;
	quit;	

	proc sql noprint; 
	 create table ds02 as
	 select	 put(min(svcdt),WEEKDATE37.) as textvalue ,
 	        "Minimum Service Date" as textdesc format=$70.
	 from pm_&practice.;
	quit;

	proc sql noprint; 
	 create table ds03 as
	 select	 put(max(svcdt),WEEKDATE37.) as textvalue ,
 	        "Maximum Service Date" as textdesc format=$70.
	 from pm_&practice.
	 where svcdt < today() ;
	quit;
	
	proc sql noprint; 
	 create table ds04 as
	 select left(put(count(distinct(filename)),10.)) as textvalue,
	        "Total Files" as textdesc format=$70.
	 from &datasetin. ;
	quit;
	
	proc sql noprint;  
	 select  textvalue into: practice_files_cnt  
	 from ds04;
	quit;

	%put NOTE:  practice_files_cnt = &practice_files_cnt. ;

	data ds_all;
	 length textvalue textdesc $70 ;
	 set ds00a ds00b ds00c ds00cc ds00d ds00e ds01a ds01aa ds01b 
	     %if %sysfunc(exist(work.ds01c)) %then %do;
	        ds01c 
	     %end;
	     ds04 ds02 ds03;
	 textvalue=left(textvalue);
	run;
	
	data quality_control_definitions ;
	 format string_text $105. ;  
	 string_text="Individual Value and Moving Range Control Charts - Total observations within monthly files are";
     output;
     string_text="compared to the monthly history of all files by practice. Control limits are established based";
     output;
     string_text="on statistical significance departures away from the mean number of file records per month. Thus,";
     output;
     string_text="any observation outside of these control limits, whether too high or too low, is considered an";
     output;
     string_text="observational extreme based on the previous file history and is flagged for further review.";
	 output;
     string_text="Values:  0=No Issue 1=Lower Limit Issue 2=Upper Limit Issue";
	 output;
	 string_text=" ";
	 output; 
	 string_text="Fraction Nonconforming Control Charts - The rate of invalid or missing (nonconforming) records ";
     output;
     string_text="within monthly files are compared within respective fields to the monthly history of all files by";
     output;
     string_text="practice.  An upper control limit is established based on statistical significance departure above";
     output;
     string_text="the mean rate of nonconforming records per month.  Thus, any observation above the upper control ";
     output;
     string_text="limit represents an observational extreme based on the previous file history and is flagged for ";
     output;
     string_text="further review.";
     output;
     string_text="Values:  0=No Issue 1=Lower Limit Issue 2=Upper Limit Issue";
	 output; 
	run;
	
%mend dq_descriptive_statistics;
 
