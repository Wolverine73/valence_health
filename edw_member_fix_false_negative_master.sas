
/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_fix_false_negative_master.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Master Program to kick off member fix XREF
|
| logic:    
|
| input:    Macro parameters
|           sk_prcs_ctrl_id - bpm process identifier
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|
| output:   sas_prgm_id - SAS program ID will be initialized in this master
							program depending on which SAS program it is 
							calling.
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 26MAY2011 - G Liu  - Clinical Integration  1.0.01
|             Original
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/


%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment; 


%macro edw_false_negative_master;
	%let filename=MEMFIX-FALSENEGATIVE;
    %bpm_process_control(timevar=START);

	%global sas_prgm_id;
%macro nono;
	*SASDOC--------------------------------------------------------------------------
	| Since member_xref logic is based on MEMBER, if something in MEMBER table
	|	is updated after member_key_xref table, then we should execute the false
	|	negative programs.
	+------------------------------------------------------------------------SASDOC*; 
	%let mfm_fneg_newcnt=0;
	proc sql noprint;
		select	count(*)
		into	:mfm_fneg_newcnt
		from	cihold.member_key_xref
		where	substr(put(member_key,z16.),1,2)=put(&client_id.,z2.);
	quit;

	%if &mfm_fneg_newcnt.=0 %then %do; /* brand new client */
		%let mfm_fneg_newcnt=1;
		%put NOTE: No history of false negative. Execute for the first time.;	
	%end;
	%else %do;
		proc sql noprint;
			select	count(*)
			into	:mfm_fneg_newcnt
			from	ciedw.member
			where	updated_on gt (	select	max(created_on)
									from	cihold.member_key_xref);
		quit;
		%let mfm_fneg_newcnt=&mfm_fneg_newcnt.;
		%put MEMBER records updated after last false negative process = &mfm_fneg_newcnt.;
	%end;
%mend nono; %let mfm_fneg_newcnt=1;
	%IF &mfm_fneg_newcnt. %THEN %DO;
		%if %index(%str(&sqlci.),%str(Data Source=SQLCIDEV)) %then %do;
			%let sas_prgm_id=15; %inc 'M:\ci\programs\Development\EDW\edw_member_consolidation.sas';
			%let sas_prgm_id=17; %inc 'M:\ci\programs\Development\EDW\edw_claims_reprocess_xref.sas';
		%end;
		%else %if %index(%str(&sqlci.),%str(Data Source=SQL-CI)) %then %do;
			%let sas_prgm_id=15; %inc 'M:\ci\programs\EDW\edw_member_consolidation.sas';
			%let sas_prgm_id=17; %inc 'M:\ci\programs\EDW\edw_claims_reprocess_xref.sas';
		%end;
	%END;

    %bpm_process_control(timevar=COMPLETE);
    
    
    	%macro send_email_alert;
			%if %symexist(sas_mode) %then %do;
				%if %upcase(&sas_mode.)=PROD %then %do;		%let sasmode_title=;		%let email_edwprod="edwprod@valencehealth.com";		%end;
				%else %do;									%let sasmode_title=TEST ;	%let email_edwprod=;								%end;
			%end;
			%else %do;										%let sasmode_title=TEST ;	%let email_edwprod=;								%end;
				
    		filename mail_out email to=(&email_edwprod. "bstropich@valencehealth.com" "knachman@valencehealth.com" "smore@valencehealth.com" 
										"amcmillan@valencehealth.com" "mlogsdon@valencehealth.com")
    				subject="CIO &sasmode_title.- Member Fix Work Flow &wflow_exec_id. - Complete";
    
    		data _null_;
	    		file mail_out lrecl=32767;
	    		put "Client ID &client_id.";		
	    		put "Member fix is complete for work flow ID of &wflow_exec_id.";
				put "SAS mode &sas_mode.";
	    		put "   ";		
    		run;
    	%mend send_email_alert;
	%send_email_alert;
	

%mend edw_false_negative_master;
%edw_false_negative_master;
