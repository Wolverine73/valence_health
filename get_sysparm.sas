
/*HEADER------------------------------------------------------------------------
|
| program:  get_sysparm
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Assign all system parameters to global macro variables
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
|
| 01JAN2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

%macro get_sysparm;

	data sysparm;
	  length  sysparm express param value $ 300 ;
	  sysparm = symget('sysparm');
	  do i=1 to 50 until(express = '');
	    express = left(scan(sysparm, i, ' '));
	    param   = left(upcase(scan(express, 1, '=')));
	    value  = left(scan(express, 2, '='));
		if param ne '';
		output;
	    if param ne '' and length(param) <=32 then do;
		call symput(param, trim(left(value)));
	    end;
	  end;
	run;
	
	data _null_;
	 set sysparm;
	 put _all_;
	run;
	
	proc sql noprint;
	  select count(*) into: globalvarscnt 
	  from sysparm;
	quit;
	
	%if &globalvarscnt ne 0 %then %do;

		data vmacro;
		set sashelp.vmacro;
		run; 

		proc sql noprint;
		  create table sysparm as
		  select a.*, b.scope
		  from sysparm as a left join 
               vmacro as b
          on a.param = b.name ;
		quit;

		%let globalvars= ;
		
		proc sql noprint;
		  select param into: globalvars separated by " "
		  from sysparm
		  where scope = '';
		quit;

		%put NOTE: globalvars = &globalvars. ;

		%global &globalvars.  ;
	
	%end;
	%else %do;
		%put NOTE: globalvars = No sysparm variables exist.;
	%end;

%mend get_sysparm;