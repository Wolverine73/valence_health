/*HEADER------------------------------------------------------------------------
|
| program:  last_seen_V3.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  program for last_seen attribution
|
+--------------------------------------------------------------------------------
| *HISTORY:  
| 11APR2012	- EM Added reportingType macros for clients
| 16AUG2012 - EM dmpat_comment now read in from work folder
| HISTORY*
+-----------------------------------------------------------------------HEADER*/

%macro last_seen_V3;

	Data elig4 (keep= memberid provid svcdt rank pcpid&location.);
	set g1;

		where provspec in (&rank1. &rank2. &rank3.) and
		
	  		%if %qupcase(&client) =ADVENTIST 	%then %do; put(provid||" "||tin,$ReportingType.)	in ("V")			and	%end;
	  %else %if %qupcase(&client) =CCCPP 		%then %do; put(provid,$provtype.) 					in ("P","V","U") 	and	%end;
/*	  %else %if %qupcase(&client) =NSAP 		%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;*/
	  %else %if %qupcase(&client) =OHG 			%then %do; put(provid,$ProvType.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =STLUKES 		%then %do; put(provid,$rptcode.) 					in ("NotManual")	and	%end;

	  /*PHS, NORTHSHORE, EXEMPLA*/
	  %else %do; 
		put(provid,$provtype.) in ("P","V") and 
	  %end;

		substr(provid,1,1) not in ("8","9") and

		put(provid,$provyn.) = "Y" and 

		&var. ge 1 and

		source in ("C","P");

		if provspec in (&rank1.) then rank=1;
		else if provspec in (&rank2.) then rank=2;
		else if provspec in (&rank3.) then rank=3;
		pcpid&location. = cat(provid,"|",&location);
		/*rename provid = pcpid;*/
	run;

	%if %QUPCASE(&period.) = CURRENT %then %do;
		data no_longer /*comment_key = 2*/
			 gl_notapplicable /*comment_key = 4*/
			 ;
		set /*out_det.*/DMPAT_COMMENT;
			if comment_key = 2 then do;
				no_longer_pt = 1;
				output no_longer;
			end;
			else if comment_key = 4 then do;
				if guideline_key = "&guideline_key." then do;
					gl_notapplicable = 1;
					output gl_notapplicable;
				end;
			end;
		run;

		proc sql noprint;
			select count(*) into: no_longer
				from no_longer;

			select count(*) into: gl_notapplicable
				from gl_notapplicable;
		quit;
		%put &no_longer.;
		%put &gl_notapplicable.;

		%macro provider_comments;
			%if &no_longer. ^= 0 or &gl_notapplicable. ^= 0 %then %do;
				proc sql;
				create table elig4a as
				select a.*

				/*Remove 'No Longer My Patient' comment attributions*/
				%if &no_longer. ^= 0 %then %do;
						,b.no_longer_pt
				%end;
				/*Remove patients with 'Measure Exclusion' comments*/
				%if &gl_notapplicable. ^= 0 %then %do;
						,c.gl_notapplicable
				%end;
					from elig4 as a
					%if &no_longer. ^= 0 %then %do;
						left join
							no_longer as b
								/*Remove attributions on a member-provider level*/
								on a.memberid = b.memberid and
								   a.provid = b.provid
					%end;
					%if &gl_notapplicable. ^= 0 %then %do;
						left join
							gl_notapplicable as c
								/*Remove attributions on a member level*/
								on a.memberid = c.memberid
					%end;
					;
				quit;
			%end;
			%else %do;
				data elig4a;
				set elig4;
					no_longer_pt = .;
					gl_notapplicable = .;
				run;
			%end;
		%mend; 
		%provider_comments;

		data elig4;
		set elig4a;
			if no_longer_pt = 1 or gl_notapplicable = 1 then delete;
		run;
	%end;

	proc sort data=elig4;
	by memberid rank descending svcdt;
	run;

	Data elig5;
	set elig4;
	by memberid rank descending svcdt; 
	if first.memberid;
	rename provid = pcpid;
	run;

%mend last_seen_V3;
