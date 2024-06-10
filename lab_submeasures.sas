/*HEADER------------------------------------------------------------------------
|
| program:  lab_submeasures.sas
|
| location: \\sas2\CI\programs\StandardMacros
|
| purpose:  calculate lab submeasures for the retrospective guidelines
|
+----------------------------------------------------------------------------------------------------------------------------------------------------
| *HISTORY:  
| 05APR2012 - EM Added lab_stdt and lab_enddt parameters to compliance1 dataset
| 31AUG2012 - EM SAS code saves out to text files on \\sas2 now
| HISTORY*
/*+-----------------------------------------------------------------------------------------------------------------------------------------HEADER*/

%macro lab_submeasures;

	data _null_;
	gk1 = %sysfunc(scan(&guideline_key.,1,"."));
	gk2 = %sysfunc(scan(&guideline_key.,2,"."));
	gkey = strip(gk1)||"_"||strip(gk2);
	call symputx('gkey',gkey);
	run;
	%put &gkey.;

	/** Create lab_submeasures_detail to display eligibility/compliance lab data for guidelines of interest **/
	data lab_ranges (rename = (sub_key=submeasure_key));
	length submeasure care_element range submeasure_key $30. comorbidity 3. operator $3. conditional $5. guideline_key $15.;
	format submeasure care_element range submeasure_key $30. comorbidity 3. operator $3. conditional $5. guideline_key $15.;
	informat submeasure care_element range $30. submeasure_key comorbidity 3. operator $3. conditional $5. guideline_key $15.;
	set control.Lab_rules (where=(guideline_key = "&gkey."));

	sub_key = input(submeasure_key,3.);
	drop submeasure_key;

	range_op = strip(strip(operator)||" "||strip(range));
	run;

	proc sort data = lab_ranges;
	by guideline_key care_element submeasure submeasure_key comorbidity;
	run;

	proc transpose 	data = lab_ranges
					out = lab_ranges1 (drop = _NAME_);
		by guideline_key care_element submeasure submeasure_key comorbidity conditional;
		var range_op;
	run;

	/** Create a counter table based on the number of columns after transpose **/
	proc transpose 	data = lab_ranges1
					out = num_cols (keep = _NAME_);
	var COL:;
	run;

	proc sql noprint;
		select count(_name_) into :col_obs
			from num_cols;
	quit;
	%put &col_obs.;

	proc sort data = lab_ranges1;
	by submeasure_key comorbidity;
	run;

	/*Determine the number of columns in the table*/
	%macro col_count;
		data num_colsA;
		set Lab_ranges1;
		length count 3.;

		  count = 0;

		  %do i=1 %to &col_obs.;		
			if COL&i. ne '' then count + 1;
		  %end;
		run;
	%mend col_count;
	%col_count;


	/*Total Number of Ranges per Submeasure*/
	data range_cnt;
	set num_colsA end=eof;
	  g+1;
	  ii=left(put(g,4.));
	  a=count;
	  b=submeasure_key;
	  c=strip(conditional);
	  d=strip(comorbidity);

		call symput('count'||ii,trim(a));
		call symput('submeasure_key'||ii,trim(b));
		call symput('conditional'||ii,strip(c));
 		call symput('comorbid'||ii,trim(d));
 		call symput('order'||ii,trim(g));
    if eof then call symput('totalr',ii);
	run;
	%put &totalr;

	%macro k;

		/*Create the lab range rule and insert conditions (and / or) if necessary*/
		%do l = 1 %to &totalr.;
			%macro lab_range(sk=, cnt=, cond=);

				data num_cols&l.;
				set num_colsA;
				length lab_rule $50.;

				where submeasure_key=&sk.;
					if count > 1 then do;
					/*do loop*/							
					%do i=1 %to &cnt;
						%if &i. = 1 and &i. ^= &cnt. %then %do;
							lab_rule = "value"||strip(col&i.)||" "||conditional
						%end;
						%else %if &i. ne 1 and &i. ^= &cnt. %then %do;
							||" "||"value"||strip(col&i.)||" "||conditional
						%end;
						%else %if &i. = 1 and &i. = &cnt. %then %do;
							lab_rule = "value"||strip(col&i.)
						%end;
						%else %do;
							||" "||"value"||strip(col&i.)
						%end;
					%end;
					;
					output;
					end;

					else if count = 1 then do;
					/*assign one value*/
						lab_rule = "value"||strip(col1);
						output;
					end;

					else do;
					/*assign missing value*/
						lab_rule = "";
						output;
					end;
				run;
			%mend;
			%lab_range(sk=&&submeasure_key&l, cnt=&&count&l, cond=&&conditional&l);

			%if &l.=1 %then %do;
				data lab_rules;
				set num_cols&l. (keep = guideline_key care_element submeasure submeasure_key comorbidity lab_rule);
				run;
			%end;
			%else %do;
				data lab_rules;
				set lab_rules
					num_cols&l. (keep = guideline_key care_element submeasure submeasure_key comorbidity lab_rule);
				run;
			%end;
		%end;
	%mend;
	%k;

	/*Create Lab Rules Macros*/
	proc sort data = lab_rules nodup out = lab_rules1;
	by guideline_key care_element submeasure_key comorbidity;
	run;

	/*Create text file to create code for lab rules*/
	data a;
	  file "M:\CI\programs\ValenceBaseMeasures\Retrospective\V3\PRODUCTION\lab_files\&client._&gkey._submeasures.txt" lrecl=5000;
	  set lab_rules1 end=eof; 
	  by guideline_key care_element submeasure_key;

		  gk='"'||trim(left(upcase(guideline_key)))||'"';
		  ce='"'||trim(left(upcase(care_element)))||'"';
		  sm='"'||trim(left(submeasure))||'"'; 
		  sk=trim(left(upcase(submeasure_key))); 
		  lr=trim(left(upcase(lab_rule))); 
		  co=trim(left(upcase(comorbidity))); 

		  mr='"'||'"';
	  

			 if first.submeasure_key and _n_=1 then do;
			   put "	if care_element=" ce " then do;";
			 end;
			 else if first.care_element then do;
			   put "	else if care_element= "ce " then do;";
			 end; 
		
			 if first.care_element then do;
				if comorbidity ^= . then do;	/*does not require comorbidity*/
					if comorbidity = 0 then do;	/*does not require comorbidity*/
				    put "		if submeasure_key in (" sk ") then do;";
				    put "      		submeasure = " sm ";";
					put "      		if comorbidity = " co " then do;";
				    put "      			if " lr " then comp = 1;";
				    put "      			else comp = 0;";
				    put "      		end;";
					end;
					if comorbidity = 1 then do;	/*does not require comorbidity*/
					put "      		else if comorbidity = " co " then do;";
				    put "      			if " lr " then comp = 1;";
				    put "      			else comp = 0;";
				    put "      		end;";
					put "		end;";
					end;
				end;
				else do;
				    put "		if submeasure_key in (" sk ") then do;";
				    put "      		submeasure = " sm ";";
				    put "      		if " lr " then comp = 1;";
				    put "      		else comp = 0;";
					put "		end;";
				end;
			 end;

			 else do;
				if comorbidity ^= . then do;	/*does not require comorbidity*/
					if comorbidity = 0 then do;	/*does not require comorbidity*/
				    put "		else if submeasure_key in (" sk ") then do;";
				    put "      		submeasure = " sm ";";
					put "      		if comorbidity = " co " then do;";
				    put "      			if " lr " then comp = 1;";
				    put "      			else comp = 0;";
				    put "      		end;";
					end;
					if comorbidity = 1 then do;	/*does not require comorbidity*/
					put "      		else if comorbidity = " co " then do;";
				    put "      			if " lr " then comp = 1;";
				    put "      			else comp = 0;";
				    put "      		end;";
					put "		end;";
					end;
				end;
				else do;
				    put "		else if submeasure_key in (" sk ") then do;";
				    put "      		submeasure = " sm ";";
				    put "      		if " lr " then comp = 1;";
				    put "      		else comp = 0;";
					put "		end;";
				end;
			 end;

			 if last.care_element then do;
			    put "	 end;";
			    put " ";
			 end;

