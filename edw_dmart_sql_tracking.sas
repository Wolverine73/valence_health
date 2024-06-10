
/*HEADER------------------------------------------------------------------------
|
| program:  edw_dmart_sql_tracking.sas
|
| location: M:\CI\programs\EDW
|
| purpose:   
|
| logic:    
|              
|
| input:    
|		
|                        
| output:   
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| define sas macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
options mprint mlogic symbolgen;

*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*;  
/*%let sysparm=%str(sk_prcs_ctrl_id=9999 wflow_exec_id=5207 sas_prgm_id=60 client_id=4 sas_mode=test  ); */
%bpm_environment;

*SASDOC--------------------------------------------------------------------------
| BPM - Set the process control tables to Start.        
+------------------------------------------------------------------------SASDOC*;
%bpm_process_control(timevar=START);

*SASDOC--------------------------------------------------------------------------
| Collect information about dmart tables and insert into 
| vbpm.sk_process_control
+------------------------------------------------------------------------SASDOC*;
%macro update_dmarts(prgid,tblname);

	data _null_; 
	  ts=input("&date."||put(time(),time16.6),datetime22.3);
	  update_time="'"||left(trim(PUT(ts,DATETIME22.3)))||"'dt"; 
	  call symput('update_time',left(trim(update_time))); 
	run; 

	proc sql noprint;
	  select count(*) into: chk_it
	  from vbpm.sk_process_control
	  where client_id = &client_id.
	  and sk_ext_prgm_id = &prgid.  ;
	quit;

	%if &chk_it = 0 %then %do;
        	%let src_record_cnt=0;
	%end;
	%else %do;

		data get_last;
		  format start_time datetime.;
		  set vbpm.sk_process_control;
		  where client_id = &client_id. and sk_ext_prgm_id = &prgid.;
		  keep sk_ext_prgm_id tgt_record_cnt start_time; 
		run;

		proc sort data=get_last;
		  by start_time;
		run;

		data get_last;
		  set get_last;
		  by sk_ext_prgm_id start_time;
		  if last.sk_ext_prgm_id;
		run;

		proc sql noprint;
		  select  tgt_record_cnt
		  into: src_record_cnt
		  from get_last
		  ;
		quit;
	%end;

	proc sql noprint;
	  select count(*) into: tgt_record_cnt
	  from dmart.&tblname.	  ;
	quit;
	
	%put NOTE: src_record_cnt = &src_record_cnt.;
	%put NOTE: tgt_record_cnt = &tgt_record_cnt.;

	proc sql;
	  insert into vbpm.sk_process_control
	    set sk_status_id = 2,
			sk_ext_prgm_id = &prgid.,
			wflow_exec_id = &wflow_exec_id.,
			client_id = &client_id,
			start_time = &update_time. ,
			end_time = &update_time.  ,
			src_record_cnt = &src_record_cnt.,
			tgt_record_cnt = &tgt_record_cnt. ;
	quit;

%mend update_dmarts;

*SASDOC--------------------------------------------------------------------------
| Call update dmarts macro   
+------------------------------------------------------------------------SASDOC*; 
%update_dmarts(49,major_category);
%update_dmarts(50,dmpat_claim_detail);
%update_dmarts(51,dmpat_claim_summary);
%update_dmarts(52,dmpat_diagnosis_summary);
%update_dmarts(53,dmpat_provider_summary);
%update_dmarts(54,dmpat_patient_snapshot);
%update_dmarts(55,dmpat_patient_timeline);
%update_dmarts(56,dmprv_diagnosis_summary);
%update_dmarts(57,dmprv_patient_summary);
%update_dmarts(58,dmprv_procedure_summary);
%update_dmarts(59,dmprv_provider);

%let src_record_cnt = 0;
%let tgt_record_cnt = 0;


*SASDOC--------------------------------------------------------------------------
| BPM - Reset the process control tables to start.   
+------------------------------------------------------------------------SASDOC*; 
%bpm_process_control(timevar=COMPLETE);
