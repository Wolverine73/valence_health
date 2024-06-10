
/*HEADER------------------------------------------------------------------------
|
| program:  dq_history_cio.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Capture the data within the data quality history and send an email
|           to the user if any issues exist
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
|             Quality Control - Modifications for Email Alerts
|             1.  Exclude Data Elements - Remove phone, zip, and address on FNCC 
|             2.  Lower Limit Only - If FNCC exceeds lower limits only
|             3.  Young Practices - Restrict for 6 or more practice files 
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_history_cio;

	*SASDOC--------------------------------------------------------------------------
	| Collect History Information       
	+------------------------------------------------------------------------SASDOC*;
	data x;
	  x=1;
	run;

	data column_information (rename=(data_assessment=data_assessment2 data_variable=data_variable2));
	  set x summary_validation (keep=data_assessment data_variable);
	run;

	data null;
	  date=put(today(),date9.);
	  call symput('date',date);
	run;

	data summary_validation_history;
	  format filename $30. complete_ts complete_ts_actual DATETIME22.3 clientname $50. systemname $80. practicename $80.;
	  merge summary_validation column_information;
	  if data_assessment = '' and data_variable=data_variable2 then do;
	     data_assessment=data_assessment2;
	  end;
	  filename    ="&filename.";
	  clientid    =&clientid.;
	  clientname  ="&clientname.";
	  systemid    =&systemid.; 
	  systemname  ="&systemname.";   
	  practiceid  =&practiceid.; 
	  practicename="&practicename.";  
	  complete_ts =INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME22.3);
	  complete_ts_actual =INPUT("&DATE."||PUT(TIME(),TIME16.6),DATETIME22.3);;
	  if count = . then delete;
	  drop x data_assessment2 data_variable2 ;
	run;	
	
	*SASDOC--------------------------------------------------------------------------
	| Transpose History Information       
	+------------------------------------------------------------------------SASDOC*;		
	data group1;
	 set summary_validation_history ;
	 var1=trim(left(data_variable))||"_"||trim(left(lowcase(validation)));
	 var2=trim(left(data_variable))||"_assessment";
	run;

	data group2;
	 set group1;
	 if data_validation ne '' or data_validation ne '' and upcase(validation) ne "DNE";
	run;
	
	data group1;
	 set group1;
	 if upcase(validation) ne "DNE";
	run;	

	proc sort data = group1;
	 by  clientid clientname systemid systemname practiceid practicename filename complete_ts complete_ts_actual;
	run;

	proc sort data = group2;
	 by  clientid clientname systemid systemname practiceid practicename filename complete_ts complete_ts_actual;
	run;

	proc transpose data = group1 out = trans1 (drop = _NAME_);
	 by clientid clientname systemid systemname practiceid practicename filename complete_ts complete_ts_actual;
	 id var1 ;
	 var count ;
	run;

	proc transpose data = group2 out = trans2 (drop = _NAME_);
	 by clientid clientname systemid systemname practiceid practicename filename complete_ts complete_ts_actual;
	 id var2 ;
	 var data_validation ;
	run;

	data all_trans;
	 merge trans1 (in=a) trans2 (in=b);
	 by  clientid clientname systemid systemname practiceid practicename filename complete_ts complete_ts_actual;
	 if a;
	run;

	data all_trans;
	 set history.summary_validation_history_cio (obs=0)
	     all_trans;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Assign Numeric values to zero and append to history data set       
	+------------------------------------------------------------------------SASDOC*;		
	data all_trans;
	set all_trans;
	 array allnums {*} _numeric_;
	 do i = 1 to dim(allnums);
	  if allnums{i} = . then  allnums{i} = 0;
	  drop i;
	 end;
	run;	

	proc append base = history.summary_validation_history_cio 
		    data = all_trans force ;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Maintain and clean history data set 
	| -Remove invalid records due to failures in processes
	| -Reassign ts values due to older files being processed in the current month
	+------------------------------------------------------------------------SASDOC*;
	data history.summary_validation_history_cio ;
	  set history.summary_validation_history_cio ; 
	  if clientid = 0 and systemid = 0 and practiceid = 0 then delete;
	run;
	

	data history.summary_validation_history_cio (drop = temp01 filedate tsdate filemonth tsmonth ts
			   file_month ts_month dashvalue practicevalue complete_ts2);
	  format   complete_ts2 DATETIME22.3;
	  retain filename complete_ts ;
	  set history.summary_validation_history_cio;
	  dashvalue=index(filename,'-');
	  practicevalue=scan(filename,1,'-')*1;
	  if dashvalue > 0 and practicevalue > 0 then do ;
		 temp01=scan(left(filename),2,'-');
		 temp01=substr(temp01,1,8);
		 filedate=input(temp01,yymmdd8.); 
		 tsdate=datepart(complete_ts);
		 filemonth=intnx('month1.1',filedate,0); ** file month;
		 tsmonth=intnx('month1.1',tsdate,0); ** ts month;
		 file_month=put(filemonth,yymmdd8.);
		 ts_month=put(tsmonth,yymmdd8.);
		 ts=put(filedate,date9.); 
		 complete_ts2 =INPUT(ts||PUT(TIME(),TIME16.6),DATETIME22.3);
		 if file_month ne ts_month then do;
		   complete_ts=complete_ts2;
		 end;
	  end;
	run;
	
	
	*SASDOC--------------------------------------------------------------------------
	| Create email only for validation issues       
	+------------------------------------------------------------------------SASDOC*;	
	data email ;
	  retain  filename clientid clientname systemid systemname practiceid practicename
	          data_assessment data_validation percent ;
	  set Summary_validation_history;
	  if upcase(data_validation) = "**NOT ACCEPTABLE**";
	  keep filename clientid clientname systemid systemname practiceid practicename
	       data_assessment data_validation percent ;
	run;

	%let email_count=0;
	
	proc sql noprint;
	  select count(filename) into: email_count
	  from email;
	quit;

	%if &email_count ne 0 %then %do;

	%end;
	%else %do ;
		%if &practice. ne 0 and  &practice_files_cnt > 5 %then %do;  /** only vmine practices with 6 or more files **/
	
			%if %sysfunc(exist(work.fn_controlcharts_filedt)) %then %do;
			data email1 ; 
			  set fn_controlcharts_filedt;
			  if fncc_indicator = 1 ; /** only email when fn controlling exceeds lower limits only **/
			  if lowcase(data_element) not in ('phone', 'zip', 'address');  /** exclude to prevent emails - insignificant **/
			run;
			%end;

			data email2 ; 
			  set qc_movingrange_filedt;
			  if flag_reason ne "";
			run;

			data email1;
			 set %if %sysfunc(exist(work.fn_controlcharts_filedt)) %then %do; email1 %end; email2;
			run;

			%let email_count2=0;

			proc sql noprint;
			  select count(*) into: email_count2
			  from email1;
			quit;

			%if &email_count2 ne 0 %then %do;		



			%end;
		%end;
	%end;

%mend dq_history_cio;
