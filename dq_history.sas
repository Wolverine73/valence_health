
/*HEADER------------------------------------------------------------------------
|
| program:  dq_history.sas
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
| 24AUG2011 - Nick Williams - Clinical Integration 1.0.02
|             1. Changed start position of data_validation field for writting out email.
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_history;

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
	 set history.summary_validation_history (obs=0)
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
	  drop i ;
	 end;
	run;	
	
	proc sql;
	 select count(*) into: service_date_cutoff
	 from pm_&practice.
	 where index(upcase(issue_svcdt),'SERVICE') > 0;
	quit;

	%put NOTE: service_date_cutoff = &service_date_cutoff. ;
	
	%if &service_date_cutoff. ne 0 %then %do;
	
	  data all_trans;
	    set all_trans;
	    validation_svcdt_assessment='';
	    validation_svcdt_valid=validation_svcdt_invalid;
	    validation_svcdt_invalid=0;
	  run;
	    
	%end;

	proc append base = history.summary_validation_history 
		    data = all_trans force ;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Maintain and clean history data set 
	| -Remove invalid records due to failures in processes
	| -Reassign ts values due to older files being processed in the current month
	+------------------------------------------------------------------------SASDOC*;
	data history.summary_validation_history ;
	  set history.summary_validation_history ; 
	  if clientid = 0 and systemid = 0 and practiceid = 0 then delete;
	run;
	

	data history.summary_validation_history (drop = temp01 filedate tsdate filemonth tsmonth ts
			   file_month ts_month dashvalue practicevalue complete_ts2);
	  format   complete_ts2 DATETIME22.3;
	  retain filename complete_ts ;
	  set history.summary_validation_history;
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
	
		%let emailfile=%str(\\Fs\&clientdir\reports\Data_Quality_Reports\email_&clientdir..txt);

		data _null_;
		  set email  end=end;
		  file "&emailfile." lrecl=200 ;
		  if _n_=1 then put " ";
		  if _n_=1 then put "Hello.  There are data quality issues with the vmine practice file described below for the client - &clientname..";
		  if _n_=1 then put " ";
		  if _n_=1 then put filename ":"  ;
		  if _n_=1 then put " ";
/*		  if _n_=1 then put "System Name                  Assessment                    Validation                    Percent   ";*/
/*		  if _n_=1 then put "------------                 -------------                 ------------                  --------- ";*/

		  if _n_=1 then do;
			  put @1  "System Name" 
			      @30 "Assessment" 
			      @65 "Validation"
			      @90 "Percent" ;
		  end;
          if _n_=1 then put @1 100*'-' ;
                        
		  put @1  systemname 
		      @30 data_assessment 
		      @65 data_validation
		      @90 percent ;
		  if end then put " ";
		  if end then put / "Please examine the following PDF report for more details: &xl. ";
		  if end then put / "General rules for resolving data quality issues are the following:";
		  if end then put   "1.  Validate log for the execution of the practice. ";
		  if end then put   "2.  Validate the past DQ reports for the practice which are available within the FS directory or DQ history SAS dataset. ";
		  if end then put   "3.  Validate any merges, joins, or formats for the table(s) in question. ";
		  if end then put   "4.  Validate the variables in question and their existence in the SAS dataset and vMine text file. ";
		  if end then put   "5.  Validate with IT Team that there was no issue with the vMine text file extraction from the practice. ";
		  if end then put   "6.  Validate the SQL used by the IT Team. ";
		  if end then put / "Thanks.";
		  if end then put " ";
		  if end then put "SAS2";
		run;
		
		%if %upcase(&SYSUSERID) = LSFUSER %then %do;
			libname emailid "M:\ci\sasdata\CIReference";

			data _null_;
			  set emailid.usertable;
			  where client = &client.;
			  call symputx('emailid',emailid);
			run;
			%put NOTE: emailid = &emailid. ;
		%end;
		%else %do;
			data _null_;
			  emailid="&SYSUSERID.@valencehealth.com";
			  call symputx('emailid',emailid);
			run;
			%put NOTE: emailid = &emailid. ;
		%end;		

		%email_parms(em_to=&emailid.,
		             em_subject=Clinical Integration - &clientname vMine Data Quality Issues,
		             em_msg_file=%str(&emailfile.),
			     em_from=&emailid.  );
		
		data _null_;
		 x "del &emailfile.";
		run;

	%end;
	%else %do ;
		%if &practice. ne 0 and  &practice_files_cnt > 5 %then %do;  /** only vmine practices with 6 or more files **/
	
			data email1 ; 
			  set fn_controlcharts_filedt;
			  if fncc_indicator = 1 ; /** only email when fn controlling exceeds lower limits only **/
			  if lowcase(data_element) not in ('phone', 'zip', 'address');  /** exclude to prevent emails - insignificant **/
			run;

			data email2 ; 
			  set qc_movingrange_filedt;
			  if flag_reason ne "";
			run;

			data email1;
			 set email1 email2;
			run;

			%let email_count2=0;

			proc sql noprint;
			  select count(*) into: email_count2
			  from email1;
			quit;

			%if &email_count2 ne 0 %then %do;		


				%let emailfile=%str(\\Fs\&clientdir\reports\Data_Quality_Reports\email_&clientdir..txt);

				data _null_;
				  set Summary_validation_history (obs=1)  end=end;
				  file "&emailfile." lrecl=200 ;
				  if _n_=1 then put " ";
				  if _n_=1 then put "Hello.  There are quality control issues with the vmine practice file below for the client - &clientname.. ";
				  if _n_=1 then put "These issues may or may not be significant but have been discovered through the DQ process. ";
				  if _n_=1 then put " ";
				  if _n_=1 then put filename ;
				  if end then put " ";
				  if end then put / "Please examine the following PDF report for more details: &xl. ";
				  if end then put / "Thanks.";
				  if end then put " ";
				  if end then put "SAS2";
				run;

				%if %upcase(&SYSUSERID) = LSFUSER %then %do;
					libname emailid "M:\ci\sasdata\CIReference";

					data _null_;
					  set emailid.usertable;
					  where client = &client.;
					  call symputx('emailid',emailid);
					run;
					%put NOTE: emailid = &emailid. ;
				%end;
				%else %do;
					data _null_;
					  emailid="&SYSUSERID.@valencehealth.com";
					  call symputx('emailid',emailid);
					run;
					%put NOTE: emailid = &emailid. ;
				%end;		

				%email_parms(em_to=&emailid.,
					     em_subject=Clinical Integration - &clientname vMine Quality Control Issues,
					     em_msg_file=%str(&emailfile.),
					     em_from=&emailid.  );

				data _null_;
				 x "del &emailfile.";
				run;

			%end;
		%end;
	%end;

%mend dq_history;
