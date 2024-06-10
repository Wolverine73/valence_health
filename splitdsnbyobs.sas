
/*HEADER------------------------------------------------------------------------
|
| program:  splitdsnbyobs.sas
|
| location: M:\CI\programs\StandardMacros - (Production Copy)
|           M:\CI\programs\Development\StandardMacros  - (Development Copy)
|
| purpose:  SAS Macro to split dataset by observations
|
| logic:    
|
| input:    Macro parameters 
|           dsn - SAS dataset name
|           splitby - number of observations to spilit dataset by.
|           macvar  - macro variable that will store count of dataset splits
|                        
| output:   Multiple output datasets, macro variable (contain total number of splits)
|
| usage:     
|	%splitdsnbyobs(dsn=dqclmsum,splitby=24,macvar=dqclmsumcols);	
|	%splitdsnbyobs(dsn=dqprov,splitby=30,macvar=dqprovcols);
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01SEP2011 - Nick Williams - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

    *SASDOC--------------------------------------------------------------------
	| Split dataset by nth observations
	+--------------------------------------------------------------------SASDOC*;
	%macro splitdsnbyobs(dsn=,splitby=,macvar=);
	%global &macvar ;
	proc sql noprint;
	  select count(*) into: no_obs
	  from &dsn.;
	quit; 
	%let no_obs=&no_obs; 	
	%do i=1 %to %sysfunc(ceil(&no_obs/&splitby));
		data &dsn.&i.;
		set &dsn (firstobs=%sysfunc(floor(%eval((&i.-1)*&splitby.+1))) obs=%sysfunc(ceil(%eval(&i * &splitby.))));        
		run;		
		%let &macvar=&i.; 
		%put Note: Macro variable &macvar. contains this no# of observations &&&macvar.;
	%end;
	%mend splitdsnbyobs;

