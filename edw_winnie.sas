
options mlogic mprint ;
%include "M:\CI\programs\StandardMacros\edw_linking_macros.sas";

libname temp  "F:\SASWORK\bstropich\SAS Temporary Files\temp";
libname fmt   "M:\dw\Formats";
libname score "M:\NSAP\sasdata\CI\CIETL\member";


proc format cntlin=fmt.NickName; 
run;

proc format cntlin=fmt.fnameGender; 
run;

proc format cntlin=fmt.zipcodes; 
run;

proc format cntlin=score.mscore; 
run;

data PRIMARY (drop=_memaddress1 _memzip _memlname _memfname _memphone _memcity);
length block $10.;
length memAddress1 $50. memzip $5. memlname $25. memfname $15. memphone $10. memcity $25.; 
set temp.PRIMARY (rename = (memAddress1=_memAddress1 memzip=_memzip memlname=_memlname memfname=_memfname memphone=_memphone memcity=_memcity));
block = "PRIMARY";
memAddress1 = _memAddress1;
memzip = _memzip;
memlname = _memlname;
memfname = _memfname;
memphone = _memphone;
memcity = _memcity;
run;

data PRIMARY2 (keep=matchscore ageR weight1-weight7 dob memdob block rid member_key);
set PRIMARY;
%thecleaner(mem);											
%compare;
run;

data secondary (drop=_memaddress1 _memzip _memlname _memfname _memphone _memcity);
length block $10.;
length memAddress1 $50. memzip $5. memlname $25. memfname $15. memphone $10. memcity $25.; 
set temp.SECONDARY (rename = (memAddress1=_memAddress1 memzip=_memzip memlname=_memlname memfname=_memfname memphone=_memphone memcity=_memcity));
block = "SECONDARY";
memAddress1 = _memAddress1;
memzip = _memzip;
memlname = _memlname;
memfname = _memfname;
memphone = _memphone;
memcity = _memcity;
run;

data SECONDARY2 (keep=matchscore ageR weight1-weight7 dob memdob block rid member_key);
set SECONDARY;
%thecleaner(mem);											
%compare;
run;

data TERTIARY (drop=_memaddress1 _memzip _memlname _memfname _memphone _memcity);
length block $10.;
length memAddress1 $50. memzip $5. memlname $25. memfname $15. memphone $10. memcity $25.; 
set temp.TERTIARY (rename = (memAddress1=_memAddress1 memzip=_memzip memlname=_memlname memfname=_memfname memphone=_memphone memcity=_memcity));
block = "TERTIARY";
memAddress1 = _memAddress1;
memzip = _memzip;
memlname = _memlname;
memfname = _memfname;
memphone = _memphone;
memcity = _memcity;
run;

data TERTIARY2 (keep=matchscore ageR weight1-weight7 dob memdob block rid member_key);
set TERTIARY;
%thecleaner(mem);											
%compare;
run;


data MatchMaker2 (keep = RID matchscore member_key);
length block $10.;
set primary 
	secondary 
	tertiary;

%thecleaner(mem);											
%compare;

if matchscore ge ((put(put(ageR,$5.),$mscore.))*1) then do;
	if (weight2 lt 0) and (weight6 lt 0) and (abs(dob-memdob) gt 30) then delete;
	else if block = "PRIMARY" and matchscore gt sum(weight4,weight6,weight7) then output;
	else if block = "SECONDARY" and matchscore gt sum(weight4,weight5,weight7) then output;
	else if block = "TERTIARY" and matchscore gt sum(weight1,weight4,weight7) then output;
end;
run;


data MatchMaker1 (keep = RID matchscore member_key);
length block $10.;
set primary2 
	secondary2 
	tertiary2;
if matchscore ge ((put(put(ageR,$5.),$mscore.))*1) then do;
	if (weight2 lt 0) and (weight6 lt 0) and (abs(dob-memdob) gt 30) then delete;
	else if block = "PRIMARY" and matchscore gt sum(weight4,weight6,weight7) then output;
	else if block = "SECONDARY" and matchscore gt sum(weight4,weight5,weight7) then output;
	else if block = "TERTIARY" and matchscore gt sum(weight1,weight4,weight7) then output;
end;
run;
