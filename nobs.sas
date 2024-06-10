/* Function-style macro to return the number of observations in a			*/
/*         dataset or view. This will either be a positive integer or forced*/
%macro nobs(ds);
%local nobs dsid rc;
%let dsid=%sysfunc(open(&ds));

%if &dsid EQ 0 %then %do;
  %put ERROR: (nobs) Dataset &ds not opened due to the following reason:;
  %put %sysfunc(sysmsg());
%end;

%else %do;
  %if %sysfunc(attrn(&dsid,WHSTMT)) or
    %sysfunc(attrc(&dsid,MTYPE)) EQ VIEW %then %let nobs=%sysfunc(attrn(&dsid,NLOBSF));
  %else %let nobs=%sysfunc(attrn(&dsid,NOBS));
  %let rc=%sysfunc(close(&dsid));
  %if &nobs LT 0 %then %let nobs=0;
&nobs
%end;
%mend;
