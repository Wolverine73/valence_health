
/*HEADER------------------------------------------------------------------------
|
| program:  edw_claims_load.sas
|
| location: M:\CI\programs\Development\EDW
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
| 01DEC2011 - Brian Stropich  - Clinical Integration  1.0.02
|             Added logic to create XML on the fly and facility indicator condition
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             Added statement begin and end dates to header logic
|             Added payer key to header logic 
|
| 06APR2012 - Winnie Lee  - Clinical Integration  Release 1.1 H04 M03
|
| 03MAY2012 - G Liu - Clinical Integration 1.2.02
|			  Added PERSON_KEY to header_var
|
| 03MAY2012 - Winnie Lee - Clinical Integration Release 1.2 H05 H07
|			  Added DATA_SOURCE_ID and POA1_PFKEY-POA9_PFKEY
|			  to the header_by_vars and other_by_vars. Also added logic to include
|			  DATA_SOURCE_ID and PERSON_KEY to claim exist logic and historical logic
|
| 08JUN2012 - Brian Stropich - Clinical Integration Release 1.3.01 M01 
|			  Added member_key_old to the header keep statements
|
| 14JUN2012 - G Liu - Clinical Integration Release 1.3.02 H01
|			  Added payer conditional logic to toggle between UB and HCFA runs
|			  Added dummy trigget dataset in staging folder to toggle execution of 
|				UB vs HCFA for step 1.
|			  Rename staging dataset to include prefix of ub_ or hcfa_ after completion.
|			  Payer data, load everything unless dq_member_flag=1 (which should never happen)
|				Reset load_flag in this program, which has different definition than step 3
|
| 05JUL2012 - G Liu - Clinical Integration Release 1.4.01 TCHP
|			  Add ciedw.dbo.encounter_financial load
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
%bpm_environment


*SASDOC--------------------------------------------------------------------------
| Macro:  create_sas_encounters  
|  
| Create the SAS datasets for encounter header and detail from the 
| SAS staging dataset
+------------------------------------------------------------------------SASDOC*;


%macro create_sas_encounters(dsn=);

	%if %sysfunc(exist(&dsn)) %then %do;  /** begin - dsn **/

		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to start.   
		+------------------------------------------------------------------------SASDOC*; 
		%bpm_process_control(timevar=START)

		%global sasprogramby;
		%if &sas_prgm_id.=18 %then %do;
			%let sasprogramby='reprocess - error';
		%end;
		%else %if &sas_prgm_id.=19 %then %do;
			%let sasprogramby='reprocess - nl hold';
		%end;
		%else %do;
			%let sasprogramby='bpm - sas';
		%end;

		%global incoming_library incoming_dataset;
	 	%let incoming_library=%scan(&dsn.,-2,'.');
		%let incoming_dataset=%scan(&dsn.,-1,'.');
	 	%if &incoming_library.= %then %let incoming_library=work;

		*SASDOC--------------------------------------------------------------------------
		| data_source_information - retrieve information about practice.   
		+------------------------------------------------------------------------SASDOC*; 		
		%data_source_information;

		/* For Payer, toggle between UB & HCFA using dummy dataset in staging folder, and set facility_indicator according to
			which type of claim that has yet to be processed */
		%if &dataformatgroupid.=20 %then %do;
			%if &PayerContainUB. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._ub_batch&batch_key.))=0 %then %do;
				%let facility_indicator=1;
			%end;
			%else %if &PayerContainHCFA. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._hcfa_batch&batch_key.))=0 %then %do;
				%let facility_indicator=0;
			%end;

			/* for now, since encounter header practice key is not nullable */
			/* reset load_flag regardless of dq_claim_flag */
			data &dsn.;
				set &dsn.;
				practice_key=coalesce(practice_key,0);
				if dq_member_flag=1 then load_flag=1;
				else do; load_flag=0; dq_claim_flag=0; end;
			run;
		%end;

		*SASDOC--------------------------------------------------------------------------
		| create_sas_header_detail - Initialize dates.   
		| 
		+------------------------------------------------------------------------SASDOC*; 
		data _null_;
		  date=put(today(),date9.);
		  time=put(time(),time16.6);
		  call symput('date',date); 
		  call symput('time',time);  
		run; 

		data date_time;
		  date=datetime() ; 
		  _dt=datepart(date);
		  _tm=timepart(date);
	    run; 

		%if &sas_prgm_id.=18 or &sas_prgm_id.=19 %then %do;
			proc sql;
				update	&dsn.
			  	set	created_by = &sasprogramby.,
				  	updated_by = &sasprogramby.
				;
			quit;
		%end;
		
		*SASDOC--------------------------------------------------------------------------
		| Variable definition for claims load
		|
		| header_by_vars - Header columns needed for the ciedw.encounter_header table
		| detail_by_vars - Detail columns needed for the ciedw.encounter_detail table
		| other_by_vars  - Other important columns needed for the process
		| 
		+------------------------------------------------------------------------SASDOC*; 
		%if &facility_indicator. = 0 %then %do;
				  %let header_by_vars= client_key payer_key person_key member_key member_key_old provider_key practice_key data_source_id service_date mod1 mod2  admit_diagnosis_cd drg_key
				     diagnosis_cd1-diagnosis_cd9 is_sensitive is_sensitive_diag1-is_sensitive_diag9 surgical_cd1-surgical_cd6 file_date_key  
				     admit_date discharge_date bill_type discharge_status pos tin referral claim_source wflow_exec_id 
				     statement_begin_date statement_end_date
					 poa1_pfkey poa2_pfkey poa3_pfkey poa4_pfkey poa5_pfkey poa6_pfkey poa7_pfkey poa8_pfkey poa9_pfkey;
		%end;
		%else  %if &facility_indicator. = 1 %then %do;
				  %let header_by_vars= client_key payer_key person_key member_key member_key_old provider_key practice_key data_source_id admit_diagnosis_cd drg_key
				     diagnosis_cd1-diagnosis_cd9 is_sensitive is_sensitive_diag1-is_sensitive_diag9 surgical_cd1-surgical_cd6 file_date_key  
				     admit_date discharge_date bill_type discharge_status pos tin referral claim_source wflow_exec_id 
				     statement_begin_date statement_end_date
					 poa1_pfkey poa2_pfkey poa3_pfkey poa4_pfkey poa5_pfkey poa6_pfkey poa7_pfkey poa8_pfkey poa9_pfkey;

		%end;
		
		%let detail_by_vars = procedure_code_key maj_cat_name service_date service_date2 mod1 mod2 revenue_code submitted market_value 
				      units wflow_exec_id created_by updated_by vmine_kprocessid;
		%let other_by_vars =  encounter_key detail_key historical fname lname practice_id data_source_id proccd claim_key dq_member_flag dq_claim_flag load_flag;				  
		
		%put NOTE: header_by_vars = &header_by_vars.;
		%put NOTE: detail_by_vars = &detail_by_vars.;
		%put NOTE: other_by_vars  = &other_by_vars.;

		*SASDOC--------------------------------------------------------------------------
		| create_sas_encounters - Create encounter detail data from cistage dataset.   
		| 
		+------------------------------------------------------------------------SASDOC*;
		data encounter_detail;
		  format date datetime. created_on updated_on $20. ;  
		  if _n_=1 then set date_time;
		  set &dsn 
	      	 (where = (load_flag=0 and dq_member_flag=0 and dq_claim_flag=0 )
	          keep  = 	&detail_by_vars.
				&header_by_vars. 
				&other_by_vars.				
				%if &facility_indicator. = 1 %then %do;
				    e_key
				%end;				
				) ;
				
		  created_on = put(_dt,yymmdd10.)||" "||put(_tm,time8.);
		  updated_on = put(_dt,yymmdd10.)||" "||put(_tm,time8.);
		  if historical=0 then vMine_kProcessID=1;
		  else if historical=1 then vMine_kProcessID=2;
	      drop date _dt _tm  ;
		run;

		%set_error_flag
	  	%on_error(ACTION=ABORT)

		%check_sas_ciedw_variables
		%check_issue_count(dataset_in=&syslast., validation=61, zero_count=valid)

	  	%global historical;
		data _null_;
		  set encounter_detail(obs=1); 
		  call symput('historical',historical);
		run; 
		
		%put NOTE: historical = &historical. ;
		
		%check_issue_count(dataset_in=encounter_detail, validation=58)


		*SASDOC--------------------------------------------------------------------------
		| create_sas_encounters - Create encounter header data from cistage dataset.   
		| 
		+------------------------------------------------------------------------SASDOC*;
		data encounter_header ; 
		 set encounter_detail (where = (dq_member_flag=0 and dq_claim_flag=0 ));
		 keep   	&header_by_vars.
				encounter_key
				created_on
				created_by
				updated_on
				updated_by ;
		run;

		%set_error_flag
	  	%on_error(ACTION=ABORT)

		*SASDOC--------------------------------------------------------------------------
		| create_sas_encounters - Determine unique header claim records and identify 
		| each one with a claim ID.  This claim ID will be merged back onto the 
		| detail claim records to identify CIEDW header and detail keys.
		+------------------------------------------------------------------------SASDOC*;
