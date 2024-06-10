
/*HEADER------------------------------------------------------------------------
|
| program:  edw_insert_guidelines.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Run the guidelines from the EDW
|
| logic:    
|              
|
| input:    client_id   - the client id from vmine (e.g., 4=NSAP) 
|		
|                        
| output:   Guideline SAS datasets
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
| 1JUN2012 - RS Modify loading code from proc sql insert to proc append for member_key length issue
|             
+-----------------------------------------------------------------------HEADER*/

%*sasdoc----------------------------------------------------------------------
| define sas macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
/*options sasautos = ("M:\CI\programs\Development\StandardMacros" "M:\CI\programs\Development\ClientMacros" sasautos);

options mlogic mprint symbolgen;  */



%macro edw_insert_guidelines;


/** Run guideline table refresh code here - will avoid having to update these CIEDW tables manually **/
 %include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\guideline_submeasures_refresh.sas" ;
 

	libname gline clear;
	libname gline "M:\CI\sasdata\guidelines\client_&client_id.";

		   proc sql noprint;
		     connect to oledb(init_string=&ciedw.);
		     select data_mart 
		     into :dmart separated by '' 
		     from connection to oledb
		     (	
			select data_mart
			from  [dbo].[client]  
			where client_key=&client_id. 
		     );
		   quit;

 
