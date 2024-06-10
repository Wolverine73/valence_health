
%macro cleanse_diagnosis_length_4(dataset_in=);

	options nomlogic nosymbolgen;

	*SASDOC--------------------------------------------------------------------------
	| Determine diagnosis variables per pm system - practice.   
	+------------------------------------------------------------------------SASDOC*;
	proc contents data = &dataset_in.
	out  = contents_diag (keep = name) noprint;
	run;

	proc sql noprint;
	  select distinct(name), count(*) into : diag_names separated by ' ',  : diag_total 
	  from contents_diag
	  where substr(upcase(name),1,4)='DIAG'
	  and substr(upcase(name),6,1)='';
	quit;

	%put NOTE: diag_names = &diag_names ;
	%put NOTE: diag_total = &diag_total ;
	
	%if &diag_names ne %then %do;
			proc sql noprint;
			  select count(*) into : count_diagnosis_decimal separated by ''
			  from &dataset_in.
			  where (substr(diag1,4,1) ='.'
			         and length(diag1)=4 )
			  %do qq = 2 %to &diag_total. ;
			    or
			    (substr(diag&qq.,4,1) ='.'
			     and length(diag&qq.)=4 )
              %end;;
			quit; 

			%put NOTE: Decimal count for length of 4 diagnosis = &count_diagnosis_decimal ;		
	%end;

	%if &diag_total. ne 0 and &count_diagnosis_decimal ne 0 %then %do;
	
		data &dataset_in. ;
		set &dataset_in. ;
		
			*SASDOC--------------------------------------------------------------------------
			| Remove any decimals from diagnosis that are a length of 4 with 
			| a decimal in the fourth location
			------------------------------------------------------------------------SASDOC*;				
			%do diag = 1 %to &diag_total.;
			  if length(diag&diag.)=4 then do;
			    if substr(diag&diag.,4,1) ='.' then do;
				diag&diag.=substr(diag&diag.,1,3);
			    end;
			  end;
			%end;
			
		run;
	
	%end;

	options mlogic symbolgen;

%mend cleanse_diagnosis_length_4;
