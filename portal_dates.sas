/*HEADER------------------------------------------------------------------------
|
| program:  portal_dates.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  rolls up guideline output for prior and current periods
|
+--------------------------------------------------------------------------------
| *HISTORY:  
| 16AUG2012 - EM dmpat_comment now read in from work folder
| HISTORY*
+-----------------------------------------------------------------------HEADER*/


%macro portal_dates(period=);

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to start.   
	| 
	+------------------------------------------------------------------------SASDOC*; 

	/** SET UP PRIOR PERIOD DATES AND UPDATE PORTAL_DATES TABLE **/
	%if &period = prior %then %do;
		libname temp clear;
		libname temp "&prior1.";
		data _null_;
		  s = put(intnx('year',&gl_enddt.,-2,'same'),date9.);
		  e = put(intnx('year',&gl_enddt.,-1,'same'),date9.);
		  call symputx('s',s);
		  call symputx('e',e);
		run;
		%put NOTE:  Start Date: &s.;
		%put NOTE:  End Date: &e.;

		data _null_;
		   call symputx('stdt',%str("'&s.'d"));
		   call symputx('enddt',%str("'&e.'d"));
		run;

		%put NOTE:  Start Date: &stdt.;
		%put NOTE:  End Date: &enddt.;

		data _null_;
			PriorPeriodStart  = put(&stdt.,worddate.);
			PriorPeriodEnd  = put((&enddt. - 1),worddate.);
			Prior_Period = cats(PriorPeriodStart) || " - " || cats(PriorPeriodEnd) ;
			call symput('Prior_Period',Prior_Period);
		run;
			%put &Prior_Period;
			%*let client=&Client_name.;

		proc sql;
	      update out_det.portal_dates
		  set value=%sysfunc(strip("&Prior_Period."))
		  where Parameter = 'PriorPeriod' ;
		quit;

	%end;

	/** SET UP CURRENT PERIOD DATES AND UPDATE PORTAL_DATES TABLE **/
	%else %if &period = current %then %do;
		libname temp clear;
		libname temp "&current1.";
		data _null_;
		  s = put(intnx('year',&gl_enddt.,-1,'same'),date9.);
		  e = put(intnx('year',&gl_enddt.,0,'same'),date9.);
		  rp = put(intnx('year',&gl_enddt.,0,'same'),yymon.) || "-" || put(intnx('month',&gl_enddt.,-13,'same'),yymon.);
		  call symputx('s',s);
		  call symputx('e',e);
		  call symputx('rp',rp);
		run;
		%put NOTE:  Start Date: &s.;
		%put NOTE:  End Date: &e.;
		%put NOTE:  Reporting Period: &rp.;

		data _null_;
		   call symputx('stdt',%str("'&s.'d"));
		   call symputx('enddt',%str("'&e.'d"));
		run;

		%put NOTE:  Start Date: &stdt.;
		%put NOTE:  End Date: &enddt.;

		%*let client=&Client_name.;

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
	  		set value=%sysfunc(strip("&Current_Period."))
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

	%end;

	*SASDOC--------------------------------------------------------------------------
	| Retrieve a list of SAS datasets 
	------------------------------------------------------------------------SASDOC*; 
	data tables;
	  set sashelp.vtable;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Submeasures_detail
	------------------------------------------------------------------------SASDOC*; 
	data temp;
	  set tables;
	  where upcase(libname)='TEMP' and substr(memname,1,3)='G9_' and length(memname) gt 4
            and nobs > 0;
	run;

	data _null_;
	  set temp  end=eof;
	  i+1;
	  ii=left(put(i,4.));
	  call symput('table'||ii,memname);
	  if eof then call symput('table_total',ii);
	run;

	data submeasures_detail_stckd1;
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

	/*Remove Refused Patients*/
	%if %QUPCASE(&period.) = CURRENT %then %do;
		/*Patient Refused*/
		data pt_refused (drop = sub_key_n); 
		set /*out_det.*/DMPAT_COMMENT (rename = (submeasure_key = sub_key_n));
		where comment_key = 5;
			/*Only apply comments that are a year old from today's date*/
			if (intnx('month', datepart(EVENT_DATE),-4,'same')) <= today() < (intnx('month', datepart(EVENT_DATE),12,'same'));
			length Submeasure_key $2.;
			Submeasure_key = strip(put(sub_key_n,2.));
			comment = 1;
			svcdt = datepart(EVENT_DATE);
		run;

		proc sql;
		create table submeasures_detail_cmmts as
		select 	 a.*
				,b.comment

			from submeasures_detail_stckd1 as a

			left join
				pt_refused as b
					on 	a.memberid = b.memberid and
						a.guideline_key = b.guideline_key and
						a.submeasure_key = b.submeasure_key;
		quit;

		data submeasures_detail_stckd1;
		set submeasures_detail_cmmts;
		length orig_comp 3.;
			orig_comp = comp;
			if comment = 1 then comp = 1;
		run;
	%end;

	proc sql;
	create table submeasures_detail_stckd as
	select	 a.*
			,b.overall_calculation
		from submeasures_detail_stckd1 as a

		left join
			valence.overall_calculation as b
				on a.guideline_key = b.guideline_key;
	quit;

	/*Calculate Overall Rates*/
	/*Rates where the overall value is the mean or floor of the mean*/
	proc summary data = submeasures_detail_stckd nway missing;
	where input(submeasure_key,2.) < 70 and overall_calculation in ("M");	/*don't consider informational submeasures (70+) in 'Overall' rates*/
	class memberid guideline_key;
	id guideline;
	var comp;
	output out = submeasures_detail_overall_mean1 (drop = _:) mean=;
	run;

	data submeasures_detail_overall_mean;
	set submeasures_detail_overall_mean1;
	%if &all. = 1 %then %do;
		comp = floor(comp);
	%end;
	submeasure = "Overall";
	submeasure_key = "99";
	run;


	/*Rates where the overall value is determine if at least one compliance measure is met*/
	proc summary data = submeasures_detail_stckd nway missing;
	where input(submeasure_key,2.) < 70 and overall_calculation in ("O");	/*don't consider informational submeasures (70+) in 'Overall' rates*/
	class memberid guideline_key;
	id guideline;
	var comp;
	output out = submeasures_detail_overall_or1 (drop = _:) sum=;
	run;

	data submeasures_detail_overall_or;
	set submeasures_detail_overall_or1;
	if comp ge 1 then comp = 1;
	else comp = 0;
	submeasure = "Overall";
	submeasure_key = "99";
	run;

	/*Rates where the overall value is determine if all compliance measures are met*/
	proc sql;
	create table submeas_cnt1 as
	select distinct  guideline
					,guideline_key
					,submeasure
					,submeasure_key
		from submeasures_detail_stckd
			where overall_calculation = "A";
	
	create table submeas_cnt as
	select distinct  guideline
					,guideline_key
					,count(*) as cnt
		from submeas_cnt1;
	quit;

	proc summary data = submeasures_detail_stckd nway missing;
	where input(submeasure_key,2.) < 70 and overall_calculation in ("A");	/*don't consider informational submeasures (70+) in 'Overall' rates*/
	class memberid guideline_key;
	id guideline;
	var comp;
	output out = submeasures_detail_overall_and1 (drop = _:) sum=;
	run;

	proc sql;
	create table submeasures_detail_overall_and as
	select 	 a.memberid
			,a.guideline_key
			,a.guideline
			,case when a.comp = b.cnt then 1
				  else 0
			 end as comp
			,"Overall" as submeasure
			,"99" as submeasure_key
		from submeasures_detail_overall_and1 as a
		
		inner join
			submeas_cnt as b
				on  a.guideline_key = b.guideline_key and
					a.guideline = b.guideline;
	quit;
	
	data submeasures_detail_overall;
	set submeasures_detail_overall_mean
		submeasures_detail_overall_or
		submeasures_detail_overall_and;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Guideline - used only in the outlier report
	------------------------------------------------------------------------SASDOC*; 
	proc summary data = submeasures_detail_overall nway missing;
	class guideline_key guideline;
	var comp;
	output out = guideline1 (drop = _TYPE_ rename = (_FREQ_=elig)) sum=;
	run;

	data guideline2;
	set guideline1;
	format percentcompliant percent6.;
	percentcompliant = comp / elig;
	run;

	proc sort data = guideline2 out = &period.1.guideline_&period.;
	by guideline_key;
	run;

	%if %sysfunc(exist(current1.guideline_current)) and %sysfunc(exist(prior1.guideline_prior)) %then %do;
		data guideline;
		  merge current1.guideline_current (rename=(comp=Compliant2 Elig=eligible2 Percentcompliant=percentcompliant2))
			  	prior1.guideline_prior (rename=(comp=Compliant1 Elig=eligible1 Percentcompliant=percentcompliant1));
		  by guideline_key;
		  if eligible2 ge 1;
		  guidelinetype = 'V';
		run;

		data out_det.guideline;
		  set /*out_det.manual_guideline_all*/ guideline;  /** No manual data from EDW at this time RDS 20110527 **/
		  diff = percentcompliant2 - percentcompliant1;
		run;
	%end;

	/*Stack Submeasure and Overall Rates*/
	data &period.1.submeasures_detail_mem_%sysfunc(strip(&period.));
	set submeasures_detail_stckd (drop = overall_calculation)
		submeasures_detail_overall;
	run;

