%macro check_issue_count(dataset_in=, validation=0, zero_count=invalid, count_in=nocount);

	%let issue_count = 0 ;
	
	proc sql noprint;
	  select count(*) into: issue_count separated by ''
	  from &dataset_in. ;
	quit;
	
	%put NOTE: issue_count = &issue_count. ; 

	proc sql noprint;
	 select trim(left(vld_typ_desc)), resolution_steps into : %trim(message01),  : %trim(message02)
	 from  vbpm.validation_type 
	 where validation_type_id=&validation. ;
	quit;
	
	%if &zero_count. = invalid %then %do;	
		%if &issue_count eq 0 %then %do; 
		  %put ERROR: There are 0 observations within &dataset_in. ;
		  %put ERROR: &message01. ;
		  %put ERROR: &message02. ;
		  
		  %bpm_additional_validations(validation_rule=&validation., validation_count=&issue_count.);
		  %let err_fl=1;
		  %set_error_flag;
		  %on_error(ACTION=ABORT, err_standard=&validation.);
		%end;
		%else %do;
		  %put NOTE: The creation of &dataset_in. was successful with counts of &issue_count.;
		%end;
	%end;
	%else %if &zero_count. = valid %then %do;	
		%if &issue_count eq 0 %then %do; 
		  %put NOTE: The creation of &dataset_in. was successful with no known issues.;
		%end;
		%else %do;
		  %put ERROR: The creation of &dataset_in. was unsuccessful with known issues ;
		  %put ERROR: %trim(&message01.) ;
		  %put ERROR: %trim(&message02.) ;

		  %bpm_additional_validations(validation_rule=&validation., validation_count=&issue_count.);
		  %let err_fl=1;
		  %set_error_flag;
		  %on_error(ACTION=ABORT,  err_standard=&validation.);
		%end;
	%end;
	%else %do;
		  %if &count_in. ne nocount %then %let issue_count=&count_in. ;
		  %put ERROR: %trim(&message01.) ;
		  %put ERROR: %trim(&message02.) ;
 
		  %bpm_additional_validations(validation_rule=&validation., validation_count=&issue_count.);
		  %let err_fl=1;
		  %set_error_flag;
		  %on_error(ACTION=ABORT,  err_standard=&validation.);
	%end;

%mend check_issue_count;
