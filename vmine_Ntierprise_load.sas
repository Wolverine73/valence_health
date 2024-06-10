
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_Ntierprise_load
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from lytec vmine view  
|
| logic:    
|           1.  Extract all non-termed practices for the client and PM system  
|           2.  Determine if the loop needs to execute for one or all practices 
|           3.  Loop through the practices                                      
|           4.  Determine and extract only claims that exceed the maximum process ID 
|           5.  Concatenate the results to the previous month of claims         
|           6.  Remove duplicate values and keep most recent updated claims     
|           7.  Save the practice data set for the client on SAS2                 
|
| input:    Macro parameters and /or SQL server practices     
|                        
| output:   Practice datasets for the client and PM system 
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
| 08APR2009 - Valence Health  - Clinical Integration  1.0.02
|             Added patient address fields
|             
| 01JAN2010 - Brian Stropich  - Clinical Integration  1.0.03
|             1.  Added the sasautos option within the process
|             2.  Added the dq_report macro within the program
|             3.  Added header and comments throughout the program
|             4.  Removed and relocated the last_file_check within the 
|                 Standard Macro folder and will be referenced with sasautos
|             5.  Moved all macro calls at the bottom of the program
|
| 29APR2010 - Winnie Lee - Clinical Integration 1.0.04
|			  1.  Update source of data from vMine text files to SQL Server
|             
+-----------------------------------------------------------------------HEADER*/


*SASDOC--------------------------------------------------------------------------
| Initialize the environment for the program
------------------------------------------------------------------------SASDOC*; 
options sasautos = ("M:\CI\programs\StandardMacros" sasautos);
options mprint nomlogic nosymbolgen msglevel=i error=2 ls=120 ps=60;
%include "M:\dw\Formats\ssn_memberid_fmt.sas";
libname fmt "M:\dw\Formats";

/*
%oledb_init_string;
libname vmine  oledb init_string=&vmine. preserve_tab_names=yes;
*/


