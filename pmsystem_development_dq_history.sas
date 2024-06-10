
/*HEADER------------------------------------------------------------------------
|
| program:  pmsystem_development_dq_history.sas
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
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro pmsystem_development_dq_history;

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
	 set history.pmsystem_development_history (obs=0)
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
	  drop i _LABEL_;
	 end;
	run;	

	proc append base = history.pmsystem_development_history 
		    data = all_trans force ;
	run;
	
	*SASDOC--------------------------------------------------------------------------
	| Maintain and clean history data set 
	| -Remove invalid records due to failures in processes
	| -Reassign ts values due to older files being processed in the current month
	+------------------------------------------------------------------------SASDOC*;
	data history.pmsystem_development_history ;
	  set history.pmsystem_development_history ; 
	  if clientid = 0 and systemid = 0 and practiceid = 0 then delete;
	run;
	

	data history.pmsystem_development_history (drop = temp01 filedate tsdate filemonth tsmonth ts
			   file_month ts_month dashvalue practicevalue complete_ts2);
	  format   complete_ts2 DATETIME22.3;
	  retain filename complete_ts ;
	  set history.pmsystem_development_history;
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
		  if _n_=1 then put "System Name                  Assessment                    Validation                    Percent   ";
		  if _n_=1 then put "------------                 -------------                 ------------                  --------- ";
		  put @1  systemname 
		      @30 data_assessment 
		      @60 data_validation
		      @90 percent ;
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
		             em_subject=Clinical Integration - &clientname vMine Data Quality Issues,
		             em_msg_file=%str(&emailfile.),
			     em_from=&emailid.  );
		
		data _null_;
		 x "del &emailfile.";
		run;

	%end;
	%else %do ;
		%put NOTE: Validate the PDF report in the FS directory for the client. ;
	%end;

%mend pmsystem_development_dq_history;
