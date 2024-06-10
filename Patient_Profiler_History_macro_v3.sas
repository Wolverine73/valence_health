/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  NSAP_patient_profiler_history.sas
|
| LOCATION: m:\nsap\Programs\Auto\NSAP_patient_profiler_history.sas
|
| PURPOSE:  Look at web utilization of providers only (i.e. the history of patient profiler use)
|           
| LOGIC:    Create SAS dataset looking at unique providers and number of logins trended over time

			and

			Create SAS dataset looking at # of patients looks up across all unique providers over time
|
| INPUT:    Data from SQL fg_nsap, and meeting information           
|
| OUTPUT:   SAS dataset / EXCEL file
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 21JUL2011 - Mark Logsdon  - Clinical Integration 
|
| 26AUG2011 - Mark Logsdon - Updated all "sas2" to "m:" and "sasbi" to "ebicompute" 
|
| 03OCT2011 - Nick Gryfakis - Converted program to macro
+-----------------------------------------------------------------------HEADER*/

options sasautos = ("m:\CI\programs\StandardMacros" "m:\CI\programs\ClientMacros" sasautos);
options mprint mlogic symbolgen msglevel=i error=2 ls=120 ps=60;
%let outpath = temp;




*SASDOC----------------------------------------------------------------------
| Define SAS options for program                                               
+----------------------------------------------------------------------SASDOC*;
%macro libnames;

%if &vlink_client_name=nsap %then %do;
	libname provfmt "M:\&vlink_client_name\sasdata\ci\cietl\provider\formats";
	%let outpath = \\fs\&vlink_client_name\Reports\CIOPS\PortalUsage;
%end;

%if &vlink_client_name = Adventist %then %do;
	libname provfmt "M:\&vlink_client_name\SASDATA\CIETL\provider\formats";
	%let outpath = \\fs\&vlink_client_name\Reports\PortalUsage;
%end;

%if &vlink_client_name ne Adventist and &vlink_client_name ne nsap %then %do;

	libname provfmt "M:\&vlink_client_name\SASDATA\CIETL\provider\formats";
	%let outpath = \\fs\&vlink_client_name\Reports\Monthly_Reports\PortalUsage;
%end;

%mend libnames;

%macro porstats;



%let nicedate=xx;
data _null_;
	nicedate=put(today(), worddate.);
	call symput('nicedate', nicedate);
run;

%put &nicedate.;

*SASDOC--------------------------------------------------------------------------
| Get Provider List
+------------------------------------------------------------------------SASDOC*;

%let outpath = temp;
%libnames;


proc format cntlin=provfmt.provyn;
run;


libname vlink oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vlinkNSAP;" ;

data allproviders;
	set vlink.tblprovider;
	where p_networkstatus=5 and clientid=&client_id and p_npi ne "";
		cipar=put(p_npi, $provyn.);
	rename p_npi=npi;
	keep p_npi cipar;
run;

proc sort data=allproviders nodupkey ;
	by npi;
run;

/*Removed format call b/c can't find it used elsewhere*/
/*proc format cntlin=provfmt.provtype;*/
/*run;*/




*SASDOC--------------------------------------------------------------------------
|  CREATING PROVIDER-CHECK FORMAT VARIABLE 
+------------------------------------------------------------------------SASDOC*;

libname memdb oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vLinkNSAP;";

data ProviderTable;
set memdb.tblProvider (keep=p_firstname p_lastname p_clientproviderID P_NPI);
run;


data ProviderFmt;
LENGTH FMTNAME $9  TYPE $1 label $1 start $11.;
  SET ProviderTable (keep=p_npi);
  KEEP START LABEL TYPE FMTNAME ;
  RETAIN FMTNAME 'provcheck'  TYPE 'C';
	start = p_npi;
    label = 'Y';
    output;
  if _n_ = 1 then do;
 	start = "other";
 	label = ".";
 	output;
  end;
run;
proc sort data=ProviderFmt nodupkey;
	by start;
run;
PROC FORMAT CNTLIN=ProviderFmt;*very important line of code;
RUN;




