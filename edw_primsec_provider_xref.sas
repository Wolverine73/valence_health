
/*HEADER------------------------------------------------------------------------
|
| program:  edw_primsec_provider_xref.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Determine the primary and secondary practice provider definitions
|           based on a valid IDS ID from IntegrationDataSource
|
| logic:    
|
| input:    practice dataset         
|
| output:   practice dataset
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|             
| 07JUN2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Modified the TEST mode for EMINE to point to SQLCIDEV instead because dev environment
|				now has more new files loaded.
|    
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
+-----------------------------------------------------------------------HEADER*/

%macro edw_primsec_provider_xref(m2_client_id,m2_datasource_id=,m2_inset=,m2_outset=,m2_save_prim=,m2_save_sec=,m2_save_lab=,m2_trigger_facility=0);

	  *SASDOC--------------------------------------------------------------------------
	  | Determine routine for macro to perform
	  |
	  ------------------------------------------------------------------------SASDOC*;
	  %if &m2_outset. = %then %do;
		%let m2_outset=&m2_inset.;
	  %end;
	  %if &m2_save_prim. = %then %do;
		%let ppx_primary=ppx_primary_provider_xref;
	  %end;
	  %else %do;
		%let ppx_primary=&m2_save_prim.;
	  %end;
	  %if &m2_save_sec. = %then %do;
		%let ppx_secondary=ppx_secondary_provider_xref;
	  %end;
	  %else %do;
		%let ppx_secondary=&m2_save_sec.;
	  %end;
	  %if &m2_save_lab. = %then %do;
		%let ppx_lab=ppx_lab_provider_xref;
	  %end;
	  %else %do;
		%let ppx_lab=&m2_save_lab.;
	  %end;

	  *SASDOC--------------------------------------------------------------------------
	  | Practice Logic        
	  |
	  ------------------------------------------------------------------------SASDOC*; 
	  proc sql;
	    create table &ppx_primary. as
	    select 	a.provider_key, 
				a.client_key, 
				a.practice_key,
				b.practiceid as vmine_key,
				b.datasourceid,
				c.npi1,
				c.provider_name, 
				d.practice_name,
				d.tin,
				min(coalesce(c.clncl_int_exp_dt,datetime()),coalesce(a.exp_dt,datetime())) as ci_term_date,
				case when e.clientid < 0 then 1
				else 0 
				end as facility_indicator
		from 	ciedw.provider_practice_xref as a left join
				ciedw.practice 				 as d on a.practice_key=d.practice_key left join
				ids.datasource_practice 	 as b on d.vsource_practice_key=b.practiceid left join
				ciedw.provider 				 as c on a.provider_key=c.provider_key left join				
				vlink.tblgroups 			 as e on d.vsource_practice_key=e.groupid 
		where 	a.client_key=&m2_client_id. and
				d.vsource_practice_key ne .;

	    create table &ppx_secondary. as
	    select 	c.provider_key, c.client_key, c.npi1, c.provider_name, coalesce(c.clncl_int_exp_dt,datetime()) as ci_term_date
	    from 	ciedw.provider as c 	    
	    where 	c.client_key = &m2_client_id.;

		create table &ppx_lab. as
		select	123456789 as client_key, 123456789 as provider_key, '123456789' as npi1, 
		        '123456789' as provider_name, a.clncl_int_exp_dt, 1 as practice_lab_key
		from	ciedw.provider (obs=1) a;
	  quit;
 
	  
	  *SASDOC--------------------------------------------------------------------------
	  | Assignment Logic        
	  |
	  | Assign group ID, practice key, and provider key for the data source
	  |
	  ------------------------------------------------------------------------SASDOC*;  
	  %let ppx_facility_cnt=0;
	  %if &m2_datasource_id. ne or &m2_trigger_facility. %then %do;	 
		  proc sql noprint;
		   select count(*) into: ppx_facility_cnt
		   from &ppx_primary.
		   where DataSourceID=&m2_datasource_id.
		     and facility_indicator = 1;
		  quit;
	  %end;
	  
	  %put NOTE: Facility Count = &ppx_facility_cnt. ;
	  
	  %if &m2_inset. ne %then %do;
		  proc sql noprint;
		  select count(*) into: m2_inset_cnt separated by ''
		  from &m2_inset. ;
		  quit;
	  %end;
	  
	  %if &m2_inset. ne and &ppx_facility_cnt.=0 %then %do;
		  proc sql;
			create table &m2_outset. as
			select	a.*,
					case when a.svcdt le coalesce(b.ci_term_date,c.ci_term_date) then coalesce(d.practice_lab_key,b.practice_key,0) else 0 end as group_id,
					case when a.svcdt le coalesce(b.ci_term_date,c.ci_term_date) then coalesce(d.practice_lab_key,b.practice_key,0) else 0 end as practice_key,
					coalesce(b.provider_key,c.provider_key,0) as provider_key
			from	&m2_inset. a left join 
					&ppx_primary. b		on a.npi=b.npi1 and a.tin=b.tin and a.practice_id=b.datasourceid left join
					&ppx_secondary. c 	on a.npi=c.npi1 and c.npi1 ne '' left join
					&ppx_lab. d 		on a.npi=d.npi1 and a.practice_id=d.practice_lab_key;
		  quit;
	  %end;   
	  %else %if &m2_inset. ne and &ppx_facility_cnt. ne 0 %then %do;
		  proc sql;
			create table &m2_outset. as
			select	a.*,
					case when a.svcdt le coalesce(b.ci_term_date) then coalesce(b.practice_key,0) else 0 end as group_id,
					case when a.svcdt le coalesce(b.ci_term_date) then coalesce(b.practice_key,0) else 0 end as practice_key,
					coalesce(b.provider_key,0) as provider_key
			from	&m2_inset. a left join 
					&ppx_primary. b		on a.npi=b.npi1 and a.practice_key=b.practice_key and a.practice_id=b.datasourceid ;
		  quit;
	  %end; 
	  
	  %if &m2_inset. ne %then %do;
		  proc sql noprint;
		  select count(*) into: m2_outset_cnt separated by ''
		  from &m2_outset. ;
		  quit;
		  
		  %put NOTE: Inbound dataset counts  - m2_inset_cnt   = &m2_inset_cnt. ;
		  %put NOTE: Outbound dataset counts - cm2_outset_cnt = &m2_outset_cnt. ;
		  
		  %if &m2_inset_cnt. ne &m2_outset_cnt. %then %do;	
			proc catalog catalog=work.sasmacr ;
			  contents out = work.list_sasmacr;
			run;

			%let list_sasmacr_cnt=0;

			proc sql noprint;
			  select count(*) into: list_sasmacr_cnt separated by ''
			  from work.list_sasmacr
			  where upcase(name) in ('BPM_ADDITIONAL_VALIDATIONS');
			quit;

			%put NOTE: list_sasmacr_cnt = &list_sasmacr_cnt. ;

			%if &list_sasmacr_cnt. ne 0 %then %do;
				%bpm_additional_validations(validation_rule=47,validation_count=0);
				%put ERROR: The edw_primsec_provider_xref macro produced additional records.  Possible issue with Provider Practice data.;
				%let err_fl=1;
				%set_error_flag;
				%on_error(ACTION=ABORT);
			%end;
		  %end;
	  %end;

	  *SASDOC--------------------------------------------------------------------------
	  | Delete SAS reference datasets
	  |
	  ------------------------------------------------------------------------SASDOC*;  
	  %if &m2_save_prim. = %then %do;
		proc sql;
		  drop table ppx_primary_provider_xref;
		quit;
	  %end;
	  %if &m2_save_sec. = %then %do;
	  %end;
		proc sql;
		  drop table ppx_secondary_provider_xref;
		quit;
	  %if &m2_save_lab. = %then %do;
		proc sql;
		  drop table ppx_lab_provider_xref;
		quit;
	  %end;
	  
%mend edw_primsec_provider_xref;
