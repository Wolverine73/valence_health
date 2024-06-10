
/*HEADER------------------------------------------------------------------------
|
| program:  edw_claims_no_load.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Load practice data into the CIEDW header and detail tables  
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
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/
 
%*sasdoc----------------------------------------------------------------------
| define sas macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

options mlogic mprint symbolgen;

*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*;   
%bpm_environment; 


*SASDOC--------------------------------------------------------------------------
| Macro:  create_sas_header_detail  
|  
| Create the SAS datasets for header and detail from the SAS staging dataset
|
+------------------------------------------------------------------------SASDOC*;


%macro edw_claims_no_load(dsn= );

	%if %sysfunc(exist(&dsn)) %then %do;  /** begin - dsn **/

		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to start.   
		+------------------------------------------------------------------------SASDOC*; 
		%bpm_process_control(timevar=START);

		*SASDOC--------------------------------------------------------------------------
		| edw_claims_no_load - Insert all header and detail into NL Hold. 
		| 
		+------------------------------------------------------------------------SASDOC*;
		data names;
		  set cihold.NL_HOLD_ENCOUNTER_HEADER_DETAIL (obs=5);
		  drop encounter_key ;
		run;

		proc contents data = names 
	                   out = names (keep=name varnum)  noprint;
		run;

		proc sort data = names;
		  by varnum;
		run;

		proc sql noprint;
		  select name, name as keepnames 
	      into:  names separated by ',', :  keepnames separated by ' '
		  from names;
		quit;

		%put NOTE: names = &names. ; 

		data nl_hold_encounter_header_detail   (rename=(
												procedure_code_key2=procedure_code_key
												service_date2=service_date
												admit_date2=admit_date
												discharge_date2=discharge_date
												dob2=dob
												moddt2=moddt 
												svcdt2=svcdt
												createdt2=createdt )); 
		  format service_date2 admit_date2 discharge_date2 discharge_date2 dob2 moddt2 created_on datetime22.3 ;
		  set &dsn. ; 
		  where load_flag in (0,1); /** valid and invalid **/
			  procedure_code_key2=input(procedure_code_key,8.);
			  admit_date2=dhms(admit_date,0,0,0);
			  discharge_date2=dhms(discharge_date,0,0,0);
			  dob2=dhms(dob,0,0,0);
			  moddt2=dhms(moddt,0,0,0);
			  service_date2=dhms(service_date,0,0,0);
			  svcdt2=dhms(svcdt,0,0,0);
			  createdt2=dhms(createdt,0,0,0); 
			  created_on = input("&date."||put(time(),time16.6),datetime22.3) ;
			  created_by = 'bpm - sas';
			  sk_status_id=4; /** failure on claim validation **/
		  drop procedure_code_key service_date admit_date discharge_date dob moddt service_date svcdt createdt;
		run;

		data nl_hold_encounter_header_detail;
		 retain &keepnames. ;
		 set nl_hold_encounter_header_detail (keep = &keepnames.) ;	
		run;

		proc sql ;
		  insert into cihold.nl_hold_encounter_header_detail
		  (&names.  )
		  select  &names. 		
		  from nl_hold_encounter_header_detail  ;
		quit;


	    *SASDOC--------------------------------------------------------------------------
	    | BPM - Create source and target counts             
	    +------------------------------------------------------------------------SASDOC*;
		proc sql noprint;
		  select count(*) into: src_record_cnt
		  from &dsn. ;
		quit;

		proc sql noprint;
		  select count(*) into: tgt_record_cnt
		  from &dsn. 
          where load_flag=0;
		quit;

		
		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to start.   
		+------------------------------------------------------------------------SASDOC*; 
		%bpm_process_control(timevar=COMPLETE);


		*SASDOC--------------------------------------------------------------------------
		| edw_claims_no_load - Delete temp staging table and dataset. 
		| 
		+------------------------------------------------------------------------SASDOC*;
		proc sql;
	      connect to oledb(init_string=&cihold.);
	      execute ( 
	                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
	              ) 
	      by oledb; 
	    quit;

		proc datasets library=%scan(&dsn,1,.) nolist;
		 delete %scan(&dsn,2,.) ;
		quit;

		
	%end;  /** end - dsn **/
	%else %do;
	  %put NOTE: The dataset &dsn. does not exists ;
	%end;

%mend edw_claims_no_load;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;  
%edw_claims_no_load(dsn=cistage.claims_&practice_id._&client_id._&wflow_exec_id.);