/*			 if eof then do;*/
/*			    put "end;";*/
/*			 end;*/
	run; 


	proc sql;
	create table lab_compliance1 as
	select a.* 
		from out_det.lab_submeasures_detail (where=(&lab_stdt. <= svcdt < &lab_enddt.)) as a

		inner join
		(	
			select distinct memberid
				from g5b
		) as d
			on a.memberid = d.memberid
			order by a.memberid, a.care_element, a.value;
	quit;


	/*Take the latest lab service date, sort by hierarchy value*/
	proc sql;
	create table lab_compliance as

		select distinct	a.maxSvcdt format=mmddyy10. as svcdt,
						b.memberid,
						b.client_key label="",
						/*b.units*/
						b.value label="" as value_character,
						b.value_numeric label="" as value,
						"&guideline_key." as guideline_key,
						b.care_element from

		(	select distinct max(svcdt) as maxSvcdt,
							memberid,
							client_key,
							care_element
				from lab_compliance1
					group by client_key,memberid,care_element
		) a
			
		inner join
		  
		(	select distinct svcdt,
							memberid,
							value,
							value_numeric,
							client_key,
							care_element
				from lab_compliance1
		) b
		 
			on	a.memberid = b.memberid and
				a.client_key = b.client_key and
				a.care_element = b.care_element and
		  		a.maxSvcdt = b.svcdt

		inner join
		
		(	select distinct care_element
							,guideline_key 
				from lab_ranges
		) as c

			on a.care_element = c.care_element
			order by b.memberid, b.care_element, b.value
	;
	quit;

	proc sql;
	create table mashup as
	select 	a.guideline_key,
			a.client_key,
			a.memberid,
			a.svcdt,
			a.care_element,
			a.value,
			a.value_character,
			b.submeasure_key,
			b.comorbidity from
	
		lab_compliance as a

		inner join

		lab_rules1 as b
			on 	a.care_element = b.care_element
		;
	quit;


	/*Output the lab_submeasures_comp which contains which compliance bucket the lab value falls into */
	data lab_submeasures_comp (rename = (svcdt=date));
	set mashup;
	attrib _all_ label = '';
	  %include "M:\CI\programs\ValenceBaseMeasures\Retrospective\V3\PRODUCTION\lab_files\&client._&gkey._submeasures.txt";
	  elig = 1;
	run;

	proc sort data = lab_submeasures_comp;
	by memberid submeasure_key;
	run;

	/*Create a line for members with missing labs for a particular lab test -- will be populated with format in guideline code*/
	proc sql;
	create table all_mems as
	select distinct memberid, "&guideline_key" as guideline_key 
		from lab_submeasures_comp;
	quit;

	proc sql;
	create table g9_lab_all as
	select distinct a.memberid,
					a.guideline_key,
					b.submeasure_key,
					b.submeasure
	from
		all_mems as a
	full outer join
		(select distinct submeasure_key, submeasure, "&guideline_key" as guideline_key from lab_rules1) as b
			on a.guideline_key = b.guideline_key
			order by a.memberid,b.submeasure_key;
	quit;

	/*Create a record -- even if lab is missing -- for every memberid-lab test combination*/
	data g9_lab_&prefix.;
	merge g9_lab_all (in = a)
		  lab_submeasures_comp (in = b keep = memberid guideline_key submeasure submeasure_key comp date comorbidity);
		by memberid submeasure_key;
		if a;
		elig = 1;
	run;

	/*Output g9 table -- ATTENTION: members with missing lab values will not be flagged in this table, this needs to be done in the
	  guideline program because the 'missing lab compliance' flag is unknown at this point*/
