
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_information.sas
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
| 01APR2010 - Brian Stropich  - Clinical Integration  1.0.01
|             Original           
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_information;

	proc sql;
      create table vmine_pmsystem_information as
	  select a.transmissionid,a.practiceid,a.clientid,
	  a.clientname,
      a.name as practicename,
	  a.versionid,a.receiveddate as dateentered,
	  b.directorypath as systemname,
	  b.systemid,
	  c.enabled
      from ids.datalist a left outer join ids.version b
	  on a.versionid = b.versionid left outer join ids.datasource c
        on a.practiceid=c.datasourceid
        and a.clientid=c.clientid
      where a.clientid  = &client_id.  
	    and b.systemid  = &system_id.
		%if &practice_id ne %then %do;
		  and a.practiceid = &practice_id.
		%end;
	   /** and c.enabled = 1   bss- commented out for termed practices **/
      order by a.practiceid;
    quit;

	proc sort data = vmine_pmsystem_information;
	  by practiceid descending dateentered;
	run;

	proc sort data = vmine_pmsystem_information
	           out = vmine_practice_information nodupkey;
	  by practiceid ;
	run;    

  %*SASDOC--------------------------------------------------------------------------
  | View Condition indicator    
  |
  | The indicator determines the different versions of PM Systems available     
  | within vMine.  This allows the view code to determine what SQL Server view 
  | to utilize when extracting the data.
  ------------------------------------------------------------------------SASDOC*;     
   data vmine_practice_information ;
     format subfolder $50. ;
     set vmine_practice_information ;
     view_condition=0;
	/* if clientid = 4 then do; */
        subfolder=systemname; 
/*	 end;
	 else do;
        subfolder=scan(filepath,5,'\');  
	 end;*/
	 if upcase(systemname)='MEDISOFT16' or versionid = 154 then do;
	   subfolder='Medisoft';
	   view_condition=1;
	 end;
	 else if upcase(systemname)='LYTEC2010' or versionid = 155 then do;
	   subfolder='Lytec';
	   view_condition=1;
	 end;
	 else if upcase(systemname)='ALTAPOINT8' then do;
		subfolder='AltaPoint';
		view_condition=1;
	 end;
	 else if upcase(systemname)='APRIMA2011' or versionid = 453 then do;
		subfolder='iMedica';
		view_condition=1;
	 end;
   run;  

	options ls=150 ps=60 mprint;
	
	data _null_;
	  set vmine_practice_information end=eof;
	  cur_month = put(today(),yymmn.);
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
	
	%global system subfolder enabled;

	data _null_;
	  set vmine_practice_information (obs=1 keep=systemname subfolder enabled); 
	  call symput('system',trim(systemname)); 
	  call symput('subfolder',trim(left(subfolder)));
	  call symput('enabled',trim(left(enabled)));
	  /**call symput('versionid',trim(left(versionid)));**/
	run;

	proc sql noprint;
	  select practiceid into: practice_id separated by " "
	  from vmine_practice_information;
	quit;

	%put NOTE: practice_id = &practice_id. ;
	
%mend vmine_pmsystem_information;


