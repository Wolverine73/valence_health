
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_medisoft_load.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from medisoft vmine view  
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
|             1.  Update source of data from vMine text files to SQL views
|             
+-----------------------------------------------------------------------HEADER*/


*SASDOC--------------------------------------------------------------------------
| Macro -  vmine_loop      
|
| Process a practice data file for a particular client
------------------------------------------------------------------------SASDOC*; 
%macro vmine_medisoft_load(system_id=, client_id=, client=, practice_id=);

	ods listing ;	
	
	%*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	------------------------------------------------------------------------SASDOC*;	
	%macro lib;
	  %if %upcase(&client) = NSAP %then %do;
		data _null_;
		call symput('out',"M:\&client\sasdata\CI\CIETL\claims\vMine\Medisoft");
		run;
	  %end; 
	  %else %do;
		data _null_;
		call symput('out',"M:\&client\sasdata\CIETL\Claims\vMine\Medisoft");
		run;
	  %end;
	%mend lib;
	%lib;

	%let out = M:\CI\programs\CIO\Temp;
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
        e.name as systemname, 
        e.systemid
      from vmine.ExtractedFileList a
	    inner join vmine.practice  b on a.practiceid=b.practiceid
	    inner join vmine.client    c on b.clientid=c.clientid 
	    inner join vmine.version   d on a.versionid=d.versionid
	    inner join vmine.system    e on d.systemid=e.systemid
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

	%let dopid =0;
	%do %while (%scan(&practice_id., &dopid+1) ne );  /**begin do_practice_id **/

		%let dopid  =%eval(&dopid+1);
		%let do_practice_id=%scan(&practice_id.,&dopid);
    

		%*SASDOC--------------------------------------------------------------------------
		| Determine maximum process ID for extracting data from the view
		|  
		| Logic:
		| 1.  Validate that a dataset exist for the practice
		| 2.  Validate if a maximum process ID exists for the practice
		| 3.  If there is a valid maximum process ID assign it to maxprocessid
		| 4.  If there is not a valid maximum process ID assign maxprocessid to 0
		|     and pull a complete history of the practice data from the view      
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
			select *	               
			from    dbo.tstMedisoftView
			where kpracticeid = &do_practice_id.
			  and diag1   <> ''
			  and submit2 >= 0
			  and proccd  <> ''
			  and substring(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9')
			  and maxprocessid > &maxprocessid.
			order by memberid, svcdt2, lname, fname, dob2, _proccd, mod1, maxprocessid desc,
                     linenum desc, mod2, units, submit2, payorname1, diag1, diag2, diag3, claimnum desc
		  );
		quit;

		proc sql noprint; 
		  select distinct(MaxProcessID) into: kprocessid separated by ","
		  from practice_&do_practice_id.;
		quit;

		%if %symexist(kprocessid) %then %do;   /**start - sysmexist - kprocessid **/

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
		  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $40.;
		  set practice_&do_practice_id. ;		  	

			%*SASDOC--------------------------------------------------------------------------
			| Reformat dates and dollars and other                        
			------------------------------------------------------------------------SASDOC*;
			svcdt=datepart(svcdt2);
			createdt=datepart(createdt2);
			moddt=datepart(moddt2);
			dob=datepart(dob2);
			submit=submit2;
			system="&system.";
			filename=put(MaxProcessID, kprocessid.);

			%*SASDOC--------------------------------------------------------------------------
			| Missing values for variables                                
			------------------------------------------------------------------------SASDOC*;
			if mname='.' then mname="";
			if pos='.' then pos="";
			if address1='.' then address1="";
			if address2='.' then address2="";
			if state='.' then state="";

			%*SASDOC--------------------------------------------------------------------------
			| Practice reformat - proccd diags payorname      
			------------------------------------------------------------------------SASDOC*;
			if kpracticeid = 256 then do;
				if length(_proccd) = 6 then do;
				  proccd = upcase(compress(trim(substr(_proccd,2,5)),'.'));
				end;
			    else do;
				  proccd = upcase(compress(trim(substr(_proccd,1,5)),'.'));
				end;
			end;
			else do;
			  proccd = upcase(compress(trim(substr(_proccd,1,5)),'.'));
			end;

			if kpracticeid in (274,270) then do;
				diag1=compress(cats(diag1),'.');
				if length(diag1)=5 then do;
				  diag1=substr(diag1,1,3) || "." || substr(diag1,4,2) ;
				end;
				else if length(diag1)=4 then do;
				  diag1=substr(diag1,1,3) || "." || substr(diag1,4,1) ;
				end;
				else if length(diag1)le 3 then do;
				  diag1=substr(diag1,1,3);
				end;

				diag2=compress(cats(diag2),'.');
				if length(diag2)=5 then do;
				  diag2=substr(diag2,1,3) || "." || substr(diag2,4,2) ;
				end;
				else if length(diag2)=4 then do;
				  diag2=substr(diag2,1,3) || "." || substr(diag2,4,1) ;
				end;
				else if length(diag2)le 3 then do;
				  diag2=substr(diag2,1,3);
				end;

			    diag3=compress(cats(diag3),.);
				if length(diag3)=5 then do;
				  diag3=substr(diag3,1,3) || "." || substr(diag3,4,2) ;
				end;
				else if length(diag3)=4 then do;
				  diag3=substr(diag3,1,3) || "." || substr(diag3,4,1) ;
				end;
				else if length(diag3)le 3 then do;
				  diag3=substr(diag3,1,3);
				end;

				diag4=compress(cats(diag4),.);
				if length(diag4)=5 then do;
				  diag4=substr(diag4,1,3) || "." || substr(diag4,4,2) ;
				end;
				else if length(diag4)=4 then do;
				  diag4=substr(diag4,1,3) || "." || substr(diag4,4,1) ;
				end;
				else if length(diag4)le 3 then do;
				  diag4=substr(diag4,1,3);
				end;
			end; 
			else if kpracticeid = 295 then do;
			    if diag1 = 'V0381' then diag1 = 'V03.81';
			    if diag2 = 'V0381' then diag2 = 'V03.81';
			    if diag3 = 'V0381' then diag3 = 'V03.81';
				if diag4 = 'V0381' then diag4 = 'V03.81';
			end;
			else if kpracticeid = 31 then do;
				if tin in ('','.') then tin='364032157';
			end;
			else if kpracticeid =37 then do;
				if tin in ('','.') then tin='200587989';
			end;
			else if kpracticeid = 42 then do;
				 if payorid1='CCN'   then payorname1='CCN';
				else if payorid1='HCI'   then payorname1='HCI';
				else if payorid1='IAC'   then payorname1='IAC';
				else if payorid1='SAMBA' then payorname1='SAMBA';
				else if payorid1='UMR'   then payorname1='UMR';
			end;
			else if kpracticeid = 62 then do;
			    if payorid1='CCMSI' then payorname1='CCMSI';
			end;
			else if kpracticeid = 92 then do;
				if payorid1='MMSI' then payorname1='MMSI';
			    else if payorid1='PAI'  then payorname1='PAI';
			end;

			%*SASDOC--------------------------------------------------------------------------
			| Diags       
			------------------------------------------------------------------------SASDOC*;
			if diag1="     ." then diag1 = "";
			if diag2="     ." then diag2 = "";
			if diag3="     ." then diag3 = "";
			if diag4="     ." then diag4 = "";
			if index(diag1,'.')=4 and substr(diag1,5,2)="" then diag1=compress(diag1,'.');
			if index(diag2,'.')=4 and substr(diag2,5,2)="" then diag2=compress(diag2,'.');
			if index(diag3,'.')=4 and substr(diag3,5,2)="" then diag3=compress(diag3,'.');
			if index(diag4,'.')=4 and substr(diag4,5,2)="" then diag4=compress(diag4,'.');	

			%*SASDOC--------------------------------------------------------------------------
			| Mod       
			------------------------------------------------------------------------SASDOC*;
			mod1 = compress(cats(mod1),"'""+""`""[""]");
			mod2 = compress(cats(mod1),"'""+""`""[""]");
			if compress(mod1)='.' then mod1 = '';
			if compress(mod2)='.' then mod2 = '';
			pos	= compress(pos,"'""+""`""[""]");

			%*SASDOC--------------------------------------------------------------------------
			| Gender                                    
			------------------------------------------------------------------------SASDOC*;
			if sex not in ('F','M') then sex = 'U';

			%*SASDOC--------------------------------------------------------------------------
			| Member ID                                 
			------------------------------------------------------------------------SASDOC*;
			if memberid in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';


			%*SASDOC--------------------------------------------------------------------------
			| Client                          
			------------------------------------------------------------------------SASDOC*;
			%if &client_id. = 1 %then %do;
              provid=upin; /** Adventist **/
			%end;

			drop svcdt2 createdt2 moddt2 dob2 submit2;
		run;


		%*SASDOC--------------------------------------------------------------------------
		| Remove duplicate claims - include maximum process ID to keep the latest  
		| claims for the practice data
		------------------------------------------------------------------------SASDOC*;
		%let byvars = %str(memberid svcdt lname fname dob proccd mod1 descending maxprocessid
                           descending linenum mod2 units submit payorname1 diag1 diag2 
                           diag3 descending claimnum );

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
		| Create the final output dataset of the practice data and remove any
		| duplicates which may exist
		------------------------------------------------------------------------SASDOC*; 
		data out1.claims_&do_practice_id. (sortedby = &byvars.) 
			 dups                 ;
		  set practice_&do_practice_id.;
		  by &byvars.;

		  if first.mod1 and last.mod1 then dupcount=.;
		  else if first.mod1 then dupcount =0 ;
		  else dupcount = 1;
		  if first.mod1 then output out1.claims_&do_practice_id.;
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
		  %put WARNING:  Turn on work clean up once testing is complete ; 
		%end;

		%end;  /**end - sysmexist - kprocessid **/
    
	%end;  /**end do_practice_id **/

%mend vmine_medisoft_load;









