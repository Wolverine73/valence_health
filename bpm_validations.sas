
/*HEADER------------------------------------------------------------------------
|
| program:  bpm_validations.sas
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
|
|             
+-----------------------------------------------------------------------HEADER*/


%macro bpm_validations(in_dataset=, claims=0);

	%local count_bpm_validations;

	%let count_bpm_validations=0;

	proc sql noprint;
	  select count(*) into: count_bpm_validations
	  from &in_dataset.;
	quit;

	%if &count_bpm_validations. ne 0 %then %do ;
		
		data _null_;
		  date=put(today(),date9.);
		  call symput('date',date);
		run; 
		
		data &in_dataset. ;
		  set &in_dataset. ;
		  count=1;
		run;

		%if &claims = 0 %then %do;
			proc summary data= &in_dataset. nway missing;
			  class wflow_exec_id validation_type_id ;
			  var count;
			  output out=temp001 (drop= _type_ _freq_) sum=;
			run;

			data temp001;
			  set temp001;
			  acceptable=1;
			run;
		%end;
		%else %do;
			proc sql noprint;
			 create table temp001 as
			 select wflow_exec_id, validation_type_id, count(*) as count, max(acceptable) as acceptable
			 from &in_dataset.
			 group by wflow_exec_id, validation_type_id ;
			quit;
		%end;
		
		data temp001; 
		 set temp001;
		 vld_value=left(put(count,20.));
		run;		

		proc sql;
		  create table bpm_validations as
		  select a.*, 
		  &sk_prcs_ctrl_id as sk_prcs_ctrl_id,
		  input("&date."||put(time(),time16.6),datetime22.3) as created_on format datetime22.3,
		%if &sas_prgm_id.=18 %then %do;
		  "REPROCESS - ERROR" as created_by, 
		%end;
		%else %if &sas_prgm_id.=19 %then %do;
		  "REPROCESS - NL HOLD" as created_by, 
		%end;
		%else %do;
		  "BPM - SAS" as created_by, 
		%end;
		  input("&date."||put(time(),time16.6),datetime22.3) as updated_on format datetime22.3,
		%if &sas_prgm_id.=18 %then %do;
		  "REPROCESS - ERROR" as updated_by  
		%end;
		%else %if &sas_prgm_id.=19 %then %do;
		  "REPROCESS - NL HOLD" as updated_by  
		%end;
		%else %do;
		  "BPM - SAS" as updated_by  
		%end;
		
		  from temp001 as a; 
		quit;

		%bulkload_to_cio(&wflow_exec_id.,bpm_validations,m_desttable=BPMMetaData.dbo.validations,
						m_isdatetime=created_on updated_on,m_truncate=1,
						m_keepvar=wflow_exec_id sk_prcs_ctrl_id vld_value validation_type_id acceptable created_on created_by updated_on updated_by
						);
	%end; 
  
%mend  bpm_validations;
