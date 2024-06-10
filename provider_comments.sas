
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  provider_comments.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Remove members/providers from guideline eligibility  
|
| LOGIC:    Remmove members/providers from guideline eligibility based on provider comments formats
|           
| INPUT:    ELIG4 sas dataset          
|
| OUTPUT:   ELIG4 sas dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 26MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created provider comments macro
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro provider_comments;

%if &period = current %then %do;
	data elig4;
	set elig4;
	length mem_guide $32. mem_pcp $27. guideline_key $15.;
	guideline_key = "&guideline_key.";
	mem_guide = cats(memberid)||"||"||cats(guideline_key);
	mem_pcp = cats(memberid)||"||"||cats(pcp1);
    	
	if put(memberid,$expired.) = 'Y' then delete;
	if put(mem_guide,$refused.) = 'Y' then delete;
	if put(mem_pcp,$nopat.) = 'Y' then delete;
	run;
%end;

%mend provider_comments;

