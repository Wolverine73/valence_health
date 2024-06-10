%LET _CLIENTTASKLABEL='Macro header';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;

/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  Data_Acquistion_Dashboard.sas 
|
| LOCATION: m:\ci\programs\StandardMacros
|
| PURPOSE:  Produces the Data Acquisiton Dashboard  
|
| INPUT:   
 \\fs\DataTeam\CI\Process\Internal\Data_Acquisition_Dashboard\Data_Acquisition_Dashboard_Template.xlsm
      datasets under M:\&client.\SASDATA\CIOPS\Data_Acquisition
|
| OUTPUT:  
 \\fs\&client.\Reports\Data_Acquisition\&client._Data_Acquisition_Dashboard_yyyymmdd.xlsm
|
| USAGE EXAMPLES: 
| %data_acquisition_dashboard (
|            clientnm=OHG /*Client Shortname in CHISQL:  AHP, AHN, StLukes,
 NSAP, PHS, &clientnm., OHG, Exempla, CCPA, Ingalls
|			,clientid=7 /* ohg=7 , stlukes=3 etc  
|			,rdate=%eval(%SYSFUNC(TODAY()))  /* sas date '01jan2012'd or
 %eval(%SYSFUNC(TODAY())); 
|			,debug=\TEST  /*   /TEST  * for testing purposes - removes data from master
 files 

);
| 
| Notes:
| ----------------------------------------
Code exported from SAS Enterprise Guide
DATE: Tuesday, February 07, 2012     TIME: 9:55:07 AM
PROJECT: Data Acquisition Dashboard 20120206
PROJECT PATH: P:\Projects\20120202 Data acquistion dashboard\Data Acquisition
 Dashboard 20120206.egp
---------------------------------------- */
/*
|
+--------------------------------------------------------------------------------
| HISTORY:  07Jan2012 Written by Steve Bittner
| 
+------------------------------------------------------------------------HEADER*/


%macro data_acquisition_dashboard (
            clientnm= , /*Client Shortname in CHISQL:  AHP, AHN, StLukes, NSAP,
 PHS, &clientnm., OHG, Exempla, CCPA, Ingalls*/
			clientid=,  /* ohg=7 , stlukes=3 etc  */
			rdate=,     /* sas date '01jan2012'd or %eval(%SYSFUNC(TODAY())); */
			debug=    /*   /TEST  * for testing purposes - removes data from master files
 */

);

%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='libnames and dates';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;

/*Client Shortname in CHISQL:  AHP, AHN, StLukes, NSAP, PHS, &clientnm., OHG,
 Exempla, CCPA, Ingalls*/
/*%let clientnm =StLukes;*/
/*%let clientid=;*/
/*%let reportdate = %qsysfunc(today());*/
/*%PUT &REPORTDATE;*/

options mlogic symbolgen mprint VALIDVARNAME=V7 IBUFSIZE=32767;
options sasautos = ("m:\CI\programs\StandardMacros" 
"m:\CI\programs\ClientMacros" sasautos);
data _null_;
RDATE=&RDATE;
current = put(RDATE,date9.);
prior = put(RDATE-7,date9. );
rptdt = put(RDATE,yymmddn8.);
call symput ('current',current);
call symput ('prior',prior);
call symput ('rptdt',rptdt);
CALL symput ('reportdate',rdate);
run;

%put &current &prior &rptdt;
%let prgm_location=M:\&clientnm.\Programs\CIOPS\Data_Acquisition&DEBUG.;
%let data_location=M:\&clientnm.\SASDATA\CIOPS\Data_Acquisition&DEBUG.;
%let rpt_location=\\fs\&clientnm.\Reports\Data_Acquisition&DEBUG.;
%let
 tmplt_location=\\fs\DataTeam\CI\Process\Internal\Data_Acquisition_Dashboard&DEBUG.;

/*output template*/
%let exceltemplate=&tmplt_location.\Data_Acquisition_Dashboard_Template.xlsm;
%let excelout=&rpt_location\&clientnm._Data_Acquisition_Dashboard_&rptdt..xlsm;

%PUT &EXCELOUT;




/* libname for database  */
libname trend "&data_location";
libname vlink oledb init_string=
"Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vLinkNSAP;";
libname ids oledb init_string=
"Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=IntegrationDataSource;";
libname notes oledb init_string=
"Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=DEVSERV1;Initial Catalog=vLinkDataAcquisition;";


%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='Dashboard Acquire data';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;


/* start acquire data */


proc sql;
create table GroupName as
select distinct
	GroupName
	,GroupID
from vLink.TblGroups
where ClientID = &clientid
order by 1,2
;quit;


proc sql;
create table vsource_data as
SELECT distinct
	a.Login
	,trim(a.LastName) ||', '||trim(a.FirstName) as ProviderName
	,a.providerid
	,a.GroupName
	,a.GroupID
	,a.PMSystem
/*	,CASE*/
/*	when a.PMSystem = 'Other' and a.g_versiondesc = 'Cure MD' then 'Cure MD'*/
/*	else a.PMSystem END as PMSystem*/
	,a.RealCategory as Data_Category FORMAT=$50.
	,a.category as system_category
	,a.VersionID
	,a.InstallStat
	,CASE
	when a.PMSystemReason = 'RSL (Rocket System Labratories)' then 
'RSL - Rocket System Labratories'
	when a.PMSystemReason = 'RSL (Rocket System Labratories)  (Override)' then 
'RSL - Rocket System Labratories (Override)'
	when a.PMSystemReason = 'Glace (Glenwood Systems) (Not Yet Explored)' then 
'Glace - Glenwood Systems (Not Yet Explored)'
	when a.PMSystemReason = 'Other (Not Yet Explored)' and a.g_versiondesc = 
'Cure MD' then 'Cure MD (Not Yet Explored)'
	when a.PMSystemReason = 'A4 (Allscripts formerly Misys) (Not Yet Explored)'
 then 'A4 - Allscripts formerly Misys (Not Yet Explored)'
	when a.PMSystemReason = 
'Allscripts Professional PM (formerly Healthmatics Ntierprise)' then 
'Allscripts Professional PM formerly Healthmatics Ntierprise'							
	else a.PMSystemReason END as PMSystemReason
	,CASE
	when a.g_versiondesc = 'Datapoint' then 'Data Point'
	else a.g_versiondesc END as g_versiondesc
FROM vlink.tblGroups b
	,vlink.vAllClientsCIProgressDetailed a
WHERE a.clientid = b.clientid
  and a.groupid = b.groupid
  and a.ClientID = &clientid
  AND a.EntityID in (1)
ORDER BY 
	ProviderName
	,a.Login
	,a.GroupName
	,a.GroupID
	,a.PMSystem
	,a.RealCategory  Desc
	,a.category desc
	,a.GroupName Asc
;quit;

proc sql;
create table vsource_datax as
select a.*
	,b.VersionDescription
	,b.VersionName
from vsource_data a
	left outer join
	ids.pmsystemstatus b
on a.pmsystem = b.name
and a.SYSTEM_CATEGORY = b.category
and a.versionid = b.versionid
ORDER BY 
	ProviderName
	,a.Login
	,a.GroupName
	,a.GroupID
	,a.PMSystem
	,a.SYSTEM_CATEGORY Desc
	,a.GroupName Asc
;quit;

data physprac_prep;
	set vsource_datax;
	SystemReason = scan(PMSystemReason,2,'()');
run;
data physprac_view;
	length physpracinstallstat Data_Category $50.;
	format reportdate date9. Data_Category $50.;
	set physprac_prep;
	reportdate = "&reportdate.";

	if Data_Category = 'vReplicator' then  Data_Category = 'vMine';
	physpracinstallstat = installStat;
   
	if installstat in ('In Progress', 'Not Scheduled') then do;
		if system_category in ('Not Yet Developed','Not Yet Explored',
'Preliminary Development')
			then physpracinstallstat = 'System Exploration';
		if substr(system_category,1,16)= 'Will Not Develop' and DATA_CATEGORY in (
'TBD')
			then physpracinstallstat = 'Will Not Crack';
	end;
    if data_category='Manual' then do;
	  if installstat in ('Not Scheduled','Scheduled','In Progress') then 
 physpracinstallstat='Manual';
    end;
	   


	if (physpracinstallstat = 'System Exploration' and PMSystem = 'Other') then do;
		if g_versiondesc ne '' then PMSystem2 = 'Other'||"-"||g_versiondesc;
	end;
	if PMSystem = 'Other' then do;
		PMSystem = g_versiondesc;
	end;
	Count=1;
	if InstallStat in ('Termed & Uninstalled') then delete;
run;
/*'"' ||'0d'x || '0A'x || '07'x || "'"*/
%macro note_tbls(dsn,type);
proc sql;
create table &dsn._note_dates as
select distinct
	a.practiceid
	,CASE when b.notetype = "&type." then a.author else '' END as &dsn.noteauthor
	,CASE when b.notetype = "&type." then a.date else . END as &dsn.notets
 format=datetime.
	,CASE when b.notetype = "&type." then datepart(a.date) else . END as
 &dsn.notedate format=mmddyy8.
	,CASE when b.notetype = "&type." then compress(strip(a.note),'"' || '0A'x || 
'0b'x ||'0c'x || '0d'x || '07'x || '08'x|| '09'x  || '"','h') else '' END as
 &dsn.note
	
 
from notes.notes a
	,notes.notetype b
where a.notetypeid = b.notetypeid
  and a.author not in ('CHICAGO\aortiz')
order by 1,3 desc
;quit;

proc sort data=&dsn._note_dates;
	by practiceid &dsn.notets;
run;

data &dsn._note_dates_last;
format &dsn.note  $255.;
	set &dsn._note_dates;
	by practiceid &dsn.notets;
	if last.practiceid;
run;
%mend;

%note_tbls(Practice, Practice Notes);
%note_tbls(Install, Install Notes);
%note_tbls(Defect, Defect Notes);
%note_tbls(DQ, Data Quality Notes);

%macro note_fix(dsn_end);
data practice_note_&dsn_end._fix;
	format  practiceid 11. 
	practicenotets installnotets defectnotets dqnotets datetime.
	practicenote installnote defectnote dqnote $255.
	practicenoteauthor installnoteauthor defectnoteauthor dqnoteauthor $255.
	practicenotedate installnotedate defectnotedate dqnotedate mmddyy8.;

	set practice_note_&dsn_end.;
	Installnoteauthor = '';
	Installnotets = .;
	Installnotedate = .;
	Installnote = '';
	Defectnoteauthor = '';
	Defectnotets = .;
	Defectnotedate = .;
	Defectnote = '';
	DQnoteauthor = '';
	DQnotets = .;
	DQnotedate = .;
	DQnote = '';
run;

data notes_&dsn_end._all_fix;
	merge	practice_note_&dsn_end._fix
			install_note_&dsn_end.
			defect_note_&dsn_end.
			dq_note_&dsn_end.;
	by practiceid;
	maxts = max(Practicenotets, Installnotets, Defectnotets, DQnotets);
	format maxts datetime.;
	if substr(practicenoteauthor,1,8) = "CHICAGO\" then
		practicenoteauthorx = tranwrd(practicenoteauthor, "CHICAGO\", "VH_");
	if substr(practicenoteauthor,1,22) = "fbamembershipprovider:" then
		practicenoteauthorx = tranwrd(practicenoteauthor, "fbamembershipprovider:", 
"&clientnm._");
	if substr(installnoteauthor,1,8) = "CHICAGO\" then
		installnoteauthorx = tranwrd(installnoteauthor, "CHICAGO\", "VH_");
	if substr(installnoteauthor,1,22) = "fbamembershipprovider:" then
		installnoteauthorx = tranwrd(installnoteauthor, "fbamembershipprovider:", 
"&clientnm._");
	if substr(defectnoteauthor,1,8) = "CHICAGO\" then
		defectnoteauthorx = tranwrd(defectnoteauthor, "CHICAGO\", "VH_");
	if substr(defectnoteauthor,1,22) = "fbamembershipprovider:" then
		defectnoteauthorx = tranwrd(defectnoteauthor, "fbamembershipprovider:", 
"&clientnm._");
	if substr(DQnoteauthor,1,8) = "CHICAGO\" then
		DQnoteauthorx = tranwrd(DQnoteauthor, "CHICAGO\", "VH_");
	if substr(DQnoteauthor,1,22) = "fbamembershipprovider:" then
		DQnoteauthorx = tranwrd(DQnoteauthor, "fbamembershipprovider:", 
"&clientnm._");
run;

proc sql;
create table notes_&dsn_end._all_fix2 as
select
	b.groupname
	,a.practiceid
	,a.practicenoteauthorx as practicenoteauthor
	,a.practicenotets
	,a.practicenotedate
	,a.practicenote
	,a.installnoteauthorx as installnoteauthor 
	,a.installnotets
	,a.installnotedate
	,a.installnote
	,a.defectnoteauthorx as defectnoteauthor
	,a.defectnotets
	,a.defectnotedate
	,a.defectnote
	,a.DQnoteauthorx as DQnoteauthor
	,a.DQnotets
	,a.DQnotedate
	,a.DQnote
	,a.maxts
	,c.LastupdateDt as tblpracticeLastupdateDt
	,c.PracticeInstallDate as tblpracticePracticeInstallDate
	,c.status as tblpracticestatus
	,c.assignedto as tblpracticeassignedto
	,c.defecttype as tblpracticedefecttype
	,c.datateamlead as tblpracticedatateamlead
from notes_&dsn_end._all_fix a	
  left outer join notes.practice c 
     on a.practiceid= c.practiceid
  left outer join vLink.tblgroups b 
     on a.practiceid = b.groupid
order by
	b.groupname
	,a.maxts desc
;quit;

data notes_&dsn_end._all;
	set notes_&dsn_end._all_fix2;
	if substr(tblpracticeassignedto,1,8) = "CHICAGO\" then
		tblpracticeassignedtox = tranwrd(tblpracticeassignedto, "CHICAGO\", "VH_");
	if substr(tblpracticeassignedto,1,22) = "fbamembershipprovider:" then
		tblpracticeassignedtox = tranwrd(tblpracticeassignedto, 
"fbamembershipprovider:", "&clientnm._");
	if substr(tblpracticedatateamlead,1,8) = "CHICAGO\" then
		tblpracticedatateamleadx = tranwrd(tblpracticedatateamlead, "CHICAGO\", 
"VH_");
	if substr(tblpracticedatateamlead,1,22) = "fbamembershipprovider:" then
		tblpracticedatateamleadx = tranwrd(tblpracticedatateamlead, 
"fbamembershipprovider:", "&clientnm._");
run;
%mend;

%note_fix(dates);
%note_fix(dates_last);

/*LAST UPDATE DATE FROM PRACTICE TABLE FROM SHAREPOINT API*/
proc sql;
create table sp_lastupdate as
select
	practiceid as groupid
	,CreatedDt as spCreatedDtts
	,datepart(CreatedDt) as spCreatedDt format mmddyy8.
	,LastupdateDt as splastupdatets
	,datepart(LastupdateDt) as splastupdate format mmddyy8.
	,PracticeInstallDate as PracticeInstallDatets
	,datepart(PracticeInstallDate) as PracticeInstallDate format mmddyy8.
from notes.practice
order by 1
;quit;

/*MAX UPDATE DATE FROM NOTES TABLE FROM SHAREPOINT API*/
proc sql;
create table sp_noteupdate as
select
	practiceid as groupid
	,max(date) as spmaxnotedatets format datetime.
	,datepart(max(date)) as spmaxnotedate format mmddyy8.
from notes.notes
group by
	groupid
order by 1
;quit;

 

proc sql;
create table db_groups as
select distinct groupid, groupname
from physprac_view
order by 1,2;
quit;

proc sql;
create table calc_lastupdatex as
select
	a.*
	,b.spCreatedDtts
	,b.spCreatedDt
	,b.splastupdatets
	,b.splastupdate
	,c.spmaxnotedatets
	,c.spmaxnotedate
	,b.PracticeInstallDatets
	,b.PracticeInstallDate
from db_groups a left outer join sp_lastupdate b on a.groupid = b.groupid
					left outer join sp_noteupdate c on a.groupid = c.groupid
order by 1,2
;quit;

data calc_lastupdate;
	set calc_lastupdatex;
	calclastupdate = max(spcreateddt, splastupdate, spmaxnotedate);
	format calclastupdate mmddyy8.;
run;

proc sql;
create table physprac_viewx as
select a.*
	,b.calclastupdate
	,b.PracticeInstallDate
from physprac_view a left outer join calc_lastupdate b on a.groupid = b.groupid
order by
	providername
	,providerid
	,groupname
;quit;

data physprac_view_agex;
	format daysaged comma5.;	
	length weeksaged monthsaged $14.;
	set physprac_viewx;
	by providername providerid groupname;

	daysaged = intck('weekday71w',calclastupdate,reportdate);
	
	if  0 < daysaged <= 7 then weeksaged = 'week 0';
	else if 8 < daysaged <=  14 then weeksaged = 'week 1';
	else if 15 < daysaged <=  21 then weeksaged = 'week 2';
	else if 22 < daysaged <=  28 then weeksaged = 'week 3';
	else if 29 < daysaged <=  35 then weeksaged = 'week 4';
	else weeksaged = 'over 5 weeks';

	if  0 < daysaged <= 30 then monthsaged = 'month 0';
	else if 31 < daysaged <=  60 then monthsaged = 'month 1';
	else if 61 < daysaged <=  90 then monthsaged = 'month 2';
	else if 91 < daysaged <=  120 then monthsaged = 'month 3';
	else if 121 < daysaged <=  150 then monthsaged = 'month 4';
	else monthsaged = 'over 5 months';

	if first.providername then Provider1stRecord = 1;
		else Provider1stRecord = 0;
	if  System_Category in ('vMine','PGF','837') and  physpracinstallstat=
'Not Scheduled'    THEN NOT_SCHEDULED_FLG=1;
	 ELSE NOT_SCHEDULED_FLG=0;
run;
/* becomes dashboard detail in sheet */;
proc sql;
create table physprac_view_age as
select distinct
	
	a.physpracinstallstat
	,a.DATA_CATEGORY

	,a.reportdate
	,a.Login
	,a.ProviderName
	,a.ProviderID
/*	,' ' as Degree*/
/*	,'Physician_Type' as PhysicianType*/
	,a.GroupName
	,a.GroupID
	,a.PMSystem
	,a.Data_Category AS DATA_CATEGORY2
	,a.VersionID
	,a.InstallStat
	,a.PMSystemReason
	,a.g_versiondesc
	,a.VersionDescription
	,a.VersionName
	,a.SystemReason
	,a.PMSystem2
	,a.daysaged
	,a.weeksaged
	,a.monthsaged
	,a.Count
	,a.calclastupdate
	,a.PracticeInstallDate
	,a.Provider1stRecord
	,a.NOT_SCHEDULED_FLG
	,a.system_category
from physprac_view_agex a 

order by 7,8,11,12
;quit;	

proc sql;
create table xl_dashboard_detail as
select "&clientnm." as client, *
from physprac_view_age
;quit;

proc sql;
create table distinct_provid as
select distinct
	providername
	,login
	,providerid
from physprac_view_age
order by 1;
quit;

proc freq data=physprac_view_age noprint;
	tables physpracinstallstat/out=cnt_physpracinstallstat;
run;



/* the client queue gets those practices that are flagged for client effort */

proc sql;
create table xl_work_queue as
select distinct
	a.physpracinstallstat
	,a.installstat as Status
	,a.Data_Category
	,a.groupid as GroupID
	,a.groupname as GroupName
	,a.pmsystem2
	,a.versiondescription
	,count(distinct a.providerid) as ProviderCount
	,a.daysaged as DaysAged
	,datepart(b.tblpracticelastupdatedt) as LastUpdateDt format=mmddyy8.
	,b.tblpracticeassignedtox as AssignedTo
	,datepart(b.tblpracticepracticeinstalldate) as LastPracticeInstallDate
 format=mmddyy8.
	,b.practicenotedate as LastPracticeNoteDate format=mmddyy8.
	,b.practicenoteauthor as LastPracticeNoteAuthor
	,b.practicenote as LastPracticeNote
	,b.installnotedate as LastInstallNoteDate format=mmddyy8.
	,b.installnoteauthor as LastInstallNoteAuthor
	,b.installnote as LastInstallNote
	,b.defectnotedate as LastDefectNoteDate format=mmddyy8.
	,b.defectnoteauthor as LastDefectNoteAuthor
	,b.defectnote as LastDefectNote
	,b.tblpracticedefecttype as PracticeDefectType
from physprac_view_age a left outer join notes_dates_last_all b on a.groupid =
 b.practiceid
where substr(b.tblpracticeassignedtox,1,length("&clientnm")) = "&clientnm"
 and  a.physpracinstallstat <> 'Successful'

group by 
	a.groupid
	,a.groupname
order by
	 groupname
	,providercount desc
	,physpracinstallstat desc;
quit;

proc sql;
create table xl_vh_work_queue as
select distinct
	a.physpracinstallstat
	,a.installstat as Status
	,a.data_Category
	,a.groupid as GroupID
	,a.groupname as GroupName
	,a.pmsystem2
	,a.versiondescription
	,count(distinct a.providerid) as ProviderCount
	,a.daysaged as DaysAged
	,datepart(b.tblpracticelastupdatedt) as LastUpdateDt format=mmddyy8.
	,b.tblpracticeassignedtox as AssignedTo
	,datepart(b.tblpracticepracticeinstalldate) as LastPracticeInstallDate
 format=mmddyy8.
	,b.practicenotedate as LastPracticeNoteDate format=mmddyy8.
	,b.practicenoteauthor as LastPracticeNoteAuthor
	,compress(b.practicenote,' ','uldK') as LastPracticeNote format=$1000.
	,b.installnotedate as LastInstallNoteDate format=mmddyy8.
	,b.installnoteauthor as LastInstallNoteAuthor
     ,compress(b.installnote,' ','uldK') as LastInstallNote
	,b.defectnotedate as LastDefectNoteDate format=mmddyy8.
	,b.defectnoteauthor as LastDefectNoteAuthor
	,compress(b.defectnote,' ','uldK') as LastDefectNote
	,b.tblpracticedefecttype as PracticeDefectType
from physprac_view_age a left outer join notes_dates_last_all b on a.groupid =
 b.practiceid
where a.installstat in ('In Progress','Data Issue','Scheduled')
/*  and substr(b.tblpracticeassignedtox,1,2) = 'VH'*/
group by 
	a.groupid
	,a.groupname;
quit;
/* GROUP LEVEL DETAIL */
proc sql;
create table append_trend_detail as
select
 
	ReportDate
	,a.GroupName
	,GroupID
	,PhysPracInstallStat
	,DATA_CATEGORY
	
	,InstallStat
	,CalcLastUpdate
	,DaysAged
	,WeeksAged
	,MonthsAged
	,count(*) as ProviderCount
	,system_category
   ,max(b.tblpracticedefecttype) as PracticeDefectType
from physprac_view_age a
   left join notes_dates_last_all b on a.groupid = b.practiceid

group by 
	ReportDate
	,a.GroupName
	,GroupID
	,PhysPracInstallStat
	,DATA_CATEGORY
	
	,InstallStat
	,CalcLastUpdate
	,DaysAged
	,WeeksAged
	,MonthsAged
     ,system_category
order by
	ReportDate
	,a.GroupName
;quit;

/*PROC APPEND BASE=trend.trend_detail data=append_trend_detail force;*/
/*run;*/

proc sql;
create table xl_outreach_5days as
select distinct
	CASE
	when a.daysaged <= 5 then 'Within 5 Days'
	     when b.tblpracticedefecttype in ('Incorrect Mapping',
'Appointment Pending') then 'Over 5 Days (accepted*)'
	     else 'Over 5 Days' END as TouchCategory
	,a.daysaged
	,a.GroupName
	,a.GroupID
	,count(distinct a.ProviderID) as ProviderCount
	,a.physpracinstallstat
	,a.DATA_CATEGORY
	,a.installstat
	,a.pmsystem2
	,a.versiondescription
	,a.ReportDate
	,a.calclastupdate as LastOutreachDate format=mmddyy8.
	,PracticeInstallDate
    ,b.tblpracticedefecttype as PracticeDefectType
	
from physprac_view_age a
  left join notes_dates_last_all b on a.groupid = b.practiceid
where installstat in ('Data Issue','Scheduled','In Progress')
/*  and PracticeInstallDate < &reportdate.*/
group by 
	a.GroupName
	,a.GroupID
	,a.physpracinstallstat
	,a.DATA_CATEGORY
	,a.installstat
	,a.pmsystem2
	,a.versiondescription
	,a.daysaged
	,a.ReportDate
	,a.calclastupdate
	,PracticeInstallDate
	 ,b.tblpracticedefecttype

;quit;


%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='Change Matrix';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;



data current;
	set append_trend_detail;
	where ReportDate = "&current"d;
	CurrentStatus = physpracinstallstat;
	CurrentProviderCount = ProviderCount;
	CurrentPracticeCount = 1;
	keep GroupID GroupName CurrentStatus CurrentPracticeCount CurrentProviderCount;
run;

data prior;
	set trend.trend_detail;
	where ReportDate = "&prior"d;
	PriorStatus = physpracinstallstat;
	PriorProviderCount = ProviderCount;
	PriorPracticeCount = 1;
	keep GroupID GroupName PriorStatus PriorPracticeCount PriorProviderCount;
run;

proc sort data = current;
	by GroupID;
run;

proc sort data = prior;
	by GroupID;
run;

data change_matrix;
	merge 	current(in=a)
			prior(in=b);
	by GroupID;
	if a or b;

	NetChangeProviders = sum(CurrentProviderCount - PriorProviderCount);
	NetChangePractices = sum(CurrentPracticeCount - PriorPracticeCount);

	if CurrentStatus = PriorStatus then do;
		ChangeMatrixStatus = CurrentStatus;
			if CurrentStatus = 'Client Issue' then ClientIssue = CurrentProviderCount;
			if CurrentStatus = 'Data Issue' then DataIssue = CurrentProviderCount;
			if CurrentStatus = 'Incomplete PM Survey' then IncompletePMSurvey =
 CurrentProviderCount;
			if CurrentStatus = 'Not Scheduled' then NotScheduled = CurrentProviderCount;
			if CurrentStatus = 'In Progress' then InProgress = CurrentProviderCount;
		    if CurrentStatus = 'Scheduled' then Scheduled = CurrentProviderCount;
			if CurrentStatus = 'Successful' then Successful = CurrentProviderCount;
			if CurrentStatus = 'System Exploration' then SystemExploration =
 CurrentProviderCount;
			if CurrentStatus = 'Will Not Crack' then WillNotCrack = CurrentProviderCount;
			if CurrentStatus = 'Manual' then Manual = CurrentProviderCount;
	end;
	if (CurrentStatus ne PriorStatus and PriorStatus ne '') then do;
		ChangeMatrixStatus = PriorStatus;
			if CurrentStatus = 'Client Issue' then ClientIssue = CurrentProviderCount;
			if CurrentStatus = 'Data Issue' then DataIssue = CurrentProviderCount;
			if CurrentStatus = 'Incomplete PM Survey' then IncompletePMSurvey
 =CurrentProviderCount;
			if CurrentStatus = 'Not Scheduled' then NotScheduled = CurrentProviderCount;
			if CurrentStatus = 'In Progress' then InProgress = CurrentProviderCount;
		    if CurrentStatus = 'Scheduled' then Scheduled = CurrentProviderCount;
			if CurrentStatus = 'Successful' then Successful = CurrentProviderCount;
			if CurrentStatus = 'System Exploration' then SystemExploration
 =CurrentProviderCount;
			if CurrentStatus = 'Will Not Crack' then WillNotCrack = CurrentProviderCount;
			if CurrentStatus = 'Manual' then Manual = CurrentProviderCount;
	end;
	if (CurrentStatus ne '' and PriorStatus eq '') then do;
		ChangeMatrixStatus = 'ZZ New Practice';
		PriorStatus = 'ZZ New Practice';
		NetChangeProviders = CurrentProviderCount;
		NetChangePractices = 1;
			if CurrentStatus = 'Client Issue' then ClientIssue = CurrentProviderCount;
			if CurrentStatus = 'Data Issue' then DataIssue = CurrentProviderCount;
			if CurrentStatus = 'Incomplete PM Survey' then IncompletePMSurvey
 =CurrentProviderCount;
			if CurrentStatus = 'Not Scheduled' then NotScheduled = CurrentProviderCount;
			if CurrentStatus = 'In Progress' then InProgress = CurrentProviderCount;
		    if CurrentStatus = 'Scheduled' then Scheduled = CurrentProviderCount;
			if CurrentStatus = 'Successful' then Successful = CurrentProviderCount;
			if CurrentStatus = 'System Exploration' then SystemExploration
 =CurrentProviderCount;
			if CurrentStatus = 'Will Not Crack' then WillNotCrack = CurrentProviderCount;
			if CurrentStatus = 'Manual' then Manual = CurrentProviderCount;
	end;
	if (CurrentStatus eq '' and PriorStatus ne '') then do;
		ChangeMatrixStatus = PriorStatus;
		StatusDeleted = PriorProviderCount;
		NetChangeProviders = PriorProviderCount*-1;
		NetChangePractices = -1;
	end;
run;

PROC SORT DATA=change_matrix;BY GROUPNAME;RUN;

proc sql;
create table practice_systems as
select distinct
	a.GroupName
	,a.GroupID
	,b.category as system_category
	,b.name as PMSystem
	,b.VersionDescription
	,b.VersionName
from vLInk.Tblgroups a
	,ids.pmsystemstatus b
where a.ClientId = &clientid
  and a.g_version = b.versionid
order by 1,2
;quit;

proc sql;
create table xl_change_matrix_detail as
select
	"&prior"d as prior  format=mmddyy8.
	,"&current"d as current format=mmddyy8.
	,a.GroupName
	,a.GroupID
	,a.PriorStatus
	,a.CurrentStatus

	,b.system_category
	,b.PMSystem
	,b.VersionDescription as Version
	,a.ClientIssue
	,a.DataIssue
    ,a.InProgress
	,a.IncompletePMSurvey
	,a.Manual
	,a.NotScheduled
    ,a.Scheduled 
	,a.Successful
	,a.SystemExploration
	,a.WillNotCrack
	,a.StatusDeleted	
	,a.PriorProviderCount
	,a.CurrentProviderCount
	,a.NetChangeProviders
	,a.PriorPracticeCount
	,a.CurrentPracticeCount
	,a.NetChangePractices
from change_matrix a
	,practice_systems b
where a.GroupName = b.GroupName
  and a.GroupID = b.GroupID
order by 3,4
;quit;



%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='Build permanent datasets';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;


%macro build (dsn=,InDSN=);

data trend.&DSN ;
set &InDSN (in=b) trend.&DSN (in=a) ;
if reportdate ne .;
if a then do;
 if datepart(updatedtdt)=&RDATE then delete;
 end;
if b then do;
   rec=_N_;
   updatedtdt=dhms(&rdate,hour(time()),minute(time()),second(time()));
   end;
format updatedtdt datetime20.;
run;
proc sort data=trend.&dsn;by descending  reportdate groupname;run;

%mend;

%build (DSN=trend_detail,InDSN=APPEND_TREND_DETAIL);
%build (DSN=dashboard_detail,InDSN=xl_dashboard_detail);
%build (DSN=OUTREACH_5DAYS,InDSN=XL_OUTREACH_5DAYS);




/*/*Run if you want to delete date from trend table*/*/
/*%macro clean;*/
/*data trend_backup;*/
/*	set trend.trend_detail;*/
/*run;*/
/**/
/*data trend_clean;*/
/*	set trend.trend_detail;*/
/*	if reportdate = '03JAN2012'd then delete;*/
/*run;*/
/**/
/*data trend.trend_detail;*/
/*	set trend_clean;*/
/*run;*/
/*%mend;*/
/*%clean;*/
;

%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='Successful';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;



proc sql;
create table successful1 as
 select  reportdate format=mmddyy8.
        ,count(*) as practice_cnt

        ,sum(case when upcase(strip(physpracInstallStat))='SUCCESSFUL' THEN 1
 ELSE 0 END) AS successful_cnt
		,sum(Provider1stRecord) as Provider1stRecord_cnt	

	from trend.dashboard_detail
	group by reportdate;
	run;
proc sort data=successful1; by  descending reportdate ;run;

data successful2;
set successful1;
days=today()-reportdate+1;
week=int(days/7);
* get a week;
reporttxt=put(reportdate,mmddyy8.);
practiceTxt=left(put(practice_cnt,4.));
successfultxt=left(put(successful_cnt,4.));
providertxt=left(put(Provider1stRecord_cnt,4.));
PctSuccessful=left(put(successful_cnt/practice_cnt,percent10.1));
rec='Order' || put(week,3.);
drop   practice_cnt successful_cnt Provider1stRecord_cnt ;
label reporttxt="Category"
practiceTxt="N= Provider Practice Records"
Successfultxt="# Successful"
pctsuccessful="% Successful"
providertxt="Unique Provider Count"
;
run;
proc sort data=successful2;by  week  days;run;

data successful3;
set successful2;
by week;
if first.week;
if week <= 5;
status=1;
run;
proc sort data=successful3;by days;run;
data succdummy;
status=0;
do wk_cnt=0 to 5;

		days=(wk_cnt*7)+1;
		week=wk_cnt;

		reporttxt=put(&rdate+days,mmddyy8.);
	
        practiceTxt='';
        successfultxt='';
        providertxt='';
        PctSuccessful='';
		rec='Order' || put(week,3.);
     output;
	end;
	drop wk_cnt;
run;

data successful4;
set successful3 succdummy;
drop reportdate;
run;
proc sort data=successful4;by week descending status;run;
proc sort data=successful4 nodupkey;by week ;run;

proc sort data=successful4;by descending week;run;
proc transpose data=successful4 out=successful;
id rec;
var reporttxt practicetxt pctSuccessful successfultxt providertxt ;
run;


/**** outreach  */

proc sql;
create table outreach1a as
 select  reportdate format=mmddyy8.
         ,TouchCategory
        ,count(*) as n_cnt

	from trend.outreach_5days 
	
	group by reportdate,touchcategory;
	run;
proc sql ;
create table outreach0 as 
 select distinct reportdate from outreach1a;
 run;
data outreach0a;
format touchcategory $30.;
set outreach0;
n_cnt=0;
TouchCategory='Over 5 Days';
output;
TouchCategory='Over 5 Days (accepted*)' ;
output;
TouchCategory='Within 5 Days';
output;
run;

proc sql;
 create table outreach1 as
  select a.reportdate
     ,a.touchcategory
	 ,coalesce(b.n_cnt,a.n_cnt) as  n_cnt
	from outreach0a a left join outreach1a b
	 on a.reportdate=b.reportdate and a.touchcategory=b.touchcategory;
quit;


proc sort data=outreach1; by  descending reportdate touchcategory ;run;

data OVER WITHIN accepted missing_reportdate ;
set outreach1;
by descending reportdate;
days=today()-reportdate+1;
week=int(days/7);
retain rec;
  reporttxt=put(reportdate,mmddyy8.);
  count=left(put(n_cnt,4.));

if first.reportdate then rec='Order' || put(_N_,z2.);
drop reportdate reportdate  ;
label reporttxt="Outreach Category";
IF TouchCategory='Over 5 Days' THEN OUTPUT OVER;
else if touchcategory='Over 5 Days (accepted*)' then output accepted;
ELSE if touchcategory='Within 5 Days' then OUTPUT WITHIN;
output missing_reportdate;
run;



PROC SORT DATA=OVER;BY WEEK DAYS;RUN;
PROC SORT DATA=within;BY WEEK DAYS;RUN;
PROC SORT DATA=accepted;BY WEEK DAYS;RUN;

data over1;
set over;
by week;
if first.week;
if week <= 5;
run;

data within1;
set within;
by week;
if first.week;
if week <= 5;
run;

data accepted1;
set accepted;
by week;
if first.week;
if week <= 5;
run;

data outreach2;
set over1 within1 accepted1;
run;
/*proc contents data= outreach2 varnum short;run;*/








proc sort data=outreach2;by touchcategory descending week ;
run;

proc transpose data=outreach2 out=outreach3 prefix=WK_;
id week;
by touchcategory;
var reporttxt count ;
run;

proc sort data=outreach3;
by descending _name_  touchcategory;
run;

data outreach;
format touchcategory $30. touchcategory $9. wk_5 wk_4 wk_3 wk_2 wk_1 wk_0 $10.;
set outreach3;
array wk {*} wk_5 wk_4 wk_3 wk_2 wk_1 wk_0;
array lwk (*) $ lwk0-lwk5;
do m=1 to dim(lwk);
 lwk(m)=lag1(wk(m));
end;
if 1 < _N_ <=3 then do;
 do i=1 to dim(wk);
  if wk(i)='' then wk(i)=lwk(i);
 end;
end;
drop i m lwk0-lwk5 _name_ _label_;
run;


%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='Not Scheduled client Trend';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;



proc sql;
create table ns1 as
 select  distinct a.reportdate format=mmddyy8.
        ,case when daysaged > 30 then 'Over 30 days'
		      when daysaged <=30 then 'Within 30 days'
			    else '' end as Not_scheduled_category
        ,count(distinct case when  physpracinstallstat='Not Scheduled'  then
 GroupID else . end ) as ns_cnt
        ,max(practice_cnt) as practice_cnt
	
		
	from trend.dashboard_detail b left join 
	 (select distinct reportdate ,count(*) as practice_cnt from
 trend.dashboard_detail group by reportdate) a
	  on a.reportdate=b.reportdate
	where system_category in ('vMine','PGF','837')
	group by a.reportdate,Not_scheduled_category;
	run;


proc sort data=ns1; by  descending reportdate ;run;

data over within;
set ns1;
days=today()-reportdate+1;
week=int(days/7);
* get a week;
reporttxt=put(reportdate,mmddyy8.);
Not_scheduled_cnt=(put(ns_cnt,4.));
practiceTxt=left(put(practice_cnt,4.));

PctNS=left(put(ns_cnt/practice_cnt,percent10.1));
rec='Order' || put(week,1.);
drop reportdate reportdate practice_cnt ns_cnt   ;
label reporttxt="Category"
Not_scheduled_cnt="N= Practices Not Scheduled"
pctNS="% Not Scheduled";

IF Not_scheduled_category='Over 30 days' THEN OUTPUT OVER;
ELSE OUTPUT WITHIN;
run;
PROC SORT DATA=OVER;BY WEEK DAYS;RUN;
PROC SORT DATA=within;BY WEEK DAYS;RUN;

data over;
set  over;
by week;
if first.week;
if week <= 5;
run;

data within;
set  within;
by week;
if first.week;
if week <= 5;
run;

data ns3;
set over within;
Status=1;
run;
proc contents short varnum data=ns3;run;

data ns_missing;
format Not_scheduled_category $20.;
Status=0;
do week=0 to 5;
/* Not_scheduled_category days week reporttxt Not_scheduled_cnt practiceTxt
 PctNS rec*/
days=week+7;
rec='Order' || put(week,1.);
reporttxt=put(&rdate-(week*7),mmddyy8.);
Not_scheduled_cnt='0';
practiceTxt='0';
PctNS='0';

Not_scheduled_category='Over 30 days';
output;
Not_scheduled_category='Within 30 days';
output;
end;
run;
data ns4;
set ns3 ns_missing;
run;

proc sort data=ns4;by week Not_scheduled_category descending status;run;

proc sort data=ns4 nodupkey ;by week Not_scheduled_category ;run;


proc sort data=ns4;by Not_scheduled_category descending week ;run;
proc transpose data=ns4 out=ns5;
id rec;
by Not_scheduled_category;
var reporttxt practicetxt pctns   Not_scheduled_cnt  ;
run;

proc sort data=ns5;by _name_;run;



%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='Write Excel sheet.1';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;



%let
 excelfile=\\fs\&clientnm\reports\Data_Acquisition&debug.\DataAcquisition_data.xlsx;

data _null_;
fname="Tempname";
rc=filename(fname,"&excelfile");
if rc=0 and fexist(fname) then rc=fdelete(fname);
rc=filename(fname);
run;



libname xl_data oledb init_string="Provider=Microsoft.ACE.OLEDB.12.0; 
      data source=&excelfile.;
      extended Properties='Excel 12.0 XML'" ;

data xl_data.xl_work_queue;

set xl_work_queue;
run;


data xl_data.xl_vh_work_queue;
set xl_vh_work_queue;
run;

DATA XL_DATA.XL_DASHBOARD_DETAIL;
SET WORK.XL_DASHBOARD_DETAIL;
RUN;


DATA XL_DATA.XL_CHANGE_MATRIX_DETAIL;
SET WORK.XL_CHANGE_MATRIX_DETAIL;
RUN;

data xl_data.xl_outreach_5days;
set xl_outreach_5days;
run;

data xl_data.successful;
set successful;
run;
data xl_data.outreach;
set outreach;
run;
data xl_data.Not_scheduled;
set ns5;
run;


LIBNAME XL_DATA CLEAR;


%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

%LET _CLIENTTASKLABEL='Macro close';
%LET _CLIENTPROJECTPATH=
'M:\CI\programs\DataAcquisitionDashboard\Data Acquisition Dashboard 20120523.egp';
%LET _CLIENTPROJECTNAME='Data Acquisition Dashboard 20120523.egp';
%LET _SASPROGRAMFILE=;

%mend data_acquisition_dashboard;

%LET _CLIENTTASKLABEL=;
%LET _CLIENTPROJECTPATH=;
%LET _CLIENTPROJECTNAME=;
%LET _SASPROGRAMFILE=;

