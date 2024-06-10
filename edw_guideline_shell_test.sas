
/*HEADER------------------------------------------------------------------------
|
| program:  edw_guideline_shell.sas
|
| location: m:\ci\programs\edw
|
| purpose:  run the guidelines from the edw for all ci clients
|
| logic:                  
|
| input:    client_id   - the client id from vmine (e.g., 4=nsap, 6=cccpp) 		
|                        
| output:   Guideline SAS datasets
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%*SASDOC----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*; 
%global date_run daterun;

data _null_;
  date_run = today();
  call symput('date_run',date_run);
run;

%let daterun=%sysfunc(date(),yymmdds10.);

%put NOTE: date_run = &date_run;
%put NOTE: daterun  = &daterun;



*SASDOC--------------------------------------------------------------------------
| Run the Care Elements and Registry
------------------------------------------------------------------------SASDOC*; 

%include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\VALENCE\Prospective Logic\Release 1.0 Prospective Front End Setup.sas";



*SASDOC--------------------------------------------------------------------------
| Process the guidelines for CI clients if it is a guideline run day
------------------------------------------------------------------------SASDOC*; 

%macro edw_guideline_shell;

	libname out_det  "M:\ci\sasdata\guidelines\%qcmpres(&client.)\development";
	libname current1 "M:\ci\sasdata\guidelines\%qcmpres(&client.)\development\current";
	libname prior1   "M:\ci\sasdata\guidelines\%qcmpres(&client.)\development\prior";
	libname fmtlab   "\\Fs\datateam\ci\HEDIS\Sasdata\2008";
	libname dummy    "M:\%qcmpres(&client.)\sasdata\CI\Portal\Dummy";


	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);
	
	
	*SASDOC--------------------------------------------------------------------------
	| Guideline Formats  
	| 
	+------------------------------------------------------------------------SASDOC*;
	%include "M:\ci\programs\StandardMacros\edw_guidelines_formats.sas";

/*
	proc format cntlin=dummy.dummyid; 
	run;

	proc format cntlin=dummy.dummynm; 
	run;

	proc format cntlin=dummy.dummyYN; 
	run; 
*/	

	*SASDOC--------------------------------------------------------------------------
	| Guideline Comments  
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%include "&guideline_comment_file.";
	
 
	*SASDOC--------------------------------------------------------------------------
	| Macro - Run All Guidelines   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%macro run_all_guidelines;

		libname temp clear; 
		libname temp  "M:\CI\sasdata\guidelines\%qcmpres(&client.)\Development\&period.";


		*SASDOC--------------------------------------------------------------------------
		| Nursing and Home Health Formats
		------------------------------------------------------------------------SASDOC*; 
		%if &format_nursing. = 1 or &format_homehealth. = 1 %then %do;  /** start -  format_nursing and format_homehealth **/
		
			data patex;
			  format svcdt mmddyy10. member_key 16.;
			  length memberid $16.;
			  set ciedw.vlabclme(keep   = client_key member_key memberid ci_status clncl_int_exp_dt svcdt2 proccd pos
					     rename = (memberid=ssn));

			  where client_key=&client_id. and (ci_status = 'PAR' or (ci_status = 'NONPAR' and clncl_int_exp_dt > datetime() ));
			  procn = proccd *1 ;
			  svcdt = datepart(svcdt2);
			  memberid=member_key;

			  *EXCLUDE NURSING PATIENTS FROM BOTH REPORTING PERIODS;
			  if ((&stdt. - 365) <= svcdt < &enddt.) then do;
				if (proccd in ('99301','99302','99303','99304','99305','99306','99307','99308',
							   '99309','99310','99311','99312','99313','99315','99316','99318') or 
					pos in ('31','32','34')) then nursingpat_exclude = 1;


				if (procn in (99341:99345,99347:99353,99374:99375,99500:99602) or pos = '12') then
					Homehealth_exclude=1 ;

			  end;
			run;

			proc summary data=patex (keep=memberid nursingpat_exclude) nway missing;
			class memberid;
			var nursingpat_exclude;
			output out=nursingpat_exclude (drop=_type_ _freq_) sum=;
			run;

			data nursingpat_fmt (compress=yes keep=fmtname type start label);
			set nursingpat_exclude;
			where nursingpat_exclude ge 1 and nursingpat_exclude not in (.,-0,0);
			length fmtname $14. type $1. start $16. label $1.;
			start = memberid;
			label = 'Y';
			retain fmtname 'nursingpat_fmt' type 'C';
			output;
			if _n_ = 1 then do;
				start = '';
				label = 'N';
				output;
			end;
			run;

			proc sort data=nursingpat_fmt nodupkey;
			by start;
			run;

			proc format cntlin = nursingpat_fmt; run;

			proc print data=nursingpat_fmt (obs=10);
			title 'Exclude Nursing Patients';
			run;

			proc summary data=patex (keep=memberid Homehealth_exclude) nway missing;
			class memberid;
			var Homehealth_exclude;
			output out=Homehealthpat_exclude (drop=_type_ _freq_) sum=;
			run;

			data homepat_fmt (compress=yes keep=fmtname type start label);
			set Homehealthpat_exclude;
			where Homehealth_exclude ge 1 and Homehealth_exclude not in (.,-0,0);
			length fmtname $11. type $1. start $16. label $1.;
			start = memberid;
			label = 'Y';
			retain fmtname 'homepat_fmt' type 'C';
			output;
			if _n_ = 1 then do;
				start = '';
				label = 'N';
				output;
			end;
			run;

			proc sort data=homepat_fmt nodupkey;
			by start;
			run;

			proc format cntlin = homepat_fmt; run;

			proc print data=homepat_fmt (obs=10);
			title 'Exclude Home Health Patients';
			run;
		
		%end;  /** end -  format_nursing and format_homehealth **/

		
		*SASDOC--------------------------------------------------------------------------
		| CIEDW lab results
		------------------------------------------------------------------------SASDOC*; 		
		proc sql;
		  create table lab_results as
		  select 
			service_date as svcdt2, 
			'' as mod1, 
			'' as mod2, 
			'' as revcd, 
			. as units, 
			b.npi1 as provid, 
			. as admdt, 
			'' as diag1, 
			'' as diag2, 
			'' as diag3, 
			. as disdt, 
			'' as pos, 
			'' as tin, 
			'' as referral, 
			'' as drg, 
			c.dob as dob2,
			c.sex as sex,
			a.cpt_code as proccd, 
			50 as majcat, 
			'' as provspec, 
			'' as practice, 
			'' as system, 
			'l' as source, 
			lab_code as loinc, 
			a.member_key format 16., 
			a.client_key, 
			a.ord_provider_key as provider_key,
			. as practice_key, 
			. as market_value, 
			'' as specdesc, 
			. as sensitive, 
			case when a.created_on = a.updated_on 
			then a.created_on else a.updated_on 
			end as max_proc_date, 
			'' as surg1, 
			'' as dis_cond, 
			'' as ci_status, 
			. as clncl_int_exp_dt, 
			. as sas_prov_id, 
			c.sas_member_id
		  from ciedw.lab_result a left outer join ciedw.provider b
		    on a.ord_provider_key=b.provider_key left outer join ciedw.member c
		    on a.member_key=c.member_key 
		  where a.client_key=&client_id. 
		    and a.member_key ne -99 
		    and service_date ne .;
		quit;

		data lab_results;
		  set lab_results;
		  format svcdt dob mmddyy10. ;
		  length memberid $16.;
		  memberid=member_key;
		  svcdt = datepart(svcdt2); 
		  dob = datepart(dob2);
		  drop svcdt2 dob2;
		run;


		*SASDOC--------------------------------------------------------------------------
		| CIEDW vlabclme
		------------------------------------------------------------------------SASDOC*; 
		data vlabclme ;
		  format svcdt dob mmddyy10. member_key 16.;
		  length memberid $16.;
		  set ciedw.vlabclme(rename=(memberid=ssn /*revenue_code=revcd*/ dob=dob2));
		  where client_key=&client_id. and (ci_status = 'PAR' or (ci_status = 'NONPAR' and clncl_int_exp_dt > datetime() ));
		  svcdt = datepart(svcdt2);
		  memberid=member_key;
		  dob = datepart(dob2);
		run;
		
		
		*SASDOC--------------------------------------------------------------------------
		| G0 - Combine vlabclme and lab results
		------------------------------------------------------------------------SASDOC*; 		
		data g0;
		  format loinc $7.;
		  set vlabclme (obs=2000000) lab_results (obs=1000000);
		run;
		
		%put WARNING: Remove 2 million and 1 million sample from g0 data step ;

		*SASDOC--------------------------------------------------------------------------
		| DROP VLABCLME and LAB_RESULTS data sets to save space
		------------------------------------------------------------------------SASDOC*; 

		proc datasets library = work;
		   delete vlabclme lab_results;
		run;
		
		proc sql;
		  create table g0 as
		  select a.* 
		  from g0 a 
		  where ( (source='P' and provid in (select distinct npi1 from ciedw.PROVIDER) )
			  and (source = 'P' and provid <> '')
			  or source <> 'P') 
		  order by memberid, svcdt, proccd;			  
		quit;


