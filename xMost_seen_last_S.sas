/*HEADER------------------------------------------------------------------------
|
| program:  most_seen_last_s.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  program for single attribution
|
+--------------------------------------------------------------------------------
| *HISTORY:  
| 01AUG2011 - VH Original Program
| 01NOV2011 - EM Changed prep table to elig4 to comply with previous attribution program.
|				 Also calling the provider_comments_V3 program now (provid var replaces pcp1)
| 18JAN2012 - LS place in qupcase for client specific condition statements.
| 13MAR2012 - EM Implemented provtype of "P","V" or "U" for CCCPP
| 03MAY2012 - EM PHS now calls provtype since going into CIO
| 24MAY2012 - LS add Northshore into the conditional logic for provtype.
| HISTORY*
+--------------------------------------------------------------------------------
| DIRECTIONS:
| **RANK**
|	Usage:  Use rank1 only for mulitple attribution.  Use ranks 1 - 3 for single attribution.
|
|	Mulitple attribution:  The provider specialties listed in rank1 are the only specialties considered for attribution
|	under the multiple attribution model .  When available in the data, one provider per specialty will be assigned to the 
|	patient.
|
|	Single attribution:  One provider of the highest rank (indicated bylowest rank number (rank 1 over rank2, rank2 over rank3)
|	will be assigned to the patient.
|
| **Class**
|	Usage:  available for multiple attribution only.  Allows providers of similar specialties to be rolled up to a single 
|	specialty group so that the most appropriate provider of the rolled up group can be assigned to the patient under
|	mulitple attribution models.  The class assignment is SPECIFIC TO THE GUIDELINE; therefore, the usage of a format on the
|	EDW in lieu of the class assignment is not advised at this time.
|
|	Example 1: Colon cancer screening 
|	Providers from family practice (provspec 21), internal medicine (provspec 35), geriatric medicine (provspec 25)
|	No class variable, one provider from each specialty will be assigned.
|	If Class1_provspec = "21","35","25", then only the most appropriate provider of these three specialties will be assigned
|	using the most seen last logic.
|
|	Example 2:  Asthma, ages 12 - 50.
|	Class1 				= "21","25","35","62"; Roll up IM, peds, geriatrics, etc. to a single "dummy category" primary care for
|										use in attribution for this guideline only.
|	Class1_provspec2 	= "35";  
|	Class2 				= "02","56"; Roll up pediatric allergists and allergists to a single category of allergist for use in 
|							 attribution for this guideline only.
|	Class2_provspec2 	= "02";
|	class3				= "XX" ;
|	class3_provspec2	= "XX";
|
|	location = TIN;
|	attribution = S;
+-----------------------------------------------------------------------HEADER*/
%macro xmost_seen_last_S;

	data elig4;
	set g1;
	where provspec in (&rank1. &rank2. &rank3.) and
			
	  		%if %qupcase(&client) =ADVENTIST 	%then %do; put(provid||" "||tin,$ReportingType.)	in ("V")			and	%end;
	  %else %if %qupcase(&client) =CCCPP 		%then %do; put(provid,$provtype.) 					in ("P","V","U") 	and	%end;
	  %else %if %qupcase(&client) =EXEMPLA 		%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =NORTHSHORE	%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =OHG 			%then %do; put(provid,$ProvType.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =PHS 			%then %do; put(provid,$provtype.) 					in ("P", "V") 		and	%end;
	  %else %if %qupcase(&client) =STLUKES 		%then %do; put(provid,$rptcode.) 					in ("NotManual")	and	%end;

			  substr(provid,1,1) not in ("8","9") and

			  put(provid,$provyn.) = "Y" and 

			  &var. ge 1 and

			  source in ("C","P") ;



		if provspec in (&rank1) then rank = 1;
		else if provspec in (&rank2) then rank = 2;
		else if provspec in (&rank3) then rank = 3;
		run;


	%provider_comments_V3;	/*removed "not my patient" comments*/

	proc sql noprint;
	create table prep2 as
	select distinct *
		from elig4;
			quit;


	/*  Single attribution   */

		proc sql noprint;
			create table attributiona as 
				select distinct 
						 memberid
						,provid as pcpid
						,rank
						,sum(&var.) as sum_visits
						,cat(provid,"|",&location) as pcpid&location
						,max(svcdt) format mmddyy10. as last_seen
						from prep2
						group by memberid, pcpid
						having sum_visits not is null
						order by memberid, rank, sum_visits desc, last_seen desc, pcpid;
						
					quit;


		data attributionb ;
		length max_visit 3.;
		set attributiona;
		by memberid rank;
		retain max_visit;
			if first.rank then do;
			max_visit = sum_visits;
			end;

		if sum_visits = max_visit then output;

		run;


		data elig5;
		set attributionb;
		by memberid;

		if first.memberid then output;
		run;


		/*  Attribution to practice   */
		proc sql noprint;
		create table practice as
		select   a.memberid
				,a.pcpid 
				,scan(a.pcpid&location,-1,'|') as &location 
				from AttributionA a, elig5 b
				where a.memberid = b.memberid and a.pcpid=b.pcpid
/*				order by memberid, pcpid, a.pcpid&location;*/
                order by memberid, pcpid, &location;
				quit; 

%mend xmost_seen_last_S;
