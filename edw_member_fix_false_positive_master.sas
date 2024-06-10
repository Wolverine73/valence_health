
/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_fix_false_positive_master.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Master Program to kick off member fix ERROR
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
| 26MAY2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 14MAR2012 - G Liu 		  - Clinical Integration  1.1.02
|			  Commented out conditional run. We will run false positive everytime it is kicked off.
| 15AUG2012 - B Fletcher      - Clinical Integration  1.5.01
|			  All clients will run the edw_claims_reprocess_error in case manually records are added.
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


%macro edw_false_positive_master;
	%let filename=MEMFIX-FALSEPOSITIVE;
    %bpm_process_control(timevar=START)

	%global sas_prgm_id;

	*SASDOC--------------------------------------------------------------------------
	| Since member_error logic is based on HOLD/NL HOLD, if something in HOLD and/or
	|	NL HOLD is loaded after member_key_error table, then we should execute 
	|	the false positive programs.
	| Check NL Hold (smaller table) first. If nothing, check Hold.
	+------------------------------------------------------------------------SASDOC*; 
%macro nono;
	%let mfm_fpos_newcnt=0;
	proc sql noprint;
		select	count(*)
		into	:mfm_fpos_newcnt
		from	cihold.member_false_positive
		where	substr(put(member_key,z16.),1,2)=put(&client_id.,z2.);
	quit;

	%if &mfm_fpos_newcnt.=0 %then %do; /* brand new client */
		%let mfm_fpos_newcnt=1;
		%put NOTE: No history of false positive. Execute for the first time.;	
	%end;
	%else %do;
		proc sql noprint;
			select	count(*)
			into	:mfm_fpos_newcnt
			from	cihold.nl_hold_encounter_header_detail
			where	created_on gt (	select	max(created_on)
									from	cihold.member_false_positive
									where	substr(put(member_key,z16.),1,2)=put(&client_id.,z2.));
		quit;

		%if &mfm_fpos_newcnt.=0 %then %do;
			proc sql noprint;
				select	count(*)
				into	:mfm_fpos_newcnt
				from	cihold.hold_encounter_header_detail
				where	created_on gt (	select	max(created_on)
										from	cihold.member_false_positive
										where	substr(put(member_key,z16.),1,2)=put(&client_id.,z2.));
			quit;
		%end;

		%let mfm_fpos_newcnt=&mfm_fpos_newcnt.;
		%put NOTE: HOLD claims loaded after last false positive process = &mfm_fpos_newcnt.;
	%end;
%mend nono; %let mfm_fpos_newcnt=1;
	%IF &mfm_fpos_newcnt. %THEN %DO;
		%if %index(%str(&sqlci.),%str(Data Source=SQLCIDEV)) %then %do;
			%let sas_prgm_id=16; %inc 'M:\ci\programs\Development\EDW\edw_member_error.sas';
			%let sas_prgm_id=18; %inc 'M:\ci\programs\Development\EDW\edw_claims_reprocess_error.sas';
		%end;
		%else %if %index(%str(&sqlci.),%str(Data Source=SQL-CI)) %then %do;
		  %if &client_id. ne 5 and &client_id. ne 6 and &client_id. ne 8 %then %do;
			%let sas_prgm_id=16; %inc 'M:\ci\programs\EDW\edw_member_error.sas';
		  %end;	
		  %let sas_prgm_id=18; %inc 'M:\ci\programs\EDW\edw_claims_reprocess_error.sas';
		%end;
	%END;

    %bpm_process_control(timevar=COMPLETE)
%mend edw_false_positive_master;
%edw_false_positive_master
