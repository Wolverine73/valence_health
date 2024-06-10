

%macro sort_part(dataset=,sortedby=);

	%local cnt;
	%let cnt=0;
	proc sql noprint;
	 select count(*) into :cnt
	 from &dataset.;
	quit;

  %IF &cnt. ge 1 %then %do;
	%let firstobs = 1;
	%let lastobs  = 100000;

	%let doloop = %eval(%sysfunc(ceil(&cnt/&lastobs)));
	%put doloop = &doloop. ;
	%put firstobs = &firstobs. ;

	%local i;

	%do i = &firstobs %to &doloop;

		proc sort data = &dataset. (firstobs = &firstobs. obs = &lastobs.) 
			  out  = x&i ;
		by &sortedby.;
		run;

		%let firstobs = %eval(&lastobs + 1);
		%let lastobs  = %eval(&lastobs + 100000);

	%end;

	proc datasets library=work nolist;
	 delete &dataset. (memtype = data);
	quit;

	data &dataset. (sortedby=&sortedby);
	 set %do j = 1 %to &doloop; x&j %end;;
	 by &sortedby ;
	run; 

	proc datasets library=work nolist;
	 delete %do k = 1 %to &doloop; x&k %end; (memtype = data);
	quit;  

  %END;
%mend sort_part;