*SASDOC--------------------------------------------------------------------------
| Macro -  vmine_loop      
|
| Process a practice data file for a particular client
------------------------------------------------------------------------SASDOC*; 
%macro vmine_ntierprise_load(system_id=, client_id=, client=, practice_id=);

	%vmine_libnames;

	ods listing close;	

	*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	------------------------------------------------------------------------SASDOC*;	
	%macro lib;
		%if %upcase(&client) = NSAP %then %do;
			data _null_;
			  call symput('out',"M:\&client\sasdata\CI\CIETL\claims\vMine\ntierprise"); 
			run;
		%end; 
		%else %do;
			data _null_;
			  call symput("out","M:\&client\sasdata\CIETL\Claims\vMine\ntierprise"); 
			run;
		%end;
	%mend;
	%lib;

	libname out1 "&out." ;

	proc format cntlin=fmt.diag5cd; 
    run;

	proc format cntlin=fmt.procfmt; 
    run;

	%*SASDOC--------------------------------------------------------------------------
	| Determine the practice IDs which need to be processed for the client 
	| and PM System from vMine SQL Server
	------------------------------------------------------------------------SASDOC*;
	proc sql;
      create table vmine_parms as
      select distinct 
        b.practiceid,  
        b.name as practicename, 
        c.clientid, 
        c.clientname, 
        d.versionid, 
        e.name as systemname, 
        e.systemid
      from vmine.ExtractedFileList a
	    inner join vmine.Practice  b on a.practiceid=b.practiceid
	    inner join vmine.Client    c on b.clientid=c.clientid 
	    inner join vmine.Version   d on a.versionid=d.versionid
	    inner join vmine.System    e on d.systemid=e.systemid
      where c.clientid  = &client_id.  
	    and e.systemid  = &system_id.
		%if &practice_id ne %then %do;
		  and b.practiceid = &practice_id.
		%end;
	    and b.Termed = 0 
      order by b.practiceid;
    quit;

	data _null_;
	  set vmine_parms;
	  put  "NOTE: " _n_ clientname systemname practiceid practicename;
	run;

	data _null_;
	  set vmine_parms (obs=1 keep=systemname); 
	  call symput('system',trim(systemname)); 
	run;

	proc sql noprint;
	  select practiceid into: practice_id separated by " "
	  from vmine_parms;
	quit;

	%put NOTE: practice_id = &practice_id. ;

	%vmine_practice_information;

	%let dopid =0;
	%do %while (%scan(&practice_id., &dopid+1) ne );  /**begin do_practice_id **/

		%let dopid  =%eval(&dopid+1);
		%let do_practice_id=%scan(&practice_id.,&dopid);


		%*SASDOC--------------------------------------------------------------------------
		| Determine maximum process ID for extracting data from the view
		|
		| Logic:
		|   1.  Validate that a dataset exist for the practice
		|   2.  Validate if a maximum process ID exists for the practice
		|   3.  If there is a valid maximum process ID assign it to maxprocessid
	    |   4.  If there is not a valid maximum process ID assign maxprocessid to 0
	    |       and pull a complete history of the practice data from the view 
		------------------------------------------------------------------------SASDOC*;
		%if %sysfunc(exist(out1.claims_&do_practice_id.))=1 %then %do ;  
	  
		  proc contents data = out1.claims_&do_practice_id. 
	                    out  = contents_claims (keep = name) noprint;
		  run;

		  proc sql noprint;
		    select count(*) into: maxprocessid_exist
		    from contents_claims
		    where lowcase(name) = 'maxprocessid';
		  quit;

		  %put NOTE: maxprocessid_exist = &maxprocessid_exist. ; 

		  %if &maxprocessid_exist = 1 %then %do;

			  proc sql noprint;
			    select max(maxprocessid) into: maxprocessid
			    from out1.claims_&do_practice_id. ;
			  quit;

			  %if &maxprocessid = . %then %let maxprocessid = 0;

		  %end;
		  %else %do;
		      %let maxprocessid = 0;
		  %end;
	    %end;
	    %else %do; 
	      %let maxprocessid = 0;
	    %end;

	 	%put NOTE: maxprocessid = &maxprocessid. ; 


		%*SASDOC--------------------------------------------------------------------------
		| Connect to SQL Server to retreive the practice data from the PM System view
		------------------------------------------------------------------------SASDOC*; 
		proc sql;
		  connect to oledb(init_string=&emine.);
		  create table practice_&do_practice_id. as select * from connection to oledb
		  (	
			select  *	               
			from    dbo.tstntierprise
			where kpracticeid = &do_practice_id.
			  and proccd <> ''
			  and maxprocessid > &maxprocessid. 

		   order by memberid, lname, fname, dob2, svcdt2 desc, proccd desc, 
                          mod1, createdt2, units desc, linenum desc
		  );
		quit;

	%vmine_view_&system_id.;

				proc sql noprint; 
		  select distinct(MaxProcessID) into: kprocessid separated by ","
		  from practice_&do_practice_id.;
		quit;

		%if %symexist(kprocessid) %then %do;   /**start - symexist - kprocessid **/

		%put NOTE: kprocessid = &kprocessid. ;

		proc sql;
		  connect to oledb(init_string=&emine.);
		  create table kprocessid_format as select * from connection to oledb
		  (	
			select kProcessID, filename	               
			from  dbo.KTBL_Process
			where kProcessID in (&kprocessid.)
		  );
		quit;

		data kprocessid_format;
		  set kprocessid_format; 
		  retain fmtname 'kprocessid'  type 'N';
		  length fmtname $10  type $1 label $100;	
		  start = kprocessid;
		  label = scan(filename,1,'.');
		  keep start label type fmtname;
		run;

		proc format cntlin=kprocessid_format;
		run; 


		%*SASDOC--------------------------------------------------------------------------
		| Perform cleaning and edits to the practice data
		------------------------------------------------------------------------SASDOC*;

		data practice_&do_practice_id. ;
		  format svcdt moddt dob createdt mmddyy10. system $30. units 8.2; 
		  set practice_&do_practice_id. ;			 

			%*SASDOC--------------------------------------------------------------------------
			| Reformat dates and dollars and other                       
			------------------------------------------------------------------------SASDOC*;	
			svcdt = datepart(svcdt2);
			moddt=datepart(moddt2);
			dob= datepart(dob2);
			createdt = datepart(createdt2);
			system="&system.";
			filename = put(MaxProcessID, kprocessid.);
			if address2="." then address2="";
			rename billamt = submit;

			%*SASDOC--------------------------------------------------------------------------
			| Diagnosis codes                                    
			------------------------------------------------------------------------SASDOC*;
		
			%*SASDOC--------------------------------------------------------------------------
			| Mod1 values                          
			------------------------------------------------------------------------SASDOC*;
			length md1 md2 $2.;
			md1 = substr(mod1,1,2);
			md2 = substr(mod1,4,5);
			drop mod1 mod2;
			rename md1=mod1
                   md2=mod2;


			%*SASDOC--------------------------------------------------------------------------
			| Genders                                 
			------------------------------------------------------------------------SASDOC*;
			sex = upcase(sex);
			if sex not in ('M','F') then sex = 'U';

			%*SASDOC--------------------------------------------------------------------------
			| Member ID                                 
			------------------------------------------------------------------------SASDOC*;
			if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';

			drop svcdt2 moddt2 dob2 createdt2 _proccd;
		run;

		%*SASDOC--------------------------------------------------------------------------
		| Remove duplicate claims - include maximum process ID to keep the latest   
	    | claims for the practice data
		------------------------------------------------------------------------SASDOC*; 
		%let byvars = %str(linenum svcdt);

		proc sort data=practice_&do_practice_id.;
		  by &byvars.;
		run;

		%*SASDOC--------------------------------------------------------------------------
		| Append new practice claims to existing practice claims from the prior 
		| execution and retain the sorting order of the dataset
		------------------------------------------------------------------------SASDOC*;
		%if &maxprocessid ne 0 %then %do; 

			proc sort data=out1.claims_&do_practice_id.;
			  by &byvars.;
			run;
	 
			data practice_&do_practice_id. (sortedby = &byvars.);
			  set out1.claims_&do_practice_id.
			      practice_&do_practice_id.   ;
			  by &byvars.;
			run;
	      
	    %end;

		%*SASDOC--------------------------------------------------------------------------
		| Create output dataset of the practice data
		------------------------------------------------------------------------SASDOC*; 
		data out1.claims_&do_practice_id. 
			 dups ;  
		  set practice_&do_practice_id.;
		  by  &byvars.; 

		  if first.svcdt and last.svcdt then dupcount=.;
		  else if first.svcdt then dupcount =0 ;
		  else dupcount = 1;
		  if first.svcdt then output out1.claims_&do_practice_id.;
		  if dupcount ne . then output dups;
		run;

		proc sql noprint;
		 select count(*) into: issue_count
		 from out1.claims_&do_practice_id. ;
		quit;

		%if &issue_count eq 0 %then %do;
		  %put ERROR: There are 0 observations within out1.claims_&do_practice_id. ;
		%end;
		%else %do;
		  proc datasets lib=work kill nolist ;
		  run;
		  quit;

		%end;

	%end;  /**end do_practice_id **/

%mend vmine_ntierprise_load;


*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
%vmine_ntierprise_load(system_id=11, client_id=5, client=PHS ); 
%vmine_ntierprise_load(system_id=11, client_id=1, client=Adventist ); 














