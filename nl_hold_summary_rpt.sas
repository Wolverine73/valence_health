

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  nl_hold_summary_rpt
|
| LOCATION: M:\&client.\Programs\CIETL\NoHold_load\NL hold report20120309.sas
|
| PURPOSE:  Summarize results of data in no load hold table  
|
| INPUT:    
|
| OUTPUT:   \\fs\&client.\reports\Monthly_Reports\Data_Load\NoHold_Load
|
| USAGE EXAMPLES: 

| 
| HISTORY:  09Mar2012 Written by Steve Bittner
| 25Jun2012 added week summaryies 


1)	Summary of NLHold failures by Practice (Counts of Provider_Key=0 or Member_Key=0 or Proccd_Key=0 or Svcdt > Today).
2)	Summary of Linking Analysis by Practice (Counts only looking at Member_key=0)
3)	List of bad providers (Listing of Provider_key=0)

| ----------------------------------------*/



%macro nl_hold_summary_rpt();


libname registry "\\fs\ci\Data\Provider";
libname formats "M:\dw\formats";

/*proc format cntlin=registry.npilevel;*/
/*proc format cntlin=registry.Npitax;*/
/*proc format cntlin=registry.Npitax2;*/
/*proc format cntlin=registry.taxsp;*/
/*proc format cntlin=formats.Specdesc;*/

run;

%let init_string_edw=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=CIEDW;" );

proc sql;
 connect to oledb ( INIT_STRING=&sqlci); 
create table edw_claim_summary as
 select provider_key
          ,data_source_id as datasourceid
		 
          ,edw_cnt as edw_cnt 
          ,cnt_wk
		  ,start_wk
		  ,end_wk
         from connection to oledb
(SELECT   a.PROVIDER_KEY
         ,data_source_id
		 ,dateadd(DAY,-6, GETDATE()) as start_wk
		 , getdate() as end_wk
       ,COUNT(*) as edw_CNT
	   ,sum(case when a.created_on between dateadd(DAY,-6, GETDATE()) and getdate() then 1 else 0 end) as cnt_wk
  FROM [CIEDW].[dbo].[ENCOUNTER_HEADER] as a with (nolock) inner join
       [CIEDW].[dbo].[ENCOUNTER_DETAIL] as b with (nolock) 
  on a.ENCOUNTER_KEY=b.ENCOUNTER_KEY
  and a.CLIENT_KEY=b.CLIENT_KEY
  where a.CLIENT_KEY=&client_id and provider_key > 0 and provider_key is not null

  group by 
    a.PROVIDER_KEY  ,data_source_id
	order by a.provider_key  ,data_source_id
 );
   quit;

/**/

%edw_pick_latest_nlhold(nl_prov_grp_clm_cnt2,&client_id,m_keepvar=_all_);

data npi_registry;
set registry.npi_registry;
keep npi provider_first_name provider_last_name;
run;

proc sort data=npi_registry out=npi_registsry2 nodupkey;by npi;run;

%macro get_summary(outname=, claimfile=, where=);
proc sql;

 create table _&outname. as 
  select distinct
   practice_id AS DatasourceID
   ,name as datasource_name
   ,source
   ,source_system_id
   ,system
   ,g.groupid as nl_groupid
   ,g.groupname as nl_groupname
   ,c.provider_key
   ,max(case when c.npi is null and (c.provider_key is null or c.provider_key=0) then c.provname else "" end) as nl_prov_no_npi
   ,p2.p_lastname as vlink_lname
   ,p2.p_firstname as vlink_fname

   ,p2.IsMidlevel label="IsMidlevel"
   ,c.npi
   ,s.specialty_description

   ,max(pcipar) as pcipar
   ,max(g.g_cipar) as gcipar
   ,sum(case when substr(proccd,1,1)='7' then 1 else 0 end) as proccd7xxxxx
   ,sum(case when substr(proccd,1,1)='8' then 1 else 0 end) as proccd8xxxxx
   ,sum(case when substr(proccd,1,1)='9' then 1 else 0 end) as proccd9xxxxx 
   ,sum(case when member_key=0 or member_key is null then 1 else 0 end) as member_key_missing
   ,sum(case when c.provider_key=0 or c.provider_key is null then 1 else 0 end) as provider_key_missing
   ,sum(case when procedure_code_key=0 or procedure_code_key is null then 1 else 0 end) as procedure_code_key_missing
   ,sum(case when svcdt > c.CREATED_ON or svcdt is null  then 1 else 0 end) as svcdt_key_error
   ,sum(case when member_key=0 or member_key is null then 1 else 0 end) +
      sum(case when c.provider_key=0 or c.provider_key is null then 1 else 0 end)+
	  sum(case when procedure_code_key=0 or procedure_code_key is null then 1 else 0 end)+
	  sum(case when svcdt > c.CREATED_ON or svcdt is null  then 1 else 0 end) as error_rec_cnt
   ,MAX(edw_cnt) as edw_cnt
   ,count(*) as nl_rec_cnt
   ,count(*)/(max(edw_cnt)+count(*)) as NL_percent format=percent10.4