/*
		proc sort data=g0;
		  by memberid  svcdt proccd;
		run;
*/
		data g0;
		  set g0;
		  where memberid ne "";
		  by memberid  svcdt proccd;
		  
		  %if &format_nursing. = 1 %then %do;
		    if put(memberid,$nursingpat_fmt.) = 'Y' then delete; *removing nursing home patients;
		  %end;
		  %if &format_homehealth. = 1 %then %do;
		    if put(memberid,$homepat_fmt.) = 'Y' then delete; *removing home health patients;
		  %end;
		  
		  length 	d1_3 d2_3 d3_3 $3.  d1_4 d2_4 d3_4 $5.;
		  d1_3 = substr(diag1,1,3);
		  d2_3 = substr(diag2,1,3);
		  d3_3 = substr(diag3,1,3);
		  d1_4 = substr(diag1,1,5);
		  d2_4 = substr(diag2,1,5);
		  d3_4 = substr(diag3,1,5);
		  d1_3n = d1_3 * 1;
		  d2_3n = d2_3 * 1;
		  d3_3n = d3_3 * 1;
		  d1_4n = d1_4 * 1;
		  d2_4n = d2_4 * 1;
		  d3_4n = d3_4 * 1;
		  procn = proccd *1 ;
		  *if 100 <= procn < 1000 and 1 <= majcat <= 13 then revcd = procn;
		  diag1n = diag1 * 1;
		  diag2n = diag2 * 1;
		  diag3n = diag3 * 1;
		  *pos=pos;
		  surg1n = surg1* 100;
		  *ageR =round((&enddt - dob)/365.23,.1);  * calc age as of end date;
		  ageR = floor((intck('month', dob, &enddt.)- (day(&enddt.) < day(dob))) / 12);
		  diff = svcdt - dob; * calc difference in days between birth and servicde date;
		  			   
		  count=_n_;
		  ndc= "";
		  
		  drop svcdt2 dob2;
		run;


		*SASDOC--------------------------------------------------------------------------
		| Guideline Configuration File  
		| 
		+------------------------------------------------------------------------SASDOC*;
		%include "&guideline_config_file.";
		
		
		*SASDOC--------------------------------------------------------------------------
		| Keep g0 program for now for validation  
		------------------------------------------------------------------------SASDOC*;  
		/*** TURNED THIS OFF FOR WORKFLOW TESTING - TURN IT BACK ON TO DO VALIDATIONS **/

	/*	data temp.g0;
		  set g0;
		run;
        */		

		*SASDOC--------------------------------------------------------------------------
		| Retrieve a list of SAS datasets 
		------------------------------------------------------------------------SASDOC*;  
		data tables;
		  set sashelp.vtable;
		run;

		data temp;
		  set tables;
		  where upcase(libname)='TEMP' and substr(memname,1,3)='G6_' and length(memname) gt 4;
		run;

		data _null_;
		  set temp  end=eof;
		  i+1;
		  ii=left(put(i,4.));
		  call symput('table'||ii,memname);
		  if eof then call symput('table_total',ii);
		run;	

		*SASDOC--------------------------------------------------------------------------
		| G6 
		------------------------------------------------------------------------SASDOC*;  
		data temp.g6 (compress=binary);
		  set %do g=1 %to &table_total. ;
		        temp.&&table&g
		      %end;;
		run;

		data out_det.submeasures_&period.;
		  set temp.g6;
		run;

		data temp;
		  set tables;
		  where  upcase(libname)='TEMP' and substr(memname,1,3)='G8_' and length(memname) gt 4;
		run;

		data _null_;
		  set temp  end=eof;
		  i+1;
		  ii=left(put(i,4.));
		  call symput('table'||ii,memname);
		  if eof then call symput('table_total',ii);
		run;

		*SASDOC--------------------------------------------------------------------------
		| G9
		------------------------------------------------------------------------SASDOC*; 
		data temp.g9 (compress=binary keep=pcpid elig comp guideline comprate /*quartile*/);
		  set %do g=1 %to &table_total. ;
		        temp.&&table&g
		      %end;;
		run;

		proc summary data=temp.g9  nway missing;
		  class guideline;
		  var elig comp;
		  output out=g10 (drop=_type_ _freq_) sum= ;
		run;

		*SASDOC--------------------------------------------------------------------------
		| G10
		------------------------------------------------------------------------SASDOC*; 
		data temp.g10;
		  format PercentCompliant percent6. ;
		  set g10;
		  PercentCompliant = comp / elig;
		run;

		%if &period. = current %then %do;
		
			data temp;
			  set tables;
			  where upcase(libname)='TEMP' and substr(memname,1,3)='G9_' and length(memname) gt 4;
			run;

			data _null_;
			  set temp  end=eof;
			  i+1;
			  ii=left(put(i,4.));
			  call symput('table'||ii,memname);
			  if eof then call symput('table_total',ii);
			run;

			data submeasures_detail;
			  set %do g=1 %to &table_total. ;
				temp.&&table&g
			      %end;;
			run;

		/*	data submeasures_detail_dummy;
			  set submeasures_detail;
			  where put(memberid,$dummyYN.) = "Y" and pcpid = "&dummyNPI.";
			  memberid = put(memberid,$dummyid.);
			  pcpid = "9999999999"; 
			run;
		*/	

			data out_det.submeasures_detail;
			  set submeasures_detail /*submeasures_detail_dummy */;
			run;
			
		%end;
		
	%set_error_flag;
	%on_error(ACTION=ABORT);		

	%mend run_all_guidelines; 

	*SASDOC--------------------------------------------------------------------------
	| Current Guidelines
	------------------------------------------------------------------------SASDOC*; 
	%*let stdt  = '01apr2010'd;
	%*let enddt = '01apr2011'd; 
	%let period = current;

	data _null_;
	  mon1 = month(date()) - (&lag_number. - 1);
	  year1 = year(date());
	  stdt = mdy(cats(mon1),'01',cats(year1 - 1));
	  stdt2 = mdy(cats(mon1),'01',cats(year1 - 2));
	  enddt = mdy(cats(mon1),'01',cats(year1));

	  call symput('stdt',stdt);    /** current start date and prior end date **/
	  call symput('stdt2',stdt2);  /** prior start data **/
	  call symput('enddt',enddt);  /** current end date **/
	run;
	
	%put WARNING: Brian and Robyn... check with Brandon the lag number calculation for CCCPP... does it need to be 3 or 4 in fg_guide.active_clientmacroparameters;

	%put NOTE: stdt2 = &stdt2.;
	%put NOTE: stdt  = &stdt.;
	%put NOTE: enddt = &enddt.; 
	
	%run_all_guidelines; 


	%set_error_flag;
	%on_error(ACTION=ABORT);


	data _null_;
		CurrentPeriodStart  = put(&stdt.,worddate.);
		CurrentPeriodEnd  = put((&enddt. - 1),worddate.);
		Current_Period = cats(CurrentPeriodStart) || " - " || cats(CurrentPeriodEnd) ;
		call symput('Current_Period',trim(Current_Period));
		StartDate = put(&stdt.,date9.);
		call symput('StartDate',trim(StartDate)); 
		EndDate = put((&enddt.-1),date9.);
		call symput('EndDate',trim(EndDate)); 
	run;
	
	%put NOTE: Current Period = &Current_Period;
	
	proc sql;
	  update out_det.portal_dates
	  set value="&Current_Period."
	  where Parameter = 'Period' ;
	quit;
	
	proc sql;
	  update out_det.portal_dates
	  set value="&StartDate."
	  where Parameter = 'StartDate' ;
	quit;
	
	proc sql;
	  update out_det.portal_dates
	  set value="&EndDate."
	  where Parameter = 'EndDate' ;
	quit;


	proc sql noprint;
	  select count(*) into: g0_count
	  from g0 ;
	quit;

	%let src_record_cnt=&g0_count;
	%put NOTE: count_src = &g0_count;


	*SASDOC--------------------------------------------------------------------------
	| Prior Guidelines
	------------------------------------------------------------------------SASDOC*; 
	%*let stdt  = '01apr2009'd;
	%*let enddt = '01apr2010'd;
	%let enddt  = &stdt.;
	%let stdt   = &stdt2.;
	%let period = prior;

	%put NOTE: stdt = &stdt.;
	%put NOTE: enddt = &enddt.;

	%run_all_guidelines; 

