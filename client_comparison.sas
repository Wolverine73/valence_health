/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  client_comparison.sas
|
| LOCATION: M:\ci\standardmacros
|
| PURPOSE:  generate load stastics across clients each month
|           
| LOGIC:    Create sas datasets summarizing monthly load
|
| INPUT:    Data from SQL, provider table, portal datasets, vmine combined and labclme          
|
| OUTPUT:   Entry in client comparison sas dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 20JAN2011 - Abby Isaacs  - Clinical Integration  1.0.01
|             Created program to standardize and automate client comparison report
|             
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS options for program                                               
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);
options mprint mlogic symbolgen msglevel=i error=2 ls=120 ps=60;



%*SASDOC----------------------------------------------------------------------
| Standard Assignments of Libnames and Formats                                             
+----------------------------------------------------------------------SASDOC*;
%macro clientcompare(client=);

%macro lib;
	%if "&client" = "NSAP" or "&client" = "nsap" %then %do;
		data _null_;
		call symput('portal',"M:\&client.\sasdata\ci\Portal\PortalOut");
		call symput('labclme',"M:\&client.\sasdata\ci\CIETL\dw");
		call symput('vminepgf',"M:\&client.\sasdata\ci\CIETL\dw");
		call symput('member', "M:\&client.\sasdata\ci\CIETL\member");
		call symput('vmine1',"M:\&client.\sasdata\ci\CIETL\dw");
		call symput('prov',"M:\&client.\sasdata\ci\CIETL\provider");
		call symput('provfmt',"M:\&client.\sasdata\ci\CIETL\provider\formats");
		call symput('sasbi',"\\ebicompute\projects\&client.\data");
		run;
	%end; 
	%else %if "&client" = "ADVENTIST" %then %do;
		data _null_;
		call symput('portal',"M:\Adventist\SASTemp\CIProcess\Portal");
		call symput('member', "M:\&client.\sasdata\CIETL\members");
		call symput('sasbi',"\\ebicompute\projects\&client.\data");
		call symput('vminepgf', "M:\Adventist\SASTemp\CIProcess\Claims");
		call symput('labclme', "M:\&client.\sasdata\CIETL\dw");
		call symput('prov', "M:\&client.\sasdata\CIETL\provider");		
		call symput('provfmt', "M:\&client.\sasdata\CIETL\provider\Formats");
		run;
	%end; 
	%else %do;
		data _null_;
		call symput('portal', "M:\&client.\sasdata\Portal\PortalOut");
		call symput('member', "M:\&client.\sasdata\CIETL\member");
		call symput('vminepgf', "M:\&client.\sastemp\CIProcess\vminecombined");
		call symput('labclme', "M:\&client.\sasdata\CIETL\dw");
		call symput('vmine1', 'M:\&client.\sastemp\vMine_Combined');
		call symput('prov', "M:\&client.\sasdata\CIETL\provider");
		call symput('provfmt', "M:\&client.\sasdata\CIETL\provider\Formats");
		call symput('sasbi',"\\ebicompute\projects\&client.\data");
		run;
	%end;
	%if "&client." = "STLUKES" or "&client." = "stlukes" %then %do;  
		data _null_;
		call symput('vmine1', 'M:\&client.\sastemp\ciprocess\vMine_Combined');
		call symput('vminepgf', "M:\&client.\sastemp\CIProcess");
		run;
	%end;
	%if "&client." = "EXEMPLA"  %then %do;  
		data _null_;
		call symput('vmine1', 'M:\&client.\sastemp\ciprocess');
		call symput('vminepgf', "M:\&client.\sastemp\CIProcess");
		run;
	%end;
	%if "&client." = "CCCPP"  %then %do;  
		data _null_;
		call symput('portal', 'M:\&client.\sastemp\portal\portalout');
		call symput('labclme', "M:\&client.\sastemp\labclme");
		call symput('vmine1', "M:\&client.\sastemp\ciprocess\vmine_combined");
		call symput('vminepgf', "M:\&client.\sastemp\ciprocess\vmine_combined");
		run;
	%end;
	%if "&client." = "OHG"  %then %do;  
		data _null_;
		call symput('vminepgf', 'M:\&client.\SASTEMP\vMine_Combined');
		run;
	%end;
	%mend;

	%lib;