from &claimfile. c 
  left join ids.DataSource  p
    on c.practice_id=p.DataSourceID
  left join(select  p.providerid
                 ,max(p_lastname) as p_lastname
				 ,max(p_firstname) as p_firstname
                 ,max(p_cipar) as pcipar				
				 ,max(P_Pract) as IsMidlevel			 					
		 		 ,max(primSpec.S_SpecialtyID) AS specialty
        	from vlink.tblprovider p 
 		
    		left outer join vlink.tblSpecialty primSpec
	      			 ON p.ProviderID = primSpec.ProviderID AND primSpec.S_Primary = 1
   			where p.clientid=&clientid
           group by  p.providerid ) p2
    	on c.provider_key=p2.providerid
  left join vlink.tblgroups g
   on c.group_id=g.groupid
  left join ciedw.specialty s
   on p2.specialty=s.specialty_code
   left join edw_claim_summary e
    on e.provider_key=c.provider_key and e.datasourceid=c.practice_id
/*	left join npi_registsry2 r*/
/*	on r.npi=c.npi*/
	&where
group by  

   practice_id
   ,name 
   ,source
   ,source_system_id
   ,system
   ,g.groupid
   ,g.groupname
   ,c.provider_key
/*   ,case when c.npi is null and (c.provider_key is null or c.provider_key=0) then c.provname else "" end*/
   ,p2.p_lastname
   ,p2.p_firstname

   ,IsMidlevel
   ,c.npi
   ,s.specialty_description;
quit;

proc sql;
 create table &outname. as
  select a.*
   ,strip(b.provider_last_name) ||', ' || strip(provider_first_name) as Registry_provider_name
  from _&outname. a left join npi_registsry2 b
   on a.npi=b.npi;
   quit;

%mend;




%get_summary(outname=NL_HOLD_SUMMARY, claimfile=nl_prov_grp_clm_cnt2);

%get_summary(outname=NL_HOLD_SUMMARY_wk, claimfile=nl_prov_grp_clm_cnt2,where=where datepart(c.created_on) between today()-6 and today() );

%get_summary(outname=NL_HOLD_mem_SUMMARY_wk, claimfile= (select * from nl_prov_grp_clm_cnt2 where member_key=0 and provider_key ne 0 and procedure_code_key ne 0)
              ,where=where datepart(c.created_on) between today()-6 and today() );

%get_summary(outname=NL_HOLD_mem_SUMMARY
        ,claimfile= (select * from nl_prov_grp_clm_cnt2 where member_key=0 and provider_key ne 0 and procedure_code_key ne 0)
              );

 proc sql;
create table _datasource_summary as
  select datasourceid,
  datasource_name,
            sum(proccd7XXXXX) as proc7s,
            sum(proccd8xxxxx) as proc8s,
            sum(proccd9xxxxx) as proc9s,
            sum(member_key_missing) as member_key_miss,
            sum(provider_key_missing) as provider_key_miss,
            sum(procedure_code_key_missing) as proccd_miss,
            sum(svcdt_key_error) as svcdt_miss,
            sum(nl_rec_cnt) as feed_cnt,
			sum(edw_cnt) as edw_cnt,
            sum(nl_rec_cnt)/(sum(edw_cnt)+sum(nl_rec_cnt))  as nl_percent format percent10.2,
            sum(provider_key_missing)/ sum(nl_rec_cnt) as provider_miss_freq format percent10.2,
            sum(member_key_missing)/ sum(nl_rec_cnt) as member_miss_freq format percent10.2,
            sum(procedure_code_key_missing)/ sum(nl_rec_cnt) as proccd_miss_freq format percent10.2,
            sum(svcdt_key_error)/ sum(nl_rec_cnt) as svcdt_miss_freq format percent10.2
            from NL_HOLD_SUMMARY
            group by datasourceid, datasource_name
            order by feed_cnt desc;
            quit;