/*
	%set_error_flag;
	%on_error(ACTION=ABORT);
*/

	data _null_;
		PriorPeriodStart  = put(&stdt.,worddate.);
		PriorPeriodEnd  = put((&enddt. - 1),worddate.);
		Prior_Period = cats(PriorPeriodStart) || " - " || cats(PriorPeriodEnd) ;
		call symput('Prior_Period',trim(Prior_Period));
	run;
	
	%put NOTE: Prior Period = &Prior_Period;
	
	proc sql;
	  update out_det.portal_dates
	  set value="&Prior_Period."
	  where Parameter = 'PriorPeriod' ;
	quit;

	data guideline;
	  merge current1.g10 (rename=(comp=Compliant2 Elig=eligible2 Percentcompliant=percentcompliant2))
		  prior1.g10 (rename=(comp=Compliant1 Elig=eligible1 Percentcompliant=percentcompliant1));
	  by guideline;
	  if eligible2 ge 1; *Mod 6/2/09 by KG;
	  guidelinetype = 'V';
	run;

	data out_det.guideline;
	  set /*out_det.manual_guideline_all*/ guideline;  /** No manual data from EDW at this time RDS 20110527 **/
	  diff = percentcompliant2 - percentcompliant1;
	run;

	proc sort data=current1.g9;
	  by guideline pcpid;
	run;
	
	proc sort data=prior1.g9;
	  by guideline pcpid;
	run;

	data out_det.GuidelineProvider;
	  merge current1.g9 (rename = (Elig = Eligible2 Comp = Compliant2 comprate=percentcompliant2)) 
		    prior1.g9 ( rename = (Elig = Eligible1 Comp = Compliant1  comprate=percentcompliant1))
			;
	  by guideline pcpid;
	  if eligible2 ge 1; *Mod 6/2/09 by KG;
	  quartile = quartile +1;
	  pcpname=put(pcpid,$provname.);
	run;

	proc freq data=out_det.guideline;
	  tables guideline / list missing;
	run;

	data SC_Dummy;
	  set out_det.submeasures_current;
	  where pcpid = "&dummyNPI.";
	  pcpid = "9999999999";
	run;
	
	data out_det.submeasures_current;
	  set out_det.submeasures_current SC_dummy;
	run;

	proc sql;
	  drop index pcpid from out_det.submeasures_detail;
	  drop index memberid from out_det.submeasures_detail;
	  drop index guideline from out_det.submeasures_detail;
	  drop index mempcpid from out_det.submeasures_detail;
	  create index pcpid on out_det.submeasures_detail (pcpid);
	  create index memberid on out_det.submeasures_detail (memberid);
	  create index guideline on out_det.submeasures_detail (guideline);
	  create index mempcpid on out_det.submeasures_detail(memberid,pcpid);
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Run the outlier report
	------------------------------------------------------------------------SASDOC*; 
	%edw_outlier_report;
	%set_error_flag;
	%on_error(ACTION=ABORT);


	*SASDOC--------------------------------------------------------------------------
	| BPM - Store the location of the report in the BPMMetadata table       
	+------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
	 select count(*) into: submeas_count
	 from out_det.submeasures_detail;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Create Guideline Outlier Report
	------------------------------------------------------------------------SASDOC*; 
	%let xl = %str(M:\ci\programs\edw\&client.\guidelines\&client._outliers_&sysdate..pdf);

	%let tgt_record_cnt=&submeas_count.;
	%put NOTE:  tgt_record_cnt = &submeas_count.;
	
	%macro send_email_alert;
	filename mail_out email to="rstellman@valencehealth.com" subject="CIO Guideline Shell Program - Complete";
	data _null_;
	file mail_out lrecl=32767;   
	run;
	%mend send_email_alert;
	%send_email_alert;

	proc sql noprint;
	  update vbpm.sk_process_control a
	  set EXT_OUTPUT_LOG = "&xl."
	  where a.wflow_exec_id=&wflow_exec_id.
	  and a.client_id=&client_id.
	  and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
	quit;

	proc sql noprint;
	  update vbpm.sk_process_control a
	  set src_record_cnt = &src_record_cnt.
	  where a.wflow_exec_id=&wflow_exec_id.
	  and a.client_id=&client_id.
	  and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
	quit;

	proc sql noprint;
	  update vbpm.sk_process_control a
	  set tgt_record_cnt = &tgt_record_cnt.
	  where a.wflow_exec_id=&wflow_exec_id.
	  and a.client_id=&client_id.
	  and a.sk_prcs_ctrl_id=&sk_prcs_ctrl_id. ;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*;
	%set_error_flag;
	%on_error(ACTION=ABORT);

	%bpm_process_control(timevar=COMPLETE);
	

	

%mend edw_guideline_shell;
%edw_guideline_shell;
