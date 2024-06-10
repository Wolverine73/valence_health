
/*HEADER------------------------------------------------------------------------
|
| program:  bpm_validation_detail.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:   
|
| logic:     
|           
|
| input:               
|
| output:    
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro bpm_validation_detail(in_datasets=);

	data _null_;
	  date=put(today(),date9.);
	  call symput('date',date);
	run;

	data temp001;
	  set &in_datasets. ;
	run;
	
	%local count_validation_detail;
	
	%let count_validation_detail=0;
	
	proc sql noprint;
	  select count(*) into: count_validation_detail
	  from vbpm.validations;
	quit;

	%if &count_validation_detail ne 0 %then %do ; 

		proc sql;
		  create table validation_detail as
		  select a.*, 
		  input("&date."||put(time(),time16.6),datetime22.3) as CREATED_ON format datetime22.3,
		%if &sas_prgm_id.=18 %then %do;
		  "REPROCESS - ERROR" as CREATED_BY, 
		%end;
		%else %if &sas_prgm_id.=19 %then %do;
		  "REPROCESS - NL HOLD" as CREATED_BY, 
		%end;
		%else %do;
		  "BPM - SAS" as CREATED_BY, 
		%end;
		  input("&date."||put(time(),time16.6),datetime22.3) as UPDATED_ON format datetime22.3,
		%if &sas_prgm_id.=18 %then %do;
		  "REPROCESS - ERROR" as UPDATED_BY  
		%end;
		%else %if &sas_prgm_id.=19 %then %do;
		  "REPROCESS - NL HOLD" as UPDATED_BY  
		%end;
		%else %do;
		  "BPM - SAS" as UPDATED_BY  
		%end;
		  from temp001 as a; 
		quit; 
		
		%bulkload_to_cio(
		&wflow_exec_id. ,
		validation_detail,
		m_desttable=bpmmetadata.dbo.validation_detail,
		m_isdatetime=created_on updated_on,
		m_truncate=1,
		m_keepvar=wflow_exec_id validation_type_id entity_id old_val new_val val_type created_on created_by updated_on updated_by);
		
	%end;


%mend bpm_validation_detail;
