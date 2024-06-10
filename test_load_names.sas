
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
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
| Macro:  create_sas_encounters  
|  
| Create the SAS datasets for encounter header and detail from the 
| SAS staging dataset
+------------------------------------------------------------------------SASDOC*;

%let dsn = cistage.claims_921_6_7777 ;
%macro create_sas_encounters(dsn=);

	%if %sysfunc(exist(&dsn)) %then %do;  /** begin - dsn **/

		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to start.   
		+------------------------------------------------------------------------SASDOC*; 


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
			  %if &sas_prgm_id.=18 %then %do;
				  set	created_by = 'reprocess - error',
				  		updated_by = 'reprocess - error'
			  %end;
			  %else %if &sas_prgm_id.=19 %then %do;
				  set	created_by = 'reprocess - nl hold',
				  		updated_by = 'reprocess - nl hold'
			  %end;
				;
			quit;
		%end;

		*SASDOC--------------------------------------------------------------------------
		| create_sas_encounters - Create encounter detail data from cistage dataset.   
		| 
		+------------------------------------------------------------------------SASDOC*;
		data encounter_detail;
		  format date datetime. created_on updated_on $20. ;  
		  if _n_=1 then set date_time;
		  set &dsn 
	      	 (where = (load_flag=0 and dq_member_flag=0 and dq_claim_flag=0 )
	          keep  =  
				service_date  
				referral
				detail_key 
				procedure_code_key fname lname
				proccd
				client_key 
				service_date2
				mod1
				mod2
				revenue_code
				submitted
				market_value
				units
				wflow_exec_id  
				created_by
				updated_by
				vMine_kProcessID
				historical
				maj_cat_name
				claim_key

				encounter_key
				client_key
				payer_key
				member_key
				provider_key
				practice_key
				practice_id
				admit_diagnosis_cd
				drg_key
				diagnosis_cd1
				diagnosis_cd2
				diagnosis_cd3
				diagnosis_cd4
				diagnosis_cd5
				diagnosis_cd6
				diagnosis_cd7
				diagnosis_cd8
				diagnosis_cd9
				file_date_key
				admit_date
				discharge_date
				bill_type
				discharge_status
				pos
				tin
				referral 

	            dq_member_flag
	            dq_claim_flag
	            load_flag) ;
		  created_on = put(_dt,yymmdd10.)||" "||put(_tm,time8.);
		  updated_on = put(_dt,yymmdd10.)||" "||put(_tm,time8.);
		  if historical=0 then vMine_kProcessID=1;
		  else if historical=1 then vMine_kProcessID=2;
	      drop date _dt _tm  ;
		run;

	  	
	  	%global historical;
		data _null_;
		  set encounter_detail; 
		  call symput('historical',historical);
		run; 
		
		%put NOTE: historical = &historical. ;


		*SASDOC--------------------------------------------------------------------------
		| create_sas_encounters - Create encounter header data from cistage dataset.   
		| 
		+------------------------------------------------------------------------SASDOC*;
		data encounter_header ; 
		 set encounter_detail (where = (dq_member_flag=0 and dq_claim_flag=0 ));
		 keep   encounter_key
				client_key
				payer_key
				member_key
				provider_key
				practice_key
				service_date 
				mod1 
				mod2
				admit_diagnosis_cd
				drg_key
				diagnosis_cd1
				diagnosis_cd2
				diagnosis_cd3
				diagnosis_cd4
				diagnosis_cd5
				diagnosis_cd6
				diagnosis_cd7
				diagnosis_cd8
				diagnosis_cd9
				file_date_key
				admit_date
				discharge_date
				bill_type
				discharge_status
				pos
				tin
				referral
				wflow_exec_id
				created_on
				created_by
				updated_on
				updated_by ;
		run;


		*SASDOC--------------------------------------------------------------------------
		| create_sas_encounters - Determine unique header claim records and identify 
		| each one with a claim ID.  This claim ID will be merged back onto the 
		| detail claim records to identify CIEDW header and detail keys.
		+------------------------------------------------------------------------SASDOC*;
		proc sql noprint;
		  select distinct(wflow_exec_id) into: wflow separated by ','
		  from encounter_detail ;
		quit;

		%put NOTE: wflow = &wflow. ;

	    proc sql noprint;
		  connect to oledb(init_string=&ciedw.);
		  select max_claim_id into: max_claim_id from connection to oledb
			(	
				select max(claim_id) as max_claim_id
				from  [ciedw].[dbo].[encounter_header] 
				/**where wflow_exec_id in (&wflow.)**/
			);
	    quit;

		%if &max_claim_id = . %then %let max_claim_id = 0;

		%put NOTE: max_claim_id = &max_claim_id. ;

		proc sort data = encounter_header nodup;
		  by client_key member_key provider_key practice_key service_date mod1 mod2 admit_diagnosis_cd drg_key
		     diagnosis_cd1-diagnosis_cd9 file_date_key admit_date discharge_date bill_type 
		     discharge_status pos tin referral wflow_exec_id;
		run;

		data encounter_header;
		  set encounter_header;
		  claim_id=&max_claim_id. + _n_;
		run;

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
		  by client_key member_key provider_key practice_key service_date mod1 mod2 admit_diagnosis_cd drg_key
		     diagnosis_cd1-diagnosis_cd9 file_date_key admit_date discharge_date bill_type 
		     discharge_status pos tin referral wflow_exec_id;
		run;

		data encounter_detail;
		  merge encounter_detail (in=a)
		        encounter_header (in=b rename=(claim_id=claim_id_header)
		                                      drop = created_on created_by updated_on updated_by);
		  by client_key member_key provider_key practice_key service_date mod1 mod2 admit_diagnosis_cd drg_key
		    diagnosis_cd1-diagnosis_cd9 file_date_key admit_date discharge_date bill_type 
		    discharge_status pos tin referral wflow_exec_id;
		  if a and b then do;
		    claim_id=claim_id_header;
		  end; 
		run; 



		proc sql;
		  create table encounter_detail  as
		  select a.*,   
		         coalesce(c.procedure_code_key,0) as procedure_code_key
		  from encounter_detail (drop = procedure_code_key)  a  
		  left outer join ciedw.procedure_cd c 
		    on a.proccd = c.procedure_code;
		quit;		 



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

		proc sql noprint;
		  select distinct(practice_id) into: pid separated by ','
		  from encounter_detail ;
		quit;

		%put NOTE: pid = &pid. ;

		proc sql noprint;
		  select distinct(practice_key) into: vlink_id separated by ','
		  from encounter_detail ;
		quit;		

		%put NOTE: datasourceid = &vlink_id. ;  
		%put NOTE: practice_id = &practice_id. ; 

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
				      ,a.[member_key] 
				      ,a.[practice_key]
				      ,a.[provider_key]
				      
				      ,max(b.[detail_key]) as detail_key_ciedw     
				      ,b.[procedure_code_key]
				      ,b.[service_date]
				      ,b.[mod1]
				      ,b.[mod2]
				      ,1 as claim_exists_key

				 into  [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ] 
				 from  [ciedw].[dbo].[encounter_detail] as b,
				       [ciedw].[dbo].[encounter_header] as a 
				 where a.encounter_key=b.encounter_key
				   and a.client_key=b.client_key 
				   and a.client_key=&client_id.
				   and a.practice_key in (&vlink_id. )
			/* Are we going to have issues if practice_key is legitimately 0? We might not be able to
				   match claims? */
				 group by 
				       a.[client_key] 
				      ,a.[member_key] 
				      ,a.[practice_key]
				      ,a.[provider_key]
				          
				      ,b.[procedure_code_key]
				      ,b.[service_date]
				      ,b.[mod1]
				      ,b.[mod2]	  
	             ) 
	      by oledb; 
	    quit;

		proc sql noprint;
		  select count(*) into: saswrk_count 
		  from cihold.saswrk_header_detail_&wflow_exec_id. ;
		quit;

		%put NOTE: saswrk_count = &saswrk_count. ;

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
			
	    proc sql;
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
			and a.mod2=b.mod2 ;
	    quit; 

		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Add encounter key onto header. 
		| 
		+------------------------------------------------------------------------SASDOC*;
	    proc sort data = encounter_detail (where = (encounter_key_ciedw ne 0) 
	                                       keep  = claim_id_header encounter_key_ciedw
                                                   service_date procedure_code_key mod1 mod2)
	              out  = ciedw_header_info  nodupkey;
	      by claim_id_header encounter_key_ciedw ;
	    run;

		/* We should drop service_date, mod1 and mod2 from left table, or don't keep from right table
			coz those fields are common and will create unnecessary warnings */
	    proc sql;
	      create table encounter_header as
	      select a.*,
                 b.service_date,
                 b.procedure_code_key,
                 b.mod1,
                 b.mod2, 
		         coalesce(b.encounter_key_ciedw,0) as encounter_key_ciedw 	          
		  from encounter_header  a 
		  left outer join ciedw_header_info b
		  on a.claim_id=b.claim_id_header ;
	    quit; 


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
		run;

		proc sql noprint;
		  select count(*) into: after_cnt
		  from encounter_header
          where encounter_key_ciedw=0;
		quit;

		%put NOTE:  Header count before logic divide: &before_cnt. ;
		%put NOTE:  Header count after logic divide: &after_cnt. ;


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Update and insert header into CIEDW. 
		|                       
		+------------------------------------------------------------------------SASDOC*;		
