

%macro create_pgf_libnames;

	filename dirlist1 pipe "dir /s /b  M:\&clientname.\sasdata\*"; **directory and files;
	
	data pgf_libnames ;
	   infile dirlist1 length=ln end=eof;
	   input sasdirectory $varying400. ln;
	   if index(upcase(sasdirectory),'PGF') > 0 ;
	   if index(upcase(sasdirectory),'OLD') > 0 then delete;
	   if index(upcase(sasdirectory),'.SAS') > 0 then delete; 
	   if substr(left(reverse(upcase(sasdirectory))),1,3)='FGP' then delete;
	   libname = upcase(compress(reverse(scan(left(reverse(sasdirectory)),1,'\')),"'/',' '"));
       if length(libname) gt 8 then do;
          libname=compress(upcase(libname),'AEIOU_');
          libname=substr(libname,1,8);
       end;
	   saslibname='libname '||trim(left(libname))||' "'||trim(left(sasdirectory))||'"; ' ; 
       run;
       
	 %let qa_libname=0;

    proc sql noprint;
     select count(libname) into: qa_libname
     from  pgf_libnames
     group by libname
     having count(libname) > 1;
    quit;

	%put NOTE: qa_libname = &qa_libname. ;

	%if &qa_libname. ne 0 %then %do;
	  %put ERROR: Duplicate libnames exist for client. ;
	%end;
	%else %do;
	    data _null_;
	      set pgf_libnames  end=eof;
	      i+1;
	      ii=left(put(i,4.));
	      call symput('libname'||ii,trim(saslibname));
	      /**call symput('directory'||ii,trim(sasdirectory));**/
	      if eof then call symput('libname_total',ii);
	    run;
	   
	    %do i = 1 %to &libname_total. ;
	     /**x "if not exist &&directory&i mkdir &&directory&i";**/
	     &&libname&i 
	    %end;
	%end;

%mend create_pgf_libnames;

