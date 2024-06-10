
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  clinical_integration_execute.sas
|
| LOCATION: 
|
| PURPOSE:  
|
| LOGIC:    
|
| INPUT:           
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             Created and updated Code to Business Requirements Specifiation for NSAP
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro clinical_integration_execute;

data _null_;
     call symput('this_mon',"'"||put(month(today()),z2.)||"'");
     call symput('this_day', "'"||put(day(date()),z2.)||"'");
     call symput('this_wkday', "'"||put(weekday(date()),1.)||"'");
run;

%put NOTE: THIS_MON = &THIS_MON, THIS_DAY = &THIS_DAY, THIS_WKDAY = &THIS_WKDAY. ;

/***
data ciref.clinical_integration_schedule;
set ciref.clinical_integration_schedule;
if stepid in (1,2) then schedule_day='06';
if stepid in (3) then schedule_day='07,99';
else schedule_day='99';
run;

data ciref.clinical_integration_step;
set ciref.clinical_integration_step;
if taskid in (2) then schedule_day='07'; 
else schedule_day='99';
run;
***/

proc sql;
  create table job_4_today as
  select * 
  from  ciref.clinical_integration_schedule
  where (      ( index(schedule_weekday, &this_wkday)> 0 or compress(schedule_weekday)='*')
           and ( index(schedule_day, &this_day)      > 0 or compress(schedule_day)='*')
           and ( index(schedule_month, &this_mon)    > 0 or compress(schedule_month)='*' ))
  and scheduleid = 1
  and clientid = &vmine_client_id. ;
quit;

proc sql noprint;
 select count(*) into: ci_stepid
 from job_4_today
 where ci_stepid = 1;
quit;

%put NOTE: CI Step Dataset Count = &ci_stepid. ;

%if &ci_stepid ne 0 %then %do;
	proc sql;
	  create table job_step_4_today as
	  select b.* 
	  from  job_4_today a,
            ciref.clinical_integration_step b
	  where (      ( index(b.schedule_day, &this_day)      > 0 or compress(b.schedule_day)='*')
	           and ( index(b.schedule_month, &this_mon)    > 0 or compress(b.schedule_month)='*' ))
	  and b.scheduleid = 1
	  and b.clientid = &vmine_client_id. 
      and a.clientid=b.clientid
      and a.stepid=b.stepid ;
	quit;
%end;

data job_4_today;
  set job_4_today;
  macro_name='%'||left(trim(scan(program_name,1,'.')))||";";
run;

proc sql noprint;
  select step_description, count(*) into :step_programs separated by ", " , :step_counts
  from job_4_today ; 
quit;

%put NOTE: STEP_PROGRAMS: &STEP_PROGRAMS. ;
%put NOTE: STEP_COUNTS: &STEP_COUNTS;

%if &step_counts = 0 %then %do;
  %put NOTE: No Steps to execute for client. ;
  data for_notes; 
    x=1; 
  run;
%end;
%else %do;
   data _null_;
      set job_4_today  end=eof;
      i+1;
      ii=left(put(i,4.));
      call symput('stepmacros'||ii,trim(macro_name));
      if eof then call symput('stepmacros_total',ii);
   run;
   
   %put NOTE: Beginning Steps to execute for client. ;
   
   %do step = 1 %to &stepmacros_total. ;
   
     &&stepmacros&step  
   
   %end;
   
   %put NOTE: Steps are complete for client. ;

%end;

%mend clinical_integration_execute;





 



