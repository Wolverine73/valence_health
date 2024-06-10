/*HEADER------------------------------------------------------------------------
|
| program:  bpm_initialize_variables.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Initialize all BPM global variables.
|
| logic:    Set variables up to use in bpm programs
|
| input:    clientname is optional          
|
| output:   
|
+--------------------------------------------------------------------------------
| history:  
|
| 04NOV2010 - Winnie Lee  - Clinical Integration  1.0.01
|             
| 18NOV2011 - G Liu - Clinical Integration 2.0.01
|				Added validation rule and count
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%macro bpm_initialize_variables;

	%global err_fl src_record_cnt tgt_record_cnt /*validation_rule validation_count*/ date critical_claim_variables issue_count;

	%let err_fl=0;
	%let src_record_cnt=0;
	%let tgt_record_cnt=0;
/*	%let validation_rule=0;
	%let validation_count=0;
*/
	/*SASDOC--------------------------------------------------------------------------
	| if updating critical_claim_variables values will need to update the following:
	|  1.  update edw_claim_validations.sas - crtical issue section
	|  2.  bpm.validation_type sql table - load_flag=0 warnings, load_flag=1 critical issues
	+------------------------------------------------------------------------SASDOC*/  

    %let edi		 =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=EDI;");  
	
	%let critical_claim_variables=%str('PROCCD','SVCDT','NPI','MEMBERID','DIAG1','POS','PHONE','SEX','DOB','LNAME'); 
	

	data _null_;
		date=put(today(),date9.);
		call symput('date',date);
	run;

%mend bpm_initialize_variables;