libname portal "&portal.";
libname vminepgf "&vminepgf.";
libname labclme "&labclme.";
libname vmine1 "&vmine1.";
libname prov "&prov.";
libname sasbi "&sasbi.";
libname provfmt "&provfmt.";
libname member "&member.";
libname pgf "&pgf.";
libname SQL oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vLinkNSAP;" ;

libname SQL2 oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=IntegrationDataSource;" ;

libname hist "M:\ci\sasdata\cisubmeasurehistory";

proc format cntlin = provfmt.provyn;
quit;


%*SASDOC----------------------------------------------------------------------
| Create Report Date Macro Variables                                              
+----------------------------------------------------------------------SASDOC*;

data _null_;
	month = put(intnx('month',today(),-1),yymmn.);
	call symput ('month',month);
run;
%put &month.;


*current reporting year;
data a ;
set portal.portal_dates;
if parameter = "StartDate" then do;
	call symput ('sdate',value);
end;
else if parameter = "EndDate" then do;
	call symput ('edate',value);
end;
a=value;
label a = "current reporting year";
keep a;
if parameter = "Period" then output;
run;

%put &sdate;
%put &edate;


%*SASDOC----------------------------------------------------------------------
|Practice Counts                                         
+----------------------------------------------------------------------SASDOC*;

%if "&client"="CCCPP" %then %do; 
	proc summary data=prov.provider nway missing;
	class tin;
	output out=a1;
	run;
%end;

%else %if "&client."="NSAP" or "&client."="OHG" or "&client"="EXEMPLA"  %then %do;
	proc summary data=prov.provider nway missing;
	class practice;
	output out=a1 ;
	run;
%end;

%else %if "&client"="ADVENTIST" %then %do;
	proc summary data=prov.provider nway missing;
	class practice_name;
	output out=a1 ;
	run;

%end;

%else %if "&client."="PHS" %then %do;
	proc sql;
	create table a1 as select distinct groupid, groupname, g_cipar
	from sql.tblGroups 
	where clientid=5 and g_cipar=1;
	quit;
%end;
%else %do;
	proc summary data=prov.provider nway missing;
	class provgroup;
	output out=a1 ;
	run;
%end;

data _null_;
set a1;
obsprov = _n_;
call symput ('obsgroup',obsprov);
run;
%put &obsgroup.;

data a2;
a2 = &obsgroup.;
label a2= "Total IPA Practices";
keep a2;
run;

*ADD IN ALL PRACTICES LOADED;

*vMine Practices Loaded = Data Load Excel;

%if "&client"="CCCPP" %then %do; 
	proc summary data=vminepgf.&client._vmine_combined nway missing;
	class tin ;
	output out=aa1 ;
	run;


	proc summary data=vminepgf.&client._pgf_combined nway missing;
	class tin ;
	output out=aa2 ;
	run;

	data aa11;
	set aa1 (in=a)
		aa2 (in=b);
	if a then Category="VMINE";
	else if b then Category="PGF";
	run;
%end;
%else %do;

	%if "&client." = "NSAP" or 
	"&client." = "ADVENTIST"  %then %do;
		proc summary data=vminepgf.matchedvmineandpgf nway missing;
		class practiceid 
				%if "&client." = "NSAP"  %then %do; 
					practice; 
				%end; 
				%else %do; 
					pcpid;
				%end;
		output out=aa1 ;
		run;

		data aa11;
		set aa1;
		by practiceid 				
				%if "&client." = "NSAP"  %then %do; 
					practice; 
				%end; 
				%else %do; 
					pcpid;
				%end;
		run;
	%end;

	%else %do;
		proc summary data=vmine1.vmine_&client._claims nway missing;
		class practiceid;
		output out=aa1 ;
		run;
	%end;

	proc sql;
	create table systemtype as select
		ps.datasourceid, ps.versionid, v.versionid, v.statusid, s.statusid, s.category
			from sql2.datasource ps left join (sql2.version v left join sql2.versionstatus s on    v.statusid = s.statusid)
					on ps.versionid= v.versionid 
						order by  datasourceid, category ;		
					quit;

	data aa11;
	merge aa1 (in=a) systemtype (rename=(datasourceid=practiceid));
	by practiceid;
	if a;
	if Category="" then category="PGF";
	run;

%end;
data _null_;
set aa11;
where upcase(cats(category))="VMINE";
obsvmine = _n_;
call symput ('obsvmine',obsvmine);
run;
%put &obsvmine.;

data b1;
b1 = &obsvmine.;
label b1= "vMine Practices Loaded";
run;
;



