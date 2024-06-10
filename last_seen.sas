/*HEADER------------------------------------------------------------------------
|
| program:  Last_seen.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose: Last Attribution logic for guidelines                     
|
| logic:                                                     
|
| input:         
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
| 16JAN2012 - EM Exempla calls the last_seen_V3 macro - converting to EDW
+-----------------------------------------------------------------------HEADER*/

%macro last_seen;

/*	%if &client = Exempla %then %do;*/
/*		%last_seen_V3;*/
/*	%end;*/
/**/
/*	%else %do;*/

		Data elig4 (keep= memberid pcpid svcdt rank );
		set g1;
		if put(provid,$provyn.) = "Y" and source = "P" and &var. = 1;
		if provspec not in (&rank1. &rank2. &rank3.) then delete;
		if provspec in (&rank1.) then rank=1;
		else if provspec in (&rank2.) then rank=2;
		else if provspec in (&rank3.) then rank=3;
		rename provid = pcpid;
		run;

		/*%provider_comments;*/

		proc sort data=elig4;
		by memberid rank  descending svcdt;
		run;

		Data elig5;
		set elig4;
		by memberid rank  descending svcdt; 
		if first.memberid;
		run;
/*	%end;*/

%mend last_seen;
