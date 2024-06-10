
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  clinical_integration_email.sas
|
| LOCATION: M:\CI\programs\ClientMacros
|
| PURPOSE:  To create the formats for CI
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
|             
+-----------------------------------------------------------------------HEADER*/

%macro clinical_integration_email;
 
   %if &err_fl. = 0 and &step_counts ne 0 %then %do ;
   
	filename mymail email 'qcpap020@dalcdcp';	   
	data _null_;
	set job_4_today end=end;
	file mymail
	to =("&primary_programmer_email.") 
	cc =( ) 
	subject="CLINICAL INTEGRATION: %upcase(&clientname.) - CI Process Completed" ;

	if _n_ =1 then put 'CI User,' ;
	if _n_ =1 then put / "This message is to inform you that the CI - Process completed the scheduled steps successfully.";
	if _n_ =1 then put / "The following steps were scheduled and executed: ";
	if _n_ =1 then put  " " ;
	if _n_ =1 then put  " " ;
	if _n_ =1 then put  "   Step            Title                                             " ;
	if _n_ =1 then put  "   ----------      -----                                             " ;
	put                     @5 stepid      @20 step_description  ;
	if end then put  " " ;
	if end then put / "A summary report is currently available within the client report directory.";
	if end then put / 'Thanks,';
	if end then put   'CI Support';
	run;
  
   
   %end;
   %else %if &err_fl. = 1 and &step_counts ne 0 %then %do ;
   
	filename mymail email 'qcpap020@dalcdcp';	   
	data _null_;
	set job_4_today end=end;
	file mymail
	to =(&primary_programmer_email.) 
	cc =( ) 
	subject="CLINICAL INTEGRATION: %upcase(&clientname.) - CI Process FAILURE" ;

	if _n_ =1 then put 'CI User,' ;
	if _n_ =1 then put / "This message is to inform you that the CI - Process failed because of issues.";
	if _n_ =1 then put / "The following steps were scheduled and executed: ";
	if _n_ =1 then put  " " ;
	if _n_ =1 then put  " " ;
	if _n_ =1 then put  "   Step            Title                                             " ;
	if _n_ =1 then put  "   ----------      -----                                             " ;
	put                     @5 stepid      @20 step_description  ;
	if end then put  " " ;
	if end then put / "Please examine the steps logs for an explanation of the issues which is available within the client log directory.";
	if end then put / 'Thanks,';
	if end then put   'CI Support';
	run;   

   %end;

%mend clinical_integration_email;