data ds1;
set _datasource_summary;
format severity $6.;
ReprocessPriorityIndex= (nl_percent*&pctnlhold.) 
           + (provider_miss_freq*&ProvKeyMiss.) 
           + (member_miss_freq * &MbrKeyMiss. ) 
		   + (proccd_miss_freq * &ProccdMiss. )
		   + (feed_cnt * &TotalErrorcnt. ) ;
rev_rank=ReprocessPriorityIndex*-1;
	if  .1  < nl_percent <.5 then severity="Medium";
	else if nl_percent >=0.5 then severity="High";
	else severity="Low";

/*=(L4*$Y$4+M4*$Z$4+N4*$AA$4+O4*$AB$4+J4*$X$4)*/
/*=IF(AND(L4>0.1,L4<0.5),"Medium",IF(L4>=0.5,"High","Low"))*/
run;
proc rank data=ds1 out=ds2;
var rev_rank;
ranks ReprocessPriority;
run; 
proc sort data=ds2 out=datasource_summary; by descending feed_cnt;run;

 proc sql;
create table datasource_summary_mem as
  select datasourceid,
  datasource_name,
            sum(proccd7XXXXX) as proc7s,
            sum(proccd8xxxxx) as proc8s,
            sum(proccd9xxxxx) as proc9s,
            sum(member_key_missing) as member_key_miss,
            sum(provider_key_missing) as provider_key_miss,
            sum(procedure_code_key_missing) as proccd_miss,
            sum(svcdt_key_error) as svcdt_miss,
            sum(nl_rec_cnt) as feed_cnt,
			sum(edw_cnt) as edw_cnt,
            sum(nl_rec_cnt)/(sum(edw_cnt)+sum(nl_rec_cnt))  as nl_percent format percent10.2,
            sum(provider_key_missing)/ sum(nl_rec_cnt) as provider_miss_freq format percent10.2,
            sum(member_key_missing)/ sum(nl_rec_cnt) as member_miss_freq format percent10.2,
            sum(procedure_code_key_missing)/ sum(nl_rec_cnt) as proccd_miss_freq format percent10.2,
            sum(svcdt_key_error)/ sum(nl_rec_cnt) as svcdt_miss_freq format percent10.2
            from NL_HOLD_mem_SUMMARY
            group by datasourceid, datasource_name
            order by feed_cnt desc;
            quit;


 proc sql;
create table _datasource_summary_wk as
  select datasourceid,
  datasource_name,
            sum(proccd7XXXXX) as proc7s,
            sum(proccd8xxxxx) as proc8s,
            sum(proccd9xxxxx) as proc9s,
            sum(member_key_missing) as member_key_miss,
            sum(provider_key_missing) as provider_key_miss,
            sum(procedure_code_key_missing) as proccd_miss,
            sum(svcdt_key_error) as svcdt_miss,
            sum(nl_rec_cnt) as feed_cnt,
			sum(edw_cnt) as edw_cnt,
            sum(nl_rec_cnt)/(sum(edw_cnt)+sum(nl_rec_cnt))  as nl_percent format percent10.2,
            sum(provider_key_missing)/ sum(nl_rec_cnt) as provider_miss_freq format percent10.2,
            sum(member_key_missing)/ sum(nl_rec_cnt) as member_miss_freq format percent10.2,
            sum(procedure_code_key_missing)/ sum(nl_rec_cnt) as proccd_miss_freq format percent10.2,
            sum(svcdt_key_error)/ sum(nl_rec_cnt) as svcdt_miss_freq format percent10.2
            from NL_HOLD_SUMMARY_wk
            group by datasourceid, datasource_name
            order by feed_cnt desc;
            quit;
data dsk1;
set _datasource_summary_wk;
format severity $6.;
ReprocessPriorityIndex= (nl_percent*&pctnlhold.) 
           + (provider_miss_freq*&ProvKeyMiss.) 
           + (member_miss_freq * &MbrKeyMiss. ) 
		   + (proccd_miss_freq * &ProccdMiss. )
		   + (feed_cnt * &TotalErrorcnt. ) ;

	if  .1  < nl_percent <.5 then severity="Medium";
	else if nl_percent >=0.5 then severity="High";
	else severity="Low";
rev_rank=ReprocessPriorityIndex*-1;
/*=(L4*$Y$4+M4*$Z$4+N4*$AA$4+O4*$AB$4+J4*$X$4)*/
/*=IF(AND(L4>0.1,L4<0.5),"Medium",IF(L4>=0.5,"High","Low"))*/
run;
proc rank data=dsk1 out=dsk2;
var rev_rank;
ranks ReprocessPriority;
run; 
proc sort data=dsk2 out=datasource_summary_wk; by descending feed_cnt;run;

