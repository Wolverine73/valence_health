%macro lab_detail_max (submeasure_key = );
libname lab 'M:\CI\sasdata\ValenceBaseMeasures\Guideline Development';
	%if &lab_results = 1 and &period = current %then %do;

		proc sql noprint;
		select  (control_limit)
			   ,quote(strip(care_element))
			into :control_limit
				,:care_element  
		from lab.retrospective_labtable
		where client in ("&Client") and guideline_key in ("&guideline_key") and submeasure_key in ("&submeasure_key");
		quit;

		proc sql noprint;
		create table lab_&submeasure_key as
		(select distinct l.memberid "memberid" format 16.
				/*,"&guideline_name" as guideline*/
				,"&guideline_key" as guideline_key
				/*,'&submeasure_name' as Submeasure */
				,"&submeasure_key" as Submeasure_key 
				,l.svcdt as lab_date
				,l.value_numeric
				,case 
				when l.value_numeric > &control_limit. or value_numeric = . then 1
				when l.value_numeric <= &control_limit. then .
				end as comp
				,upcase(strip(c.care_granular)) as care_granular2
			
				from control.care_elements c, lab_edw as l
					where ((l.svcdt between &stdt. and &enddt.)
					and (l.lab_code = c.code)
					and (calculated care_granular2 in(&care_element) and c.indicator in ("LOINC"))))
				order by  l.memberid, l.svcdt desc;
				quit;

		data lab_last_&submeasure_key (drop =  care_granular2);
		set lab_&submeasure_key;
		by memberid;
		if first.memberid then output;
		run;

	%end;
%mend lab_detail_max;
