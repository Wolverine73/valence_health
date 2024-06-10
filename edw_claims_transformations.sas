
/*HEADER------------------------------------------------------------------------
|
| program:  edw_claims_transformations.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create data quality reports based on calculated thresholds 
|
| logic:    The driver program for the data quality process updated version for pgf process
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
| 14JAN2011 - Robyn Stellman - added logic to include PGF files
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 30MAY2012 - Brian Stropich  - Clinical Integration  1.2.01
|             Added changes for noload hold reprocess.  the logic is to 
|             by pass the incremental code and go to sections needed for the
|             reprocessing of the nl load hold encounters. search for 
|             nlhold_reprocess within the code.  commented the begin and end
|             for the conditions to easily follow the logic.
|
| 03MAY2012 - G Liu - Clinical Integration 1.2.02
|             Redirecting DQ report to \test\ folder if sas_mode is not PROD 
|
| 03MAY2012 - Winnie Lee - Clinical Integration 1.2 H07
|             Added logic to include DATA_SOURCE_ID
|
| 08JUN2012 - Brian Stropich - Clinical Integration 1.3.01 M01
|             Added logic for member key and person key joins for encounter_header
|
| 18JUN2012 - G Liu - Clinical Integration 1.3.02
|			  Changed validate_claim_exist step 3 to use PERSON_KEY instead of member
|				demographics, to include changes in PATID/system_member_id
|
| 19JUN2012 - G Liu - Clinical Integration 1.3.03 H01
|			  Added payer conditional logic to toggle between UB and HCFA runs
|			  Added payer dataformatgroupid 20 to run 837 or regular case logic dependent 
|				on bill_type availability in staging dataset
|
| 08JUN2012 - Brian Stropich - Clinical Integration 1.3.04 
|             Added member key old assignment for nl hold reprocess
|
| 20JUN2012 - G Liu - Clinical Integration 1.3.05
|			  For non-payer, hardcode payer_key = null
|			  From this point on, payer_key means data coming from Payer
|
| 05JUL2012 - G Liu - Clinical Integration 1.4.01 TCHP
|			  For facility_indicator=0, only assign majcat when %ContainMajcat=0
|			  Change CaseLogic vs StayLogic dependent on indicators in DataFormat table 
|			  For payer HCFA, drg_key is set to null. (CI defaults to 1... why?)
|			  For payer HCFA, admit_diagnosis_cd
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
|
| 31JUL2012 - Winnie Lee - Release 1.5 L02
|				Updated hospital case logic from edw_837_case_logic macro to
|				edw_billtype_hospital_stay_logic macro.
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| define sas macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\ci\programs\standardmacros" "M:\ci\programs\clientmacros" sasautos);
options mlogic mprint symbolgen;
options bufsize=600k; 


*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment

%macro edw_claims_transformations(dsn=, practice=, client=, practice_nm=, 
                                  client_dir=, client_nm=, sys_id=, sys_nm=, cioproject=);

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START)

	%if &sas_prgm_id.=18 %then %do;
		%let sasprogramby='reprocess - error';
	%end;
	%else %if &sas_prgm_id.=19 %then %do;
		%let sasprogramby='reprocess - nl hold';
	%end;
	%else %do;
		%let sasprogramby='bpm - sas';
	%end;

	%let increment_count=0;
	%if %sysfunc(exist(&dsn.)) %then %do;
		proc sql noprint;
		  select count(*) into: increment_count
		  from &dsn. ;
		quit;
	%end;

	%put NOTE: increment_count = &increment_count.;

	%IF &increment_count ne 0 %THEN %DO;  /** begin - increment_count **/

		*SASDOC--------------------------------------------------------------------------
		| Initialize Options 
		+------------------------------------------------------------------------SASDOC*;  
		%global status dqstatus reportdir datasetin pdfname pdf_report_date maxprocessid xl practice_key ;

		%let maxprocessid = 0;
	
		*SASDOC--------------------------------------------------------------------------
		| Practice Logic    
		------------------------------------------------------------------------SASDOC*;  
		%data_source_information	

		/* For Payer, toggle between UB & HCFA using dummy dataset in staging folder, and set facility_indicator according to
			which type of claim that has yet to be processed */
		%if &dataformatgroupid.=20 %then %do;
			%if &PayerContainUB. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._ub_batch&batch_key.))=0 %then %do;
				%let facility_indicator=1;
			%end;
			%else %if &PayerContainHCFA. and %sysfunc(exist(cistage.ck&client_id._fmtgrp&dataformatgroupid._hcfa_batch&batch_key.))=0 %then %do;
				%let facility_indicator=0;
			%end;
		%end;
		
		%put NOTE: dataformatid  = &dataformatid. ; 
		%put NOTE: edw_directory = &edw_directory. ;
		

		%if  &dataformatid. = 6 %then %do; /** vmine data source **/
			%let pgf_practice=;
		%end;
		%else %if &dataformatid. = 47 %then %do; /**837 Professional**/
			%let pgf_practice=&practice_id.;
		%end;
		%else %do; /** non-vmine data source **/
			%let pgf_practice=&practice_id.;
		%end;

		*SASDOC-------------------------------------------------------------------------
		|  Hospital Case Logic                        
		|------------------------------------------------------------------------SASDOC*; 
		%if &facility_indicator. = 1 %then %do;
			%if &RunStayLogic. and &dataformatgroupid.=20 %then %do; 
				/* stay logic looks for poa variables named poa1-poa?. instead of making the stay logic dynamic code
					more complicated to accommodate for poa1 vs poa1_pfkey, we're just renaming the variables here
					going in to the stay logic, then rename them back coming out of stay logic */
				proc contents data=&dsn. out=incoming_contents noprint;
				data _null_;
					set incoming_contents;
					name=upcase(name);
					retain numofpoapfkey numofpoa 0;
					if name=:'POA' and compress(substr(name,4),'0123456789')='' 
						then numofpoa=max(numofpoa,substr(name,4));
					call symput('n_poa',cats(numofpoa));

					if scan(name,2,'_')='PFKEY' and scan(name,1,'_')=:'POA' and compress(substr(scan(name,1,'_'),4),'0123456789')='' 
						then numofpoapfkey=max(numofpoapfkey,substr(scan(name,1,'_'),4));
					call symput('n_poapfkey',cats(numofpoapfkey));
				run;

				data &dsn.;
					/* stay logic assumes that maxprocessid is the header surrogate key, but payer table is flat and 
						has only line surrogate key */
					set &dsn.(rename=(maxprocessid=payer_line_surrogate_key));
					maxprocessid=claimnum;
				  %if &n_poa.=0 and &n_poapfkey. %then %do;
					rename %do dpoa=1 %to &n_poapfkey.; poa&dpoa._pfkey=poa&dpoa. %end; ;		
				  %end;
				run;

				%edw_billtype_hospital_stay_logic(dataset_in=&dsn.)

				data &dsn.;
					set &dsn.(drop=maxprocessid rename=(payer_line_surrogate_key=maxprocessid));
					payer_key=&payer_key.; /* stay logic does not retain payer key properly. reset payer key */
					maxprocessid=.; /* 7/18/2012 null this out for now, stay logic jumbled up the staging surrogate key, pending Winnie's investigation */
				  %if &n_poa.=0 and &n_poapfkey. %then %do;
					rename %do dpoa=1 %to &n_poapfkey.; poa&dpoa.=poa&dpoa._pfkey %end; ;		
				  %end;
				run;
				/* we want to keep maxprocessid in EDW so that we have a way to tie back to staging table */
			%end;
			%else %if &RunStayLogic. %then %do;
				%edw_billtype_hospital_stay_logic(dataset_in=&dsn.)
			%end;
			%else %if &RunCaseLogic. %then %do; 
				%edw_hospital_case_logic(dataset_in=&dsn.)
			%end;
		%end;

		%If &dataformatgroupid.=20 %Then %Do; /* begin - payer loop */
			%if &maxprocessid = . %then %let maxprocessid = 0;
			%let datasetin=%str(&dsn.);
			%if &practice  = %then %let practice=0;
			%let pdfname=%scan(&pgf_practice.,2,".");
			%let practice_count=0;
			%let var_npi=npi;

			proc sql noprint;
  			   select clientname into: clntname
			   from ids.client
			   where clientid = &client_id. ;
			quit;
			%let clientname = %cmpres(&clntname.);
			%let clientdir=&clientname.;
			%let clientid=&client_id.;
			%let client=&client_id.;
			%let systemid=0;

			data _null_;
				set &dsn.(obs=1);
				pdf_report_date = put(today(),$yymmn.);
				call symputx('pdf_report_date',pdf_report_date);
				call symput('systemname',trim(systemname));
				call symput('practiceid',trim(left(groupid)));
				call symput('practicename',trim(payorname1));
			run;
		%End; /* end - payer loop */
		%Else %If &pgf_practice. eq %Then %Do;  /* vmine loop */

			proc sql noprint;
                 select 
                       distinct(b.practice_key) into: practice_key separated by ','
                 from ids.datasource_practice as a inner join
                      ciedw.practice as b on a.practiceid=b.vsource_practice_key 
                 where a.datasourceid=&practice_id. and b.vsource_practice_key ne .;
           quit;


			proc sql noprint;
			  connect to oledb(init_string=&ciedw.);
			  select maxprocessid into: maxprocessid from connection to oledb
			  (	
				select max(vmine_kprocessid) as maxprocessid
				from  [dbo].[encounter_detail] as ed,
					  [dbo].[encounter_header] as eh 
				where ed.encounter_key=eh.encounter_key
				  and ed.client_key=eh.client_key
						  and eh.client_key=&client_id.
						  and ed.data_source_id = &practice_id.
			  );
			quit;	

			%if &maxprocessid = . %then %let maxprocessid = 0;

			data _null_;
			  pdf_report_date = put(today(),yymmn.);
			  call symputx('pdf_report_date',pdf_report_date);
			run;		
			
			%if &practice ne %then %let datasetin=%str(&dsn.);
			%else %if &pgf_practice. ne %then %let datasetin=%str(&dsn.);
			%else %let datasetin=&dsn.;

			%if &practice  = %then %let practice=0;
			%let pdfname=%scan(&pgf_practice.,2,".");

			options nosymbolgen;
			%put NOTE: datasetin = &datasetin. ;
			%put NOTE: practice  = &practice. ; 
			%put NOTE: maxprocessid = &maxprocessid. ;
			%put NOTE: PDF Report Date: &pdf_report_date.;
			options symbolgen mlogic;
			

			*SASDOC--------------------------------------------------------------------------
			| Delete Datasets                                     
			+------------------------------------------------------------------------SASDOC*;
			proc datasets lib=work nolist ;
			    delete ds: vminefile_: validation_: qc_: summary: percent: 
			           data_threshold practice_threshold client_threshold: column_: email: 
			           determine_date fn: trans: contents:;
			run;
			quit;  

			*SASDOC--------------------------------------------------------------------------
			| Practice Information                                     
			+------------------------------------------------------------------------SASDOC*;	
			proc sql;
			  create table vmine_xref as
			  select distinct 
					a.practiceid,
					a.name as practicename,
					a.clientid,
					a.clientname,
					a.receiveddate as dateentered,
					b.directorypath as systemname,
					b.systemid,
					a.clientname as clientdir
			  from 	ids.datalist a left outer join ids.version b on a.versionid = b.versionid left outer join 
					ids.datasource c on a.practiceid=c.datasourceid and a.clientid=c.clientid 
	                 /** and c.enabled = 1   bss- commented out for termed practices **/
			  order by a.practiceid;
			quit;


			proc sort data = vmine_xref;
			  by practiceid descending dateentered;
			run;

			proc sort data = vmine_xref
			           out = vmine_practice_information nodupkey;
			  by practiceid ;
			run;  
		
			proc sql;
			  create table vmine_client as
			  select *
			  from ids.client ;
			quit;	
			
			*SASDOC--------------------------------------------------------------------------
			| vMine Practices       
			+------------------------------------------------------------------------SASDOC*;	
			data vmine_xref_practice;
			  format clientdir $20. ;
			  set vmine_xref (where = (practiceid=&practice));
			  practicename=compress(practicename,"'");
			  call symput('clientdir',trim(clientdir));
			  call symput('clientid',trim(clientid));
			  call symput('clientname',trim(clientname));
			  call symput('systemid',trim(systemid));
			  call symput('systemname',trim(systemname));  
			  call symput('practiceid',trim(practiceid));
			  call symput('practicename',trim(practicename));
			run;
			
			%let practice_count=0;
			%let var_npi=npi;
			
			proc sql noprint;
			  select count(*) into: practice_count
			  from vmine_xref_practice;
			quit;
			
		%End;  /** end of vmine loop **/
		/*SASDOC--------------------------------------------------------------------------
		| PGF Practices       
		+------------------------------------------------------------------------SASDOC*/
		%Else %If &pgf_practice. ne %Then %Do;	/** begin pgf instance loop **/
	      
	        %let source_type=xxx;
	        proc contents data = &dsn. out = source_type noprint;
	        run;

			data source_type;
				set source_type;
				name=lowcase(name);
				if name='source_type';
				call symput('source_type',trim(name));
			run;

			%put NOTE: source_type = &source_type. ; 
			
			%if &source_type = source_type %then %do;
				%let system_id = 0;    /** for the sorting routine later - pgf uploader files **/
			%end;
			%else %do;
				%let system_id = 0;    /** for the sorting routine later - pgf files **/
			%end;

			data _null_;
				pdf_report_date = put(today(),$yymmn.);
				call symputx('pdf_report_date',pdf_report_date);
			run;	

			%if %sysfunc(exist(&dsn.)) %then %do;
				%let datasetin=%str(&dsn.);
				%let provid=%str("0000000000");
			%end;
		
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

			*SASDOC--------------------------------------------------------------------------
			| Facility Logic    
			------------------------------------------------------------------------SASDOC*;
			%if &facility_indicator. = 1 %then %do; 
				proc sql noprint; 
				  select quote(trim(P_NPI)) into: provid 
                  from vlink.tblProvider  
				  where clientid=&client_id.;
				quit; 
			%end;

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
			
			%end;   /** tblProvider_qa loop **/

			proc sql noprint;
			  select distinct(ProviderID) into: ProviderID separated by ","
			  from tblProvider ;
			quit;

			%put NOTE: providerid = &providerid. ;	

			proc sql;
			  connect to oledb(init_string=&vlink.);
			  create table vAllClientsCIProgressDetailed as select * from connection to oledb
			  (	
				select *	 
				from vlinknsap.dbo.vAllClientsCIProgressDetailed 
			  );
			quit;			

			proc sql;
			  create table vAllClientsCIProgressDetailed as
			  select *
			  from vAllClientsCIProgressDetailed  
			  where providerid in (&providerid.);
			quit;
			
			proc sql noprint;
			select count(*) into: cnt_vAllClients separated by ''
			from vAllClientsCIProgressDetailed;
			quit;
			
			data practice_name;
			set ids.datasource (keep = datasourceid name);
			where datasourceid=&practice_id.;
			put _all_ ;
			run;	
			
			data vAllClientsCIProgressDetailed;
			merge vAllClientsCIProgressDetailed practice_name;
			GroupName=name;
			run;			

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

			proc sql noprint;
  			   select clientname into: clntname
			   from ids.client
			   where clientid = &client_id. ;
			quit;

			%let clientname = %cmpres(&clntname.);

			%put NOTE: clientname = &clientname;

			*SASDOC--------------------------------------------------------------------------
			| Facility Logic    
			------------------------------------------------------------------------SASDOC*;
			%if &facility_indicator. = 1 %then %do;
				proc sql noprint;
				  select groupname, groupid into: tmp_groupname separated by '', : tmp_groupid separated by ''
				  from vlink.tblgroups
				  where groupid in (select practiceid 
				                    from ids.datasource_practice
                                    where datasourceid=&practice_id.);
				quit;

				%put NOTE: tmp_groupid = &tmp_groupid. ;
				%put NOTE: tmp_groupname = &tmp_groupname. ;
			
				data vAllClientsCIProgressDetailed;
				  set vAllClientsCIProgressDetailed;
				  groupname="&tmp_groupname.";
				  groupid=&tmp_groupid.;
				run;
			%end;

			data one_record;
			  format DirectoryPath1 $50.;
			  set vAllClientsCIProgressDetailed  (obs=1);
			  systemname="Group ID "||trim(left(groupid));
			  DirectoryPath1="&DirectoryPath.";
			  clientid="&client_id.";
			  clientname="&clientname.";
			  keep systemname DirectoryPath1 clientid groupid groupname clientname;
			run; 			

			data vmine_xref;
			  set one_record;
			run;

			data vmine_xref_practice;
			  format clientdir $20. ;
			  set vmine_xref ;
			  /*clientdir=scan(DirectoryPath1,2,'\');*/
			  call symput('clientdir',trim(clientname));
			  call symput('clientid',trim(clientid));
			  call symput('client',trim(clientid)); 
			  call symput('systemid','0');
			  call symput('systemname',trim(systemname));
			  call symput('practiceid',trim(left(groupid)));
			  call symput('practicename',trim(groupname));
			run;	

			%let practice_key = &practice_id.;
		
		%End;   /** PGF instance ***/

		options nosymbolgen;
		%put NOTE: clientname=&clientname.;
		%put NOTE: systemname=&systemname.;
		%put NOTE: practicename="&practicename.";
		%put NOTE: clientdir=&clientdir.;
		options symbolgen mlogic;
		
		*SASDOC--------------------------------------------------------------------------
		| Report Color Options                                     
		+------------------------------------------------------------------------SASDOC*;
		%if %symexist(sas_mode) and %upcase(&sas_mode.)=PROD %then %let reportdir=%str(\\Fs\&clientdir\reports\Data_Quality_Reports);
		%else %let reportdir=%str(\\Fs\&clientdir\reports\Data_Quality_Reports\test);
		%let bcolor = cx13478C;
		%let tcolor = white;


		*SASDOC--------------------------------------------------------------------------
		| Formats Assignments 
		+------------------------------------------------------------------------SASDOC*;
		data provyn;
		  set ciedw.provider (where=(client_key=&client_id.)) end=end; 
		  length fmtname $10  type $1 label $1;
		  retain fmtname 'ProvYN'  type 'C';	
		  start = npi1;
		  label = 'Y';
		  output;
		  if end then do;
		    start='other';
			label='N';
			output;
		  end;
		  keep start label type fmtname;
		run;
		
		proc sort data = provyn nodupkey;
		  by start;
		run;

		data provname;
		  set ciedw.provider (where=(client_key=&client_id.)) end=end; 
		  length fmtname $10  type $1 label $50;
		  retain fmtname 'ProvName'  type 'C';		  	
		  start = npi1;
		  label = provider_name;
		  output;
		  if end then do;
		    start='other';
			label='';
			output;
		  end;
		  keep start label type fmtname;
		run;
		
		proc sort data = provname nodupkey;
		  by start;
		run;
		
		data diag5cd;
		  set ciedw.diagnosis  (where=(lowcase(diagnosis_cd) ne 'other')) end=end; 
		  length fmtname $10  type $1 label $50;
		  retain fmtname 'Diag5cd'  type 'C';		  	
		  start = diagnosis_cd;
		  label = diagnosis_description;
		  output; 
		  keep start label type fmtname;
		run;
		
		data adiag5cd;
		  set ciedw.diagnosis (where=(lowcase(diagnosis_cd) ne 'other')) end=end; 
		  length fmtname $10  type $1 label $50;
		  retain fmtname 'aDiag5cd'  type 'C';		  	
		  start = diagnosis_cd;
		  label = left(diagnosis_key);
		  output; 
		  if end then do;
		   start = "other";
		   label = '1';
		   output;
		  end;
		  keep start label type fmtname;
		run;

		proc sort data = adiag5cd nodupkey;
		  by start;
		run;

		data procfmt;
		  set ciedw.procedure_cd  (where=(lowcase(procedure_code) ne 'other')) end=end; 
		  length fmtname $10  type $1 label $50;
		  retain fmtname 'CPT'  type 'C';		  	
		  start = procedure_code;
		  label = procedure_code_description;
		  output;
		  keep start label type fmtname;
		run;

		%proc_format(datain=work.provyn)
		%proc_format(datain=work.provname)
		%proc_format(datain=work.diag5cd)
		%proc_format(datain=work.adiag5cd)
		%proc_format(datain=work.procfmt)
		
		data pracwalk (keep = PracticeID Name);
		  set ids.datasource;
		  where enabled = 1;
		  rename datasourceid=practiceid;
		run;

		data pracwalk;
		  length FMTNAME $8. TYPE $1. label $75. start $5.;
		  set pracwalk end=end;
		  keep START LABEL TYPE FMTNAME ;
		  retain FMTNAME 'PracWalk'  TYPE 'C';
		  if practiceID ne "" then do;
		    start = cats(PracticeID);
			label = Name;
			output;
		  end;
		  if end then do;
		   start = "other";
		   label = '';
		   output;
		  end;
		run;

		proc sort data=pracwalk nodupkey;
		  by start;
		run;

		proc format cntlin=pracwalk;
		run;
		
		proc sql;
		  connect to oledb(init_string=&vlink.);
		  create table vAllClientsCIProgressDetailed as select * from connection to oledb
		  (	
			select *	 
			from vlinknsap.dbo.vAllClientsCIProgressDetailed 
		  );
		quit; 

		data pracwalkpgf(keep=clientid groupid groupname);
		  set vAllClientsCIProgressDetailed;
		  where RealCategory = 'PGF' and ClientID=&client_id;
		  keep clientid groupid groupname;
		run;

		data pracwalkpgf;
		  length FMTNAME $12. TYPE $1. label $75. start $5.;
		  set pracwalkpgf end=end;
		  keep START LABEL TYPE FMTNAME ;
		  retain FMTNAME 'PracWalk_pgf'  TYPE 'C';
		  if groupid ne "" then do;
		    start = cats(groupid);
			label = groupName;
			output;
		  end;
		run;

		proc sort data=pracwalkpgf nodupkey;
		  by start;
		run;

		%let ect_dsid=%sysfunc(open(pracwalkpgf));
		%let ect_nobs=%sysfunc(attrn(&ect_dsid.,nobs));
		%let ect_dsrc=%sysfunc(close(&ect_dsid.));
		%if &ect_nobs.=0 %then %do;
			data pracwalkpgf;
				FMTNAME='PracWalk_pgf'; TYPE='C'; hlo='O'; start=''; label='';
				output;
			run;
		%end;

		proc format cntlin = pracwalkpgf;
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
		
		%macro dq_combine_datasets(critical_variables_list=);

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
			  %if &facility_indicator. = 1 %then %do;	 
				if left(substr(upcase(data_variable),12)) = 'NPI' then do;
				  validation='Valid';
				  data_validation='';
				end;
				if left(substr(upcase(data_variable),12)) = 'PROCCDXXX' then do;
				  validation='Valid';
				  data_validation='';
				end;
			  %end;
			run;

			proc sql noprint;
			  select count(*) into: dataset_total
			  from pm_&practice.  ;
			quit;

			proc sql noprint;
			  select count(*) into: not_acceptable
			  from summary_validation
			  where index(upcase(data_validation), 'NOT ACCEPTABLE')  
                       and left(substr(upcase(data_variable),12)) in (&critical_variables_list.) ; /** 4 critical validations **/
			quit;

			%put NOTE: dataset_total = &dataset_total. ; 
			%put NOTE: not_acceptable = &not_acceptable. ; 

			%if &not_acceptable = 0 %then %do; 
				%let status = 'ACCEPTED';
				%let dqstatus = DQSUCCESS;
			%end;
			%else %do;
			    %let status = 'NOT ACCEPTED';
				%let dqstatus = DQFAIL; 				
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
		| Remove Duplicates by Claim Identifier Variables
		|
		| This step is needed because the member process might have reconciled some
		| member issues which may cause issues within the EDW
		|
		| 1.  client_key 
		| 2.  member_key 
		| 3.  provider_key 
		| 4.  practice_key
		| 5.  service_date 
		| 6.  procedure_code_key 
		| 7.  mod1 
		| 8.  mod2
		+------------------------------------------------------------------------------*;
		%if &facility_indicator. = 1 %then %do;	 
			%put NOTE: Facility sort routine will be executed after assignment of the EDW header and detail variables. ;
		%end;
		%else %do;
			data temp1 temp2;
			  set &dsn. ;
			  if dq_member_flag=0 then output temp1;  /** good claims for the ciedw **/
			  else output temp2; /** bad claims but we want to report on them **/
			run;

			%vmine_pmsystem_byvars

			proc sort data = temp1 ; 
			  %if not %symexist(nlhold_reprocess) %then %do;  
			    by &&tranvars&system_id.;
			  %end;
			  %else %do;
			    by &tranvars0;
			  %end;			  
			run;

			data temp1 dups; 
			  set temp1 ;
			  %if not %symexist(nlhold_reprocess) %then %do;  
			    by &&tranvars&system_id.;
			  %end;
			  %else %do;
			    by &tranvars0;
			  %end;
			  if first.mod2 then output temp1;
			  else output dups;
			run;		

			data &dsn.;
			  set temp1 temp2;
			run;
		%end;
		
		proc sql noprint;
		  select count(*) into: dataset_count1
		  from &dsn. ;
		quit;
		  
		%put NOTE: Dataset Count: &dataset_count1. ;
		
		*--------------------------------------------------------------------------------
		| Determine thresholds for validations from history - set threshold values 
		+------------------------------------------------------------------------------*;	
		%dq_thresholds(client=&client_id, practice=&practiceid)
		
		data _null_;
		  set data_threshold ;
		  call symput(upcase(trim(data_quality))||"WARNING",TRIM(LEFT(warning_threshold_value)));
		  call symput(upcase(trim(data_quality))||"REJECT",TRIM(LEFT(reject_threshold_value)));
		run;


		*--------------------------------------------------------------------------------
		| Perform Variable Validations 
		+------------------------------------------------------------------------------*;
		%dq_validate_content_cio(datain=&datasetin., validate=filename )
		%dq_validate_content_cio(datain=&datasetin., validate=variables)
		%dq_create_dataset_cio
		%set_error_flag
		%on_error(ACTION=ABORT)

		*--------------------------------------------------------------------------------
		| Perform Threshold Validations  
		+------------------------------------------------------------------------------*;
		%dq_validate_data_threshold(var=validation_memberid, warningvalue=&memberidwarning., rejectvalue=&memberidreject.,  freqtitle=%str(Member ID Assessment))
		%dq_validate_data_threshold(var=validation_npi,      warningvalue=&npiwarning.,      rejectvalue=&npireject.,       freqtitle=%str(NPI Assessment))
		%dq_validate_data_threshold(var=validation_proccd,   warningvalue=&proccdwarning.,   rejectvalue=&proccdreject.,    freqtitle=%str(Procedure Assessment))
		%dq_validate_data_threshold(var=validation_diag1,    warningvalue=&diag1warning.,    rejectvalue=&diag1reject.,     freqtitle=%str(Diagnosis Assessment))
		%dq_validate_data_threshold(var=validation_svcdt,    warningvalue=&svcdtwarning.,    rejectvalue=&svcdtreject.,     freqtitle=%str(Service Date Assessment))
		%dq_validate_data_threshold(var=validation_sex,      warningvalue=&sexwarning.,      rejectvalue=&sexreject.,       freqtitle=%str(Gender Assessment))
		%dq_validate_data_threshold(var=validation_fname,    warningvalue=&fnamewarning.,    rejectvalue=&fnamereject.,     freqtitle=%str(First Name Assessment))
		%dq_validate_data_threshold(var=validation_lname,    warningvalue=&lnamewarning.,    rejectvalue=&lnamereject.,     freqtitle=%str(Last Name Assessment))
		%dq_validate_data_threshold(var=validation_dob,      warningvalue=&dobwarning.,      rejectvalue=&dobreject.,       freqtitle=%str(DOB Assessment))
		%dq_validate_data_threshold(var=validation_phone,    warningvalue=&phonewarning.,    rejectvalue=&phonereject.,     freqtitle=%str(Phone Assessment))
		%dq_validate_data_threshold(var=validation_address1, warningvalue=&address1warning., rejectvalue=&address1reject.,  freqtitle=%str(Address Assessment))
		%dq_validate_data_threshold(var=validation_city,     warningvalue=&citywarning.,     rejectvalue=&cityreject.,      freqtitle=%str(City Assessment))
		%dq_validate_data_threshold(var=validation_state,    warningvalue=&statewarning.,    rejectvalue=&statereject.,     freqtitle=%str(State Assessment))
		%dq_validate_data_threshold(var=validation_zip,      warningvalue=&zipwarning.,      rejectvalue=&zipreject.,       freqtitle=%str(Zipcode Assessment))
		%dq_validate_data_threshold(var=validation_pos,      warningvalue=&poswarning.,      rejectvalue=&posreject.,       freqtitle=%str(POS Assessment))


		*--------------------------------------------------------------------------------
		| Perform Threshold Validations 
		|  -Individual Value and Moving Range Control Charts 
		|  -Fraction Nonconforming Control Charts 
		+------------------------------------------------------------------------------*;
		%if &pgf_practice ne %then %do;
		  %put NOTE: PGF Practice. ;
		%end;
		%if &practice. = 11 %then %do;  
		  %put NOTE: Cracking Development Practice. ;
		%end;
		%else %do;
		  %dq_qualitycontrol_charts
	      %set_error_flag
	      %on_error(ACTION=ABORT)
		%end;


		*--------------------------------------------------------------------------------
		| PDF Report
		+------------------------------------------------------------------------------*;
		title; footnote;
		options msglevel=i orientation='landscape' nodate nonumber;
		options leftmargin=1in 	rightmargin=1in topmargin=0.25in	bottommargin=.25in;
		ods escapechar='~';

		%if &dataformatgroupid.=20 %then %do;
			%if &facility_indicator. %then %do;
				%let xl = %str(&reportdir.\DataQuality_payer_ub_%lowcase(&clientdir)_&pgf_practice._&wflow_exec_id._&pdf_report_date..pdf);
			%end;
			%else %do;
				%let xl = %str(&reportdir.\DataQuality_payer_hcfa_%lowcase(&clientdir)_&pgf_practice._&wflow_exec_id._&pdf_report_date..pdf);
			%end;
			filename xl "&xl.";
			proc datasets library=work nolist;
				delete fn_controlcharts_filedt;
			quit;
		%end;
		%else %if &pgf_practice ne %then %do;
		  %let xl = %str(&reportdir.\DataQuality_pgf_%lowcase(&clientdir)_&pgf_practice._&wflow_exec_id._&pdf_report_date..pdf);
		  filename xl "&xl.";
		  proc datasets library=work nolist;
 			delete fn_controlcharts_filedt;
		  run;
		  quit;
        %end;
	    %else %do;
		  %let xl = %str(&reportdir.\DataQuality_vmine_%lowcase(&clientdir.)_&practice._&wflow_exec_id._&pdf_report_date..pdf);
		  filename xl "&xl.";
	    %end;

		ods listing close;
		ods pdf  file=xl style=sasweb pdftoc=1 columns=1  author='Valence Health'  Subject='vMine File Upload Status' Title='Upload Summary' ;

			title1 c=&bcolor h=12pt f="times" j=c "Clinical Integration - &clientname."  ; 
		    %if &practice eq 0 %then %do;
			  title2 c=&bcolor justify=left h=10pt f="times"	"Practice: &practiceid - &practicename"    h=14pt j=c 'Practice Data Summary Report'  h=10pt j=r "Prepared: %sysfunc(today(),mmddyy10.)"; 
		    %end;
		    %else %do;
			  title2 c=&bcolor justify=left h=10pt f="times"	"Practice: &practice - &practicename"   h=14pt j=c 'Practice Data Summary Report'  h=10pt j=r "Prepared: %sysfunc(today(),mmddyy10.)"; 
		    %end;		
			title3 c=&bcolor justify=center '~S={preimage="\\ebicompute\Projects\tools\images\PGF_PDFHEADER.gif"}';
			footnote1 justify=center '~S={preimage="\\ebicompute\Projects\tools\images\PGF_PDFHEADER.gif"}';
			footnote2 justify=left h=8pt f="times" "Valence Health" j=r h=8pt "Practice Data Summary - ~{thispage}"; 

			%dq_combine_datasets(critical_variables_list=&critical_claim_variables.)
			%dq_descriptive_statistics_cio
			%dq_create_reports

		ods pdf close;
		ods listing;
		title; footnote;

		*--------------------------------------------------------------------------------
		| Append to History and Email if any issues
		+------------------------------------------------------------------------------*;	
		%dq_history_cio
		

		*--------------------------------------------------------------------------------
		| update_dq_claim_flag - Update claim flag
		+------------------------------------------------------------------------------*;
		%macro update_dq_claim_flag(critical_variables_list=);

			proc contents data = pm_&practice_id
			              out  = contents_validations (keep = name) noprint;
			run; 

			data contents_validations;
			  set contents_validations;
			  x=left(substr(upcase(name),7));
			  if substr(upcase(name),1,6) = 'ISSUE_';
			  if left(substr(upcase(name),7)) in (&critical_variables_list.) ; /** 4 critical validations **/
			run;

			data _null_;
			  set contents_validations end=eof;
			  i+1;
			  ii=left(put(i,4.));	 
			  call symput('dq'||ii,trim(name));
			  if eof then call symput('dq_total',ii);	 
			run;

			data &dsn. ;
			 set pm_&practice_id. ;
			 %do g = 1 %to &dq_total. ;
				 %if &g = 1 %then %do;
				   if &&dq&g ne '' 
				 %end;
				 %else %do;
				   or &&dq&g ne ''
				 %end;
				 %if &g. = &dq_total. %then %do;
				   then dq_claim_flag=1;
				   else dq_claim_flag=0;
				 %end;
			 %end;
			run;

		%mend update_dq_claim_flag;

		*--------------------------------------------------------------------------------
		| create_detail_header_variables - Prepare the data for the CIEDW
		+------------------------------------------------------------------------------*;
		%macro create_detail_header_variables;

			*SASDOC--------------------------------------------------------------------------
			| Determine diagnosis variables per pm system - practice.   
			+------------------------------------------------------------------------SASDOC*;
			proc contents data = &dsn.
			              out  = contents_diag (keep = name) noprint;
			run;

			proc sql noprint;
		      select distinct(name), count(*) into : diag_names separated by ' ',  : diag_total
			  from contents_diag
			  where substr(upcase(name),1,4)='DIAG'
		        and substr(upcase(name),6,1)='';
			quit;

			%put NOTE: diag_names = &diag_names ;
			%put NOTE: diag_total = &diag_total ;
			
			*SASDOC--------------------------------------------------------------------------
			| Determine surgical variables per pm system - practice.   
			+------------------------------------------------------------------------SASDOC*;
			proc contents data = &dsn.
			              out  = contents_surg (keep = name) noprint;
			run;

			proc sql noprint;
		      select distinct(name), count(*) into : surg_names separated by ' ',  : surg_total
			  from contents_surg
			  where substr(upcase(name),1,11)='SURGICAL_CD' ;
			quit;

			%put NOTE: surg_names = &surg_names ;
			%put NOTE: surg_total = &surg_total ;

			data date_time;
			  date=datetime() ; 
			  _dt=datepart(date);
			  _tm=timepart(date);
		    run; 
		    
			proc sql noprint;
			select quote(diagnosis_cd) into: sensitive_diagnosis_cd separated by ','
			from ciedw.diagnosis
			where IS_SENSITIVE=1;
			quit;
			
			%put NOTE: sensitive_diagnosis_cd = &sensitive_diagnosis_cd. ;
				
			
			*SASDOC--------------------------------------------------------------------------
			| Create enounter header and detail variables.    
			+------------------------------------------------------------------------SASDOC*;
			%let ect_dsid=%sysfunc(open(&dsn.));
			%let ect_admdiag_ind=%sysfunc(varnum(&ect_dsid.,admdiag));
			%let ect_billtype_ind=%sysfunc(varnum(&ect_dsid.,bill_type));
			%let ect_discond_ind=%sysfunc(varnum(&ect_dsid.,dis_cond));
			%let ect_sbdate_ind=%sysfunc(varnum(&ect_dsid.,sbdate));
			%let ect_dsrc=%sysfunc(close(&ect_dsid.));
			data &dsn.;
			  format service_date admit_date discharge_date $20. validation_value $32. ; 
			  format service_date2   datetime22.3 ; 
			  if _n_=1 then set date_time;
			  set &dsn.;

			    s_date=dhms(svcdt,0,0,0);
			    s_dt=datepart(s_date);
			    s_tm=timepart(s_date);
			    service_date = put(s_dt,yymmdd10.)||" "||put(s_tm,time8.);

				load_flag=0;
				validation_value="";
			  %if &dataformatgroupid. ne 20 %then %do;
				payer_key=.;
			  %end;
				member_key=member_key; 
				provider_key=provider_key; 
				practice_key=practice_key;
				data_source_id=&practice_id.;
				 
				*SASDOC--------------------------------------------------------------------------
				| Assign diagnosis variables
				| Fix any codes that are a length of 4 with a decimal in the fourth location
				------------------------------------------------------------------------SASDOC*;				
				%do diag = 1 %to 9;
				  %if &diag le &diag_total. %then %do;
				    diagnosis_cd&diag.=diag&diag.;
				    if length(diagnosis_cd&diag.)=4 then do;
				      if substr(diagnosis_cd&diag.,4,1) ='.' then do;
				        diagnosis_cd&diag.=substr(diagnosis_cd&diag.,1,3);
				        diag&diag.=substr(diag&diag.,1,3);
				      end;
				    end;
				  %end;
				  %else %do;
				    diagnosis_cd&diag.='';
					diag&diag.='';
				  %end;
				%end; 

				*SASDOC--------------------------------------------------------------------------
				| Assign sensitive diagnosis variables
				------------------------------------------------------------------------SASDOC*;												
				%do w = 1 %to 9;
				 is_sensitive_diag&w.=0;				 
				%end;
				
				is_sensitive=0;
				

				*SASDOC--------------------------------------------------------------------------
				| Assign surgical codes variables
				------------------------------------------------------------------------SASDOC*;								
				%do surg = 1 %to 6;
				  %if &surg le &surg_total. %then %do;
				    surgical_cd&surg.=surgical_cd&surg.;
				  %end;
				  %else %do;
				    surgical_cd&surg.=''; 
				  %end;
				%end;

				file_date_key=1;	
				pos=pos;
				tin=tin;
				detail_key=_n_;
				encounter_key=1;
				client_key=client_key; 
				service_date2=dhms(svcdt,0,0,0);
				mod1=mod1;
				mod2=mod2;				
				  if submit > 1000000 then do;  /** values greater will cause SQL to fail **/
				    submit = 0;
				  end;				
				submitted=submit;				
				units=units;
				wflow_exec_id=&wflow_exec_id.;
				vmine_kprocessid=maxprocessid;
				
				created_by=&sasprogramby.; 
				updated_by=&sasprogramby.;


				*SASDOC--------------------------------------------------------------------------
				| Facility Logic    
				------------------------------------------------------------------------SASDOC*;
				%if &facility_indicator. = 1 %then %do;
				    a_date=dhms(admdt,0,0,0);
				    a_dt=datepart(a_date);
				    a_tm=timepart(a_date);
				    admit_date = put(a_dt,yymmdd10.)||" "||put(a_tm,time8.);	  
				    if indexc(admit_date,'0123456789')= 0 then admit_date='';
				    
				    d_date=dhms(disdt,0,0,0);
				    d_dt=datepart(d_date);
				    d_tm=timepart(d_date);
				    discharge_date = put(d_dt,yymmdd10.)||" "||put(d_tm,time8.);	
				    if indexc(discharge_date,'0123456789')= 0 then discharge_date='';

					%if &ect_billtype_ind.=0 %then %do; bill_type=''; %end;
					%if &ect_discond_ind. %then %do; discharge_status=dis_cond; %end; %else %do; discharge_status=''; %end;
					%if &ect_admdiag_ind. %then %do;
						if admdiag='' then admit_diagnosis_cd=.;
						else admit_diagnosis_cd=put(admdiag, $aDiag5cd.)*1;
					%end;
					%else %do;
						admit_diagnosis_cd=.;
					%end;
					%if &ect_sbdate_ind. %then %do;
					    statement_begin_date = sbdate;	
					    if indexc(statement_begin_date,'0123456789')= 0 then statement_begin_date='';
					    statement_end_date = sedate;	
					    if indexc(statement_end_date,'0123456789')= 0 then statement_end_date='';
					%end;

				    drg_key=input(drg,8.);
				    referral='';
				    revenue_code=revcd;
				    market_value=1; 
				    maj_cat_name=majcat; 				    
				%end;
				%else %do; /* begin - facility_indicator=0 */
				    admit_date='';
				    discharge_date='' ;
					%if &dataformatgroupid.=20 %then %do;
				    	drg_key=.;
					    admit_diagnosis_cd=.;
					%end;
					%else %do;
				    	drg_key=1;
					    admit_diagnosis_cd=1;
					%end;						
				    bill_type='';
				    discharge_status='';
				    referral='';
				    revenue_code='';
				    market_value=1;
							
					%if &ContainMajcat. %then %do;
						maj_cat_name=majcat;
					%end;
					%else %do; /* begin - majcat assignment for facility_indicator=0 */
						if '10000'<=proccd<'70000' then do;
							if pos in ('21') then maj_cat_name=14;   *IP SURG ;
							else maj_cat_name=16;*OP SURG;
						end;
						else if '00000'<=proccd<'09999' then maj_cat_name =17; * ANESTHESIA ;
						else if '99100'<=proccd<='99140' then maj_cat_name=17; *ANESTHESIA;
						else if ('00000'<=proccd<'69999') and ( mod1 = '23' /* or provspec = '05'*/ ) then maj_cat_name =17; * ANESTHESIA;
						else if '99301'<=proccd<'99333' then maj_cat_name=18; * NURSING FACILITY VISITS ;
						else if '99255'<proccd<'99255' or '99217'<=proccd<='99239'  or '99291'<=proccd<='99301' or  
						'99431'<=proccd<='99440' or proccd='99356' then maj_cat_name=18; * IP VISIT;
						else if proccd='99391' or proccd='99432' then maj_cat_name=19;  *PHYSICAL EXAMS;
						else if '99381'<=proccd<='99404' then maj_cat_name=19; * WELL VISITS;
						else if '99201'<=proccd<='99215' then maj_cat_name = 19; *OTHER VISITS;
						else if '99354'<=proccd<='99355' then maj_cat_name = 19; *OTHER VISITS;
						else if '99347'<=proccd<='99347' then maj_cat_name = 19; *OTHER VISITS;
						else if proccd = 'T1015' then maj_cat_name = 19; *Clinic Visit;
						else if '99281'<=proccd<'99288' then maj_cat_name=20;  * ER OVERLAPS WITH BELOW ;
						else if '99241'<=proccd<='99275' then maj_cat_name =21; * CONSULT ;
						else if '99271'<=proccd<'99275' then maj_cat_name=21;  * CONSULT OVERLAPS WITH BELOW (LOTS MORE CODES>);
						else if '59000'<=proccd<'60000' then DO;
						if pos = '21' then maj_cat_name = 15; * IP SURGERY-OB;
						else maj_cat_name=22; *OB;
						end;
						else if '70000'<=proccd<'80000' then maj_cat_name=23;  *RAD;
						else if '80000'<=proccd<'90000' then maj_cat_name=24;  *PATH;
						else if '90471'<=proccd<'90472' then maj_cat_name=25; * IMMUNIZ;
						else if '90300'<=proccd<'90749' then maj_cat_name=25; * IMMUNIZ;
						else if '90700'<=proccd<='90799' then maj_cat_name=25; * THERE INJECTION;
						else if '92225'<=proccd<='92599' then maj_cat_name=26; *VISION HEAR ALLERGY IMMUNO;
						else if ('95807'<=proccd<='95999') OR ('96100'<=proccd<='96117') then maj_cat_name=26; *NEURO TESTING;
						else if '92900'<=proccd<='94990' then maj_cat_name=26; *CARDIO ;
						else if '90900'<=proccd<='90999' then maj_cat_name=26; *CARDIO ;
						else if '91000'<=proccd<='91299' then maj_cat_name=26; *CARDIO ;
						else if '95004'<=proccd<='95078' then maj_cat_name=26; *ALLERGY ER ;
						else if '92002'<=proccd<='92083' then maj_cat_name=26; * VISION ALLERGY IMMUNO - check;
						else if '95115'<=proccd<='95199' then maj_cat_name=27; * ALLERGY TESTING;
						else if '96900'<=proccd<='96999' then maj_cat_name=27; * SPECIAL DERMATOLIGICAL ;
						else if '97000'<=proccd<='98929' then maj_cat_name=27; * ;
						else if '96400'<=proccd<='96549' then maj_cat_name=27; * THERAPEUTIC INJ;
						else if proccd = '92507' then maj_cat_name = 27;  * changed 11/15/00;
						else if '99000'<=proccd<='99199' then maj_cat_name=28; *MISC  ;
						else if substr(proccd,1,1)='J' then do;
						    if proccd = "J7300" then maj_cat_name=31;
							else if pos = '12' then maj_cat_name = 29;
							else maj_cat_name=25;  *THERA INJ;
						end;
						else if substr(proccd,1,1) = 'A' and (pos = '41' /*or provspec = '03'*/) then maj_cat_name = 30; * ambulance changed 5/29/01;
						else if substr(proccd,1,1) in ('A','B','E','K','L') then maj_cat_name=31; *DME;
						else if '92002'<=proccd<='92286' then maj_cat_name=32; *VISION ;
						else if substr(proccd,1,1) in ('V') then maj_cat_name=32; *vision;
						else if '90801'<=proccd<='90815' then maj_cat_name=33; * MENTAL & NERVOUS OP;
						else if '90816'<=proccd<='90857' then maj_cat_name=33; * MENTAL & NERVOUS IP;
						else if '90862'<=proccd<='90899' then maj_cat_name=33; * MENTAL & NERVOUS OP;
						else if substr(proccd,1,1) in ('D') then maj_cat_name=34; *dental;
						else if ('90801'<=proccd<'90857') or ('90862'<=proccd<'90899')then maj_cat_name=39; * MENTAL & NERVOUS IP&OP; 
						else if proccd in ('96100','H2017','96117','97033','H2017','M0064') then maj_cat_name=39; *MENTAL & NERVOUS;
						/*else if provspec in ('75','36','37','75','74') and ('99222'<=proccd<='99239') then maj_cat_name = 39;  */
						else maj_cat_name = 99;

						if maj_cat_name = 99 then do;
							if proccd = '9020X' then maj_cat_name =19;
							else if proccd = '8000Y' then maj_cat_name =19;
							else if proccd = 'Y6007' then maj_cat_name =30;
							else if pos = '41' then maj_cat_name = 30;
							else if proccd = '5226X' then maj_cat_name =31;
							else maj_cat_name = 28;
						end;
						if maj_cat_name = . then maj_cat_name = 52;
					%end; /* end - majcat assignment for facility_indicator=0 */
				%end; /* end - facility_indicator=0 */
				
			        %if %symexist(nlhold_reprocess) %then %do;
				    member_key_old=.;
			        %end;

			  drop date _dt _tm s_dt s_tm s_date 
			  	%if &facility_indicator. = 1 and &dataformatid. = 56 %then %do; 
				  a_date a_dt a_tm d_date d_dt d_tm sb_dt sb_tm se_dt se_tm
				%end; 
				%else %if &facility_indicator. = 1 %then %do; 
				  a_date a_dt a_tm d_date d_dt d_tm
				%end; ;
			run;
			
			


			
			%macro build_missing_edw_variables;

					*SASDOC--------------------------------------------------------------------------
					| Add fields to staging dataset to avoid errors when loading NL_HOLD and HOLD tables
					+------------------------------------------------------------------------SASDOC*;
					data header_names;
					  set ciedw.ENCOUNTER_HEADER (obs=5);
					  drop encounter_key;
					run;
					
					data detail_names;
					  set ciedw.ENCOUNTER_DETAIL (obs=5);
					  drop encounter_key detail_key ;
					run;

					data startnames;
					  set &dsn. (obs=5);
					run;

					proc contents data=startnames
					      out = startnames (keep=name varnum type) noprint;
					run;

					data startnames;
					  set startnames;
					  name=lowcase(name);
					run;

					proc contents data = header_names 
						   out = header_names (keep=name varnum type)  noprint;
					run;
					
					proc contents data = detail_names 
						   out = detail_names (keep=name varnum type)  noprint;
					run;
					
					data header_names;
					 set header_names;
					 name=lowcase(name);
					 if name in ('statement_begin_date','statement_end_date') then type=2;
					run;					 

					proc sort data = header_names;
					  by varnum;
					run;

					data detail_names;
					 set detail_names;
					 name=lowcase(name);
					run;
					
					proc sort data = detail_names;
					  by varnum;
					run;

					%let cmiss = = ' '  ;
					%let nmiss = = .  ;

					proc sql;
						create table allmiss as
							select 
								a.name,
								a.type,
								case when a.type = 1 then left(trim(a.name))||left(trim("&nmiss." ))||left(trim(";"))
									 when a.type = 2 then left(trim(a.name))||left(trim("&cmiss."))||left(trim(";"))
									 end as rslt
							from header_names a left outer join 
								 startnames   b on a.name=b.name
							where b.type = .

							union

							select 
								a.name,
								a.type,
								case when a.type = 1 then left(trim(a.name))||left(trim("&nmiss." ))||left(trim(";"))
									 when a.type = 2 then left(trim(a.name))||left(trim("&cmiss."))||left(trim(";"))
									 end as rslt
							from detail_names a left outer join 
								 startnames   b on a.name=b.name
							where b.type = . 
						;
					quit;

					%let varexist_id=%sysfunc(open(&dsn.));
					%let varexist_ind=%sysfunc(varnum(&varexist_id.,poa1));
					%let varexist_rc=%sysfunc(close(&varexist_id.));

					%put NOTE: MACRO VARAIABLE TO CHECK IF POA1 EXISTS - varexist_ind = &varexist_ind.;
					
					data allmiss;
					set allmiss;
					if lowcase(name) in ('updated_on','updated_by','created_on','created_by',
					                     'procedure_code_key','claim_id'
										 %if &varexist_ind. > 0 %then %do;
										 ,'poa1_pfkey','poa2_pfkey','poa3_pfkey','poa4_pfkey','poa5_pfkey',
										 'poa6_pfkey','poa7_pfkey','poa8_pfkey','poa9_pfkey'
										 %end;) then delete;
					run;

					proc sql noprint;
					  select count(*) into: cntall
					  from allmiss  ;
					quit;

					%if &cntall > 0 %then %do;
						proc sort data=allmiss nodupkey;by rslt;run;

						proc sql noprint;
						  select rslt into: lines separated by ' '
						  from allmiss;
						quit;

						data &dsn.;
						  set &dsn.;
						  &lines.;
						run;

					%end;	

			%mend build_missing_edw_variables;
			%build_missing_edw_variables

			proc sql undo_policy=none;
			  create table &dsn.  as
			  select a.*,   
			         coalesce(c.procedure_code_key,0) as procedure_code_key
			  from &dsn.  a  
			  left outer join ciedw.procedure_cd c 
			    on a.proccd = c.procedure_code;
			quit;


			%let varexist_id=%sysfunc(open(&dsn.));
			%let varexist_ind=%sysfunc(varnum(&varexist_id.,poa1));
			%let varexist_rc=%sysfunc(close(&varexist_id.));

			%put NOTE: MACRO VARAIABLE TO CHECK IF POA1 EXISTS - varexist_ind = &varexist_ind.;

			%if &varexist_ind. > 0 %then %do;
				proc sql undo_policy=none;
					create table &dsn.  as
						select 
							a.*,   
							b.preset_flag_key as poa1_pfkey,
							c.preset_flag_key as poa2_pfkey,
							d.preset_flag_key as poa3_pfkey,
							e.preset_flag_key as poa4_pfkey,
							f.preset_flag_key as poa5_pfkey,
							g.preset_flag_key as poa6_pfkey,
							h.preset_flag_key as poa7_pfkey,
							i.preset_flag_key as poa8_pfkey,
							j.preset_flag_key as poa9_pfkey
						from &dsn. 				as a left outer join 
							 ciedw.preset_flag 	as b on a.poa1 = b.preset_flag_desc left outer join
							 ciedw.preset_flag 	as c on a.poa2 = c.preset_flag_desc left outer join
							 ciedw.preset_flag 	as d on a.poa3 = d.preset_flag_desc left outer join
							 ciedw.preset_flag 	as e on a.poa4 = e.preset_flag_desc left outer join
							 ciedw.preset_flag 	as f on a.poa5 = f.preset_flag_desc left outer join
							 ciedw.preset_flag 	as g on a.poa6 = g.preset_flag_desc left outer join
							 ciedw.preset_flag 	as h on a.poa7 = h.preset_flag_desc left outer join
							 ciedw.preset_flag 	as i on a.poa8 = i.preset_flag_desc left outer join
							 ciedw.preset_flag 	as j on a.poa9 = j.preset_flag_desc
					;
				quit;
			%end;
			
			%if &facility_indicator. = 1 %then %do;	 
				%facility_sort_routine(dataset_in=&dsn. , edw=yes)			
			%end;			
			
			%global pre_count ;
			
			proc sql noprint;
			  select count(*) into: pre_count 
			  from &dsn. ;
			quit;
						
		%mend create_detail_header_variables;


		*--------------------------------------------------------------------------------
		| validate_claims_exists - create a temporary encounter header detail table
		| for validating if the new claims are classified as the following:
		|  1.  new - insert load
		|  2.  change - update load
		|  3.  critical - no load 
		+------------------------------------------------------------------------------*;
		%macro validate_claims_exists;

			%if %sysfunc(exist(cihold.saswrk_header_detail_&wflow_exec_id.)) %then %do;
			    proc sql;
			      connect to oledb(init_string=&cihold.);
			      execute ( 
			                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
			              ) 
			      by oledb; 
			    quit;
			%end;
					
			/**--------------------------------------------------------------------------------
			    Step 1 - Match claims with encounter table 
			--------------------------------------------------------------------------------**/
			proc sql;
				create table ect_pk_list as
				select	distinct person_key
				from	&dsn.;
			quit;
			%bulkload_to_cio(&wflow_exec_id.,ect_pk_list);

			proc sql;
				connect to oledb(init_string=&sqlci.);
				execute ( 
							create nonclustered index [tablekey] on cihold.dbo.saswrk_bulkload_&wflow_exec_id.
							(
								[person_key] ASC
							)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
						)
				by oledb;
			quit;

		    proc sql;
		      connect to oledb(init_string=&sqlci.);
		      execute ( 
					 select distinct 
					       a.[client_key] 
					      ,m.[member_key] 
					      ,a.[practice_key]
						  ,a.[provider_key]
 
					      ,b.[procedure_code_key] 
					      ,b.[service_date]
					      ,b.[mod1]
						  ,b.[mod2]
					  %if &facility_indicator. %then %do;
					  	  ,b.[revenue_code]
					  %end;				      
						  ,1 as claim_exists_key

					 into  [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  

					 from  [ciedw].[dbo].[encounter_detail](nolock) as b inner join				 
					       [ciedw].[dbo].[encounter_header](nolock) as a on a.encounter_key=b.encounter_key
					         											and a.client_key=b.client_key inner join
						   cihold.dbo.saswrk_bulkload_&wflow_exec_id. as c on a.person_key=c.person_key inner join
						   [ciedw].[dbo].[person_member_map](nolock) as m on a.client_key=m.client_key 
																		and a.person_key = m.person_key	
				         
					 where a.client_key=&client_id.
					   and b.data_source_id=&practice_id.
		             ) 
		      by oledb; 
		    quit;

			proc sql undo_policy=none;
		      create table &dsn. as
		      select a.*,
		             coalesce(b.claim_exists_key,0) as claim_exists_key 
			  from &dsn.  a 
			  left outer join cihold.saswrk_header_detail_&wflow_exec_id. b
			  on a.client_key=b.client_key 
			    and a.member_key=b.member_key
			    and a.practice_key=b.practice_key
			    and a.procedure_code_key=b.procedure_code_key
			    and a.service_date2=b.service_date
				and a.provider_key=b.provider_key
			    and a.mod1=b.mod1
				and a.mod2=b.mod2
			%if &facility_indicator. %then %do;
				and a.revenue_code=b.revenue_code
			%end;
				;
		    quit;

			proc sql;
			  connect to oledb(init_string=&cihold.);
			  execute ( 
						drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]
						drop table cihold.dbo.saswrk_bulkload_&wflow_exec_id.
					  ) 
			  by oledb; 
			quit;

			proc sql noprint;
			  select count(*) into: post_count1 
			  from &dsn. ;
			quit;
			%put NOTE: post_count after matching to encounter = &post_count1.;

			/**--------------------------------------------------------------------------------
			        Step 2 - Match claims with NL HOLD encounter with member key ne 0.
				This is to ensure that when we do member load, if member is valid and in satellite tables but claims
				are already in NL HOLD, we recognize that and we do not duplicate the satellite counters.
			--------------------------------------------------------------------------------**/
			
			proc sql;
				create table exist_nlhold_clms1 as
				select	distinct n.client_key, practice_id, coalesce(m.member_key,0) as member_key, 
						trim(npi) as npi, service_date, trim(proccd) as proccd, trim(mod1) as mod1, trim(mod2) as mod2, 
					%if &facility_indicator. %then %do;
			  			trim(revenue_code) as revenue_code,
					%end; 
						1 as claim_exists_key
				from	cihold.nl_hold_encounter_header_detail n left join
				        ciedw.person_member_map as m on n.person_key = m.person_key and n.client_key=m.client_key
				where	n.client_key=&client_id.
				and		practice_id=&practice_id.
				and		coalesce(m.member_key,0) ne 0;
			quit;

			%let ect_dsid=%sysfunc(open(exist_nlhold_clms1));
			%let ect_nobs=%sysfunc(attrn(&ect_dsid.,nobs));
			%let ect_dsrc=%sysfunc(close(&ect_dsid.));

			%if &ect_nobs. %then %do;
				proc sql undo_policy=none;
					create table &dsn.(drop=claim_exists_key rename=(new_claim_exists_key=claim_exists_key)) as
					select	a.*, coalesce(b.claim_exists_key,a.claim_exists_key) as new_claim_exists_key
					from	&dsn. a left join exist_nlhold_clms1 b 
					on 		a.client_key=b.client_key and a.practice_id=b.practice_id
					and		a.member_key=b.member_key
					and		a.npi=b.npi
					and		a.service_date2=b.service_date
					and		a.proccd=b.proccd and a.mod1=b.mod1 and a.mod2=b.mod2
				  %if &facility_indicator. %then %do;
					and 	a.revenue_code=b.revenue_code
				  %end;
					;

					drop table exist_nlhold_clms1;
				quit;
			%end;

			/**--------------------------------------------------------------------------------
			        Step 3 - Match claims with NL HOLD encounter with member key = 0.
				This is to ensure that in onboarding 2nd pass, we've seen the claim before from 1st pass,
				and that all claims should be flagged as claim_exists_key=1 to not duplicate the satellite counters.
			--------------------------------------------------------------------------------**/
			%let dsn_mk0_ind=0;
			proc sql noprint;
				select	count(*)
				into	:dsn_mk0_ind
				from	&dsn.
				where	member_key=0;
			quit;

			%if &dsn_mk0_ind. ne 0 %then %do;
				proc sql undo_policy=none;
					create table exist_nlhold_clms2 as
					/* Add person_key in select to replace all patient demographics. Using PERSON_KEY will also include PATID/system_member_id. 
						If not, we might have a case where member_key is now assigned (say due to PATID exists), and NL hold has a copy
						without member key, and this step 3 will flag claim_exists, but member load will NOT load that new member key (i.e. new person key due to PATID)
						to person_workflow_detail, and we won't be creating patient_detail or patient_detail_map for the new member key. So, if PERSON_KEY does not
						match when member_key=0 from NL HOLD, then we will treat as new claim, which will technically double counters in person_workflow_detail, but
						this is the least intrusive way to fix this problem. G 6/18/12 */
					select	distinct n.client_key, practice_id, coalesce(m.member_key,0) as member_key, n.person_key, 
							trim(npi) as npi, service_date, trim(proccd) as proccd, trim(mod1) as mod1, trim(mod2) as mod2, 
						%if &facility_indicator. %then %do;
				  			trim(revenue_code) as revenue_code,
						%end; 
							1 as claim_exists_key
					from	cihold.nl_hold_encounter_header_detail n left join
					        ciedw.person_member_map as m on n.person_key = m.person_key and n.client_key=m.client_key
					where	n.client_key=&client_id.
					and		n.practice_id=&practice_id.
					and		coalesce(m.member_key,0)=0
					and		n.dq_member_flag=0 /* this line is temporary fix. this contradicts with step 3 member key=0. this step 3 might
													be obsolete now that we are using person key instead of member key. need to think this
													through. G 7/18/12 */
					;

					create table &dsn.(drop=claim_exists_key rename=(new_claim_exists_key=claim_exists_key)) as
					select	a.*, coalesce(b.claim_exists_key,a.claim_exists_key) as new_claim_exists_key
					from	&dsn. a left join exist_nlhold_clms2 b 
					on 		a.client_key=b.client_key and a.practice_id=b.practice_id
					and		a.person_key=b.person_key
					and		a.npi=b.npi
					and		a.service_date2=b.service_date
					and		a.proccd=b.proccd and a.mod1=b.mod1 and a.mod2=b.mod2
				%if &facility_indicator. %then %do;
					and 	a.revenue_code=b.revenue_code
				%end;
					;

					drop table exist_nlhold_clms2;
				quit;
			%end;
 
			proc sql noprint;
			  select count(*) into: post_count 
			  from &dsn. ;
			quit;
			
		    %if &pre_count. = &post_count. %then %do;
		        %put NOTE: Data set counts match - pre_count = &pre_count. post_count = &post_count.;
		    %end;
		    %else %do;
				%put WARNING: Data set have match issue - pre_count = &pre_count. post_count = &post_count.;
				
				%macro send_email_alert;
					filename mail_out email to=("edwprod@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - Transformation Failed";

					data _null_;
					file mail_out lrecl=32767; 
					put "practice ID = &do_practice_id.";
					put "system ID = &system_id.";
					run;
				%mend send_email_alert;
				%send_email_alert

		    	%bpm_additional_validations(validation_rule=53,validation_count=0)
		    %end;

		*--------------------------------------------------------------------------------
		| Temp table used in the bpm validation steps
		+------------------------------------------------------------------------------*;

			%if %sysfunc(exist(cihold.saswrk_header_detail_&wflow_exec_id.)) %then %do;
			    proc sql;
			      connect to oledb(init_string=&cihold.);
			      execute ( 
			                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
			              ) 
			      by oledb; 
			    quit;
			%end;
					

		    proc sql;
		      connect to oledb(init_string=&sqlci.);
		      execute (
					 select 
					       a.[encounter_key] as encounter_key_ciedw
					      ,a.[client_key] 
					      ,m.[member_key] 
					      ,a.[practice_key]
						  ,a.[provider_key]
						  ,a.[payer_key]
						  ,a.[admit_diagnosis_cd]
						  ,a.[drg_key]
						  ,a.[diagnosis_cd1]
						  ,a.[diagnosis_cd2]
						  ,a.[diagnosis_cd3]
						  ,a.[diagnosis_cd4]
						  ,a.[diagnosis_cd5]
						  ,a.[diagnosis_cd6]
						  ,a.[diagnosis_cd7]
						  ,a.[diagnosis_cd8]
						  ,a.[diagnosis_cd9]
						  ,a.[file_date_key]
						  ,a.[admit_date]
						  ,a.[discharge_date]
						  ,a.[bill_type]
						  ,a.[discharge_status]
						  ,a.[pos]
						  ,a.[tin]
						  ,a.[referral]
					      
					      ,b.[detail_key] as detail_key_ciedw     
					      ,b.[procedure_code_key]
						  ,b.[revenue_code]
					      ,b.[service_date]
					      ,b.[mod1]
						  ,b.[mod2]
						  ,b.[maj_cat_name]
						  ,b.[submitted]
						  ,b.[units]
						  ,b.[vmine_kprocessid]

						  ,1 as claim_exists_key

					 into  [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  

					       
					 from  [ciedw].[dbo].[encounter_detail](nolock) as b inner join				 
					       [ciedw].[dbo].[encounter_header](nolock) as a 
					      on a.encounter_key=b.encounter_key
					      and a.client_key=b.client_key inner join						       
				         [ciedw].[dbo].[person_member_map](nolock) as m 
				         on a.client_key=m.client_key and a.person_key = m.person_key	
				         
					 where a.client_key=&client_id.
					   and b.data_source_id=&practice_id.
		             ) 
		      by oledb; 
		    quit;

		%mend validate_claims_exists;


	    *SASDOC--------------------------------------------------------------------------
	    | EDW - Perform claim transformations
	    |  1.  Update claim flag
	    |  2.  Create detail and header variables for the EDW
	    |  3.  Create claims exist key 
	    |
	    +------------------------------------------------------------------------SASDOC*; 
		%update_dq_claim_flag(critical_variables_list=&critical_claim_variables.)
		%create_detail_header_variables
		%validate_claims_exists
	    %set_error_flag
	    %on_error(ACTION=ABORT)

	    *SASDOC--------------------------------------------------------------------------
	    | EDW - Perform claim validations on the data and set the prevent load indicator     
	    |  1.  validations - claim new 
	    |  2.  validations - claim change
	    |  3.  validations - claim critical
	    |
	    +------------------------------------------------------------------------SASDOC*; 
	    %edw_claim_validations(vt_name=NEW ,  	validation_type_id=28,in_dataset1=&dsn.,by_variable=claim_key)
	    %edw_claim_validations(vt_name=CHANGE,	validation_type_id=29,in_dataset1=&dsn.,by_variable=detail_key_ciedw)
	    %edw_claim_validations(vt_name=CRITICAL,validation_type_id=30,in_dataset1=&dsn.,by_variable=claim_key,
                      critical_variables_list=&critical_claim_variables.) /** values - 30 thru 34 **/
	    %set_error_flag
	    %on_error(ACTION=ABORT)

		%if %sysfunc(exist(cihold.saswrk_header_detail_&wflow_exec_id.)) %then %do;
		    proc sql;
		      connect to oledb(init_string=&cihold.);
		      execute ( 
		                drop table [cihold].[dbo].[saswrk_header_detail_&wflow_exec_id. ]  
		              ) 
		      by oledb; 
		    quit;
		%end;

	    *SASDOC--------------------------------------------------------------------------
	    | BPM - Insert claims data into edw.validations
	    |
	    +------------------------------------------------------------------------SASDOC*; 
	    %if not %symexist(nlhold_reprocess) %then %do;
		    %bpm_validations(in_dataset=edw_claim_validate_new)
		    %bpm_validations(in_dataset=edw_claim_validate_change)
		    %bpm_validations(in_dataset=edw_claim_validate_critical, claims=1)
	    %end;


	    *SASDOC--------------------------------------------------------------------------
	    | BPM - Insert claims data into edw.validations_detail
	    +------------------------------------------------------------------------SASDOC*; 
	    %if not %symexist(nlhold_reprocess) %then %do;
		    %bpm_validation_detail(in_datasets=%str(edw_claim_validate_critical edw_claim_validate_new edw_claim_validate_change ))
		    %set_error_flag
		    %on_error(ACTION=ABORT)
	    %end;
	    
	    *SASDOC--------------------------------------------------------------------------
	    | BPM - Create source and target counts             
	    +------------------------------------------------------------------------SASDOC*;
		proc sql noprint;
		  select count(*) into: src_record_cnt
		  from &dsn. ;
		quit;

		proc sql noprint;
		  select count(*) into: tgt_record_cnt
		  from &dsn. 
          where load_flag=0;
		quit;


		*SASDOC--------------------------------------------------------------------------
		| BPM - Reset the process control tables to complete.        
		+------------------------------------------------------------------------SASDOC*; 
		%bpm_process_control(timevar=&dqstatus.)
		
		%if &status. = 'NOT ACCEPTED' %then %do;
			%macro send_email_alert;
				filename mail_out email to=("edwprod@valencehealth.com") subject="CIO Work Flow &wflow_exec_id. - QA Report Failed";

				data _null_;
				file mail_out lrecl=32767;
				put "client ID = &client_id."; 
				put "practice ID = &practice_id.";
				put "system ID = &system_id.";
				run;
			%mend send_email_alert;
			%send_email_alert

		%end;


	%END;  /** end - increment_count **/

	*SASDOC--------------------------------------------------------------------------
	| macro - turn_off_skelta_step3_alerts 
	|
	| by passes workflow step 3 pauses 
	| claims and member workflow looks for acceptable = 0
	+------------------------------------------------------------------------SASDOC*; 
	%macro turn_off_skelta_step3_alerts(client_alert=);
	
		%if &client_alert. = 13 %then %do;
	
		  proc sql;
		  update vbpm.validations
		  set acceptable = 1
		  where wflow_exec_id in (&wflow_exec_id.)
		    and acceptable=0;
		  quit;
		
		%end;
		
	%mend turn_off_skelta_step3_alerts;
	%**turn_off_skelta_step3_alerts(client_alert=13);

	
	
	options nosymbolgen;
	%put NOTE: clientname=&clientname.;
	%put NOTE: systemname=&systemname.;
	%put NOTE: practicename="&practicename."; 
	%put NOTE: practice_id = &practice_id. ; 
	options symbolgen mlogic;

%mend edw_claims_transformations;

*SASDOC--------------------------------------------------------------------------
| Execute the macros
------------------------------------------------------------------------SASDOC*;
%edw_claims_transformations(dsn=cistage.claims_&practice_id._&client_id._&wflow_exec_id. ,practice=&practice_id.)
