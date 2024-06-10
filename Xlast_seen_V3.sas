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
| 02MAY2012	- EM PHS moving to EDW, uses standard macro for provtype instead of rptcode
| 24MAY2012 - LS add Northshore into the conditional logic for provtype.
| HISTORY*
+-----------------------------------------------------------------------HEADER*/

%macro xlast_seen_V3;

	Data elig4 (keep= memberid provid svcdt rank pcpid&location.);
	set g1;

		where provspec in (&rank1. &rank2. &rank3.) and
		
	  		%if %qupcase(&client) =ADVENTIST 	%then %do; put(provid||" "||tin,$ReportingType.)	in ("V")			and	%end;
	  %else %if %qupcase(&client) =CCCPP 		%then %do; put(provid,$provtype.) 					in ("P","V","U") 	and	%end;
	  %else %if %qupcase(&client) =EXEMPLA 		%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;
/*	  %else %if %qupcase(&client) =NSAP 		%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;*/
	  %else %if %qupcase(&client) =NORTHSHORE	%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =OHG 			%then %do; put(provid,$ProvType.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =PHS 			%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =STLUKES 		%then %do; put(provid,$rptcode.) 					in ("NotManual")	and	%end;

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

	%provider_comments_V3;

	proc sort data=elig4;
	by memberid rank  descending svcdt;
	run;

	Data elig5;
	set elig4;
	by memberid rank  descending svcdt; 
	if first.memberid;
	rename provid = pcpid;
	run;

%mend xlast_seen_V3;