libname dmart  oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;BULKLOAD=yes;
              Initial Catalog=&dmart.;" preserve_tab_names=yes insertbuff=10000 readbuff=10000 insert_sql=yes;



	*SASDOC--------------------------------------------------------------------------
	| ASSIGN GUIDELINE AND SUBMEASURE KEYS FROM EDW (PRIMARY TABLE KEYS)
	+------------------------------------------------------------------------SASDOC*;

	proc sql;
	  create table gline_snap1 as
	  select distinct a.memberid,a.guideline,a.submeasure,a.submeasure_key,a.pcpid,a.guideline_key as guideline_external_id,
	        a.comp,a.date as sub_date,'Current' as period,&client_id. as client_key
	  from gline.submeasures_detail a   ;
	quit;

	data gline_snap1;
	  format member_key $16.;
	  set gline_snap1;
	  member_key=(memberid);
	run;


	proc sql;
	  create table gline_snap2 as
	  select a.member_key format $16.,
		  a.client_key,
		  a.guideline as guideline_name,
		  a.submeasure as submeasure_name,
		  c.guideline_key,
		  a.guideline_external_id,
	      a.submeasure_key as submeasure_external_id,
		  d.gdln_submeas_key as submeasure_key,
	      dhms(a.sub_date,0,0,0) as last_visit_date format datetime.,
	      a.comp as compliance,
		  e.provider_key as RESPONSIBLE_PHYSICIAN_KEY1,
		  0 as RESPONSIBLE_PHYSICIAN_KEY2,
	      0 as RESPONSIBLE_PHYSICIAN_KEY3,period,
	      datetime() as created_on format datetime.,
		  datetime() as updated_on format datetime.,
		  datetime() as guideline_snapshot_date format datetime.,
		  "BPM - SAS" as created_by,
		  "BPM - SAS" as updated_by
	  from gline_snap1 a left outer join ciedw.guideline c on a.client_key = c.client_key
	   and a.guideline_external_id=c.guideline_External_id
	  left outer join ciedw.guideline_submeasure d on  c.client_key=d.client_key
	   and c.guideline_key=d.guideline_key
	   and a.submeasure_key=d.submeas_external_id
	  left outer join ciedw.provider e on a.pcpid=e.npi1
		and a.client_key=e.client_key
	  where member_key ne ''
	  order by a.member_key,c.guideline_key  ;
	quit;



	*SASDOC--------------------------------------------------------------------------
	| KILL THE PROCESS IF THERE ARE NEW GUIDELINES THAT HAVE NOT BEEN LOADED INTO 
	| THE CIEDW GUIDELINE & SUBMEASURE TABLES        
	+------------------------------------------------------------------------SASDOC*;
	%macro validation_guideline_key(gl_validation=, gl_dataset=, gl_variable=, gl_report=, gl_key=);

		%let ngline=0;

		proc sql noprint;
		  select count(*) into: ngline
		  from &gl_dataset.
		  where &gl_variable. = . ;
		quit;

		%put NOTE: Number of new &gl_validation. &gl_variable. = &ngline.;

		%if &ngline > 0 %then %do;
		
			proc sql noprint;
			  select distinct(&gl_report.),&gl_key
			      into: needgline separated by ',',
			          : needkey separated by ','
			  from &gl_dataset.
			  where &gl_variable. = .;
			quit;

			%put NOTE: Need to update &gl_validation. table with - &needgline. ID numbers - &needkey.;
			
			%let err_fl=1;
			%set_error_flag;
		  	%on_error(ACTION=ABORT); 
		  	
		%end;
	%mend validation_guideline_key;

	%validation_guideline_key(gl_validation=ciedw.guideline, gl_dataset=gline_snap2, gl_variable=guideline_key,gl_report=guideline_name,gl_key=guideline_external_id);
	%validation_guideline_key(gl_validation=ciedw.guideline_submeasures, gl_dataset=gline_snap2, gl_variable=submeasure_key,gl_report=submeasure_name,gl_key=submeasure_external_id);

	*SASDOC--------------------------------------------------------------------------
	| LOAD INTO DMPAT_GUIDELINE_SNAPSHOT TABLE - REFRESH EACH TIME 
	| THE DELETE FOR THE GUIDELINE_SNAPSHOT TABLE MAY TAKE SEVERAL MINUTES        
	+------------------------------------------------------------------------SASDOC*;
	proc sql;
		connect to oledb(init_string=&data_mart.);
		select * from connection to oledb
		(
			exec dbo.TruncateGuidelineTables  
		);
	quit;

    proc append base=dmart.dmpat_guideline_snapshot_stage(dbsastype=(member_key='char(16)') IGNORE_READ_ONLY_COLUMNS=YES) 
               data=gline_snap2 force;
   run;


	/*
    proc sql ;         
	  *create table temp as select * from gline_snap2;

	  insert into dmart.dmpat_guideline_snapshot_stage
		(guideline_snapshot_date
		,member_key
		,client_key
		,guideline_key
		,guideline_external_id
		,guideline_name
		,submeasure_key
		,submeasure_external_id
		,submeasure_name
		,compliance
		,responsible_physician_key1 
		,responsible_physician_key2
		,responsible_physician_key3
		,last_visit_date
		,period
		,created_on
		,updated_on)
	  select 
		 snpshot_dt
		,member_key
		,client_key
		,guideline_key
		,guideline_external_id
		,guideline
		,gdln_submeas_key
		,sub_id
		,submeasure
		,comp
		,prov1
		,prov2
		,prov3
		,sub_date
		,period
		,created_on 
		,updated_on
	  from gline_snap2;
	quit;

	%set_error_flag;
	%on_error(ACTION=ABORT);
*/

	*SASDOC--------------------------------------------------------------------------
	| RECREATE GUIDELINE TABLE TO GET GUIDELINE AND SUBMEASURE        
	+------------------------------------------------------------------------SASDOC*;
	proc sql;
	  create table submeas_curr2 as
	  select a.pcpid,a.guideline,a.submeasure,c.guideline_key,c.guideline_external_id,
	         d.submeas_external_id as sub_id,d.gdln_submeas_key,e.provider_key,
	         'Current' as period,elig,comp,comprate
	  from gline.submeasures_current a left outer join ciedw.guideline c on a.guideline_key=c.guideline_external_id

	      left outer join ciedw.provider e on a.pcpid=e.npi1
	      left outer join ciedw.guideline_submeasure d 
	        on a.submeasure_key=d.submeas_external_id
                and c.guideline_key=d.guideline_key

		and c.client_key=d.client_key
	        and d.client_key=&client_id.
	  where c.client_key=&client_id.
	     and e.client_key=&client_id.
	   order by a.pcpid,c.guideline_key ;
	quit;


	proc sql;
	  create table submeas_prior2 as
	  select a.pcpid,a.guideline,a.submeasure,c.guideline_key,c.guideline_external_id,
	      d.submeas_external_id as sub_id,d.gdln_submeas_key,e.provider_key,
	               'Prior' as period,elig,comp,comprate
	  from gline.submeasures_prior a left outer join ciedw.guideline c 
         on a.guideline_key=c.guideline_external_id
	     left outer join ciedw.guideline_submeasure d 
	       on a.guideline_key=c.guideline_external_id
			   and a.submeasure_key=d.submeas_external_id
               and c.guideline_key=d.guideline_key
			   and c.client_key=d.client_key
             left outer join ciedw.provider e on a.pcpid=e.npi1
	     and e.client_key=&client_id.
	  where c.client_key=&client_id.
	  and e.client_key=&client_id.
	  order by a.pcpid,c.guideline_key ;
	quit;

	data guidelines;
	  length period $7.;
	  set submeas_prior2 submeas_curr2;
	  if pcpid = '9999999999' then provider_key=0;
	run;

	*SASDOC--------------------------------------------------------------------------
	| KILL THE PROCESS IF THERE ARE NEW GUIDELINES THAT HAVE NOT BEEN LOADED 
	| INTO THE CIEDW GUIDELINE and SUBMEASURE TABLES   
	+------------------------------------------------------------------------SASDOC*;
	%validation_guideline_key(gl_validation=ciedw.guideline, gl_dataset=guidelines, gl_variable=guideline_key, gl_report=guideline, gl_key=guideline_external_id);
	%validation_guideline_key(gl_validation=ciedw.guideline_submeasures, gl_dataset=guidelines, gl_variable=gdln_submeas_key,gl_report=submeasure, gl_key=sub_id);

	proc sort data=guidelines;
	  by period guideline_key gdln_submeas_key provider_key;
	run;

	%set_error_flag;
	%on_error(ACTION=ABORT);

	*SASDOC--------------------------------------------------------------------------
	| LOAD INTO DMPRV_GUIDLINES TABLE     
	|  REFRESH DATA EACH TIME 
	+------------------------------------------------------------------------SASDOC*;
	proc sql noprint;

	  insert into dmart.dmprv_guidelines_stage
		(provider_key,
		guideline_key,
		guideline_external_id,
		guideline_name,
		submeasures_key,
		submeasures_external_id,
		submeasures_name,
		patients,
		compliance,
		period  )
	  select 
		provider_key,
		guideline_key,
		guideline_external_id,
		guideline,
		gdln_submeas_key,
		sub_id,
		submeasure,
		elig,
		comp,
		period
	  from guidelines
	  /*where provider_key <> 0  */  ;
	quit;

	%set_error_flag;
	%on_error(ACTION=ABORT);

	*SASDOC--------------------------------------------------------------------------
	| LOAD INTO LAB_SUBMEASURE_DETAIL_STAGE TABLE     
	|  REFRESH DATA EACH TIME 
	+------------------------------------------------------------------------SASDOC*;

	%if &LAB_SUBMEAS_DETS. = Y %then %do;

		data lab_submeasures_detail;
		set gline.lab_submeasures_detail;
		format svcdt1 datetime. member_key $16. rank2 $1.;
		svcdt1 = dhms(svcdt,0,0,0);
		member_key=memberid;
		rank2=rank;
		keep member_key care_element value units svcdt1 rank2 ;
		run; 

		data lab_submeasures_detail;
		  set lab_submeasures_detail;
		  rename rank2=rank
                 svcdt1=svcdt;
		run;

		%if %sysfunc(exist(dmart.lab_submeasure_detail)) %then %do;
		
			proc sql;
				connect to oledb(init_string=&data_mart.);
				select * from connection to oledb
				(
					exec dbo.TruncateLabSubmeasuresTable
				);
			quit;

    proc append base=dmart.lab_submeasure_detail(dbsastype=(member_key='char(16)') IGNORE_READ_ONLY_COLUMNS=YES) 
               data=lab_submeasures_detail force;
   run;

   /*
			proc sql noprint;
			  insert into dmart.LAB_SUBMEASURE_DETAIL
				(  MEMBER_KEY
				      ,CARE_ELEMENT
				      ,VALUE
				      ,UNITS
				      ,SVCDT)
				  select 
				   MEMBERID
				      ,CARE_ELEMENT
				      ,VALUE
				      ,UNITS
				      ,SVCDT1
				  from lab_submeasures_detail
				  ;
			quit;
*/
		%end;

	%end;
	
	*SASDOC--------------------------------------------------------------------------
	| UPDATE THE PORTAL DATES AND OTHER PARAMETERS IN SASBIWEB.CI_CLIENT_PARAMETERS       
	+------------------------------------------------------------------------SASDOC*;


  proc sql noprint;
    select value into: current_period
	from gline.portal_dates
	where parameter='Period'
	;

	select value into: prior_period
	from gline.portal_dates
	where parameter='PriorPeriod'
	;
quit;

%put &current_period.;
%put &prior_period.;
    

   libname sasbiweb oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=chisql;
      Initial Catalog=SasBiWeb;" preserve_tab_names=yes insertbuff=10000 readbuff=10000;

	proc sql;
	  update sasbiweb.CI_CLIENT_PARAMETERS
	  set parameter_value="&Current_Period."
	  where client_key=&client_id. and parameter_key=15 ;

	  update sasbiweb.CI_CLIENT_PARAMETERS
	  set parameter_value="&Prior_Period."
	  where client_key=&client_id. and parameter_key=16 ;
	quit;



%mend edw_insert_guidelines;
%edw_insert_guidelines;