data _null_;
set aa11;
where upcase(cats(category))="PGF";
obspgf = _n_;
call symput ('obspgf',obspgf);
run;

%put &obspgf.;



data b2;
b2 = &obspgf.;
label b2= "PGF Practices Loaded";
run;


/*data _null_;*/
/*set aa11;*/
/*obsvmine = _n_;*/
/*call symput ('obsprac',obsvmine);*/
/*run;*/
/*%put &obsprac.;*/

/*data b1;*/
/*b1 = &obsprac.;*/
/*label b1= "All Practices Loaded";*/
/*run;*/


%*SASDOC----------------------------------------------------------------------
| Provider Counts                                       
+----------------------------------------------------------------------SASDOC*;



proc sql;
create table b3 as select distinct start 
	from provfmt.provyn
		where start not in( 'Other', "OTHER", "other");
run;

data _null_;
set b3;
obsprov = _n_;
call symput ('obsprov',obsprov);
run;
%put &obsprov.;

data b;
b = &obsprov.;
label b = "Total IPA Physicians";
run;


%if "&client."="CCCPP" %then %do;

	proc summary data = labclme.labclme nway missing;
	where upcase(source)="P" and put(provid,$provyn.) = "Y";
	class provid;
	output out = c1;
	run;
%end;
%else %do;

	proc summary data = vminepgf.matchedvmineandpgf nway missing;
	where put(provid,$provyn.) = "Y";
	class provid;
	output out = c1;
	run;
%end;




data _null_;
set c1;
obsuprov = _n_;
call symput ('obsuprov',obsuprov);
run;
%put &obsuprov.;

data c;
c= &obsuprov.;
label c= "Unique IPA providers in data";
run;


*IPA providers with eligible members;
proc summary data = portal.guidelineprovider nway missing;
where pcpid ne '9999999999' and eligible2 not in (0,.) %if "&client." ne "OHG" %then %do; and guidelinetype='V' %end;; 
class pcpid;
output out = d1;
run;

data _null_;
	set d1;
	obs = _n_;
	call symput ('obs',obs);
run;
%put &obs.;

data d;
d = &obs.;
label d= "IPA providers with eligible members";
run;

*%IPA Providers with over 10 eligible patients;
data e1;
set portal.guidelineprovider;
%if "&client." ne "OHG" %then %do;
	where guidelinetype='V';
%end;
if eligible2 le 10 then flag = 0; else
flag = 1;
run;

proc summary data = e1 nway missing;
where flag = 1 and pcpid not in ('9999999999');
class pcpid;
var flag;
output out = e2 sum=;
run;

data _null_;
set e2;
	obs10 = _n_;
	call symput ('obs10',obs10);
run;
%put &obs10.;

data e ;
e = &obs10./&obs.;
label e = "% of IPA Providers with over 10 eligible patients";
format e percent12.2;
run;

*Claims Measures;
proc summary data = portal.guideline nway missing;
class guideline;
output out = f1;
run;

proc summary data = f1 nway missing;
var _FREQ_;
output out = f2 (drop = _TYPE_) sum=;
run;

data f;
set f2;
f=_FREQ_; 
label f = "Claims Measures";
drop _FREQ_ ;
run;

*Manual Reporting Physicians;
proc freq data = portal.providerlookup noprint;
where pcpid not in ('9999999999','8888888888') and put(pcpid, $provyn.)='Y';
table provtype / list missing out = g1;
run;

data g ;
set g1;
g=Count;
where provtype = "M";
label g = "Manual Reporting Physicians";
keep g;
run;

*Total Number of physicians who have reported manually;
proc sort data=portal.manual_measures out=everreported nodupkey;
where put(pcpid, $provyn.)='Y'; 
by pcpid;
run;

data h1;
set portal.manual_measures;
where put(monthid,yymmn.) in ("201101", "201102") and pcpid not in ('8888888888');
run;

%put &month;

proc summary data = h1 nway missing;
class pcpid;
output out = h2 (rename =(_FREQ_=count));
run;

proc summary data = h2 nway missing;
var count;
output out = h3 (drop = _TYPE_ count) sum=;
run;

data h  ;
set h3;
h = _FREQ_;
label h = "Total Number of physicians who have reported manually in the last month";
keep h;
run;

*Manual reporting 10 in last month;
proc summary data = h1 nway missing;
class pcpid guideline eligible;
output out = i1 (drop = _TYPE_ _FREQ_ rename = (eligible=count));
run;

