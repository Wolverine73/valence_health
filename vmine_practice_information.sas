
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_practice_information
|
| location: M:\CI\programs\StandardMacros
|
| purpose:    
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
+-----------------------------------------------------------------------HEADER*/

%macro vmine_practice_information;

	proc sql noprint;
	 create table  vmine_new_practices as
	 select clientname, systemname, practiceid, practicename, count(*) as count
	 from vmine_pmsystem_information 
	 group by clientname, systemname, practiceid, practicename
	 having count = 1;
	quit;
	
	proc sql noprint;
	 select count(*) into: vmine_new_practices_cnt
	 from vmine_new_practices;
	quit;

	options ls=150 ps=60 nomprint;
	
	%if &vmine_new_practices_cnt. ne 0 %then %do;

		data _null_;
		  set vmine_new_practices end=eof;
		  if _n_ =1 then put  "WARNING: *************************************************************";
		  if _n_ =1 then put  "WARNING: New Practices: ";
		  if _n_ =1 then put  "WARNING: ";
		  put  "WARNING: " _n_ clientname systemname practiceid practicename  ;
		  if eof then put  "WARNING: *************************************************************";
		run;
	
	%end;
	
	data _null_;
	  set vmine_practice_information end=eof;
	  cur_month = put(today(),$yymmn.);
	  date=datepart(DateEntered);
	  month=put(date,yymmn.);
	  if month = cur_month then flag='OK';
	  if _n_ =1 then put "NOTE: *************************************************************";
	  if _n_ =1 then put "NOTE: Monthly Practices - processed and missing data: ";
	  if _n_ =1 then put "NOTE:  ";
	  if flag='OK' then  put  "NOTE: " _n_ clientname systemname practiceid practicename @95 DateEntered;
	  else put  "WARNING: " _n_ clientname systemname practiceid practicename @95 DateEntered;
	  if eof then put  "NOTE: *************************************************************";
	run;
	

	
	options ls=150 ps=60 mprint;

%mend vmine_practice_information;