;
			
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
		  file "&sql_dir.\encounter_header_&wflow_exec_id..txt" delimiter='|'; 
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
		

		%macro create_xml_file(outfile=, indata=, additional_var=);

			proc sql noprint;
			select count(*)+2 into: xmlcount
			from &indata.;
			quit;

			%put &xmlcount.;

			data end;
			name="&additional_var.";
			varnum=&xmlcount;
			format='';
			run;

			proc sort data = &indata.;
			  by varnum;
			run;

			data temp_xml;
			set &indata.;
			varnum=varnum+1;
			run;

			data temp_xml;
			format sqlformat $30. ;
			set temp_xml end;
			if format='' and upcase(NAME) in ('UNITS','MARKET_VALUE','SUBMITTED') then sqlformat='SQLMONEY';
			else if format='' then sqlformat='SQLBIGINT';
			else if format='$' then sqlformat='SQLVARYCHAR';
			else if format='DATETIME' then sqlformat='SQLDATETIME';
			else sqlformat='SQLBIGINT';
			run;

			data temp_xml;
				set temp_xml ;
				i+1;
				ii=left(put(i,4.));
				vnum=left(put(varnum,4.));
				call symput('name'||ii,trim(name));
				call symput('format'||ii,trim(sqlformat));
				call symput('varnum'||ii,trim(vnum));
				call symput('xmltotal',trim(ii));
			run;

			data _null_; 
				file "&sql_dir.\&outfile."; lrecl=1000 ;
				put
					'<?xml version="1.0"?>'/
					'<BCPFORMAT xmlns="http://schemas.microsoft.com/sqlserver/2004/bulkload/format" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'/
					'<RECORD>'/
					' '/
					%do i = 1 %to &xmltotal. ;
						%if &i = &xmltotal. %then %do;
						'<FIELD ID="'"&&varnum&i"'" xsi:type="CharTerm" TERMINATOR="\r\n" MAX_LENGTH="999999999"/> '
						%end;
						%else %do;
						'<FIELD ID="'"&&varnum&i"'" xsi:type="CharTerm" TERMINATOR="|" MAX_LENGTH="999999999"/> '/
						%end;
					%end;;
					put '</RECORD>';
					put '<ROW>';
					%do j=1 %to &xmltotal.;
						put '<COLUMN SOURCE="' "&&varnum&j" '" NAME="' "&&name&j" '" xsi:type="' "&&format&j" '"/>';
					%end;
				put '</ROW>';
				put '</BCPFORMAT>';
			run;
			
		%mend create_xml_file;
		
		%create_xml_file(outfile=encounter_header_load_format_&wflow_exec_id..xml, indata=header_names, additional_var=encounter_key_ciedw);


		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Add encounter key onto detail. 
		| 
		+------------------------------------------------------------------------SASDOC*;
		proc sql;
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
		
		%create_xml_file(outfile=encounter_detail_load_format_&wflow_exec_id..xml, indata=detail_names, additional_var=detail_key_ciedw );

	
	  	
		*SASDOC--------------------------------------------------------------------------
		| Download encounter_key and detail_key for each claim_id (in EDW detail, which 
		|	is the same as claim_key in staging dataset, and retain encounter table keys
		|	in staging dataset.
		+------------------------------------------------------------------------SASDOC*;
		proc sql;
			create table encounter_table_keys as
			select	claim_id as claim_key, encounter_key, detail_key
			from	ciedw.encounter_detail
			where	wflow_exec_id=&wflow_exec_id.;

			create table &dsn. as
			select	a.*,
					coalesce(b.encounter_key,0) as encounter_key,
					coalesce(b.detail_key,0) as detail_key
			from	&dsn.(drop=encounter_key detail_key) a left join encounter_table_keys b
					on a.claim_key=b.claim_key;
		quit;

		*SASDOC--------------------------------------------------------------------------
		| If historical, ensure that all vmine_kprocessid is set to 1
		| 	If there are existing claims before we pull full historical, those claims
		|	will not be updated with vmine_kprocessid=1 in code above.
		+------------------------------------------------------------------------SASDOC*;
	  

		*SASDOC--------------------------------------------------------------------------
		| load_sas_encounters - Insert header and detail claims into NL Hold. 
		| Load entire staging dataset into CIHold.HOLD_ENCOUNTER_HEADER_DETAIL 
		| 	If historical, do not perform nl_hold or hold
		+------------------------------------------------------------------------SASDOC*;
/*	  %if &historical. gt 0 %then %do;*/
	    /* Ideally the first time these programs execute, we want to delete, and stop the delete operation
	  		when we loop through other practices and keep calling this program, but right now we just
	  		assume that nothing is in both tables with the same wflow. As long as we don't ever recycle
	  		workflow id, we will be fine. G */

		*SASDOC--------------------------------------------------------------------------
		| Add fields to staging dataset to avoid errors when loading NL_HOLD and HOLD tables
		+------------------------------------------------------------------------SASDOC*;		
		
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

		proc sort data = names1;
		  by varnum;
		proc sort data = holdnames1;
		  by varnum;
		run;

		%let cmiss = = ' '  ;
		%let nmiss = = .  ;

		proc sql;
		  create table findmiss1 as
		select a.name,a.type,
		   case when a.type = 1 then left(trim(a.name))||left(trim("&nmiss." ))||left(trim(";"))
		        when a.type = 2 then left(trim(a.name))||left(trim("&cmiss."))||left(trim(";"))
			end as rslt
		  from names1 a left outer join startnames b
		  on a.name=b.name
		  where b.type = .
		  ;

		  create table findmiss2 as
		select a.name,a.type,
		   case when a.type = 1 then left(trim(a.name))||left(trim("&nmiss." ))||left(trim(";"))
	        when a.type = 2 then left(trim(a.name))||left(trim("&cmiss."))||left(trim(";"))
		end as rslt
		  from holdnames1 a left outer join startnames b
		  on a.name=b.name
		  where b.type = .
		  ;
		quit;

		data allmiss;
		  set findmiss1 findmiss2;
		run;
	
		proc sql noprint;
		  select count(*) into: cntall
		  from allmiss
		  ;
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

		data nl_hold_encounter_header_detail
			 hold_encounter_header_detail(bufsize=512k); 
		  format service_date2 admit_date2 discharge_date2 discharge_date2 dob2 moddt2 created_on datetime22.3 
		         orig_nl_hold_ehd_key orig_hold_ehd_key orig_wflow_exec_id 8.;
		  set &dsn. ; 
	
			  admit_date2=dhms(admit_date,0,0,0);
			  discharge_date2=dhms(discharge_date,0,0,0);
			  dob2=dhms(dob,0,0,0);
			  moddt2=dhms(moddt,0,0,0);
			  svcdt2=dhms(svcdt,0,0,0);  
			  service_date2=svcdt2; 
			  created_on = input("&date."||put(time(),time16.6),datetime22.3) ;
			%if &sas_prgm_id.=18 %then %do;
			  created_by = 'reprocess - error';
			%end;
			%else %if &sas_prgm_id.=19 %then %do;
			  created_by = 'reprocess - nl hold';
			%end;
			%else %do;
			  created_by = 'bpm - sas';
			%end;
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

		  drop service_date admit_date discharge_date dob moddt svcdt ;
		  rename service_date2=service_date 
					admit_date2=admit_date
					discharge_date2=discharge_date
					dob2=dob
					moddt2=moddt 
					svcdt2=svcdt;
		run;

	
	
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
	%end;  /** end - dsn **/

%mend load_sas_encounters;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
%create_sas_encounters(dsn=cistage.claims_921_6_7777);
%load_sas_encounters(dsn=cistage.claims_921_6_7777);