data i2;
set i1;
*if count ge 10;
run;

data _null_;
set i2;
obsman = _n_;	
call symput ('obsman',obsman);
run;
%put &obsman.;

data i;
i = &obsman.;
label i = "Manual reporting in last month";
run;

data i3;
set i1;
if count ge 10;
run;

data _null_;
set i3;
obsman = _n_;	
call symput ('obsman1',obsman);
run;
%put &obsman1.;

data ii;
ii = &obsman1.;
label ii = "Manual reporting 10 in last month";
run;


%*SASDOC----------------------------------------------------------------------
| Member Counts                                       
+----------------------------------------------------------------------SASDOC*;

%if "&client." = "OHG"  %then %do;

	proc sort data = vmine1.allclaims_ohg out = j1 (keep = memberid svcdt) nodupkey;
	where "&sdate."d le svcdt le "&edate."d;
	by memberid;
	run;

%end;
%else %do;
	proc sql;
	create table j1 as
	select distinct memberid from vminepgf.matchedvmineandpgf 
	where "&sdate."d le svcdt le "&edate."d;
	quit;
%end;


data _null_;
	set j1;
	obspt = _n_;
	call symput ('obspt',obspt);
run;

%put &obspt.;
data j;
j = &obspt.;
label j = "Patients seen in reporting year";
run;
*pcp visits;




%if "&client."="ADVENTIST" %then %do;
	proc format cntlin=provfmt.npi2provspec; run;

	proc sql;
	create table jj1 as
	select distinct memberid svcdt from vminepgf.matchedvmineandpgf 
	where (("&sdate."d le svcdt le "&edate."d )
		and (proccd in ('99201', '99202', '99203', '99204', '99205', '99206', '99207', '99208',	'99209', '99210', '99211',	
						'99212', '99213', '99214', '99215',	'99241', '99242', '99243', '99244',	'99245', '99281', '99282', 
						'99283', '99284', '99285', '99286', '99287', '99288', '99289', '99290',	'99291', '99292', '99293',	
						'99294', '99295', '99296', '99297')) 
		and (put(provid, $npi2provspec.) in ("21", "35", "45", "25", "44", "62")));
	quit;

%end;
%else %do; 

	proc format cntlin=provfmt.provspec; run;

	proc sql;
	create table jj1 as
	select distinct memberid, svcdt from vminepgf.matchedvmineandpgf 
	where (("&sdate."d le svcdt le "&edate."d )
		and (proccd in ('99201', '99202', '99203', '99204', '99205', '99206', '99207', '99208',	'99209', '99210', '99211',	
						'99212', '99213', '99214', '99215',	'99241', '99242', '99243', '99244',	'99245', '99281', '99282', 
						'99283', '99284', '99285', '99286', '99287', '99288', '99289', '99290',	'99291', '99292', '99293',	
						'99294', '99295', '99296', '99297')) 
		and (put(provid, $provspec.) in ("21", "35", "45", "25", "44", "62")));
	quit;

%end;


data kk2 ;
set jj1;
kk=_n_;
call symput('npcpvisits', kk);
run;

data kk;
kk=&npcpvisits;
label kk = "PCP office visits in reporting year";
run;
*Eligible patients in reporting year;
proc sql;
create table k1 as select distinct memberid from
	portal.submeasures_detail;
quit;

data k2 ;
set k1;
k=_n_;
call symput('nelig', k);
run;

%put &nelig;
data k;
k=&nelig;
label k = "Eligible patients in reporting year";
run;

/*unique patients seen within reporting year*/
proc sort data=j1 out=j2 nodupkey;
by memberid;
run;
*Mean eligible Patients per provider = # eligible patients in reporting year/Number of providers with eligible members;
data l;
set k;
l = k/&obs.;
label l = "Mean eligible Patients per provider";
keep l;
run;

*Total Unique Patients in Patient table;

%if "&client."="ADVENTIST" %then %do;
	data _null_;
		set member.members;
		obsmem = _n_;
		call symput ('obsmem',obsmem);
	run;
	%put &obsmem.;
%end;
%else %do;
	data _null_;
		set member.member;
		obsmem = _n_;
		call symput ('obsmem',obsmem);
	run;
	%put &obsmem.;
%end;
data m;
m = &obsmem.;
label m = "Total Unique Patients in Patient table";
run;

ods output Members=sasbisets;

