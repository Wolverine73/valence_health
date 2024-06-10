
%macro multiple_attribution;

Data elig_dt1 (keep= memberid provid svcdt );
set g1;
if provspec not in (&rank1. &rank2. &rank3.) then delete;
if put(provid,$provyn.) = "Y" and source = "P";
%if "&client."="NSAP" or "&client."="nsap"  %then %do;
	if put(provid, $provtype.) in ("P", "V");
%end;

if &var. ge 1;
run;

proc sort data = elig_dt1 out=elig_dt2 nodupkey;
by memberid provid svcdt ;
run;

data elig_dt3;
set elig_dt2;
by memberid provid svcdt ;
if last.provid and last.svcdt;
rename provid = pcpid;
run;

proc summary data=g1 nway missing;
class memberid svcdt provid provspec;
where &var. ge 1 and put(provid,$provyn.) = "Y" and source = "P" and provspec in (&rank1. &rank2. &rank3.)
%if "&client."="NSAP" or "&client."="nsap"  %then %do;
	and put(provid, $provtype.) in ("P", "V");
%end;

;
var &var. ;
output out = elig1 (drop=_type_ _freq_) sum=;
run;

Data elig2;
set elig1;
&var. = 1;
rename provid = pcpid;
run;
proc summary data=elig2 nway missing;
class memberid pcpid provspec;
var &var. ;
output out = elig3 (drop=_type_ _freq_) sum=;
run;

proc sort data=Elig_dt3;
by memberid pcpid;
run;
proc sort data=elig3;
by memberid pcpid;
run;

Data elig4;
merge elig3 (in=a) Elig_dt3 (in=b);
by memberid pcpid;
if a;
pcp1=pcpid;
*if a or b;
*if pcpid = pcp2 then match = 1;
*else match = 2;
run;

proc sort data=elig4;
by memberid provspec descending &var. descending svcdt;
run;

Data elig5;
set elig4;
by memberid provspec descending &var. descending svcdt; 
if first.provspec;
run;

%mend multiple_attribution;

