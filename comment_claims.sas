
%macro comment_claims(client=);

%if "&client."= "NSAP" or "&client."= "nsap" or "&client."= "Nsap"%then %do;
	LIBNAME memfmt "M:\&client.\sasdata\ci\CIETL\Member";
%end;
%else %if "&client."=Adventist  %then %do;
	LIBNAME memfmt "M:\adventist\sasdata\CIETL\Members\CIO";
%end;
%else %if "&client" = "OHG"  %then %do;
	libname memfmt "M:\OHG\SASTEMP\CIprocess\Payer\";
%end;
%else %do;
	LIBNAME memfmt "M:\&client.\sasdata\CIETL\Member";
%end;

libname parm '\\ebicompute\projects\Tools\parms';
libname in3 "\\ebicompute\projects\&client.\data";
%include "M:\dw\Formats\programs\ssn_memberid_fmt.sas";

title "Provider Comments";
*Add provider comments;

%if "&client" = "Adventist"  or "&client."= "ADVENTIST" or "&client."= "adventist" or "&client." = "OHG"  %then %do;
%put these formats are already created for AHN;
%end;
/**/
%else %do;

data Member_dob;
LENGTH FMTNAME $10. TYPE $1. start $10. label 8.;
set memfmt.member (keep = memberid dob);
KEEP START LABEL TYPE FMTNAME ;
if dob NE . then do;
start = cats(memberid);
label = dob;
output;
end;
RETAIN FMTNAME 'Member_dob'  TYPE 'C';
	if _n_ = 1 then do;
		start = "";
		label = "";
		output;
	end;
	run;

	data Member_sex;
		LENGTH FMTNAME $10. TYPE $1 label $1. start $10.;
	  set memfmt.member (keep = memberid sex);
	   KEEP START LABEL TYPE FMTNAME ;
	  RETAIN FMTNAME 'Member_sex'  TYPE 'C';
	  if memberid NE "" then do;
	    start = cats(memberid);
		label = cats(sex);
		output;
	  end;
	  if _n_ = 1 then do;
	   start = "";
	   label = "U";
	   output;
	  end;
	run;


	proc sort data=Member_dob nodupkey;
	where start ne "";
	by start;
	run;

	proc print data= Member_dob(obs=50);
	title2 "Member DOB Format";
	run;
	proc format cntlin= Member_dob ;
	run;
	proc contents data= Member_dob ;
	run;

	*Member sex format;

	proc sort data=member_sex;
	where start ne "";
	by start label;
	run;

	proc sort data=Member_sex out= Member_sex nodupkey;
	by start;
	run;
	proc print data= Member_sex(obs=50);
	title2 "Member Sex Format";
	run;
	proc format cntlin= Member_sex ;
	run;
	proc contents data= Member_sex ;
	run;
/*%end;*/

proc contents data = parm.adventist_guideline_test; run;
%end;
*GUIDELINES COMPLIANT TEST format;

data compfmt (keep = fmtname type start label);
set parm.&client._guideline_test (rename=majcat=_majcat);
length start $27. proccd $5. diag1 $6. pos referral $2. majcat $2.;

guidelinekey=cats(put(guideline_key, $12.));
testkey=cats(put(test_key, $12.));

proccd = cats(proc_code);
diag1 = cats(diag_code);
pos = cats(pos);
referral = cats(provspec);
majcat = cats(_majcat);

length fmtname $7. type $1. start $10. label $25.;

start = cats(guidelinekey) ||"||"|| cats(testkey);
label = proccd || "||" || diag1 || "||" || referral || "||" || pos || "||" || majcat;

retain fmtname "compfmt" type "C";
output compfmt;
if _n_ = 1 then do;
	start = "OTHER";
	label = "     ||      ||  ||  ||  ";
	output compfmt;
end;
run;

proc sort data=compfmt nodupkey;
by start;
run;

proc format cntlin = compfmt; run;

proc print data=compfmt;
title2 "Compliant Format";
run;

proc contents data = compfmt; run;

%if "&client" = "OHG"  %then %do;
proc sort data = in3.membercompliant_clean(where = (comment_key = 2)) out = compliant;
by memberid pcpid test_key test_date submitted_date;
run;
%end;
%else %do;
proc sort data = in3.membercompliant(where = (comment_key = 2)) out = compliant;
by memberid pcpid test_key test_date submitted_date;
run;
%end;

data compliant2;
set compliant;
by memberid pcpid test_key test_date;
if last.test_date;
run;

data compliant3(keep = proccd provspec dob sex source svcdt provid memberid test_key diag1 pos referral test_date majcat);
set compliant2;
length 	dob test_date 8. memberid $9. provid $10.  sex $1. proccd $5. diag1 $6. source $1.
		provspec referral pos $2.  majcat 3.; 
format dob test_date mmddyy10. ;

rename test_date = svcdt;
provid = substr(pcpid,1,10);
provspec = put(provid,$provspec.);
if put(provid,$provname.) ne provid then provname = put(provid,$provname.);
else provname = '';
if put(memberid,$Member_sex.) ne substr(memberid,1,1) then sex = put(memberid,$Member_sex.);
else sex = 'U';
guidelinekey=cats(put(guideline_key, $12.));
testkey=cats(put(test_key, $12.));
key=cats(guidelinekey) ||"||"|| cats(testkey);
dob = put(memberid,$Member_dob.);
proccd = cats(substr(put(key,$compfmt.),1,5));


diag1= cats(substr(put(key,$compfmt.),8,6));
referral = cats(substr(put(key,$compfmt.),16,2)); 
pos = cats(substr(put(key,$compfmt.),20,2));
majcat = cats(substr(put(key,compfmt.),24,2)) *1;
source = "C";

 run;

proc print data = compliant3; 
title2 "Compliant Dataset";
run;
proc contents data = compliant3; run;

proc freq data=compliant3;
table provid*provspec memberid sex dob svcdt proccd diag1 referral pos majcat/list missing;
format memberid $memberid. dob year4. svcdt yymmn6.;
run;

%mend;
