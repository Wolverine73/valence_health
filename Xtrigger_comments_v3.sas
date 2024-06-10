/*| 24MAY2012 - LS add Northshore into the conditional logic for provtype.*/

%macro xtrigger_comments_v3;
%if &trigger_comments = 1 %then %do;
	data g5;
	set g5;

	where 	 %if %qupcase(&client) =ADVENTIST 	%then %do; put(pcpid||" "||tin,$ReportingType.)	in ("V")			and	%end;
	  %else %if %qupcase(&client) =CCCPP 		%then %do; put(pcpid,$provtype.) 					in ("P","V","U") 	and	%end;
	  %else %if %qupcase(&client) =EXEMPLA 		%then %do; put(pcpid,$provtype.) 					in ("P", "V") 		and	%end;
/*	  %else %if %qupcase(&client) =NSAP 		%then %do; put(pcpid,$provtype.) 					in ("P", "V") 		and	%end;*/
	  %else %if %qupcase(&client) =NORTHSHORE	%then %do; put(pcpid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =OHG 			%then %do; put(pcpid,$ProvType.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =PHS 			%then %do; put(pcpid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =STLUKES 		%then %do; put(pcpid,$rptcode.) 					in ("NotManual")	and	%end;

	  substr(pcpid,1,1) not in ("8","9") and
	  put(pcpid,$provyn.) = "Y";

	%if &period = current %then %do;
		length mem_guide $32. mem_pcp $29. guideline_key $15. memberid_c $16.;
		guideline_key = "&guideline_key.";
		memberid_c = put(memberid,16.);
		mem_guide = strip(put(memberid_c,$16.))||"||"||strip(guideline_key);
		mem_pcp = strip(put(memberid_c,$16.))||"||"||cats(pcpid);
	    	
		if put(memberid,$expired.) = 'Y' then delete;
		if put(mem_guide,$refused.) = 'Y' then delete;
		if put(mem_pcp,$nopat.) = 'Y' then delete;
		run;
	%end;
%end;
%mend xtrigger_comments_v3;
