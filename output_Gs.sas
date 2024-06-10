%macro output_Gs;
/*	%let start_Gs=%sysfunc(time());*/

/*	data g9_base;*/
/*	set temp.g9_&prefix.;*/
/*	  elig = 1;*/
/*	run;*/

	%if &measure_level = location %then %do;

		/*OUTPUT G12*/
		proc sql;
			create table temp.g12_&prefix. as
			select  distinct pcpid
					,pcpid&location.
					,guideline
					,guideline_key
					,submeasure
					,submeasure_key
					,sum(comp) as comp
					,1 as elig_a
					,sum(calculated elig_a) as elig
					,(sum( Comp) / sum( Elig)) as CompRate format=percent6.1
				from temp.g9_&prefix.
				group by guideline_key,submeasure_key,pcpid,pcpid&location.
				order by guideline_key,submeasure_key,pcpid,pcpid&location.;
		quit;

		/*OUTPUT G13*/
		proc sql;
			create table temp.g13_&prefix. as
			select distinct pcpid
							,pcpid&location.
							,guideline
							,guideline_key
							,sum(comp) as comp
							,sum(elig) as elig
							,(sum( comp) / sum( elig)) as CompRate /*format=percent6.1*/
				from temp.g12_&prefix.
				where submeasure_key = "99"
				group by pcpid,pcpid&location.,guideline_key;
		quit;

		/*OUTPUT G6 at measure_level = location*/
		proc sql;
			create table temp.g6_&prefix. as
			select  distinct pcpid
					,guideline
					,guideline_key
					,submeasure
					,submeasure_key
					,sum(comp) as comp
					,sum(elig) as elig
					,(sum( Comp) / sum( Elig)) as CompRate format=percent6.1
				from temp.g12_&prefix.
				group by guideline_key,submeasure_key,pcpid
				order by guideline_key,submeasure_key,pcpid;
		quit;
	%end;
	%if &measure_level = provider %then %do;
		/*OUTPUT G6 at measure_level = provider*/
		proc sql;
			create table g6a_&prefix. as
			select  distinct pcpid
					,guideline
					,guideline_key
					,submeasure
					,submeasure_key
					,comp
/*					,sum(comp) as comp*/
					,1 as elig
/*					,sum(calculated elig_a) as elig*/
/*					,(sum( Comp) / sum(  Elig)) as CompRate format=percent6.1*/
				from temp.g9_&prefix.
				group by guideline_key,submeasure_key,pcpid
				order by guideline_key,submeasure_key,pcpid;
		quit;

		proc sql;
			create table temp.g6_&prefix. as
			select  distinct pcpid
					,guideline
					,guideline_key
					,submeasure
					,submeasure_key
					,comp
					,elig
/*					,sum(comp) as comp*/
/*					,1 as elig_a*/
/*					,sum(calculated elig_a) as elig*/
					,(sum( Comp) / sum(  Elig)) as CompRate format=percent6.1
				from g6a_&prefix.
				group by guideline_key,submeasure_key,pcpid
				order by guideline_key,submeasure_key,pcpid;
		quit;

	%end;

		/*OUTPUT G8*/
		proc sql;
			create table temp.g8_&prefix. as
			select distinct pcpid
							,guideline
							,guideline_key
							,sum(comp) as comp
							,sum(elig) as elig
							,(sum( comp) / sum( elig)) as CompRate /*format=percent6.1*/
				from temp.g6_&prefix.
				where submeasure_key = "99"
				group by pcpid,guideline_key,submeasure_key;
		quit;

/*	%let end_Gs=%sysfunc(time());*/
/*	data _null_; */
/*	seconds=&end_Gs.-&start_Gs.;*/
/*	minutes=seconds/60;*/
/*	hours=minutes/60;*/
/*	call symputx('seconds', seconds);*/
/*	call symputx('minutes', minutes);*/
/*	call symputx('hours', hours);*/
/*	run;*/
/*	%put NOTE: Production Guideline Gs - Period = BOTH (seconds, minutes, hours) = &seconds. &minutes.;*/

%mend;








/*COMPARE DATASETS*/
/*%let byvar=pcpid guideline submeasure comp1 elig1 CompRate1;*/
/**/
/*data dev (drop =  elig comp comprate);*/
/*set G6_diabetestest;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*run;*/
/**/
/*data prod (drop =  elig comp comprate);*/
/*set G6_diabetes;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*run;*/
/**/
/*proc sort data = dev;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc sort data = prod;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc compare base     = dev*/
/*	         compare  = prod;*/
/*run;*/
/**/
/*%let byvar=pcpid guideline comp1 elig1 CompRate1;*/
/*data dev (drop =  elig comp comprate);*/
/*set g8_&prefix.test;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*run;*/
/**/
/*data prod (drop =  elig comp comprate &prefix._HbA1cC &prefix._visitC &prefix._lipidC &prefix._microC &prefix._eyeC);*/
/*set G8_diabetes;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*run;*/
/**/
/*proc sort data = dev;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc sort data = prod;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc compare base     = dev*/
/*	         compare  = prod;*/
/*run;*/
/**/
/*%let byvar=pcpid&location. guideline submeasure comp1 elig1 CompRate1;*/
/*data dev (drop = elig comp comprate);*/
/*set G12_diabetestest;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*	run;*/
/**/
/*data prod (drop = elig comp comprate);*/
/*set G12_diabetes;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*run;*/
/**/
/*proc sort data = dev;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc sort data = prod;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc compare base     = dev*/
/*	         compare  = prod;*/
/*run;*/
/**/
/**/
/*%let byvar=pcpid&location. guideline comp1 elig1 CompRate1;*/
/*data dev (drop =  elig comp comprate &prefix._HbA1cC &prefix._visitC &prefix._lipidC &prefix._microC &prefix._eyeC);*/
/*set G13_diabetestest;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*run;*/
/**/
/*data prod (drop =  elig comp comprate &prefix._HbA1cC &prefix._visitC &prefix._lipidC &prefix._microC &prefix._eyeC);*/
/*set G13_diabetes;*/
/*	elig1=floor(elig);*/
/*	comp1=floor(comp);*/
/*	comprate1=floor(comprate*100);*/
/*run;*/
/**/
/*proc sort data = dev;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc sort data = prod;*/
/*by &byvar;*/
/*run;*/
/**/
/*proc compare base     = dev*/
/*	         compare  = prod;*/
/*run;*/
