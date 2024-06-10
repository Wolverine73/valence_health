
/*HEADER------------------------------------------------------------------------
|
| program:  dq_report.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create data quality reports based on preassigned thresholds 
|
| logic:    The driver program for the data quality process
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
| 03SEP2010 - Winnie Lee  - Clinical Integration  1.0.02
|             Added subfolder PROGRAMS to the SSN and MEMBERID format program that gets called
|
| 03JAN2011 - Brian Stropich  - Clinical Integration  1.0.03
|             Removed other from diag5cd and procfmt formats
|
| 16FEB2011 - Winnie Lee - Clinical Integration 1.0.04
|			1. Update libname vMine to libname IDS
|			2. Update to call from IDS instead of vMine 
| 04MAR2011 - Nick Williams - Clinical Integration 1.0.05
|			1. Added quotation marks around sys_id macro variable
|			   so it can be resolved from vmine_xref_practice (when practiceid=11)
| 24AUG2011 - Nick Williams - Clinical Integration 1.0.05
|			1. For testing purposes I renamed the DQ REPORT so it doesnt overwrite 
|			   production reports.
|           2. Add New NPI Section (CI participation by NPI).
|           3. Add Claims Start Date variable to the report.
|           4. If input dataset is empty then abort the code.
+-----------------------------------------------------------------------HEADER*/

