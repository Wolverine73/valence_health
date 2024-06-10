
/*HEADER------------------------------------------------------------------------
|
| program:  edw_guideline_shell_4.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Run the guidelines from the EDW
|
| logic:                  
|
| input:    client_id   - the client id from vmine (e.g., 4=NSAP) 
|		
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
/**todays date**/
%let daterun=%sysfunc(date(),yymmdds10.);
%let dummyNPI = 1134117609;

%let guidelibname = M:\CI\programs\ValenceBaseMeasures\V2.1\Production Guidelines; 

%let all = 0; * choose 1 to make compliance calculate all or none/ choose 0 to calculate mean compliance ;
%let all_hospice_exclude=0; 
%let number_diags = 3; 


libname fg_guide oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=fg_Guidelines;" preserve_tab_names=yes readbuff=10000;

proc sql;
create table Active_ClientMacroParameters as 
select *
from fg_guide.Active_ClientMacroParameters
where clientid = 4;
quit;

data _null_;
 set Active_ClientMacroParameters  ;
 call symput(client_var,trim(left(paramvalue))); 
run;

%put NOTE: guideline_config_file = &guideline_config_file. ;


*SASDOC--------------------------------------------------------------------------
| Process the guidelines for NSAP
------------------------------------------------------------------------SASDOC*; 
proc sql noprint;
  select left(trim(client_name)), data_mart into :client, :data_mart
  from ciedw.client
  where client_key = &client_id. ;
quit;

%put NOTE: Client = &client.;
%put NOTE: Data Mart = &data_mart.;

%let dmpat = "Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=devserv1;Initial Catalog=&data_mart.;";
libname dmart oledb  init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=devserv1;Initial Catalog=&data_mart.;" preserve_tab_names=yes;


%macro edw_guideline_shell;

	/*libname in1  oledb init_string=&ciedw. preserve_tab_names=yes; */
	/*libname fmtlab "\\Fs\datateam\ci\HEDIS\Sasdata\2008";  */
	libname out_det "M:\ci\sasdata\guidelines\%qcmpres(&client.)\development";
	libname current1 "M:\CI\sasdata\guidelines\%qcmpres(&client.)\Development\current";
	libname prior1 "M:\CI\sasdata\guidelines\%qcmpres(&client.)\Development\prior";
	libname fmtlab "\\Fs\datateam\ci\HEDIS\Sasdata\2008";
	libname dummy "M:\%qcmpres(&client.)\sasdata\CI\Portal\Dummy";


	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 
	%bpm_process_control(timevar=START);
	%include "M:\ci\programs\StandardMacros\edw_guidelines_formats.sas";

	proc format cntlin=dummy.dummyid; 
	run;

	proc format cntlin=dummy.dummynm; 
	run;

	proc format cntlin=dummy.dummyYN; 
	run;