*SASDOC--------------------------------------------------------------------------
|  GETTING UPDATED USAGE DATA
+------------------------------------------------------------------------SASDOC*;

libname userinfo "\\ebicompute\projects\tools\parms\";

data work.trackusage_1;
	set userinfo.usage_reporting_data;
	where(upcase(project)=upcase("&vlink_client_name")) and runtype='PROD';
/*	where project=&vlink_client_name and runtype='PROD';*/
	date=datepart(rundate);

	rename user =userid;
	if patientid ne "" then profiler=1;
run;

proc sort data=trackusage_1;
	by report date;
run;

libname userinfo clear;




*SASDOC--------------------------------------------------------------------------
|  Counting Logins Per Provider Per Month
+------------------------------------------------------------------------SASDOC*;

proc sql;
	create table LoginsMonth as 
	select distinct substr(Userid, 1, 10) as npi, count(distinct date) as count, input(put(date, yymmn6.),6.) as year_month  
	from trackusage_1 
	where put(substr(Userid,1,10),$provcheck.)='Y'
	group by npi, input(put(date, yymmn6.),6.)
	order by input(put(date, yymmn6.),6.);
quit; 

proc sql;
	create table LoginsMonthFinal as 
	select year_month, sum(count) as logins   
	from LoginsMonth
	group by year_month
	order by year_month;
quit; 


*SASDOC--------------------------------------------------------------------------
|  Counting Patient Profile Views Per Provider Per Month
+------------------------------------------------------------------------SASDOC*;

proc sql;
	create table ProfileViews as 
	select distinct substr(Userid, 1, 10) as npi, count(distinct patientid) as count, input(put(date, yymmn6.),6.) as year_month
	from trackusage_1
	where profiler=1 and put(substr(Userid,1,10),$provcheck.)='Y'
	group by npi,input(put(date, yymmn6.),6.)
	order by input(put(date, yymmn6.),6.);
quit; 

proc sql;
	create table ProfileViewsFinal as 
	select year_month, sum(count) as totcount 
	from ProfileViews 
	group by year_month
	order by year_month;
quit; 



*SASDOC--------------------------------------------------------------------------
|  Counting Report Types Per Provider Per Month
+------------------------------------------------------------------------SASDOC*;

%macro reporttype (report, report2);

proc sql;

create table Report as 
	select distinct substr(Userid, 1, 10) as npi, count(distinct date) as count, input(put(date, yymmn6.),6.) as year_month  
	from trackusage_1 
	where put(substr(Userid,1,10),$provcheck.)='Y' and report in (&report, &report2)
	group by npi, input(put(date, yymmn6.),6.)
	order by input(put(date, yymmn6.),6.);
quit; 

proc sql;
	create table Report_&report as 
	select year_month, sum(count) as logins   
	from Report 
	group by year_month
	order by year_month;
quit; 

%mend;

%reporttype(924);
%reporttype(907,21);


*SASDOC--------------------------------------------------------------------------

|  Counting Report Types Per Provider Per Month Accounting for Missing Tracking Time

+------------------------------------------------------------------------SASDOC*;


proc sql;
create table newlogins as 
	select distinct substr(Userid, 1, 10) as npi, count(distinct patientid) as sum, date format=mmddyy10. 
	from trackusage_1 
	where/* profiler=1 and*/ put(substr(Userid, 1, 10), $provyn.)='Y'
	group by npi, date
	order by npi, date;
quit; 


proc sql;
	create table newlogins2 as 
	select npi, case when ('13JUL2011'd <= date <= '28JUL2011'd) and sum=0 then 5  else sum end as count, input(put(date, yymmn6.),6.) as year_month
	from  newlogins
	where ('13JUL2011'd <= date <= '28JUL2011'd)
	order by date;
quit; 


proc sql;
	create table newlogins3 as 
	select year_month, sum(count) as sum
	from  newlogins2
	group by year_month;
quit; 


proc sql;
	create table newlogins4 as 
	select a.year_month as date, a.totcount, b.sum
	from  profileviewsfinal a left join newlogins3 b on a.year_month=b.year_month ;quit; 