/*	proc sort data = g9_lab_&prefix. out = out.g9_lab_&prefix.;*/
/*	by memberid submeasure_key comorbidity;*/
/*	run;*/
	
	/*Begin creating g5_lab table to support creating g6 tables*/
	/*Total Number of Submeasures*/
	proc sql;
	create table sub_cnt as
	select distinct submeasure_key 
		from Lab_ranges1
			order by submeasure_key;
	run;

	data sub_cnt1;
	set sub_cnt end=eof;
	  g+1;
	  ii=left(put(g,4.));
	  b=submeasure_key;

	  call symput('sub_key'||ii,trim(b));
      if eof then call symput('totals',ii);
	run;
	%put &totals;

	proc sql;
	create table range_cntr as
	select a.submeasure_key,
		   a.g from
		sub_cnt1 as a
		inner join
			range_cnt as b
				on a.submeasure_key = b.submeasure_key;
	quit;

	data range_cntr1;
	set range_cntr end=eof;
	  h+1;
	  ii=left(put(h,4.));

	  call symput('r_cntr'||ii,trim(g));
      if eof then call symput('totalq',ii);
	run;
	%put &totalq;

	%do m = 1 %to &totalr.;
		data _g5_%sysfunc(strip(&&submeasure_key&m));
		%sysfunc(strip(&prefix.))_%sysfunc(strip(&&submeasure_key&m)) = .;
		run;
	%end;

	data g5prep;
	%do n = 1 %to &totalr.;
		set _g5_%sysfunc(strip(&&submeasure_key&n));
	%end;
	format memberid 16.;
	informat memberid 16.;
	length 	memberid 8.
			comorbidity
			submeasure_key 3.;
	run;

	proc datasets library=work;
	delete _g5_:
	run;
	quit;

	/*only flag 1 submeasure as compliant per care element-comorbidity combination*/
	%macro a;
		data g5_lab (drop = guideline_key date /*submeasure_key submeasure comp elig*/);
		set g5prep (obs = 0)
			g9_lab_%sysfunc(strip(&prefix.));	
			array submeas{*} $ 	%do y=1 %to &totals.;
									%sysfunc(strip(&prefix.))_%sysfunc(strip(&&sub_key&y)) 
								%end;
								;
			sub_key = strip(put(submeasure_key,3.));
			comor = strip(put(comorbidity,3.));
			do sm = 1 to &totals.;
				%do p = 1 %to &totalr.;
					if sub_key = "%sysfunc(strip(&&submeasure_key&p))" and comor = "%sysfunc(strip(&&comorbid&p))" then do;
						submeas{%sysfunc(strip(&&r_cntr&p))} = comp;
					end;
					else if comorbidity = 0 and "%sysfunc(strip(&&comorbid&p))" = 1 then do; /*don't rewrite over comorbid = 0 flag*/
					end;
					else submeas{%sysfunc(strip(&&r_cntr&p))}= .;
				%end;		
			end;
			drop sm;
		run;
	%mend;
	%a;

	proc summary data = g5_lab nway missing;
	class memberid comorbidity;
	var %sysfunc(strip(&prefix.)):;
	output out = g5_lab_%sysfunc(strip(&prefix.)) (drop = _:) sum=;
	run;

	/*table of memebers with labs, but missing one or more tests -- use this table in the guideline to flag missing lab values*/
	proc summary data = g5_lab_%sysfunc(strip(&prefix.)) nway missing;
	class memberid;
	var %sysfunc(strip(&prefix.)):;
	output out = g5_lab1a (drop = _:) sum=;
	run;

	proc sort data = g5_lab_%sysfunc(strip(&prefix.)) out = temp.g5_lab_%sysfunc(strip(&prefix.));
	by memberid comorbidity;
	run;

	proc datasets library=work;
	delete 	lab_:
			num_:
			range_:
			g5prep
			g9_lab:
			mashup
			sub_cnt:;
	run;
	quit;

%mend;
