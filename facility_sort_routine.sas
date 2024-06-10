
/*HEADER------------------------------------------------------------------------
|
| program:  facility_sort_routine.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:   
|
| logic:     
|           
|
| input:               
|
| output:    
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|  
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro facility_sort_routine(dataset_in=,edw=no);

	%if &edw = no %then %do;
	
		%put NOTE: Facility sort routine performed on input dataset variables. ;
	
		proc contents data = &dataset_in. out = content01 (keep = name) noprint;
		run;
	
		data content01;
		set content01;
		name=upcase(name);
		if upcase(name) in ('CLAIMNUM','CLAIM_KEY','FILENAME','FILED','FILENAMEDATE',
			            'RECORD_ORIG','ADMDT_ORIG','DISDT_ORIG','MAJCAT_ORIG') then delete;
		run;
		
	%end;
	%else %if &edw = yes %then %do;
	
		%put NOTE: Facility sort routine performed on EDW header and detail variables. ;
	
		data ehd;
		set ciedw.encounter_header (obs=5)
		ciedw.encounter_detail (obs=5);
		run;

		proc contents data = ehd out=content01 (keep=name) noprint;
		run;

		data content01;
		set content01;
		name=upcase(name);
		if upcase(name) in ('CLAIMNUM','CLAIM_KEY','FILENAME','FILED','FILENAMEDATE',		                    
				    'RECORD_ORIG','ADMDT_ORIG','DISDT_ORIG','MAJCAT_ORIG',
				    'CLAIM_ID','ENCOUNTER_KEY','DETAIL_KEY','WFLOW_EXEC_ID','VMINE_KPROCESSID',
				    'UPDATED_ON','UPDATED_BY','CREATED_ON','CREATED_BY') then delete;
		if index(NAME,'SOURCE') > 0 then delete;
		run;
		
	%end;

	proc sql noprint;
	select name into: byvar separated by ' '
	from content01;
	quit;

	proc sort data = &dataset_in. nodupkey;
	by &byvar. ;
	run;

%mend facility_sort_routine;
