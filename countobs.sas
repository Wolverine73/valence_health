
/*HEADER------------------------------------------------------------------------
|
| program:  countobs.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Count the number of observations in sas dataset and assign it to a 
|           global macro variable.
|
| logic:    
|
| input:         
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
| 01OCT2011 - Nick Williams - Clinical Integration 1.0.01
|           
+-----------------------------------------------------------------------HEADER*/

    *SASDOC--------------------------------------------------------------------
    | Countobs macro
    +--------------------------------------------------------------------SASDOC*;
    %macro countobs(dsn=,macvar=);

    %mvarexist(&macvar.); 
    %if &mvarexist. ne 0 %then %symdel &macvar. ;

    %global &macvar;

    %if %sysfunc(exist(&dsn.))=1 %then %do ;  ** 1=yes 0=no;
        %put %sysfunc(sysmsg());

    	%let dsid=%sysfunc(open(&dsn.));
    	%put %sysfunc(sysmsg());

    	%let nobs=0; ***set default value zero;

    	%let nobs=%sysfunc(attrn(&dsid,nlobsf));
    	%put %sysfunc(sysmsg());

    	%if &nobs. < 0 %then %let nobs=%sysfunc(attrn(&dsid,nlobs)); ***checking this only if first functions returned a negative value, as sometimes it doesnt work;
    	%put %sysfunc(sysmsg());

        %if &nobs. < 0 %then %do; *** last resort if still coming up with empty values then last check for non-zero data;
    		proc sql noprint;
    		  select count(*) into: nobs
    		  from &dsn.;
    		quit;
    	%end;
    	%let &macvar=&nobs.;
    	%put &dsn. &&&macvar.;
    	%put Note: Macro variable &macvar. contains this no# of observations &&&macvar.;
    	%put Note: &dsn. observations &macvar. has value of &&&macvar.;
    %let rc=%sysfunc(close(&dsid));
    %end;
    %else %do;
        %let &macvar=0;
    	%put Note: Macro variable &macvar. contains this no# of observations &&&macvar.;
    	%put Note: &dsn. does not exist default value of &macvar. will be set to &&&macvar.;
    %end;
    %mend countobs;