proc sql;
create table datasource_member_wk as
  select datasourceid,
  datasource_name,
            sum(proccd7XXXXX) as proc7s,
            sum(proccd8xxxxx) as proc8s,
            sum(proccd9xxxxx) as proc9s,
            sum(member_key_missing) as member_key_miss,
            sum(provider_key_missing) as provider_key_miss,
            sum(procedure_code_key_missing) as proccd_miss,
            sum(svcdt_key_error) as svcdt_miss,
            sum(nl_rec_cnt) as feed_cnt,
			sum(edw_cnt) as edw_cnt,
            sum(nl_rec_cnt)/(sum(edw_cnt)+ sum(nl_rec_cnt)) as nl_percent format percent10.2,
            sum(provider_key_missing)/ sum(nl_rec_cnt) as provider_miss_freq format percent10.2,
            sum(member_key_missing)/ sum(nl_rec_cnt) as member_miss_freq format percent10.2,
            sum(procedure_code_key_missing)/ sum(nl_rec_cnt) as proccd_miss_freq format percent10.2,
            sum(svcdt_key_error)/ sum(nl_rec_cnt) as svcdt_miss_freq format percent10.2
            from NL_HOLD_mem_SUMMARY_wk
			
            group by datasourceid, datasource_name
            order by feed_cnt desc;
            quit;

%macro report (font=,dsn=);

proc report data=&dsn. 
            style(report)=[fontsize=&font.pt]
            style(column)=[font=(Arial, &font.pt)]
            style(hdr)=[fontsize=&font.pt] nowd spanrows;;
column DatasourceID 
		datasource_name 
		Source
		SOURCE_SYSTEM_ID 
		SYSTEM 
        nl_groupid
		nl_groupname
/*		TIN */
		PROVIDER_KEY
        NPI 
		nl_prov_no_npi
		vlink_lname 
        vlink_fname
		Registry_provider_name
/*		Registry_Lname*/
/*		Registry_fname*/
		IsMidlevel 
		
		SPECIALTY_DESCRIPTION 
/*		regspec*/
/*		provspec*/
		pcipar 
		gcipar 
		
		proccd7xxxxx 
		proccd8xxxxx 
		proccd9xxxxx 
		member_key_missing 
		provider_key_missing 
		procedure_code_key_missing 
		svcdt_key_error 
	    edw_cnt
		nl_rec_cnt
        NL_percent;
 
define datasourceid/"Data Source ID" ;
define datasource_name/"Data Source Name" ;
define source/"Source";
Define System/"Sys";
define nl_groupname/"NL Group Name";
define SOURCE_SYSTEM_ID/"Source Sys ID"; 
define SPECIALTY_DESCRIPTION/"Vlink Specialty";
/*define regspec /"Register Specialty";*/
/*define provspec /"Register Specialty Description";*/
define Provider_key/"Prov Key";
define member_key_missing /"Missing Mbr Key";
define provider_key_missing /"Missing Prov key";
define procedure_code_key_missing /"Missing Proc Code Key";
define 	svcdt_key_error/"SVCDT Error"; 
define proccd7xxxxx/"Proccd 7XXXXX"; 
define proccd8xxxxx/"Proccd 8XXXXX"; 
define proccd9xxxxx/"Proccd 9XXXXX"; 
run;
 %mend;
 

%macro report3 (font=,dsn=);

proc report data=&dsn. 
             style(report)=[fontsize=&font.pt]
            style(column)=[font=(Arial, &font.pt)]
            style(hdr)=[fontsize=&font.pt] nowd ;;
column      datasourceid
            datasource_name
            proc7s
            proc8s
            proc9s
            provider_key_miss
            member_key_miss
            proccd_miss
            svcdt_miss
            feed_cnt
			edw_cnt
			nl_percent
            provider_miss_freq
            member_miss_freq
            proccd_miss_freq
            svcdt_miss_freq 
	%if &dsn=datasource_summary_wk or &dsn=datasource_summary %then  %do;
     ReprocessPriorityIndex ReprocessPriority Severity
	 %end;
    ;
;
define datasourceid/"Data Source ID" ;
define datasource_name/"Data Source Name" ;
define proc7s /"Count Proccd 7xxxxx" ;
define proc8s/"Count Proccd 8xxxxx" ;
define proc9s/"Count Proccd 9xxxxx" ;
define member_key_miss/"Count Member Key Miss" ;
define provider_key_miss/"Count Prov Key Miss " ;
define proccd_miss/"Count Proccd Miss" ;
define svcdt_miss/"Count Svcdt Error" ;
define feed_cnt/"Total Error Count (Feed Count)" ;
define edw_cnt/"Record Count in EDW" ;
define nl_percent/"Percent NL Hold" ;
define provider_miss_freq/"Prov Key Miss %" ;
define member_miss_freq/"Member Key Miss %" ;
define proccd_miss_freq/"Proccd Miss %" ;
define svcdt_miss_freq/"Svcdt Error %" ;
run;
%mend;



