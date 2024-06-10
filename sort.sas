%macro sort(ds,by) ;
	proc sort data=&ds ;
	  by &by ;
	run;
%mend sort;