/*		proc sql noprint;
		  select distinct(wflow_exec_id) into: wflow separated by ','
		  from encounter_detail ;
		quit;

		%put NOTE: wflow = &wflow. ;
*/
	    proc sql noprint;
		  connect to oledb(init_string=&ciedw.);
		  select max_claim_id into: max_claim_id from connection to oledb
			(	
				select max(claim_id) as max_claim_id
				from  [ciedw].[dbo].[encounter_header] (nolock)
				/**where wflow_exec_id in (&wflow.)**/
			);
	    quit;

		%if &max_claim_id = . %then %let max_claim_id = 0;

		%put NOTE: max_claim_id = &max_claim_id. ;


		proc sort data = encounter_header 	     
		     %if &facility_indicator. = 0 %then %do;
		       nodup 
		     %end;
		     %else %do;
		       nodupkey
                     %end;;
		  by &header_by_vars. ;
		run;

		data encounter_header;
		  set encounter_header;
		  claim_id=&max_claim_id. + _n_;
		run;

		%set_error_flag
	  	%on_error(ACTION=ABORT)

		*SASDOC--------------------------------------------------------------------------
		| create_sas_header_detail - Create claim ID to associate the header and detail    
		| records to one another when inserting the claims into CIEDW.  This ID will  
		| allow the process to map the encounter keys to the header and detail once
		| the data is broken into two.
		|
		| In addition, assign procedure code key from the CIEDW procedure table.
		|
		+------------------------------------------------------------------------SASDOC*;
		proc sort data = encounter_detail ;
		  by &header_by_vars. ;
		run;

		data encounter_detail;
		  merge encounter_detail (in=a)
		        encounter_header (in=b rename=(claim_id=claim_id_header)
		                                      drop = created_on created_by updated_on updated_by);
		  by &header_by_vars. ;
		  if a and b then do;
		    claim_id=claim_id_header;
		  end; 
		run; 

		%set_error_flag
	  	%on_error(ACTION=ABORT)

		proc sql undo_policy=none;
		  create table encounter_detail  as
		  select a.*,   
		         coalesce(c.procedure_code_key,0) as procedure_code_key
		  from encounter_detail (drop = procedure_code_key)  a  
		  left outer join ciedw.procedure_cd c 
		    on a.proccd = c.procedure_code;
		quit;		 

		%set_error_flag
	  	%on_error(ACTION=ABORT)

	%end;  /**end - dsn **/
	%else %do;
	  %put NOTE: The dataset &dsn. does not exists ;
	%end;

%mend create_sas_encounters;


*SASDOC--------------------------------------------------------------------------
| Macro:  load_sas_encounters  
|  
| Update the SAS datasets for header and detail from information from the CIEDW.
|
| The information from the CIEDW will determine the following:
|   1.  Updates - If the data exists from a prior load
|   2.  Inserts - If the data does not exists
|   3.  Encounter Key - The header data needs to be inserted first to obtain  
|                       this information
|  
+------------------------------------------------------------------------SASDOC*;

%macro load_sas_encounters(dsn=);

	*SASDOC--------------------------------------------------------------------------
	| load_sas_encounters - Create a temporary header + detail data from CIEDW. 
    |                       This will allow the 6 variables which create an ID
    |                       for the claims to be available within one source to 
    |                       be referenced to validate if there is any matches. 
	| 
	+------------------------------------------------------------------------SASDOC*;
	%if %sysfunc(exist(&dsn)) %then %do;  /** begin - dsn **/	

		*SASDOC--------------------------------------------------------------------------
		| encounter header and detail - remove workflow ID if exist. 
		|                       
		+------------------------------------------------------------------------SASDOC*;		