proc sql;
	create table profileviewsadj as 
	select date as year_month, case when year_month=201107 then totcount+sum  else totcount end as count
	from  newlogins4
	group by year_month;
quit; 



*SASDOC--------------------------------------------------------------------------
| Grouping Distinct NPI Providers Per Month
+------------------------------------------------------------------------SASDOC*;


proc sql;
	create table ProvidersMonth as 
	select distinct substr(Userid, 1, 10) as npi, count(distinct date) as count, input(put(date, yymmn6.),6.) as year_month  
	from trackusage_1 
	where put(substr(Userid,1,10),$provcheck.)='Y'
	group by npi, input(put(date, yymmn6.),6.)
	order by input(put(date, yymmn6.),6.);
quit; 

proc sql;
	create table ProvidersMonthFinal as 
	select year_month, count(distinct npi) as logins   
	from ProvidersMonth 
	group by year_month
	order by year_month;
quit; 





*SASDOC--------------------------------------------------------------------------
|  Counting Reports per month and removing one outlying provider
+------------------------------------------------------------------------SASDOC*;

proc sql;
	create table profilerrptx as 
	select distinct substr(Userid, 1, 10) as npi, count(report) as count, input(put(date, yymmn6.),6.) as year_month  
	from trackusage_1 
	where put(substr(Userid,1,10),$provcheck.)='Y' and report=924 and substr(Userid, 1, 10)^='1922037910'
	group by npi, date
	order by input(put(date, yymmn6.),6.);
quit; 

proc sql;
	create table profilerrpt2x as 
	select year_month, sum(count) as logins   
	from profilerrptx
	group by year_month
	order by year_month;
quit; 






*SASDOC--------------------------------------------------------------------------
| EDITABLE CODE FOR CHECKING OUTPUT (i.e. confirming that counts are correct by handcounts)
+------------------------------------------------------------------------SASDOC*;

proc sql;
	create table profilerchk2 as 
	select substr(Userid, 1, 10) as npi, count(report) as count, date format=date9.
	from trackusage_1 
	where put(substr(Userid,1,10),$provcheck.)='Y' and report=924
	group by npi, date
	order by date;
quit; 





*SASDOC--------------------------------------------------------------------------
| EDITABLE CODE FOR CHECKING month-by-month stats (i.e. confirming that counts are correct by handcounts)
+------------------------------------------------------------------------SASDOC*;



proc sql;
	create table ProvidersMonth2 as 
	select distinct substr(Userid, 1, 10) as npi, count(distinct date) as count, input(put(date, yymmn6.),6.) as year_month  
	from trackusage_1 
	where put(substr(Userid,1,10),$provcheck.)='Y' and ('01JUL2011'd le date le '13JUL2011'd or '28JUL2011'd le date le '30JUL2011'd) and patientid ne ""
	group by npi, input(put(date, yymmn6.),6.)
	order by input(put(date, yymmn6.),6.);
quit; 



*SASDOC--------------------------------------------------------------------------
| Creating final table and xls output.
+------------------------------------------------------------------------SASDOC*;



proc sql;

create table finaltable as
	select a.year_month as date, a.logins as Logins, b.logins as Unique_Providers, c.totcount as Patient_Profile, d.logins as Guideline_Results, e.logins as Patient_Lists
	from loginsmonthfinal a left join providersmonthfinal b on a.year_month=b.year_month
							left join profileviewsfinal c on a.year_month=c.year_month
							left join report_924 d on a.year_month=d.year_month
							left join report_907 e on a.year_month=e.year_month;

quit;

data finaltable2 ;
	set finaltable ;

	
	If date=201007 then NewDate='Jul-10';
	If date=201008 then newdate='Aug-10';
	If date=201009 then newdate='Sep-10';
	If date=201010 then newdate='Oct-10';
	If date=201011 then newdate='Nov-10';
	If date=201012 then newdate='Dec-10';
	If date=201101 then newdate='Jan-11';
	If date=201102 then newdate='Feb-11';
	If date=201103 then newdate='Mar-11';
	If date=201104 then newdate='Apr-11';
	If date=201105 then newdate='May-11';
	If date=201106 then newdate='Jun-11';
	If date=201107 then newdate='Jul-11';
	If date=201108 then newdate='Aug-11';
	If date=201109 then newdate='Sep-11';
	If date=201110 then newdate='Oct-11';
	if patient_profile=. then patient_profile=0;
	if guideline_results=. then guideline_results=0;
