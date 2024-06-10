/*HEADER------------------------------------------------------------------------
|
| program:  trigger_comments_V3.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  program for triggering attribution
|
+--------------------------------------------------------------------------------
| *HISTORY:  
| 01AUG2011 - VH Original Program
| 01NOV2011 - EM Changed prep table to elig4 to comply with previous attribution program.
|				 Also calling the provider_comments_V3 program now (provid var replaces pcp1)
| 06APR2012 - EM Processes the PAS table, and able to accept attribution at the provider or provider-location
|				 level. Applies comments to the provider(-location) attribution table
| 21MAY2012 - EM Rename PAS_ table to LP_ table
| 16AUG2012 - EM dmpat_comment now read in from work folder
| HISTORY*
+-----------------------------------------------------------------------HEADER*/

%macro trigger_comments_v3;
%if &trigger_comments = 0 %then %do;
	data temp.LP_%sysfunc(strip(&prefix.)) (keep = memberid guideline_key pcpid %if %QUPCASE(&MEASURE_LEVEL.) = LOCATION %then %do;
																						&location.
																					 %end;
											);
	set LP_%sysfunc(strip(&prefix.)) 	%if %QUPCASE(&MEASURE_LEVEL.) = LOCATION %then %do;
												(rename = (pcpid=pcpid_loc))
											%end;
	;
	%if %QUPCASE(&MEASURE_LEVEL.) = LOCATION %then %do;
		length pcpid $12. %sysfunc(strip(&location.)) $9.;
		pcpid = strip(scan(pcpid_loc,1,"|"));
		%sysfunc(strip(&location.)) = strip(scan(pcpid_loc,2,"|"));	
	%end;
	run;
%end;

%else %if &trigger_comments = 1 %then %do;

	data LP;
	set LP_%sysfunc(strip(&prefix.));
	/*if measuring at the provider-location level, pcpid = the start value*/
	where 	  
	  		%if %qupcase(&client) =ADVENTIST 	%then %do; put(pcpid||" "||tin,$ReportingType.)	in ("V")			and	%end;
	  %else %if %qupcase(&client) =CCCPP 		%then %do; put(pcpid,$provtype.) 					in ("P","V","U") 	and	%end;
	  %else %if %qupcase(&client) =EXEMPLA 		%then %do; put(pcpid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =NSAP 		%then %do; put(pcpid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =OHG 			%then %do; put(pcpid,$ProvType.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =PHS 			%then %do; put(pcpid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =STLUKES 		%then %do; put(pcpid,$rptcode.) 					in ("NotManual")	and	%end;

	  substr(pcpid,1,1) not in ("8","9") and
	  put(pcpid,$provyn.) = "Y";
	run;

	data temp.LP_%sysfunc(strip(&prefix.));
	set LP %if %QUPCASE(&MEASURE_LEVEL.) = LOCATION %then %do;
				(rename = (pcpid=pcpid_loc))
			%end;
	;
	%if %QUPCASE(&MEASURE_LEVEL.) = LOCATION %then %do;
		length pcpid $12. %sysfunc(strip(&location.)) $9.;
		pcpid = strip(scan(pcpid_loc,1,"|"));
		%sysfunc(strip(&location.)) = strip(scan(pcpid_loc,2,"|"));	
	%end;
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
					from temp.LP_%sysfunc(strip(&prefix.)) as a
					%if &no_longer. ^= 0 %then %do;
						left join
							no_longer as b
								/*Remove attributions on a member-provider level*/
								on a.memberid = b.memberid and
								   a.pcpid = b.provid
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
				set temp.LP_%sysfunc(strip(&prefix.));
					no_longer_pt = .;
					gl_notapplicable = .;
				run;
			%end;
		%mend; 
		%provider_comments;

		data temp.LP_%sysfunc(strip(&prefix.)) (keep = memberid guideline_key pcpid %if %QUPCASE(&MEASURE_LEVEL.) = LOCATION %then %do;
																						&location.
																					 %end;
												);
		set elig4a;
			if no_longer_pt = 1 or gl_notapplicable = 1 then delete;
		run;
	%end;

%end;
%mend trigger_comments_v3;