/* Commenting this removal paragraph temporarily. Wasting time on this step. G */
/*		proc sql;
		  connect to oledb(init_string=&cihold. );
		  execute (

				delete from [ciedw].[dbo].[encounter_header]
				where wflow_exec_id in (&wflow_exec_id.)

			  ) by oledb;
		  execute (

				delete from [ciedw].[dbo].[encounter_detail]
				where wflow_exec_id in (&wflow_exec_id.)

			  ) by oledb;
		quit;
*/
		%put NOTE: PRACTICE_ID = &practice_id. ; 
		%put NOTE: DATA_SOURCE_ID = &practice_id.;

		%if %sysfunc(exist(cihold.saswrk_header_detail_&wflow_exec_id.)) %then %do;
		    proc sql;
		      connect to oledb(init_string=&cihold.);
		      execute ( 
		                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
		              ) 
		      by oledb; 
		    quit;
		%end;

	    proc sql;
	      connect to oledb(init_string=&sqlci.);
	      execute (
				 select distinct
				       max(a.[encounter_key]) as encounter_key_ciedw
				      ,a.[client_key]  
				      ,m.[member_key] 
					  ,a.[person_key]
					  ,b.[data_source_id]
				      ,a.[practice_key]
				      ,a.[provider_key]
				      
				      ,max(b.[detail_key]) as detail_key_ciedw     
				      ,b.[procedure_code_key]
				      ,b.[service_date]
				      ,b.[mod1]
				      ,b.[mod2]
					  %if &facility_indicator. = 1 %then %do;
					  ,b.[revenue_code]
					  %end;				      
				      ,1 as claim_exists_key

				 into  [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ] 
				 
				 from  [ciedw].[dbo].[encounter_detail] as b inner join				 
				       [ciedw].[dbo].[encounter_header] as a 
				         on a.encounter_key=b.encounter_key
					 and a.client_key=b.client_key inner join						       
				       [ciedw].[dbo].[person_member_map] as m 
				         on a.person_key = m.person_key	and a.client_key=m.client_key
				       
				 where a.encounter_key=b.encounter_key
				   and a.client_key=b.client_key 
				   and a.client_key=&client_id.
				   and b.data_source_id in (&practice_id. )
				 group by 
				       a.[client_key]  
				       ,m.[member_key] 
					  ,a.[person_key]
					  ,b.[data_source_id]
				      ,a.[practice_key]
				      ,a.[provider_key]
				          
				      ,b.[procedure_code_key]
				      ,b.[service_date]
				      ,b.[mod1]
				      ,b.[mod2]	  
					  %if &facility_indicator. = 1 %then %do;
					  ,b.[revenue_code]
					  %end;				      
	             ) 
	      by oledb; 
	    quit;

		proc sql noprint;
		  select count(*) into: saswrk_count 
		  from cihold.saswrk_header_detail_&wflow_exec_id. ;
		quit;

		%put NOTE: saswrk_count = &saswrk_count. ;

		%set_error_flag
	  	%on_error(ACTION=ABORT)


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Check for matches on the 6 variables which create an ID
	    |                       for the claims.  If matches occur, then capture the
	    |                       header and detail key from the EDW which will allow the 
	    |                       process to perform an update. 
		| 
		+------------------------------------------------------------------------SASDOC*;
		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Add detail key onto detail. 
		| 
		+------------------------------------------------------------------------SASDOC*;		
		proc sql noprint;
		 select count(*) into: encounter_detail_update
		 from cihold.saswrk_header_detail_&wflow_exec_id. ;
		quit;
		
		%put NOTE: encounter_detail_update = &encounter_detail_update. ;
			
	    proc sql undo_policy=none;
	      create table encounter_detail as
	      select a.*,
	             coalesce(b.encounter_key_ciedw,0) as encounter_key_ciedw,
				 coalesce(b.detail_key_ciedw,0)    as detail_key_ciedw 
		  from encounter_detail  a 
		  left outer join cihold.saswrk_header_detail_&wflow_exec_id. b
		  on a.client_key=b.client_key 
		    and a.member_key=b.member_key
		    and a.practice_key=b.practice_key
		    and a.procedure_code_key=b.procedure_code_key
		    and a.service_date2=b.service_date
			and a.provider_key=b.provider_key
		    and a.mod1=b.mod1
			and a.mod2=b.mod2 
			and a.data_source_id=b.data_source_id
			and a.person_key=b.person_key
			%if &facility_indicator. = 1 %then %do;
			  and a.revenue_code=b.revenue_code
			%end; ;
	    quit; 
	    
	    
		%set_error_flag
	  	%on_error(ACTION=ABORT)


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Add encounter key onto header. 
		| 
		+------------------------------------------------------------------------SASDOC*;
	    proc sort data = encounter_detail (where = (encounter_key_ciedw ne 0) 
	                                       keep  = claim_id_header encounter_key_ciedw
                                                   service_date procedure_code_key mod1 mod2
							%if &facility_indicator. = 1 %then %do;
							  revenue_code
							%end;   )
	              out  = ciedw_header_info  nodupkey;
	      by claim_id_header encounter_key_ciedw ;
	    run;
	    
 	    /* We should drop service_date, mod1 and mod2 from left table, or don't keep from right table
			coz those fields are common and will create unnecessary warnings */
	    proc sql undo_policy=none;
	      create table encounter_header as
	      select a.*,
                 b.service_date,
                 b.procedure_code_key,
                 b.mod1,
                 b.mod2, 
				%if &facility_indicator. = 1 %then %do;
				     b.revenue_code,
				%end;                 
		         coalesce(b.encounter_key_ciedw,0) as encounter_key_ciedw 	          
		  from encounter_header  a 
		  left outer join ciedw_header_info b
		  on a.claim_id=b.claim_id_header ;
	    quit;

		%set_error_flag
	  	%on_error(ACTION=ABORT)


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Logic to create a new header record if two are
		|                       available for the CIEDW header record.  There should
        |                       only be one record available within the encounter
        |                       header dataset else the sql merge will fail. 
		+------------------------------------------------------------------------SASDOC*;
		proc sort data = encounter_header ;
		  by encounter_key_ciedw;
		run;

		proc sql noprint;
		  select count(*) into: before_cnt
		  from encounter_header
          where encounter_key_ciedw=0;
		quit;

		%if &encounter_detail_update. ne 0 %then %do;
			data _null_;
			  set encounter_header;
			  by encounter_key_ciedw;
			  if encounter_key_ciedw ne 0; /** new claims **/
			  if not (first.encounter_key_ciedw and last.encounter_key_ciedw);
			  put _all_ ;
			run;
		%end;
		
		data encounter_header;
		  set encounter_header;
		  by encounter_key_ciedw;
		  if first.encounter_key_ciedw then encounter_key_ciedw=encounter_key_ciedw;
		  else encounter_key_ciedw=0;
		  %if &facility_indicator. = 1 %then %do;
		    if e_key > 0 then encounter_key_ciedw=e_key;
		  %end;
		run;		

		proc sql noprint;
		  select count(*) into: after_cnt
		  from encounter_header
          where encounter_key_ciedw=0;
		quit;

		%put NOTE:  Header count before logic divide: &before_cnt. ;
		%put NOTE:  Header count after logic divide: &after_cnt. ;

		%set_error_flag
	  	%on_error(ACTION=ABORT)


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Update and insert header into CIEDW. 
		|                       
		+------------------------------------------------------------------------SASDOC*;			
		data header_names;
		  set ciedw.encounter_header (obs=5);
		  drop encounter_key ;
		run;

		proc contents data = header_names 
	                   out = header_names (keep=name varnum format)  noprint;
		run;

		proc sort data = header_names;
		  by varnum;
		run;

		data header_names;
		  set header_names end=end;
		  header_names_sql='n.['||trim(left(name))||'],'; 
		  header_names_sql_update='c.['||trim(left(name))||']='||trim(left(header_names_sql));
		  if end then do;
	        header_names_sql='n.['||trim(left(name))||']';
			header_names_sql_update='c.['||trim(left(name))||']='||trim(left(header_names_sql));
		  end;
		run;

		proc sql noprint;
		  select name, 
	             header_names_sql
	      into:  header_names separated by ' ', 
	          :  header_names_sql separated by ' '
		  from header_names;
		quit;

		proc sql noprint;
		  select header_names_sql_update
	      into:  header_names_sql_update separated by ' '
		  from header_names
	      where substr(upcase(name),1,8) ne 'CREATED_';
		quit;

		%put NOTE: header_names = &header_names. ; 
		%put NOTE: header_names_sql = &header_names_sql. ; 
		%put NOTE: header_names_sql_update = &header_names_sql_update. ; 
		
		options missing='';

		data _null_;
		  set encounter_header ;
		  file "&sql_dir.\encounter_header_&wflow_exec_id..txt" delimiter='|' lrecl=1000; 
		  svcdt_source=updated_on;
		  case_source=1;
		  put &header_names.
			  encounter_key_ciedw  ;
		run;
		
		options missing=.;

		data _null_;
		  header_data_file="'"||trim("&sql_load_dir.\encounter_header_&wflow_exec_id..txt")||"'";
		  delete_header_data_file="&sql_dir.\encounter_header_&wflow_exec_id..txt";
		  header_format_file="'"||trim("&sql_load_dir.\encounter_header_load_format_&wflow_exec_id..xml")||"'";
		  call symput('header_data_file', header_data_file);
		  call symput('delete_header_data_file', delete_header_data_file);
		  call symput('header_format_file', header_format_file);
		run;
				
		%create_xml_file(outfile=encounter_header_load_format_&wflow_exec_id..xml, indata=header_names, additional_var=encounter_key_ciedw)

		proc sql;
		  connect to oledb(init_string=&ciedw. );
		  execute (
					declare @interrorcode int
					begin tran
					merge [ciedw].[dbo].[encounter_header] as c
					using openrowset (
		              bulk &header_data_file. ,
					  formatfile=&header_format_file. ,
					  rows_per_batch = 1000 ) as n
					on  c.[encounter_key] = n.[encounter_key_ciedw] 
					when not matched and n.[claim_id] <> 0 then insert values (
						 &header_names_sql.)  
					when matched and n.[claim_id] <> 0 then update set 
						 &header_names_sql_update. ;
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				 ) by oledb;
		quit;

		%set_error_flag
	  	%on_error(ACTION=ABORT)


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Add encounter key onto detail. 
		| 
		+------------------------------------------------------------------------SASDOC*;
		proc sql undo_policy=none;
		  create table encounter_detail as
		  select a.*, 
		         coalesce(b.encounter_key,0) as encounter_key	          
		  from encounter_detail (drop=encounter_key) a 
		  left outer join ciedw.encounter_header b
		    on a.claim_id=b.claim_id 
		    and a.wflow_exec_id=b.wflow_exec_id ;
		quit; 


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Update and insert detail into EDW. 
		| 
		+------------------------------------------------------------------------SASDOC*;	
		
		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Reassign claim ID to claim key which will allow the 
		| proces to map the entity ID in the bpm validation tables
		| 
		|
		+------------------------------------------------------------------------SASDOC*;
		data encounter_detail;
		  set encounter_detail;
		  claim_id=claim_key; 
		run;

		%if &encounter_detail_update. ne 0 %then %do;
			proc sort data = encounter_detail ;
			  by detail_key_ciedw;
			run;

			data encounter_detail;
			  set encounter_detail;
			  by detail_key_ciedw;
			  if detail_key_ciedw ne 0 /** new claims **/ and not (first.detail_key_ciedw) then delete;
			run;
		%end;
		
		data detail_names;
		  set ciedw.encounter_detail (obs=5);
		  drop detail_key;
		run;

		proc contents data = detail_names 
	                  out  = detail_names (keep=name varnum format)  noprint;
		run;

		proc sort data = detail_names;
		  by varnum;
		run;

		data detail_names;
		  set detail_names end=end;
		  detail_names_sql='n.['||trim(left(name))||'],'; 
		  detail_names_sql_update='c.['||trim(left(name))||']='||trim(left(detail_names_sql));
		  if end then do;
	        detail_names_sql='n.['||trim(left(name))||']';
			detail_names_sql_update='c.['||trim(left(name))||']='||trim(left(detail_names_sql));
		  end;
		run; 

		proc sql noprint;
		  select name, 
	             detail_names_sql 
	      into:  detail_names separated by ' ', 
	          :  detail_names_sql separated by ' ' 
		  from detail_names;
		quit;

		proc sql noprint;
		  select detail_names_sql_update
	      into:  detail_names_sql_update separated by ' '
		  from detail_names
		  where substr(upcase(name),1,8) ne 'CREATED_';
		quit;

		%put NOTE: detail_names = &detail_names. ; 
		%put NOTE: detail_names_sql = &detail_names_sql. ; 
		%put NOTE: detail_names_sql_update = &detail_names_sql_update. ;
		  
		options missing='';
		
		data _null_;
		  set encounter_detail ;  
		  file "&sql_dir.\encounter_detail_&wflow_exec_id..txt" delimiter='|' lrecl=1000; 
		  put &detail_names. 
			  detail_key_ciedw  ;
		run;
		
		options missing=.;

		data _null_;
		  detail_data_file="'"||trim("&sql_load_dir.\encounter_detail_&wflow_exec_id..txt")||"'";
		  delete_detail_data_file="&sql_dir.\encounter_detail_&wflow_exec_id..txt";
		  detail_format_file="'"||trim("&sql_load_dir.\encounter_detail_load_format_&wflow_exec_id..xml")||"'";
		  call symput('detail_data_file', detail_data_file);
		  call symput('delete_detail_data_file', delete_detail_data_file);
		  call symput('detail_format_file', detail_format_file);
		run;
		
		%create_xml_file(outfile=encounter_detail_load_format_&wflow_exec_id..xml, indata=detail_names, additional_var=detail_key_ciedw )

		proc sql;
		  connect to oledb(init_string=&ciedw. );
		  execute (
					declare @interrorcode int
					begin tran
					merge [ciedw].[dbo].[encounter_detail] as c
					using openrowset (
		              bulk &detail_data_file. ,
					  formatfile=&detail_format_file. ,
					  rows_per_batch = 1000 ) as n
					on  c.[encounter_key] = n.[encounter_key]
					and c.[detail_key]    = n.[detail_key_ciedw]				
					when not matched and n.[claim_id] <> 0 then insert values (
					       &detail_names_sql.)  
					when matched and n.[claim_id] <> 0 then update set 
					       &detail_names_sql_update. ;
					if (@interrorcode <> 0) begin
						rollback tran
					end
					commit tran
				 ) by oledb;
		quit;

		%set_error_flag
	  	%on_error(ACTION=ABORT)
	  	
		*SASDOC--------------------------------------------------------------------------
		| Download encounter_key and detail_key for each claim_id (in EDW detail, which 
		|	is the same as claim_key in staging dataset, and retain encounter table keys
		|	in staging dataset.
		+------------------------------------------------------------------------SASDOC*;
		proc sql;
			connect to oledb(init_string=&sqlci. readbuff=10000);
			create table encounter_table_keys(compress=no) as
			select	*
			from	connection to oledb
					(	select	claim_id as claim_key, encounter_key, detail_key
						from	ciedw.dbo.encounter_detail(nolock)
						where	wflow_exec_id=&wflow_exec_id.
					);
		quit;

		data &dsn.;
			if _n_=0 then set encounter_table_keys;
			declare hash h_key(dataset:'encounter_table_keys');
			h_key.definekey('claim_key');
			h_key.definedata('encounter_key','detail_key');
			h_key.definedone();
			call missing(claim_key,encounter_key,detail_key);
			do while (not lstobs);
				encounter_key=0; detail_key=0;
				set &dsn.(drop=encounter_key detail_key) end=lstobs;
				if h_key.find() then output;
				else output;
			end;
			stop;
		run;

		/* Load to encounter financial table if we have allowed_amt or paid_amt field. */
		%if &dataformatgroupid.=20 %then %do; /* begin - payer, load encounter financial */
			%let ecl_dsid=%sysfunc(open(&dsn.));
			%let ecl_allowedamt_ind=%sysfunc(varnum(&ecl_dsid.,allowed_amt));
			%let ecl_paidamt_ind=%sysfunc(varnum(&ecl_dsid.,paid_amt));
			%let ecl_dsrc=%sysfunc(close(&ecl_dsid.));

			%if &ecl_allowedamt_ind. or &ecl_paidamt_ind. %then %do;
				%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do; proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit; %end;
				proc sql;
					connect to oledb(init_string=&sqlci.);
					execute	(	select	top 0 *
								into	cihold.dbo.saswrk_bulkload_&wflow_exec_id.
								from	ciedw.dbo.encounter_financial(nolock)
								where	client_key=&client_id.

								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. drop column encounter_financial_key
								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. add default &client_id. for client_key
								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. add default &wflow_exec_id. for created_wflow_exec_id
								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. add default getdate() for created_on
								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. add default &sasprogramby. for created_by
								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. add default &wflow_exec_id. for updated_wflow_exec_id
								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. add default getdate() for updated_on
								alter table cihold.dbo.saswrk_bulkload_&wflow_exec_id. add default &sasprogramby. for updated_by
							)
					by oledb;
				quit;

				%bulkload_to_cio(&wflow_exec_id.,&dsn.,
								 m_desttable=cihold.dbo.saswrk_bulkload_&wflow_exec_id.,
								 m_keepvar=encounter_key detail_key 
								 		   paid_date check_date
										   units
										   billed_amt allowed_amt paid_amt refund_amt 
										   copay_amt deductible_amt coinsurance_amt cob_amt,
								 m_isdecimal=billed_amt allowed_amt paid_amt refund_amt 
											copay_amt deductible_amt coinsurance_amt cob_amt,
								 m_isdate=paid_date check_date
								)
				%set_error_flag
			  	%on_error(ACTION=ABORT)

				proc sql;
					connect to oledb(init_string=&sqlci.);
					execute	(	declare @interrorcode int
								begin tran
									merge	ciedw.dbo.encounter_financial as a
									using	cihold.dbo.saswrk_bulkload_&wflow_exec_id. as b 
											on a.client_key=b.client_key and a.encounter_key=b.encounter_key and a.detail_key=b.detail_key
									when matched then update set
											paid_date=b.paid_date, check_date=b.check_date,
											units=b.units,
											billed_amt=b.billed_amt, allowed_amt=b.allowed_amt, paid_amt=b.paid_amt, refund_amt =b.refund_amt,
											copay_amt=b.copay_amt, deductible_amt=b.deductible_amt, coinsurance_amt=b.coinsurance_amt, cob_amt=b.cob_amt,
											updated_wflow_exec_id=b.updated_wflow_exec_id, updated_on=b.updated_on, updated_by=b.updated_by
									when not matched then insert
										(	client_key, encounter_key, detail_key,
											paid_date, check_date,
											units,
											billed_amt, allowed_amt, paid_amt, refund_amt, 
											copay_amt, deductible_amt, coinsurance_amt, cob_amt,
											created_wflow_exec_id, created_on, created_by)
									values (b.client_key, b.encounter_key, b.detail_key,
											b.paid_date, b.check_date,
											b.units,
											b.billed_amt, b.allowed_amt, b.paid_amt, b.refund_amt, 
											b.copay_amt, b.deductible_amt, b.coinsurance_amt, b.cob_amt,
											b.created_wflow_exec_id, b.created_on, b.created_by)
									;
								if (@interrorcode <> 0) begin
									rollback tran
								end
								commit tran
							)
					by oledb;
				quit;
				%set_error_flag
			  	%on_error(ACTION=ABORT)

				proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
			%end;
		%end; /* end - payer, load encounter financial */


		*SASDOC--------------------------------------------------------------------------
		| If historical, ensure that all vmine_kprocessid is set to 1
		| 	If there are existing claims before we pull full historical, those claims
		|	will not be updated with vmine_kprocessid=1 in code above.
		+------------------------------------------------------------------------SASDOC*;
	  %if &historical.=0 %then %do;
		proc sql noprint;
			connect to oledb(init_string=&sqlci.);
			execute ( 
					update 	ciedw.dbo.encounter_detail
					set 	vmine_kprocessid = 1
					where	client_key=&client_id.
					and 	data_source_id in (&practice_id.)
			) 
			by oledb; 
		quit;
	  %end;

		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Insert header and detail claims into NL Hold. 
		| Load entire staging dataset into CIHold.HOLD_ENCOUNTER_HEADER_DETAIL 
		| 	If historical, do not perform nl_hold or hold
		+------------------------------------------------------------------------SASDOC*;
/*	  %if &historical. gt 0 %then %do;*/ /* we want to load 1st pass to NL HOLD so that claim_exists_key can be flagged correct on 2nd pass for claims in NL HOLD */
	    /* Ideally the first time these programs execute, we want to delete, and stop the delete operation
	  		when we loop through other practices and keep calling this program, but right now we just
	  		assume that nothing is in both tables with the same wflow. As long as we don't ever recycle
	  		workflow id, we will be fine. G */
		%if &sas_prgm_id. ne 18 and &sas_prgm_id. ne 19 %then %do; 
			/* Commenting this removal paragraph temporarily. Wasting time on this step. G */
			/*proc sql;
			  connect to oledb(init_string=&cihold. );
			  execute (
	
					delete from [cihold].[dbo].[nl_hold_encounter_header_detail]
					where wflow_exec_id in (&wflow_exec_id.)
	
				  ) by oledb;
			  execute (
	
					delete from [cihold].[dbo].[hold_encounter_header_detail]
					where wflow_exec_id in (&wflow_exec_id.)
	
				  ) by oledb;
			quit;*/
		%end;

		*SASDOC--------------------------------------------------------------------------
		| Add fields to staging dataset to avoid errors when loading NL_HOLD and HOLD tables
		| Similar step exists within Step 3 - Transformation 
		+------------------------------------------------------------------------SASDOC*;
		%macro build_missing_edw_variables;
		
			data names1;
			  set cihold.NL_HOLD_ENCOUNTER_HEADER_DETAIL (obs=5);
			  drop nl_hold_ehd_key orig_wflow_exec_id orig_nl_hold_ehd_key created_on;
			run;
			
			data holdnames1;
			  set cihold.HOLD_ENCOUNTER_HEADER_DETAIL (obs=5);
			  drop hold_ehd_key orig_hold_ehd_key orig_wflow_exec_id created_on;
			run;

			data startnames;
			  set &dsn. (obs=5);
			run;

			proc contents data=startnames
			      out = startnames (keep=name varnum type) noprint;
			run;

			data startnames;
			  set startnames;
			  name=upcase(name);
			run;

			proc contents data = names1 
				   out = names1 (keep=name varnum type)  noprint;
			proc contents data = holdnames1 
				   out = holdnames1 (keep=name varnum type)  noprint;
			run;

			data names1;
			set names1;
			if upcase(NAME) in ('STATEMENT_BEGIN_DATE','STATEMENT_END_DATE') then type=2;
			run;

			data holdnames1;
			set holdnames1;
			if upcase(NAME) in ('STATEMENT_BEGIN_DATE','STATEMENT_END_DATE') then type=2;
			run;

			proc sort data = names1;
			  by varnum;
			proc sort data = holdnames1;
			  by varnum;
			run;

			%let cmiss = = ' '  ;
			%let nmiss = = .  ;

			proc sql;
			  create table allmiss as
			select a.name,a.type,
			   case when a.type = 1 then left(trim(a.name))||left(trim("&nmiss." ))||left(trim(";"))
				when a.type = 2 then left(trim(a.name))||left(trim("&cmiss."))||left(trim(";"))
				end as rslt
			  from names1 a left outer join startnames b
			  on a.name=b.name
			  where b.type = .
			union
			select a.name,a.type,
			   case when a.type = 1 then left(trim(a.name))||left(trim("&nmiss." ))||left(trim(";"))
			when a.type = 2 then left(trim(a.name))||left(trim("&cmiss."))||left(trim(";"))
			end as rslt
			  from holdnames1 a left outer join startnames b
			  on a.name=b.name
			  where b.type = .  ;
			quit;

			proc sql noprint;
			  select count(*) into: cntall
			  from allmiss ;
			quit;

			%if &cntall > 0 %then %do;
				proc sort data=allmiss nodupkey;by rslt;run;

				proc sql noprint;
				  select rslt into: lines separated by ' '
				  from allmiss;
				quit;

				data &dsn.;
				  set &dsn.;
				  &lines.;
				run;

			%end;

		%mend build_missing_edw_variables;
		%build_missing_edw_variables;


		data names;
		  set cihold.NL_HOLD_ENCOUNTER_HEADER_DETAIL (obs=5);
		  drop nl_hold_ehd_key ;
		data holdnames;
		  set cihold.HOLD_ENCOUNTER_HEADER_DETAIL (obs=5);
		  drop hold_ehd_key ;
		run;

		proc contents data = names 
	                   out = names (keep=name varnum)  noprint;
		proc contents data = holdnames 
	                   out = holdnames (keep=name varnum)  noprint;
		run;
		
		data names;
		set names;
		if upcase(NAME) in ('STATEMENT_BEGIN_DATE','STATEMENT_END_DATE') then type=2;
		run;

		data holdnames;
		set holdnames;
		if upcase(NAME) in ('STATEMENT_BEGIN_DATE','STATEMENT_END_DATE') then type=2;
		run;

		proc sort data = names;
		  by varnum;
		proc sort data = holdnames;
		  by varnum;
		run;

		proc sql noprint;
		  select name, name as keepnames 
	      into:  names separated by ',', :  keepnames separated by ' '
		  from names;
		  select name, name as keepnames 
	      into:  holdnames separated by ',', :  keepholdnames separated by ' '
		  from holdnames;
		quit;

		%put NOTE: names = &names. ; 
		%put NOTE: HOLD names = &holdnames. ; 
		
		data _null_;
		  date=put(today(),date9.);
		  call symput('date',date);
		run; 	
		
	
		%macro refmt1(var=);
		   %if &var. = svcdt  %then %do; 
		   %let var2=service_date; 
		   format &var2.2 datetime22.3;
		   &var.2=dhms(&var.,0,0,0); 
		   if &var.2 < 0 then &var.2=.;
		   &var2.2 = &var.2;
		   drop &var. &var2.;
		   rename &var.2 = &var. &var2.2 = &var2. ; 
		   %end;
		   %else %if &var. = admdt  %then %do; 
		   %let var2=admit_date; 
		   format &var2.2 datetime22.3;
		   &var.2=dhms(&var.,0,0,0); 
		   if &var.2 < 0 then &var.2=.;
		   &var2.2 = &var.2;
		   drop &var. &var2.;
		   rename &var.2 = &var. &var2.2 = &var2. ; 
		   %end;
		   %else %if &var. = disdt  %then %do; 
		   %let var2=discharge_date; 
		   format &var2.2 datetime22.3;
		   &var.2=dhms(&var.,0,0,0); 
		   if &var.2 < 0 then &var.2=.;
		   &var2.2 = &var.2;
		   drop &var. &var2.;
		   rename &var.2 = &var. &var2.2 = &var2. ; 
		   %end;
		   %else %do;
		   format &var.2 datetime22.3;
		   &var.2=dhms(&var.,0,0,0); 
		   %if &var. ne dob %then %do;
		   if &var.2 < 0 then &var.2=.;
		   %end; 
		   drop &var. ;
		   rename &var.2 = &var. ;
		   %end;
		%mend refmt1; 	

		%macro refmt2(var=);
		   format &var.2 $10.;
		   &var.2=trim(left(year(&var.)))||"-"||trim(left(month(&var.)))||"-"||trim(left(day(&var.)));
		   if &var.2 = '.-.-.' then &var.2='';
		   drop &var. ;
		   rename &var.2 = &var. ;
		%mend refmt2;		

		data nl_hold_encounter_header_detail(bufsize=128k)
			 hold_encounter_header_detail(bufsize=512k); 
		   /* CIHold currently has varchar(10). Matching CIHold so that bulkload macro will work. Otherwise,
			 	will bomb due to truncation. */
		  length payorname1 $10.;
		  format  orig_nl_hold_ehd_key orig_hold_ehd_key orig_wflow_exec_id 8.;
		  set &dsn. ; 
				  
			%refmt1(var=admdt)
			%refmt1(var=disdt)
			%refmt1(var=dob)
			%refmt1(var=moddt)
			%refmt1(var=svcdt)
			%**refmt2(var=statement_begin_date);
			%**refmt2(var=statement_end_date);			  			  
			  
			  created_on = input("&date."||put(time(),time16.6),datetime22.3) ;
			  created_by = &sasprogramby.;
			  sk_status_id=1; /** complete **/

		  if load_flag=0 then do;
			%if &sas_prgm_id.=19 %then %do; /* nl hold claim pushed to hold */
				load_flag=4;
				orig_hold_ehd_key=orig_nl_hold_ehd_key; 
			%end;
			output hold_encounter_header_detail;
		  end;
		  else if load_flag=1 then do;
			%if &sas_prgm_id.=20 %then %do; /* hold claim pushed to nl hold */
				load_flag=5;
				orig_nl_hold_ehd_key=orig_hold_ehd_key; 
			%end;
			output nl_hold_encounter_header_detail;
		  end;		  
		run;

		 /* if claims sourced from nl hold for reprocessing ends up in nl hold again, don't duplicate 
				the same rows in nl hold table again */
		 %if &sas_prgm_id. ne 19 %then %do;
		  %bulkload_to_cio(&wflow_exec_id.,nl_hold_encounter_header_detail,
							m_desttable=cihold.dbo.nl_hold_encounter_header_detail,
							m_keepvar=&keepnames.,
							m_isdecimal=submit submitted units,
							m_isdatetime=created_on svcdt,
							m_truncate=1)
			%set_error_flag
		  	%on_error(ACTION=ABORT)		
		 %end;

		  %bulkload_to_cio(&wflow_exec_id.,hold_encounter_header_detail,
							m_desttable=cihold.dbo.hold_encounter_header_detail,
							m_keepvar=&keepholdnames.,
							m_isdecimal=submit submitted units,
							m_isdatetime=created_on svcdt,
							m_truncate=1)
		
		%set_error_flag
	  	%on_error(ACTION=ABORT)		
	
/*	  %end;*/ /* if historical, do not perform nl_hold or hold */
	
	    *SASDOC--------------------------------------------------------------------------
	    | BPM - Update entity IDs on validation detail table - new and update records             
	    +------------------------------------------------------------------------SASDOC*;	
		%if %sysfunc(exist(cihold.saswrk_header_detail_&wflow_exec_id.)) %then %do;
		    proc sql;
		      connect to oledb(init_string=&cihold.);
		      execute ( 
		                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
		              ) 
		      by oledb; 
		    quit;
		%end;

	    proc sql;
	      connect to oledb(init_string=&sqlci.);
	      execute (
				 select 
				 
				       b.[detail_key] 
				      ,b.[claim_id]
				      ,b.[wflow_exec_id] 

				 into  [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
				 from  [ciedw].[dbo].[encounter_detail] as b,
				       [ciedw].[dbo].[encounter_header] as a 
				 where a.encounter_key=b.encounter_key
				   and a.client_key=b.client_key  
				   and a.client_key=&client_id.
				   and a.wflow_exec_id in (&wflow_exec_id.  )
	             ) 
	      by oledb; 
	    quit;
    
	    proc sql;
	      connect to oledb(init_string=&sqlci.);
	      execute (
				 update  [bpmmetadata].[dbo].[validation_detail]
				 set entity_id= b.detail_key
				 from [bpmmetadata].[dbo].[validation_detail]  a
				 inner join
				 [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ] b on
				    a.entity_id = b.claim_id
				    and a.wflow_exec_id=b.wflow_exec_id 
				    and a.validation_type_id in (28,29) 
	             ) 
	      by oledb; 
	    quit;

		%set_error_flag
	  	%on_error(ACTION=ABORT)
 

	    *SASDOC--------------------------------------------------------------------------
	    | BPM - Update entity IDs on validation detail table - critical records           
	    +------------------------------------------------------------------------SASDOC*;		    
		%if %sysfunc(exist(cihold.saswrk_header_detail_&wflow_exec_id.)) %then %do;
		    proc sql;
		      connect to oledb(init_string=&cihold.);
		      execute ( 
		                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
		              ) 
		      by oledb; 
		    quit;
		%end;

	    proc sql;
	      connect to oledb(init_string=&sqlci.);
	      execute (
				 select 
				 
				       b.[nl_hold_ehd_key] 
				      ,b.[claim_key]
				      ,b.[wflow_exec_id] 

				 into  [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
				 from  [cihold].[dbo].[nl_hold_encounter_header_detail] as b 
				 where  b.wflow_exec_id in (&wflow_exec_id.  )
	             ) 
	      by oledb; 
	    quit;
	    
	    proc sql;
	      connect to oledb(init_string=&sqlci.);
	      execute (
				 update  [bpmmetadata].[dbo].[validation_detail]
				 set entity_id= b.nl_hold_ehd_key
				 from [bpmmetadata].[dbo].[validation_detail]  a
				 inner join
				 [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ] b on
				    a.entity_id = b.claim_key
				    and a.wflow_exec_id=b.wflow_exec_id 
				    and a.validation_type_id in (30,31,32,33,34) 
	             ) 
	      by oledb; 
	    quit;
	    
	    %set_error_flag
	    %on_error(ACTION=ABORT)	    


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
		%bpm_process_control(timevar=COMPLETE)


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Delete temp staging table and dataset. 
		| 
		+------------------------------------------------------------------------SASDOC*;
	    proc sql;
	      connect to oledb(init_string=&cihold.);
	      execute ( 
	                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
	              ) 
	      by oledb; 
	    quit;
	    
		/**proc datasets library=%scan(&dsn,1,.) nolist;
		 delete %scan(&dsn,2,.) ;
		quit;**/
		
		data _null_;
		  x "del &delete_header_data_file.";
		  x "del &delete_detail_data_file.";
		  x "del &sql_dir.\encounter_header_load_format_&wflow_exec_id..xml";
		  x "del &sql_dir.\encounter_detail_load_format_&wflow_exec_id..xml";
		run; 

	%end;  /** end - dsn **/
	%else %do;
	  %put NOTE: The dataset &dsn. does not exists ;
	%end;

	%macro send_email_alert;
		filename mail_out email to=("edwprod@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - Complete";

		data _null_;
		file mail_out lrecl=32767;
		put "client ID = &client_id."; 
		put "practice ID = &practice_id.";
		put "system ID = &system_id.";		
		run;
	%mend send_email_alert;
	%send_email_alert


	/* Assumption here is that all payer data will have both UB and HCFA claims. If that's not true,
		we cannot use dataformatgroupid anymore. Perhaps a table to dynamically figure out what claims
		are available for each payer based on dataformatid. */
	%if &dataformatgroupid.=20 %then %do;
		%if &facility_indicator.=1 %then %do;
			data cistage.ck&client_id._fmtgrp&dataformatgroupid._ub_batch&batch_key.;
				ub=1; client_key=&client_id.; payer_dataformatgroup=&dataformatgroupid.; batch_key=&batch_key.;
				output;
			run;
			%if %sysfunc(exist(&incoming_library..ub_&incoming_dataset.)) %then %do; proc sql; drop table &incoming_library..ub_&incoming_dataset.; quit; %end;
			proc datasets lib=&incoming_library. nolist;
				change &incoming_dataset.=ub_&incoming_dataset.;
			quit;
		%end;
		%else %do;
			data cistage.ck&client_id._fmtgrp&dataformatgroupid._hcfa_batch&batch_key.;
				hcfa=1; client_key=&client_id.; payer_dataformatgroup=&dataformatgroupid.; batch_key=&batch_key.;
				output;
			run;
			%if %sysfunc(exist(&incoming_library..hcfa_&incoming_dataset.)) %then %do; proc sql; drop table &incoming_library..hcfa_&incoming_dataset.; quit; %end;
			proc datasets lib=&incoming_library. nolist;
				change &incoming_dataset.=hcfa_&incoming_dataset.;
			quit;
		%end;
	%end;

	%if %sysfunc(exist(&dsn._plmk)) %then %do;
		proc sql; 
			drop table &dsn._plmk; 
		quit;
	%end;


	*SASDOC--------------------------------------------------------------------------
	| data_source_information - retrieve information about practice.   
	+------------------------------------------------------------------------SASDOC*; 		
	%data_source_information

	/*** FIX ER MAJCATS FOR 837 INSTITUTIONAL IN CIEDW ***/

	%if &dataformatgroupid. = 3 %then %do;
		proc sql;
			connect to oledb(init_string=&ciedw.);
			select * from connection to oledb
			(
				exec dbo.usp_ERMajorCatFix &wflow_exec_id.
			);
		quit;
	%end;

%mend load_sas_encounters;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
%create_sas_encounters(dsn=cistage.claims_&practice_id._&client_id._&wflow_exec_id.)
%load_sas_encounters(dsn=cistage.claims_&practice_id._&client_id._&wflow_exec_id.)
