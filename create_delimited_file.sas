


%macro create_delimited_file(infile, outfile, outdlm) ;

	   %if "&outdlm"="" %then %let outdlm=, ;

	   %let filedlm1 = ".\tempcode&sysjobid.pt1" ;
	   %let filedlm2 = ".\tempcode&sysjobid.pt2" ;

	   filename q1 &filedlm1 ;
	   filename q2 &filedlm2 ;

	   %let rc = %sysfunc(FDELETE(q1)) ;
	   %let rc = %sysfunc(FDELETE(q2)) ;

	*** *** *** ;

	   proc contents data = &infile 
					 out  = tempq 
                     noprint ;
	   run ;
	   
	   %sort(tempq,varnum) ;

	*** *** *** ;
	   data _null_ ;
	      set tempq end=end ;

	      if _n_ = 1 then do ;
		 file &filedlm1 ;
		 put "put '" name +(-1) "'" ;
		 file &filedlm2 ;
		 put "put " name " +(-1) " ;
	      end ;

	      else do;
		 file &filedlm1 mod ;
		 put "'&outdlm" name +(-1) "'"  ;
		 file &filedlm2 mod ;
		 put "'&outdlm' " name " +(-1) " ;
	      end ;

	      if end then do ;
		 file &filedlm1 mod ;
		 put " ; " ;
		 file &filedlm2 mod ;
		 put " ; " ;
	      end ;

	   run;


	*** *** *** ;

	   data _null_ ;
	      set &infile  ;
	      file "&outfile." dsd dropover encoding = 'utf-8' nopad lrecl = 32000;

	      if _n_=1 then do ;
		 %include &filedlm1  ;
	      end ;

	      %include &filedlm2  ;
	   run;

	*** *** *** ;


	%let rc = %sysfunc(FDELETE(q2)) ;
	%let rc = %sysfunc(FDELETE(q1)) ;


%mend create_delimited_file ;