%macro dq_report(practice=, client=, pgf_practice=, 
                 practice_nm=,client_dir=,client_nm=,sys_id=, sys_nm=,
                 cioproject=);

	*SASDOC--------------------------------------------------------------------------
	| Initialize Options 
	+------------------------------------------------------------------------SASDOC*;
	options noxwait mprint nosymbolgen msglevel=i error=2 ls=100  ;
	%global status reportdir datasetin pdfname pdf_report_date;
	
	data _null_;
	  pdf_report_date = put(today(),yymmn.);
	  call symputx('pdf_report_date',pdf_report_date);
	run;
	
	%put NOTE:  PDF Report Date: &pdf_report_date.;
	
	%if &practice ne %then %let datasetin=%str(ci.claims_&practice.);
	%else %if &pgf_practice. ne %then %let datasetin=&pgf_practice.;
	%else %let datasetin=&syslast;

	%if &practice  = %then %let practice=0;	
	%let pdfname=%scan(&pgf_practice.,2,".");

	%put NOTE: datasetin = &datasetin. ;
	%put NOTE: practice  = &practice. ;
	%oledb_init_string;
	

	*SASDOC--------------------------------------------------------------------------
	| Assign Libnames       
	+------------------------------------------------------------------------SASDOC*;
	libname dwfmt    "M:\DW\Formats";
	libname history  "M:\CI\sasdata\CIDataQuality";
	%if &practice ne 0 %then %do;
	  libname ci       "&out.";
	%end;
	libname ids    oledb init_string=&ids. preserve_tab_names=yes; /*16FEB2011 WLee - modified to call IDS instead of vMine*/
	libname vlink    oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vlinkNSAP;";


	*SASDOC--------------------------------------------------------------------------
	| Facility Indicator       
	+------------------------------------------------------------------------SASDOC*;
	%mvarexist(FACILITY_INDICATOR);  
   	%if &mvarexist. = 0 %then %do;
   	  %global FACILITY_INDICATOR ;
 	  %let FACILITY_INDICATOR=0;
	%end;	
	%put NOTE: FACILITY_INDICATOR = &FACILITY_INDICATOR. ;

	*SASDOC--------------------------------------------------------------------------
	| Delete Datasets                                     
	+------------------------------------------------------------------------SASDOC*;
	  proc datasets lib=work nolist ;
	    delete ds: vminefile_: validation_: qc_: summary: percent: 
	           data_threshold practice_threshold client_threshold: column_: email: 
	           determine_date fn: trans: contents: dq:;
	  run;
	  quit;  


	*SASDOC--------------------------------------------------------------------------
	| Practice Information                                     
	+------------------------------------------------------------------------SASDOC*;	

	/*16FEB2011 WLee - Update to call from IDS tables instead of vMine tables*/
	proc sql;
		create table vmine_xref as
		select distinct
			a.datasourceid		as practiceid,
			a.name				as practicename,
			b.clientid,
			b.clientname,
			d.name				as systemname,
			d.systemid,
			b.directorypath,			
			datepart(b.ClientBeginDate) as ClientStartDate format=mmddyy10.
		from ids.DATASOURCE as a 								inner join
			 ids.CLIENT 	as b on a.clientid = b.clientid 	inner join
			 ids.VERSION 	as c on a.versionid = c.versionid 	inner join
			 ids.SYSTEM 	as d on c.systemid = d.systemid
		order by a.datasourceid
		;
	quit;
	
	/*16FEB2011 WLee - Update to call from IDS.Client table instead of vMine.Client table*/
	proc sql;
	  create table vmine_client as
	  select *
	  from IDS.client ;
	quit;	
	
	*SASDOC--------------------------------------------------------------------------
	| vMine Practices       
	+------------------------------------------------------------------------SASDOC*;	
	%if &practice. = 11 %then %do; 
		data vmine_xref_practice;
		  format clientdir $20. ;
		  set vmine_xref (obs=1);
		  practicename = "&practice_nm.";
		  clientdir = "&client_dir.";
		  clientid = 0;
		  clientname = "&client_nm.";
		  systemid = "&sys_id.";
		  systemname = "&sys_nm.";
		  practiceid = &practice;
		  call symput('clientdir',trim(clientdir));
		  call symput('clientid',trim(clientid));
		  call symput('clientname',trim(clientname));
		  call symput('systemid',trim(systemid));
		  call symput('systemname',trim(systemname));  
		  call symput('practiceid',trim(practiceid));
		  call symput('practicename',trim(practicename));
		  call symput('clientstartdate',trim(ClientStartDate));
		run;
	%end;
	%else %do;
		data vmine_xref_practice;
		  format clientdir $20. ;
		  set vmine_xref (where = (practiceid=&practice));
		  practicename=compress(practicename,"'");
		  clientdir=scan(DirectoryPath,2,'\');
		  call symput('clientdir',trim(clientdir));
		  call symput('clientid',trim(clientid));
		  call symput('clientname',trim(clientname));
		  call symput('systemid',trim(systemid));
		  call symput('systemname',trim(systemname));  
		  call symput('practiceid',trim(practiceid));
		  call symput('practicename',trim(practicename));
		  call symput('clientstartdate',trim(ClientStartDate));
		run;
	%end;

    *SASDOC--------------------------------------------------------------------
    | Check observations of datasetin. If zero records then abort dq report else continue.
	| Send an email to the end-user that input datasource to dq report has no records.
    +--------------------------------------------------------------------SASDOC*;
    %countobs(dsn=&datasetin.,macvar=clm_obs);

	%if  &clm_obs. le 0 %then %do;

				%let emailfile=%str(\\Fs\ci\data\emailabort.txt);

				data _null_;				  
				  file "&emailfile." lrecl=200 ;
				  if _n_=1 then do; 
					put " ";
				  	put "Hello. ";
                  	put / "The are zero data records in &datasetin. for the DQ process to run on. ";
				  	put / "All code statments execution has been cancelled. ";
					put / "There will not be a DQ Report produced.";
				  	put " ";
					put / "Please examine the saslog for more details.";
				  	put / "Thanks.";
					put " ";
				  	put "&SYSHOSTNAME.";
				  end;
				run;

				%if %upcase(&SYSUSERID) = LSFUSER %then %do;
					libname emailid "M:\ci\sasdata\CIReference";

					data _null_;
					  set emailid.usertable;
					  where client = &client.;
					  call symputx('emailid',emailid);
					run;
					%put NOTE: emailid = &emailid. ;
				%end;
				%else %do;
					data _null_;
					  emailid="&SYSUSERID.@valencehealth.com";
					  call symputx('emailid',emailid);
					run;
					%put NOTE: emailid = &emailid. ;
				%end;		

				%email_parms(em_to=&emailid.,
					     em_subject=Clinical Integration - &clientname The Data Quality Report - ABENDED,
					     em_msg_file=%str(&emailfile.),
					     em_from=&emailid.  );

				data _null_;
				 x "del &emailfile.";
				run;


		%abort cancel; 

	%end;


	
	%let practice_count=0;
	%let var_npi=npi;
	
	proc sql noprint;
	  select count(*) into: practice_count
	  from vmine_xref_practice;
	quit;
	
	*SASDOC--------------------------------------------------------------------------
	| PGF Practices       
	+------------------------------------------------------------------------SASDOC*;	
	%if &practice_count eq 0 %then %do;	
	
		proc contents data = &datasetin. out = temp01 (keep=name) noprint;
		run;
		
		data temp01;
		 set temp01;
		 if upcase(name) in ("PROVID","NPI");
		 put _all_;
		run;
		
		proc sort data = temp01;
		 by name;
		run;
		
		data _null_; 
		  set temp01; 
		  call symput('var_npi',trim(name)); 
		run;		
	
		proc sql noprint;
		 select distinct(quote(trim(&var_npi.))) into: provid separated by ","
		 from &datasetin. 
		 where &var_npi. not in ("NULL","",".");
		quit;

		%put NOTE: provid = &provid. ;

		proc sql;
		  create table tblProvider as
		  select *  from vlink.tblProvider 
		  where P_NPI in (&provid.);
		quit;
		
		proc sql noprint;
		 select count(*) into: tblProvider_qa
		 from tblProvider;
		quit;
		
		%put NOTE: tblProvider_qa = &tblProvider_qa. ;
		
		%if &tblProvider_qa. = 0 %then %do;
		
			proc sort data = temp01;
			 by descending name;
			run;

			data _null_; 
			  set temp01; 
			  call symput('var_npi',trim(name)); 
			run;		

			proc sql noprint;
			 select distinct(quote(trim(&var_npi.))) into: provid separated by ","
			 from &datasetin. 
			 where &var_npi. not in ("NULL","",".");
			quit;

			%put NOTE: provid = &provid. ;

			proc sql;
			  create table tblProvider as
			  select *  from vlink.tblProvider 
			  where P_NPI in (&provid.);
			quit;		
		
		%end;

		proc sql noprint;
		 select distinct(ProviderID) into: ProviderID separated by ","
		 from tblProvider ;
		quit;

		%put NOTE: providerid = &providerid. ;

		proc sql;
		  create table vAllClientsCIProgressDetailed as
		  select *
		  from vlink.vAllClientsCIProgressDetailed  
		  where providerid in (&providerid.);
		quit;
		
		proc sql noprint;
		select count(*) into: cnt_vAllClients separated by ''
		from vAllClientsCIProgressDetailed;
		quit;

			%if &cnt_vAllClients. = 0 and %symexist(practice_id) = 1 %then %do; 

				proc sql;
				create table vAllClientsCIProgressDetailed as
				select distinct     
				g.clientid, 
				g.groupid, 
				g.groupname, 
				pg.isprimary as primarypractice,
				p.providerid 
				from vlink.tblgroups                               as g left outer join
				vlink.tblprovidergroups                            as pg on g.groupid = pg.groupid inner join
				vlink.tblprovider                                  as p on p.providerid = pg.providerid inner join
				vlink.tblspecialty                                 as s on s.providerid = p.providerid 
				where  p.providerid in (&providerid.);
				quit;

			%end;
		
		data vAllClientsCIProgressDetailed;
		set vAllClientsCIProgressDetailed; 
		if primarypractice=. then primarypractice=9;
		run;

		proc sort data = vAllClientsCIProgressDetailed;
		by primarypractice;
		run;		
		
		%if %symexist(vlink_id) = 0 %then %do;
		  %global vlink_id ;
		  proc sql noprint;
		    select distinct(groupid) into: vlink_id separated by ','
		    from vAllClientsCIProgressDetailed;
		%end;

		data one_record;
		  set vAllClientsCIProgressDetailed (obs=1 keep= groupid groupname specialty providerid);
		  systemname="Group ID "||trim(left(groupid));
		run; 		
		
		data vmine_xref;
		  set vmine_xref (where = (clientid=&client));
		  keep clientid clientname DirectoryPath ;
		run;

		data vmine_xref;
		  if _n_=1 then set one_record;
		  set vmine_xref (obs=1);
		run;
	
		data vmine_xref_practice;
		  format clientdir $20. ;
		  set vmine_xref ;
		  clientdir=scan(DirectoryPath,2,'\');
		  call symput('clientdir',trim(clientdir));
		  call symput('clientid',trim(clientid));
		  call symput('client',trim(clientid)); 
		  call symput('clientname',trim(clientname));
		  call symput('systemid','0');
		  call symput('systemname',trim(systemname));
		  call symput('practiceid',trim(left(groupid)));
		  call symput('practicename',trim(groupname));
		  call symput('clientstartdate',trim(ClientStartDate));
		run;	
	
	%end;
	
	%put NOTE: clientname=&clientname.;
	%put NOTE: clientstartdate=&clientstartdate.;
	%put NOTE: systemname=&systemname.;
	%put NOTE: practicename=&practicename.;	
	
	
	*SASDOC --------------------------------------------------------------------	
	| 01APR2011 - Nick Williams - Clinical Integration  1.0.06
	| Select Providers CI Participation, append a variable onto datasetin that holds the
	| ci-par status.
	+------------------------------------------------------------------------------SASDOC*;
		proc contents data = &datasetin. out = temp01 (keep=name) noprint;
		run;
		
		data temp01;
		 set temp01;
		 if upcase(name) in ("NPI");
		 put _all_;
		run;
		
		proc sort data = temp01;
		 by name;
		run;
		
		data _null_; 
		  set temp01; 
		  call symput('var_npi',trim(name)); 
		run;		
	
		proc sql noprint;
		 select distinct(quote(trim(&var_npi.))) into: npi separated by ","
		 from &datasetin. 
		 where &var_npi. not in ("NULL","",".");
		quit;

		%put NOTE: npi = &npi. ;
		
		proc sql noprint;
		 select count(*) into: npi_count
		 from &datasetin. 
		 where &var_npi. not in ("NULL","",".");
		quit;

		%put NOTE: npi = &npi. ;
		%put NOTE: npi_count = &npi_count. ;
		
		%if &npi_count. = 0 %then %do;
		  %let npi=%str('0');
		%end;
	
		/* ncw: get vlinkclientid */
		proc sql noprint;
		  select distinct vLinkClientID into: vlinkclientid 
		  from ids.vMineToVLink
		  %if &practice_count eq 0 %then %do;
		  where practiceid eq &practiceid. ;
		  %end;
		  %else %do;
		  where vMineID eq &practiceid. ;
		  %end;
          ;
		quit;

		%put NOTE: vlinkclientid  = &vlinkclientid . ;

		proc sql;
		  create table tblCiParProvider as		  
		  select ClientID
			      ,ProviderID
			      ,P_FirstName
			      ,P_LastName
			      ,P_Middle
			      ,P_NPI
			      ,P_NetworkStatus
			      ,P_EffectiveDate
			      ,P_CIEffDt
			      ,P_CITermDt
			      ,P_CIPar
          from vlink.tblProvider 
		  where P_NPI in (&npi.)		  
		  and clientid in (&vlinkclientid.)
          ;
		quit;

        %put NOTE: practice  = &practice. ;

	*SASDOC --------------------------------------------------------------------
	|  ncw - merge to claims - make sure to drop the npicipar variable after processing the 
	| data so we dont keep it on the permenant claims dataset.
	| maybe here the create table output can be different, and u can reassign datasetin to something different
	| that way you dont overwrite the claims dataset.
	+--------------------------------------------------------------------SASDOC*; 

	%if &practice ne %then %do; 
		proc sql;
		     /* create table ci.claims_&practice. as */
			create table work.dq_claims_&practice. as		  
			select a.*, b.P_CIPar as npicipar
			from &datasetin. a
			left join work.tblCiParProvider b
			on a.npi = b.P_NPI;
		quit;
		/*        %let datasetin=%str(ci.claims_&practice.);*/
        %let datasetin=%str(work.dq_claims_&practice);
	%end;
	%else %if &pgf_practice. ne %then %do;
		proc sql;
			/* create table &pgf_practice. as		  			*/
			create table work.dq_claims_&pgf_practice. as		  
			select a.*, b.P_CIPar as npicipar
			from &datasetin. a
			left join work.tblCiParProvider b
			on a.npi = b.P_NPI;
		quit;
		/* %let datasetin=&pgf_practice.;*/		
		%let datasetin=%str(work.dq_claims_&pgf_practice.);
	%end;	
	%else %do; /* not sure if this is needed 08.24.2011 */
        %let datasetin=&syslast;
	%end;


	*SASDOC--------------------------------------------------------------------
	| Create the claims start date 
	+--------------------------------------------------------------------SASDOC*;
	

		proc sql noprint;
		 select min(svcdt) format=WORDDATE18. into: claimstartdate 
		 from &datasetin. 
		 where svcdt ge &clientstartdate.;
		quit;

		%put NOTE: claimstartdate = &claimstartdate. ;

	
	*SASDOC--------------------------------------------------------------------------
	| Report Color Options                                     
	+------------------------------------------------------------------------SASDOC*;
	%if %symexist(sas_mode) and %upcase(&sas_mode.)=PROD %then %let reportdir=%str(\\Fs\&clientdir\reports\Data_Quality_Reports);
	%else %let reportdir=%str(\\Fs\&clientdir\reports\Data_Quality_Reports\test);
	%let bcolor = cx13478C;
	%let tcolor = white;

	*SASDOC--------------------------------------------------------------------------
	| Assign Libnames       
	+------------------------------------------------------------------------SASDOC*;
	%check_libname(lib=provfmt,   dir=%str(M:\&clientdir.\sasdata\CIETL\provider\formats));    ** all  ;
	%check_libname(lib=provfmt,   dir=%str(M:\&clientdir.\sasdata\CI\CIETL\provider\formats)); ** nsap ;
	%check_libname(lib=provfmt,   dir=%str(M:\&clientdir.\sasdata\CIETL\Provider Table));      ** adventist ;

	*SASDOC--------------------------------------------------------------------------
	| Formats Assignments 
	+------------------------------------------------------------------------SASDOC*;
	%include "M:\dw\Formats\programs\ssn_memberid_fmt.sas"; *added subfolder PROGRAMS 20100903 - WL;
	
	data diag5cd;
	  set dwfmt.diag5cd  (where=(lowcase(start) ne 'other')); 
	run;

	data procfmt;
	  set dwfmt.procfmt  (where=(lowcase(start) ne 'other'));  
	run;

		
	%proc_format(datain=work.diag5cd);
	%proc_format(datain=work.procfmt);

	%if &client = Adventist %then %do;
	%proc_format(datain=provfmt.npicipar);
	%proc_format(datain=provfmt.npiprovname);
	%end;
	%else %do;
	%proc_format(datain=provfmt.provyn);
	%proc_format(datain=provfmt.provname);
	%end;

	%proc_format(datain=dwfmt.zipcodes);
	
	data PracXwalk (keep = datasourceid Name rename=datasourceid=PracticeID);
	  set ids.datasource;
	  where enabled = 1;
	run;

	data PracWalk;
	  length FMTNAME $8. TYPE $1. label $75. start $5.;
	  set PracXwalk;
	  keep START LABEL TYPE FMTNAME ;
	  retain FMTNAME 'PracWalk'  TYPE 'C';
	  if practiceID ne "" then do;
	    start = cats(PracticeID);
		label = Name;
		output;
	  end;
	  if _n_ = 1 then do;
	   start = "other";
	   label = '';
	   output;
	  end;
	run;

	proc sort data=PracWalk nodupkey;
	  by start;
	run;

	proc format cntlin=pracwalk;
	run;	

	*--------------------------------------------------------------------------------
	| Determine thresholds for validations from history
	+------------------------------------------------------------------------------*;	
	%dq_thresholds(client=&clientid, practice=&practiceid);
	
	*--------------------------------------------------------------------------------
	| create threshold values 
	+------------------------------------------------------------------------------*;
	data _null_;
	 set data_threshold ;
	 call symput(upcase(trim(data_quality))||"WARNING",TRIM(LEFT(warning_threshold_value)));
	 call symput(upcase(trim(data_quality))||"REJECT",TRIM(LEFT(reject_threshold_value)));
	run;

	*--------------------------------------------------------------------------------
	| Macros - Internal  
	+------------------------------------------------------------------------------*;	
	%macro dq_validate_data_threshold(var=, warningvalue=, rejectvalue=, freqtitle=);

		%let percent=0;
		%let print=0;

		proc freq data= pm_&practice. noprint;
		  tables &var. / missing  out = &var.;
		run;

		proc sql noprint;
		  select percent into: percent
		  from &var.
	          where upcase(&var.) in ('INVALID','N')  ;
		quit;

		data _null_;
		 if &percent gt &rejectvalue then print=2;
		 else if &percent gt &warningvalue then print=1;
		 else print=0;
		 call symput('print',print);
		run;    

		%put NOTE: Reject Threshold = &rejectvalue.;
		%put NOTE: Warning Threshold = &warningvalue.;
		%put NOTE: %upcase(&var.) Percent   = &percent.;
		%put NOTE: Print = &print. ;

		%if &print = 2 %then %do; 
			data &var. (rename=(&var.=validation));
			 format data_assessment data_variable $40. data_validation  $20.;
			 set &var.;
			 data_variable="&var.";
			 if _n_=1 then data_assessment="&freqtitle.";
			 if _n_=1 then data_validation="**Not Acceptable**";
			run;
		%end; 
		%else %if &print = 1 %then %do;
			data &var. (rename=(&var.=validation));
			 format data_assessment data_variable $40. data_validation  $20.;
			 set &var.;
			 data_variable="&var.";
			 if _n_=1 then data_assessment="&freqtitle.";
			 if _n_=1 then data_validation="Warning";
			run;
		%end; 	
		%else %do;
			data &var. (rename=(&var.=validation));
			 format data_assessment data_variable $40. data_validation  $20.;
			 set &var.;
			 data_variable="&var.";
			 if _n_=1 then data_assessment="&freqtitle.";
			 if _n_=1 then data_validation=" ";
			run;
		%end;

	%mend dq_validate_data_threshold;
	
	%macro dq_combine_datasets;

		%local dq_variables;

		data summary_validation;
		  format percent percent 8.2;
		  set validation_dob (obs=0);
		run;

		data summary_validation;
		  retain data_assessment data_validation validation count;
		  set  summary_validation;
		run;

		proc sort data = history.data_threshold;
		  by data_quality ;
		run;

		proc sql noprint;
		  select trim(data_quality) into: dq_variables separated by " "
		  from history.data_threshold;
		quit;

		%put dq_variables = &dq_variables;

		%let z=0;
		%do %while (%scan(&dq_variables, &z+1) ne );
			%let z=%eval(&z+1);
			%let ds=%scan(&dq_variables,&z);
			
			%if %sysfunc(exist(work.validation_&ds)) %then %do;
			  proc append base=summary_validation data= VALIDATION_&ds force ;
			  run;			
			%end;
		%end;

		data summary_validation;
		  set  summary_validation;
		  if upcase(validation)='Y' then validation='Valid';
		  else if upcase(validation)='N' then validation='Invalid';
		run;

		proc sql noprint;
		  select count(*) into: dataset_total
		  from pm_&practice.  ;
		quit;

		proc sql noprint;
		  select count(*) into: not_acceptable
		  from summary_validation
		  where index(upcase(data_validation), 'NOT ACCEPTABLE')  ;
		quit;

		%put NOTE: dataset_total = &dataset_total. ; 
		%put NOTE: not_acceptable = &not_acceptable. ; 

		%if &not_acceptable = 0 %then %do; 
			%let status = 'ACCEPTED';
		%end;
		%else %do;
		    %let status = 'NOT ACCEPTED';
		%end;

	%mend dq_combine_datasets;	

	%macro createvarloop(list=, prefix=, suffix=);
	  %global &prefix. &suffix. ;
	  %let z=0;
	  %let var=;
	  %do %while (%scan(&list., &z+1) ne );
		%let z=%eval(&z+1);
		%if &prefix ne %then %do;
            %let var= &var &prefix.%scan(&list. ,&z);
		%end;
		%if &suffix ne %then %do;
            %let var= &var %scan(&list. ,&z)%left( &suffix.);
		%end;
	  %end;
	  %if &prefix ne %then %let &prefix = &var. ; 
	  %if &suffix ne %then %let &suffix = &var. ; 
	  %put NOTE: var = &var. ;
	%mend createvarloop;	

	*--------------------------------------------------------------------------------
	| Perform Variable Validations 
	+------------------------------------------------------------------------------*;
	%dq_validate_content(datain=&datasetin., validate=filename );
	%dq_validate_content(datain=&datasetin., validate=variables);
	%dq_create_dataset;

	*--------------------------------------------------------------------------------
	| Perform Threshold Validations 
	| Gds101699
	+------------------------------------------------------------------------------*;
	%dq_validate_data_threshold(var=validation_memberid, warningvalue=&memberidwarning., rejectvalue=&memberidreject.,  freqtitle=%str(Member ID Assessment));
	%dq_validate_data_threshold(var=validation_npi,      warningvalue=&npiwarning.,      rejectvalue=&npireject.,       freqtitle=%str(NPI Assessment));
    %dq_validate_data_threshold(var=validation_npicipar, warningvalue=&npiciparwarning., rejectvalue=&npiciparreject.,  freqtitle=%str(NPI CI Participation Assessment));
	%dq_validate_data_threshold(var=validation_proccd,   warningvalue=&proccdwarning.,   rejectvalue=&proccdreject.,    freqtitle=%str(Procedure Assessment));
	%dq_validate_data_threshold(var=validation_diag1,    warningvalue=&diag1warning.,    rejectvalue=&diag1reject.,     freqtitle=%str(Diagnosis Assessment));
	%dq_validate_data_threshold(var=validation_svcdt,    warningvalue=&svcdtwarning.,    rejectvalue=&svcdtreject.,     freqtitle=%str(Service Date Assessment));
	%dq_validate_data_threshold(var=validation_sex,      warningvalue=&sexwarning.,      rejectvalue=&sexreject.,       freqtitle=%str(Gender Assessment));
	%dq_validate_data_threshold(var=validation_fname,    warningvalue=&fnamewarning.,    rejectvalue=&fnamereject.,     freqtitle=%str(First Name Assessment));
	%dq_validate_data_threshold(var=validation_lname,    warningvalue=&lnamewarning.,    rejectvalue=&lnamereject.,     freqtitle=%str(Last Name Assessment));
	%dq_validate_data_threshold(var=validation_dob,      warningvalue=&dobwarning.,      rejectvalue=&dobreject.,       freqtitle=%str(DOB Assessment));
	%dq_validate_data_threshold(var=validation_phone,    warningvalue=&phonewarning.,    rejectvalue=&phonereject.,     freqtitle=%str(Phone Assessment));
	%dq_validate_data_threshold(var=validation_address1, warningvalue=&address1warning., rejectvalue=&address1reject.,  freqtitle=%str(Address Assessment));
	%dq_validate_data_threshold(var=validation_city,     warningvalue=&citywarning.,     rejectvalue=&cityreject.,      freqtitle=%str(City Assessment));
	%dq_validate_data_threshold(var=validation_state,    warningvalue=&statewarning.,    rejectvalue=&statereject.,     freqtitle=%str(State Assessment));
	%dq_validate_data_threshold(var=validation_zip,      warningvalue=&zipwarning.,      rejectvalue=&zipreject.,       freqtitle=%str(Zipcode Assessment));
	%dq_validate_data_threshold(var=validation_pos,      warningvalue=&poswarning.,      rejectvalue=&posreject.,       freqtitle=%str(POS Assessment));

	*--------------------------------------------------------------------------------
	| Perform Threshold Validations 
	| -Individual Value and Moving Range Control Charts 
	| -Fraction Nonconforming Control Charts 
	+------------------------------------------------------------------------------*;
	%if &practice. = 0 %then %do;
	  %put NOTE: PGF Practice. ;
	%end;
	%else %if &practice. = 11 %then %do;  
	  %put NOTE: Cracking Development Practice. ;
	%end;
	%else %do;
	  %dq_qualitycontrol_charts;
	%end;


	*--------------------------------------------------------------------------------
	| PDF Report
	+------------------------------------------------------------------------------*;
	title; footnote;
	options msglevel=i orientation='landscape' nodate nonumber;
	options leftmargin=1in 	rightmargin=1in topmargin=0.25in	bottommargin=.25in;
	ods escapechar='~';
	
	proc contents data = &datasetin. out = contents_maxprocessid (keep=name) noprint;
	run;
	
	%let contents_maxprocessid=0;
	
	proc sql noprint;
	 select count(*) into: contents_maxprocessid
	 from contents_maxprocessid
	 where upcase(name)='MAXPROCESSID';
	quit;
	
	%put NOTE: contents_maxprocessid = &contents_maxprocessid.;
	
	%if &contents_maxprocessid. = 0 %then %do;
	  %let clientdirname=&clientdir.;
	%end;
	%else %do;
	  %let clientdirname=&clientdir._cio;
	%end;

	
	%if &practice eq 0 %then %do;
	  %let xl = %str(&reportdir.\DataQuality_pgf_%lowcase(&clientdirname.)_&pdfname._&pdf_report_date..pdf);
	  filename xl "&xl.";
	%end;
	%else %do;
	  %let xl = %str(&reportdir.\DataQuality_vmine_%lowcase(&clientdirname.)_&practice._&pdf_report_date..pdf);
	  filename xl "&xl.";	  
	%end;
	
	ods pdf  file=xl style=sasweb pdftoc=1 columns=1  author='Valence Health' 
	         Subject='vMine File Upload Status' Title='Upload Summary' ;

			title1 c=&bcolor h=12pt f="times" j=c "Clinical Integration - &clientname."  ;

			%if &practice eq 0 %then %do;
				title2 c=&bcolor justify=left h=10pt f="times"	"Practice: &practiceid - &practicename" h=14pt f="times" j=c 'Practice Data Summary Report'  h=10pt f="times" j=r "Prepared: %sysfunc(today(),mmddyy10.)"
				h=10pt f="times" j=l "Practice Claims Start Date: &claimstartdate. ";
			%end;
			%else %do;
				 title2 c=&bcolor justify=left h=10pt f="times"	"Practice: &practice - &practicename"   h=14pt f="times" j=c 'Practice Data Summary Report'  h=10pt f="times" j=r "Prepared: %sysfunc(today(),mmddyy10.)"
				 h=10pt f="times" j=l "Practice Claims Start Date: &claimstartdate. ";
			%end;

		title3 c=&bcolor justify=center '~S={preimage="\\ebicompute\Projects\tools\images\PGF_PDFHEADER.gif"}';
		footnote1 justify=center '~S={preimage="\\ebicompute\Projects\tools\images\PGF_PDFHEADER.gif"}';
		footnote2 justify=left h=8pt f="times" "Valence Health" j=r h=8pt "Practice Data Summary - ~{thispage}";

		%dq_combine_datasets;
		%dq_descriptive_statistics;
		%dq_create_reports;

	ods pdf close;

	*--------------------------------------------------------------------------------
	| Append to History and Email if any issues
	+------------------------------------------------------------------------------*;	
	%if %upcase(&cioproject.) = YES %then %do;  
	  %put NOTE: CIO Project Develepment - Insert to development DQ History.;
	  %pmsystem_development_dq_history;
	%end;
	%else %if &practice. = 11 %then %do; 
	  %put NOTE: PM System Cracking and Develepment - Insert to development DQ History.;
	  %pmsystem_development_dq_history;
	%end;
	%else %do;
	  %dq_history;
	%end;
	
	%put NOTE: clientname=&clientname.;
	%put NOTE: systemname=&systemname.;
	%put NOTE: practicename=&practicename.;    
 
%mend dq_report;


