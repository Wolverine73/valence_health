%macro filename_assign_selfpay;
  %global selfpay_dir_list selfpay_dir ; 	  

	data _null_;
	  %if %length(&filename) > 0 %then %do;
	    call symput('selfpay_dir_list',"dir /b &file_directory.\*.* ");  
	  %end;
	  %else %do; 
	    call symput('selfpay_dir_list',"dir /b &file_directory.\&filename. ");
	  %end;
	  call symput('selfpay_dir',"&file_directory.\"); 
	run;  

%mend filename_assign_selfpay;