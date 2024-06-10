

/*HEADER------------------------------------------------------------------------
|
| program:  edw_claims_no_load_retry.sas
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
 
%*SASDOC----------------------------------------------------------------------
| define sas macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\ci\programs\standardmacros" "M:\ci\programs\clientmacros" sasautos);
options mlogic mprint symbolgen;

*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*;   
%bpm_environment; 

options missing=' ';




/*************************************************
%let practice_id=271;
%let practice_id=280;

options sasautos = ("M:\ci\programs\standardmacros" "M:\ci\programs\clientmacros" sasautos);
options mlogic mprint symbolgen;
%let sysparm=%str(sk_prcs_ctrl_id=84 wflow_exec_id=5216 sas_prgm_id=1 client_id=4 system_id=19 practice_id=347 pgf_practice= sas_mode=test); 
%bpm_environment; 
%let dsn=%str(cistage.claims_&practice_id._&client_id._&wflow_exec_id.);
%let incoming=&dsn.;

%let practice_id=000;
%let client_id=4;
%let wflow_exec_id=5216;
%let dsn=%str(cistage.claims_&practice_id._&client_id._&wflow_exec_id.);
%let incoming=&dsn.;
%let input=ssn;


data cistage.Claims_280_4_9999;
 set cistage.Claims_280_4_5214 (obs=10000);
 if _n_ > 4000 then claim_exists_key=1;
run;

%let dsn=%str(cistage.Claims_280_4_9999);
%let incoming=&dsn.;



		  proc sql;
		    create table primary_provider_xref as
		    select a.provider_key, 
                   a.client_key, 
                   a.practice_key, 
                   b.datasourceid as vmine_key, 
                   c.npi1, 
                   c.provider_name, 
                   d.tin
		    from ciedw.provider_practice_xref as a left join
		         ids.datasource_practice as b
		    on a.practice_key=b.practiceid left join
		         ciedw.provider as c
		    on a.provider_key=c.provider_key left join
		         ciedw.practice as d
		    on a.practice_key=d.practice_key		    
		    where  a.client_key=4
              and c.clncl_int_eff_dt < datetime()
              and c.clncl_int_exp_dt = .
              and a.exp_dt = .
            order by c.provider_name;
		  quit;
		  
data cistage.xxx;
set cihold.nl_hold_encounter_header_detail;
where practice_id = &practice_id.;
run;

data cistage.yyy;
set cihold.nl_hold_encounter_header_detail;
where practice_id = &practice_id.
      and  WFLOW_EXEC_ID in (5216)
	  and provname='ALAN SHAPIRO'
      and provider_key=0;
run;

 Shapiro, Alan prov-202 pract-371(347)-93 

proc sql;
connect to oledb(init_string=&ciedw. );
execute (
	update CIHold.dbo.NL_HOLD_ENCOUNTER_HEADER_DETAIL
	set LOAD_FLAG=9 ,
        PROVIDER_KEY=202
	where WFLOW_EXEC_ID in (5216)
	  and provname='ALAN SHAPIRO'
      and provider_key=0
      and practice_id = 347
    	 ) by oledb;
quit;

data cistage.zzz;
set cihold.nl_hold_encounter_header_detail;
where load_flag=9;
run;


proc sql;
connect to oledb(init_string=&ciedw. );
execute (
	delete from  ciedw.[dbo].ENCOUNTER_HEADER 
	where WFLOW_EXEC_ID=9999

	delete from  ciedw.[dbo].ENCOUNTER_DETAIL
	where WFLOW_EXEC_ID=9999
    	 ) by oledb;
quit;

 %if &sas_prgm_id=8 %then %do --- claims    load
 %if &sas_prgm_id=? %then %do --- claims no load

*************************************************/    

*SASDOC--------------------------------------------------------------------------
| Macro:  edw_claims_no_load_retry  
|  
| Create the SAS dataset for retry of the member, encounter header, and 
| detail from the no load hold table.
+------------------------------------------------------------------------SASDOC*;


%macro edw_claims_no_load_retry(dsn=);

	data &dsn. ;
	  format member_key 16. svcdt mmddyy10.  service_date $20.  service_date2   datetime22.3 ;
	  set cihold.nl_hold_encounter_header_detail (rename = (svcdt=svcdt2) 
	                                              drop   = admit_date discharge_date service_date );
	  where load_flag=9 
        and dq_member_flag=0 
        and procedure_code_key ne 0 
        and provider_key ne 0
        and svcdt2 < datetime(); /** business rules for retrying to load data **/

		if dq_member_flag=0 
        and procedure_code_key ne 0 
        and provider_key ne 0
        and svcdt2 < datetime() then do;
		  load_flag=0;
		end;
		else do;
		  load_flag=1;
		end;
		dq_claim_flag=0; 
		claim_exists_key=0;
		updated_by=created_by;
		svcdt=datepart(svcdt2); 
		s_date=dhms(svcdt,0,0,0);
		s_dt=datepart(s_date);
		s_tm=timepart(s_date);
		service_date = put(s_dt,yymmdd10.)||" "||put(s_tm,time8.);
		service_date2=dhms(svcdt,0,0,0);
		detail_key=_n_;
		member_key=member_key;
		encounter_key=1;
		admit_date = '';
		discharge_date='';
		**wflow_exec_id=&wflow_exec_id.; /** testing - identify the records**/

		drop s_date s_dt s_tm svcdt2;
	run;

	proc sql noprint;
	  select count(*) into: retry_count
	  from &dsn. ;
	quit;

	%put NOTE: retry_count = &retry_count. ;

	%if &retry_count eq 0 %then %do;
	  %put ERROR: There are 0 observations within &dsn. - Please reset the variables within the cihold correctly. ;
	  %put ERROR: The reset needs correction load flag = 9, provider key, procedure code key, service date, and member key. ;
	  %let err_fl=1;
	  %set_error_flag;
  	  %on_error(ACTION=ABORT);
	%end;
	%else %do ;
	    proc sql;
	      connect to oledb(init_string=&cihold.);
	      execute ( 
					update cihold.dbo.nl_hold_encounter_header_detail
					set load_flag=2 
					where load_flag=9 
	              ) 
	      by oledb; 
	    quit;
	%end;

%mend edw_claims_no_load_retry;

%edw_claims_no_load_retry(dsn=cistage.claims_&practice_id._&client_id._&wflow_exec_id.);