/*
	proc format cntlin=fmtlab.std;
	run; */
	
	%let dummyNPI = 1770581092;  

	%include "M:\NSAP\Programs\CIOPS\Modules\NSAP_provider_comments_formats.sas";

	%macro provider_comments;
		%if &period = current %then %do;
			data elig4;
			set elig4;
			length mem_guide $15. mem_pcp $22. guideline_key $3.;
			guideline_key = &guideline_key;
			mem_guide = cats(memberid)||"||"||cats(guideline_key);
			mem_pcp = cats(memberid)||"||"||cats(pcp1);

			if put(memberid,$expired.) = 'Y' then delete;
			if put(mem_guide,$refused.) = 'Y' then delete;
			if put(mem_pcp,$nopat.) = 'Y' then delete;
			run;
		%end;
	%mend provider_comments;

	%macro cleanup;
		/*
			%if &period = current %then %do;
				data guideline_version;
				set g6_A (obs=1);
					length guideline_key $3. version $4.;
					guideline_key=cats(&guideline_key.);
					version=cats(&version.);
					keep guideline guideline_key version;
				run;

				proc append base=out_det.guideline_version data=guideline_version;
				run; 
			%end;
		*/
		proc datasets library=work;
		delete d1 d2 d3 d4 d5 g1 g2 g3 g4 g5 g5a g6 g7 g8
		elig1 elig2 elig3 elig4 elig4a elig5 Elig_dt1 Elig_dt2 Elig_dt3 
		g6_A g6_B g6_C g6_D g6_E g6_F g6_G g6_H g6_I ;
		run;
		quit;
	%mend cleanup;


	%macro delvars;
		data temp;
		      set sashelp.vmacro;
		      *where name not in ('ENDDT','STDT','ALL','CLIENT','LASTPER','CURPER','GUIDELIBNAME','NUMBER_DIAGS',
						    'PERIOD','RPTPERIOD','SYS_SQL_IP_ALL','SYS_SQL_IP_STMT','ALL_HOSPICE_EXCLUDE')
		      and scope not in ('AUTOMATIC');
			  where name = 'VAR';

		run;

		data _null_;
		      set temp;
		      call symdel(name);
		run;
	%mend delvars;



	%macro run_all;

		libname temp clear;
		*libname temp "M:\nsap\SASTemp\CI\&period.";
		libname temp "M:\CI\sasdata\guidelines\NSAP\Development\&period.";

		Data patex;
		format svcdt mmddyy10. member_key 16.;
		length memberid $16.;
		set ciedw.vlabclme(rename=(memberid=ssn));

		where CLIENT_KEY=4 and (ci_status = 'PAR' or (ci_status = 'NONPAR' and clncl_int_exp_dt > datetime() ));

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


		data g0 (compress=binary) ;
		format svcdt dob mmddyy10. member_key 16.;
		length memberid $16.;
		set ciedw.vlabclme(rename=(memberid=ssn /*revenue_code=revcd*/ dob=dob2));
		where CLIENT_KEY=4 and (ci_status = 'PAR' or (ci_status = 'NONPAR' and clncl_int_exp_dt > datetime() ));

		svcdt = datepart(svcdt2);
		memberid=member_key;
		dob = datepart(dob2);
		run;

		proc sort data=g0;
		by memberid  svcdt proccd;
		run;

		data g0;
		set g0;
		where memberid ne "";
		by memberid  svcdt proccd;

		if put(memberid,$nursingpat_fmt.) = 'Y' then delete; *removing nursing home patients;
		if put(memberid,$homepat_fmt.) = 'Y' then delete; *removing home health patients;

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

		%let n = 2;
		%let COPD_diaginclude = ,491.0,491.8,491.9;
		%let trigger_comments = 0;
		%let all = 0;

		%*include "M:\NSAP\Programs\CIOPS\Guidelines\BaseMeasure_GuidelineShell_NSAP2.sas";

		%include "M:\ci\programs\StandardMacros\edw_guideline_config_&client_id..sas";

		/** Keep g0 program for now for validation **/
		data temp.g0;
		  set g0;
		run;


		*SET ALL DATASETS BACK HERE!;
		data temp.g6 (compress=binary);
		set
			temp.g6_ap_ped
			temp.g6_barretts
			temp.g6_cataract
			temp.g6_chf 
			temp.g6_chlamydia
			temp.g6_ckd
			temp.g6_cll
			temp.g6_colorectal
			temp.g6_copd
			temp.g6_copd_spiro
			temp.g6_diabetes
			temp.g6_diabetes_eye	
			temp.g6_dyslipidemia
			temp.g6_glaucoma
		    temp.g6_hypertension
			temp.g6_hypothyroid
			/*temp.g6_insomnia*/
			temp.g6_immuniz2
		    temp.g6_immuniz6
			temp.g6_immunizadol
			temp.g6_melanoma
		    temp.g6_prenatal
			temp.g6_Cervical_21
			temp.g6_Cervical_30
			temp.g6_osteo_women
			/*temp.g6_osteowomen_hrmed*/
			temp.g6_osteowomen_hrortho
			temp.g6_prostatear
			temp.g6_prostatehr
			temp.g6_wv_15
			temp.g6_wv_3to6
			temp.g6_wv_adolescent
			/*temp.g6_wv_12to18*/
		/*	temp.g6_head*/
			temp.g6_seizure
			temp.g6_sinusitis
			temp.g6_podiatry
			;
		run;


		data out_det.submeasures_&period.;
		set temp.g6;
		run;


		data temp.g9 (compress=binary keep=pcpid elig comp guideline comprate /*quartile*/);
		set
			temp.g8_ap_ped
			temp.g8_barretts
			temp.g8_cataract
			temp.g8_chf 
			temp.g8_chlamydia
			temp.g8_ckd
			temp.g8_cll
			temp.g8_colorectal
			temp.g8_copd
			temp.g8_copd_spiro
			temp.g8_diabetes
			temp.g8_diabetes_eye	
			temp.g8_dyslipidemia
			temp.g8_glaucoma
		    temp.g8_hypertension
			temp.g8_hypothyroid
			/*temp.g8_insomnia*/
			temp.g8_immuniz2
		    temp.g8_immuniz6
			temp.g8_immunizadol
			temp.g8_melanoma
		    temp.g8_prenatal
			temp.g8_Cervical_21
			temp.g8_Cervical_30
			temp.g8_osteowomen_hrortho
			temp.g8_osteo_women
			/*temp.g8_osteowomen_hrmed*/
			temp.g8_prostatear
			temp.g8_prostatehr
			temp.g8_wv_15
			temp.g8_wv_3to6
			temp.g8_wv_adolescent
			/*temp.g8_wv_12to18*/
		/*	temp.g8_head*/
			temp.g8_seizure
			temp.g8_podiatry
			temp.g8_sinusitis
			;
		run;


		proc summary data=temp.g9  nway missing;
		class guideline;
		var elig comp;
		output out=g10 (drop=_type_ _freq_) sum= ;
		run;

		data temp.g10;
		set g10;
		PercentCompliant = comp / elig;
		format PercentCompliant percent6. ;
		run;

		%if &period. = current %then %do;

		data submeasures_detail;
		set 	
			temp.g9_ap_ped
			temp.g9_barretts
			temp.g9_cataract
			temp.g9_chf 
			temp.g9_chlamydia
			temp.g9_ckd
			temp.g9_cll
			temp.g9_colorectal
			temp.g9_copd
			temp.g9_copd_spiro
			temp.g9_diabetes
			temp.g9_diabetes_eye	
			temp.g9_dyslipidemia
			temp.g9_glaucoma
		    temp.g9_hypertension
			temp.g9_hypothyroid
			/*temp.g9_insomnia*/
			temp.g9_immuniz2
		    temp.g9_immuniz6
			temp.g9_immunizadol
			temp.g9_melanoma
		    temp.g9_prenatal
			temp.g9_Cervical_21
			temp.g9_Cervical_30
			temp.g9_osteowomen_hrortho
			temp.g9_osteo_women
			/*temp.g9_osteowomen_hrmed*/
			temp.g9_prostatear
			temp.g9_prostatehr
			temp.g9_wv_15
			temp.g9_wv_3to6
			temp.g9_wv_adolescent
			/*temp.g9_wv_12to18*/
		/*	temp.g9_head*/
			temp.g9_seizure
			temp.g9_podiatry
			temp.g9_sinusitis
			;
		run;


		Data SUBMEASURES_DETAIL_Dummy;
		set submeasures_detail;
		where put(memberid,$dummyYN.) = "Y" and pcpid = "&dummyNPI.";
		memberid = put(memberid,$dummyid.);
		pcpid = "9999999999"; 
		run;

		data out_det.SUBMEASURES_DETAIL;
		set SUBMEASURES_DETAIL SUBMEASURES_DETAIL_Dummy;
		run;
		%end;

	%mend run_all; 

	*5-20-09 Guidelines;
	%*let client=NSAP;
	%*let stdt = '01apr2010'd;
	%*let enddt = '01apr2011'd;
	%let client=&client.;
	%*let stdt = &stdt.;
	%*let enddt = &enddt.;
	%let period=current;

	/*  Set the start date and end dates for the current and prior periods */

	data _null_;
	  mon1 = month(date());
	  year1 = year(date());
	  stdt = mdy(cats(mon1),'01',cats(year1 - 1));
	  stdt2 = mdy(cats(mon1),'01',cats(year1 - 2));
	  enddt = mdy(cats(mon1),'01',cats(year1));

	  call symput('stdt',stdt);  /** current start date and prior end date **/
	  call symput('stdt2',stdt2); /** prior start data **/
	  call symput('enddt',enddt);  /** current end date **/
	run;


	%put stdt2 = &stdt2.;
	%put stdt = &stdt.;
	%put enddt = &enddt.;


	/** Run the guidelines for Current period **/

	%run_all;
	run;


	%set_error_flag;
	%on_error(ACTION=ABORT);

	data _null_;
		CurrentPeriodStart  = put(&stdt.,worddate.);
		CurrentPeriodEnd  = put((&enddt. - 1),worddate.);
		Current_Period = cats(CurrentPeriodStart) || " - " || cats(CurrentPeriodEnd) ;
		call symput('Current_Period',Current_Period);
		StartDate = put(&stdt.,date9.);
		call symput('StartDate',StartDate); 
		EndDate = put((&enddt.-1),date9.);
		call symput('EndDate',EndDate); 
	run;
	%put &Current_Period;
	proc sql;
	      update out_det.portal_dates
		    set value="&Current_Period."
		    where Parameter = 'Period'
				;
	quit;
	proc sql;
	      update out_det.portal_dates
		    set value="&StartDate."
		    where Parameter = 'StartDate'
				;
	quit;
	proc sql;
	      update out_det.portal_dates
		    set value="&EndDate."
		    where Parameter = 'EndDate'
				;
	quit;

	proc sql noprint;
	 select count(*) into: g0_count
	 from g0 ;
	quit;

	%let src_record_cnt=&g0_count;
	%put NOTE:  count_src = &g0_count;


	/*
	proc datasets library=work;
	delete g0 ;
	run;
	quit;
	*/

	/** Reset the start and end dates for the prior period **/

	*5-20-09 Guidelines;
	%*let client=NSAP;
	%*let stdt = '01apr2009'd;
	%*let enddt = '01apr2010'd;
	%let client = &client.;
	%let enddt = &stdt.;
	%let stdt = &stdt2.;
	%let period=prior;

	%put stdt = &stdt.;
	%put enddt = &enddt.;

	%run_all;
	run;

	%set_error_flag;
	%on_error(ACTION=ABORT);


	data _null_;
		PriorPeriodStart  = put(&stdt.,worddate.);
		PriorPeriodEnd  = put((&enddt. - 1),worddate.);
		Prior_Period = cats(PriorPeriodStart) || " - " || cats(PriorPeriodEnd) ;
		call symput('Prior_Period',Prior_Period);
	run;
	%put &Prior_Period;
	proc sql;
	      update out_det.portal_dates
		    set value="&Prior_Period."
		    where Parameter = 'priorperiod'
				;
	quit;

	Data guideline;
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


	Data out_det.GuidelineProvider;
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
	Data out_det.submeasures_current;
	set out_det.submeasures_current SC_dummy;
	run;


	proc sql;
		drop index pcpid from out_det.SUBMEASURES_DETAIL;
		drop index memberid from out_det.SUBMEASURES_DETAIL;
		drop index guideline from out_det.SUBMEASURES_DETAIL;
		drop index mempcpid from out_det.SUBMEASURES_DETAIL;
		create index pcpid on out_det.SUBMEASURES_DETAIL (pcpid);
		create index memberid on out_det.SUBMEASURES_DETAIL (memberid);
		create index guideline on out_det.SUBMEASURES_DETAIL (guideline);
		create index mempcpid on out_det.SUBMEASURES_DETAIL(memberid,pcpid);
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

	%let xl = %str(M:\ci\programs\edw\&client.\guidelines\&client._outliers_&sysdate..pdf);


	%let tgt_record_cnt=&submeas_count.;
	%put NOTE:  tgt_record_cnt = &submeas_count.;

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