/*	data out_det.submeasures_detail_%sysfunc(strip(&period.));
	  set submeasures_detail *submeasures_detail_dummy;
	run;
*/

	*SASDOC--------------------------------------------------------------------------
	| LP_client Tables
	------------------------------------------------------------------------SASDOC*; 
	data temp;
	  set tables;
	  where upcase(libname)='TEMP' and substr(memname,1,3)='LP_' and length(memname) gt 4
            and nobs > 0;
	run;

	data _null_;
	  set temp  end=eof;
	  i+1;
	  ii=left(put(i,4.));
	  call symput('table'||ii,memname);
	  if eof then call symput('table_total',ii);
	run;

	data lp_%sysfunc(strip(&client.));
	  set %do g=1 %to &table_total. ;
		temp.&&table&g
	      %end;;
	run;

	proc sql;
	create table &period.1.lp_loc_%sysfunc(strip(&client.))_%sysfunc(strip(&period.)) as
	select distinct  memberid
					,pcpid
					,&location. as location
					,guideline_key 
					,"&period." as period
		from lp_%sysfunc(strip(&client.))
			order by guideline_key
					,memberid
					,pcpid
					,&location.;
	quit;

	%if %sysfunc(exist(current1.lp_loc_%sysfunc(strip(&client.))_current)) and %sysfunc(exist(prior1.lp_loc_%sysfunc(strip(&client.))_prior)) %then %do;
		data out_det.lp_loc_%sysfunc(strip(&client.));
		set current1.lp_loc_%sysfunc(strip(&client.))_current
			prior1.lp_loc_%sysfunc(strip(&client.))_prior;
		run;
	%end;

	proc sql;
	create table &period.1.lp_%sysfunc(strip(&client.))_%sysfunc(strip(&period.)) as
	select distinct  memberid
					,pcpid
					,guideline_key 
					,"&period." as period
		from lp_%sysfunc(strip(&client.))
			order by guideline_key
					,memberid
					,pcpid;
	quit;

	%if %sysfunc(exist(current1.lp_%sysfunc(strip(&client.))_current)) and %sysfunc(exist(prior1.lp_%sysfunc(strip(&client.))_prior)) %then %do;
		data out_det.lp_%sysfunc(strip(&client.));
		set current1.lp_%sysfunc(strip(&client.))_current
			prior1.lp_%sysfunc(strip(&client.))_prior;
		run;
	%end;


	/*Join Physician-Attribution to Member Compliance*/
	proc sql;
	create table %if %QUPCASE(&period.)=CURRENT %then %do;
					out_det.submeasures_detail
				 %end;
				 %else %if %QUPCASE(&period.)=PRIOR %then %do;
					out_det.submeasures_detail_%sysfunc(strip(&period.))
				 %end; as
	select 	 a.*
			,b.pcpid
			%if %QUPCASE(&measure_level.) = LOCATION %then %do;
			,b.location
			%end;
		from &period.1.submeasures_detail_mem_%sysfunc(strip(&period.)) as a

		left join
			%if %QUPCASE(&measure_level.) = PROVIDER %then %do;
				&period.1.lp_%sysfunc(strip(&client.))_%sysfunc(strip(&period.)) (drop = period) as b
					on 	a.memberid = b.memberid and
						a.guideline_key = b.guideline_key
					order by a.memberid
							,b.pcpid
							,a.guideline
							,a.submeasure_key
			%end;

			%else %if %QUPCASE(&measure_level.) = LOCATION %then %do;
				&period.1.lp_loc_%sysfunc(strip(&client.))_%sysfunc(strip(&period.)) (drop = period)  as b
					on 	a.memberid = b.memberid and
						a.guideline_key = b.guideline_key
					order by a.memberid
							,b.pcpid
							,b.location
							,a.guideline
							,a.submeasure_key
			%end;
	;
	quit;

	%if %QUPCASE(&period.)=CURRENT %then %do;
		proc sql;
		  drop index pcpid from out_det.submeasures_detail;
		  drop index memberid from out_det.submeasures_detail;
		  drop index guideline from out_det.submeasures_detail;
		  drop index mempcpid from out_det.submeasures_detail;
		  create index pcpid on out_det.submeasures_detail (pcpid);
		  create index memberid on out_det.submeasures_detail (memberid);
		  create index guideline on out_det.submeasures_detail (guideline);
		  create index mempcpid on out_det.submeasures_detail(memberid,pcpid);
		  /*CREATE AN INDEX FOR &LOCATION????*/
		quit;
	%end;

	%if %QUPCASE(&period.)=PRIOR %then %do;
		proc sql;
		  drop index pcpid from out_det.submeasures_detail_%sysfunc(strip(&period.));
		  drop index memberid from out_det.submeasures_detail_%sysfunc(strip(&period.));
		  drop index guideline from out_det.submeasures_detail_%sysfunc(strip(&period.));
		  drop index mempcpid from out_det.submeasures_detail_%sysfunc(strip(&period.));
		  create index pcpid on out_det.submeasures_detail_%sysfunc(strip(&period.)) (pcpid);
		  create index memberid on out_det.submeasures_detail_%sysfunc(strip(&period.)) (memberid);
		  create index guideline on out_det.submeasures_detail_%sysfunc(strip(&period.)) (guideline);
		  create index mempcpid on out_det.submeasures_detail_%sysfunc(strip(&period.))(memberid,pcpid);
		  /*CREATE AN INDEX FOR &LOCATION????*/
		quit;
	%end;

	*SASDOC--------------------------------------------------------------------------
	| create Overall provider-level data
	------------------------------------------------------------------------SASDOC*; 
	proc sql;
	create table provlevel as
	select distinct  memberid
					,guideline
					,guideline_key
					,submeasure
					,submeasure_key
					,comp
					,pcpid
		from %if %QUPCASE(&period.)=CURRENT %then %do;
					out_det.submeasures_detail
			 %end;
			 %else %if %QUPCASE(&period.)=PRIOR %then %do;
				out_det.submeasures_detail_%sysfunc(strip(&period.))
			 %end;

			 %if %QUPCASE(&measure_level.) = PROVIDER %then %do;
				order by memberid
						,pcpid
						,guideline
						,submeasure_key
			%end;

			%else %if %QUPCASE(&measure_level.) = LOCATION %then %do;
				order by memberid
						,pcpid
						,location
						,guideline
						,submeasure_key
			%end;
	;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| g9 - used only in the outlier report
	------------------------------------------------------------------------SASDOC*; 
	proc sql;
	create table &period.1.g9 as
	select distinct  pcpid
					,guideline
					,guideline_key
					,sum(eligible) as elig
					,sum(compliant) as comp
					,calculated comp / calculated elig as comprate format=percent7.1
			from
			(select  pcpid
					,guideline
					,guideline_key
					,comp as compliant
					,1 as eligible
					,memberid
				from provlevel (where = (submeasure="Overall"))
			)
		group by pcpid, guideline_key
		order by guideline_key, pcpid;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| g6 - submeasures_&period.
	------------------------------------------------------------------------SASDOC*; 
	proc sql;
	create table out_det.submeasures_&period. as
	select distinct
	            pcpid
	            ,guideline
	            ,guideline_key
	            ,submeasure
	            ,submeasure_key
	            ,sum(eligible) as elig
	            ,sum(compliant) as comp
	            ,calculated comp / calculated elig as comprate format=percent7.1
	      from
	      (select  pcpid
	              ,guideline
	              ,guideline_key
	              ,submeasure
	              ,submeasure_key
	              ,comp as compliant
	              ,1 as eligible
	              ,memberid
				from provlevel
	      )
	      group by pcpid, guideline_key, submeasure_key
	      order by guideline_key, submeasure_key, pcpid
	      ;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| BPM - Reset the process control tables to complete.        
	+------------------------------------------------------------------------SASDOC*;	
	
%mend portal_dates;
/*
%portal_dates_test(period=prior);
%portal_dates_test(period=current);
*/