ODS LISTING CLOSE;
options orientation=landscape;

/* write excel*/
ods tagsets.excelxp file="&excelout."  options( autofilter='ALL' 
  SHEET_NAME="Weekly: Data Source Summary" EMBEDDED_TITLES='YES'
 DEFAULT_COLUMN_WIDTH="5,20,5,5,5,5,5,5,5,10,10,10,10,10,10,10,10,10,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5");

title j=l "&client Data Source Summary for week ending %sysfunc(today(),mmddyy10.) ";
;

%report3(font=10,dsn= datasource_summary_wk);



ods tagsets.excelxp 
	options(EMBEDDED_TITLES='YES' SHEET_NAME="Weekly Provider Summary" 
	DEFAULT_COLUMN_WIDTH="3,20,5,5,12,5,20,5,5,10,10,10,10,10,10,10,10,10,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5"
	);

title J=L "&client Provider List for week ending %sysfunc(today(),mmddyy10.) ";
%report(font=10,dsn=NL_HOLD_SUMMARY_wk);

ods tagsets.excelxp  options( SHEET_NAME="Weekly Bad Member" EMBEDDED_TITLES='YES'
 DEFAULT_COLUMN_WIDTH="5,20,5,5,5,5,5,5,5,10,10,10,10,10,10,10,10,10,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5");

title j=l "&client Data Source  member_key=0 and provider_key ne 0 and procedure_code_key ne 0"
;
%report3(font=10,dsn= datasource_member_wk);


ods tagsets.excelxp  options( SHEET_NAME="All-Time Data Source Summary" EMBEDDED_TITLES='YES'
 DEFAULT_COLUMN_WIDTH="5,20,5,5,5,5,5,5,5,10,10,10,10,10,10,10,10,10,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5");

title j=l "&client Data Source Level NL Hold Summary"
;
%report3(font=10,dsn= datasource_summary);

ods tagsets.excelxp 
	options( SHEET_NAME="All-Time Datasource Bad Member" 
 DEFAULT_COLUMN_WIDTH="5,20,5,5,5,5,5,5,5,10,10,10,10,10,10,10,10,10,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5");
	;


title J=L "&client Provider DataSource NL Hold  member_key=0 and provider_key ne 0 and procedure_code_key ne 0";
%report3(font=10,dsn=datasource_summary_mem );

ods tagsets.excelxp 
	options( SHEET_NAME="All-Time Provider Summary" 
	DEFAULT_COLUMN_WIDTH="3,20,5,5,12,5,20,5,5,10,10,10,10,10,10,10,10,10,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5"
	);


title J=L "&client Provider NL Hold Summary";
%report(font=10,dsn=NL_HOLD_SUMMARY);



ods tagsets.excelxp close;
ods listing;



%macro to_mail;
%let loc=&pdfout.;

	%if &email1. ne %then %do;
       %email_parms( em_to=%str(&email1.@valencehealth.com ) 
	%if &email2. ne %then	 ,em_cc=%str(&email2.@valencehealth.com ) ;
	 ,em_subject=&clientnm.  &report_name.
	 ,em_msg=%str(The &clientnm. &report_name. was updated on &current. &excelout. )
/*	 ,em_attach= %str(&loc. )  */
);
    %end;

	%if &email3. ne %then %do;
     %email_parms( em_to=%str(&email3.@valencehealth.com) 
    %if &email4. ne %then	,em_cc=%str(&email4.@valencehealth.com ) ;
		,em_subject=&clientnm. &report_name.
	,em_msg=%str(The &clientnm. &report_name. was updated on &current. &excelout.  )
/*    ,em_attach= %str(&loc.)  */
);
    %end;
		%if &email5. ne %then %do;
     %email_parms( em_to=%str(&email5.@valencehealth.com) 
    %if &email6. ne %then	,em_cc=%str(&email6.@valencehealth.com ) ;
		,em_subject=&clientnm. &report_name.
	,em_msg=%str(The &clientnm. &report_name. was updated on &current. &excelout.  )
/*    ,em_attach= %str(&loc.)  */
);
    %end;

 
%mend;
%to_mail;

%mend nl_hold_summary_rpt;