proc datasets lib=sasbi;
quit;

data _null_;
set sasbisets;
where name = 'GUIDELINE';
date=datepart(LastModified);
call symput('refreshdt', Date);
run;

%put &refreshdt.; 


%*SASDOC----------------------------------------------------------------------
| Portal Refresh Date                                    
+----------------------------------------------------------------------SASDOC*;

data n;
format n mmddyy10.;
n=1*&refreshdt.;
label n = "Portal Refresh Date";
run;


%*SASDOC----------------------------------------------------------------------
| Sharepoint Issues                                    
+----------------------------------------------------------------------SASDOC*;


%if &client = ADVENTIST or &client = Adventist or &client = adventist %then %do ;
	data o1;
	set sql.vAHNciprogressdetailed;
	count=1;
	run; 
%end;

%else %do;
	data o1;
	set sql.v&client.ciprogressdetailed;
	count=1;
	run; 
%end;

proc sort data=o1 out= o2 (keep=Groupid installstat count )nodupkey;
 by groupid ;
 run;

proc summary data=o2 nway missing;
class installstat;
var count;
output out=o3 sum=;
run;

data o;
set o3;
where installstat="Data Issue";
o = count;
label o= "Data Issues in Sharepoint";
keep o;
run;

data p;
set o3;
where installstat="Client Issue";
p = count;
label p= "Client Issues in Sharepoint";
keep p;
run;

%*SASDOC----------------------------------------------------------------------
| Get Run Time Info                                
+----------------------------------------------------------------------SASDOC*;


data run_times;
set hist.load_program_run_times;
where upcase(clientname)in ("&client.");
run;

proc sort data=run_times;
by stage descending rundt descending starttime;
run;

data runcount;
set run_times;
where stage="portal" and put(rundt, yymm6.)= put(today(), yymm6.);
call symput('nruns', _n_);
run;

data nruns;
nruns=&nruns.;
run;

data combine (keep=combine_min combine_date combine_time) 
	portal  (keep=portal_min portal_date portal_time)
	member (keep=member_min member_date member_time)
	labclme (keep=labclme_min labclme_date labclme_time);
set run_times;
by stage;
if first.stage;
runmin=(endtime-starttime)/60;
if stage="combine_data" then do;
	combine_min=runmin;
	combine_date=rundt;
	combine_time=starttime;
	output combine;
end;
else if stage="portal" then do;
	portal_min=runmin;
	portal_date=rundt;
	portal_time=starttime;
	output portal;
end;
else if stage="member" then do;
	member_min=runmin;
	member_date=rundt;
	member_time=starttime;
	output member;
end;
else if stage="labclme" then do;
	labclme_min=runmin;
	labclme_date=rundt;
	labclme_time=starttime;
	output labclme;
end;
run;
%*SASDOC----------------------------------------------------------------------
| Combine and Output Data                                   
+----------------------------------------------------------------------SASDOC*;


data clientcomparison ;
length client $10. month $6. ;
merge a
	a2
	b1
	b
	b2
	c
	d
	e
	f
	g
	h
	i
	ii
	j
	k
	kk
	l
	m
	n
	o
	p
portal
member
combine
labclme
nruns;
client="&client";
month=put(today(), yymmn6.);
format member_date labclme_date combine_date portal_date mmddyy10.
 member_time labclme_time combine_time portal_time time.;
run;



proc print data=clientcomparison label;
run;




proc append data=clientcomparison base=hist.client_comparison force; 
run;

%mend; 

/*%global sdate;*/
/*%global edate;*/
/*%global repyr;*/
/**/
/*/*%clientcompare(client=OHG);*/ *waiting on portal dates set to be created;*/
/*%let sdate = '01nov2009'd;*/
/*%let edate = '01nov2010'd;*/
/*%let repyr = Nov 1, 2009 - Nov 1 2010;*/
/**/
/*/*%clientcompare(client=NSAP);*/ */
/*/*%clientcompare(client=STLUKES);*/*/
/*%clientcompare(client=EXEMPLA);*/
/*%let sdate = '01apr2010'd;
%let edate = '01apr2011'd;
%let repyr = Nov 1, 2009 - Nov 1 2010;*/

/*%clientcompare(client=PHS);*/
/*%clientcompare(client=ADVENTIST);*/
/*%let client=OHG;
%LET CLIENT=EXEMPLA;
%let client=PHS;
%let client=ADVENTIST;*/