/*	drop date;*/

	AvgViewsPerProvider=Logins/Unique_Providers;
	AvgProfileViews=Patient_Profile/Logins;
	AvgGuidelineViews=Guideline_Results/Logins;
	AvgPatientViews=Patient_Lists/Logins;
	

	run;
	

proc sql;

create table finaltable3 as
	select date, logins, unique_providers, avgviewsperprovider format=10.2, patient_profile, avgprofileviews format=10.2, guideline_results, avgguidelineviews format=10.2, patient_lists, avgpatientviews format=10.2
	from finaltable2;
	quit;


ods tagsets.excelxp file="&outpath.\&vlink_client_name._PortalUsage.xls"
	  options (Sheet_name="Portal Util-&vlink_client_name.-&sysdate." width_fudge ='0.4'
            FROZEN_HEADERS='yes' AUTOFIT_HEIGHT='yes' autofilter='all');

title "Summary of Portal Usage: &vlink_client_name.-&sysdate.";



proc print data=finaltable3 noobs label ;
label
 date = "Date" logins="Logins"
 unique_providers ="Unique Providers" avgviewsperprovider="Avg Logins Per Provider" patient_profile="Patient Profile Views"
 avgprofileviews="Avg Profile Views Per Login" guideline_results="Guideline Results Views" Avgguidelineviews="Avg Guideline Results Views Per Login"
 patient_lists="Patient List Views" avgpatientviews="Avg Patient List Views Per Login";

run;



ods tagsets.excelxp close;





libname combined 'm:\CI\sasdata\CISubmeasureHistory';

data All_client_portal_utilization;
set finaltable3;
client = "&vlink_client_name";
format client $20.;
rundate = "&sysdate.";
label
 date = "Date" logins="Logins"
 unique_providers ="Unique Providers" avgviewsperprovider="Avg Logins Per Provider" patient_profile="Patient Profile Views"
 avgprofileviews="Avg Profile Views Per Login" guideline_results="Guideline Results Views" Avgguidelineviews="Avg Guideline Results Views Per Login"
 patient_lists="Patient List Views" avgpatientviews="Avg Patient List Views Per Login";
run;

proc append base = combined.All_client_portal_utilization data = All_client_portal_utilization force;
run;

proc sort data = combined.All_client_portal_utilization nodup;
by client rundate date;
run;

ods tagsets.excelxp file="\\fs\DataTeam\CI\Process\Internal\Project_Management\PortalUsage\AllClients_PortalUsage.xls"


   options (Sheet_name='Portal Utilization History-All Clients' width_fudge ='0.4'
            FROZEN_HEADERS='yes' AUTOFIT_HEIGHT='yes' autofilter='all');

title "Summary of Portal Usage: All Clients-&sysdate.";

proc print data = combined.All_client_portal_utilization noobs label;
run;

ods tagsets.excelxp close;

%mend porstats;





/*-------------------NSAP----------------*/
%let vlink_client_name = nsap;
%let client_id = 4;
%porstats;
/*-------------------Exempla----------------*/
%let vlink_client_name = Exempla;
%let client_id = 8;
%porstats;
/*-------------------St Lukes----------------*/
%let vlink_client_name = StLukes;
%let client_id = 3;
%porstats;
/*-------------------CCCPP----------------*/
%let vlink_client_name = CCCPP;
%let client_id = 6;
%porstats;
/*-------------------OHG----------------*/
%let vlink_client_name = OHG;
%let client_id = 7;
%porstats;
/*-------------------PHS----------------*/
%let vlink_client_name = PHS;
%let client_id = 5;
%porstats;
/*-------------------Adventist----------------*/
%let vlink_client_name = Adventist;
%let client_id = 2;
%porstats;



