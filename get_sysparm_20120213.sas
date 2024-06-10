
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%macro get_sysparm;
	%put &sysparm.;

	data sysparm(drop=equal_position: nextparamlength);
	  length  sysparm param value $ 300 ;
	  sysparm=left(symget('sysparm'));
	  sysparm=tranwrd(sysparm,' =','=');
	  sysparm=tranwrd(sysparm,'= ','=');
	  do i=1 to 50 until(equal_position2=0);
		equal_position1=index(sysparm,'=');
		equal_position2=equal_position1+index(substr(sysparm,equal_position1+1),'=');
		nextparamlength=length(scan(substr(sysparm,1,equal_position2-1),-1));
		param=scan(sysparm,1,'=');
	    value=substr(sysparm,equal_position1+1,equal_position2-nextparamlength-equal_position1-1);
		sysparm=substr(sysparm,equal_position2-nextparamlength);
		if param ne '';
		output;
	    if param ne '' and length(param) <=32 then call symput(param, trim(left(value)));
		if equal_position2=equal_position1 then equal_position2=0;
	  end;
	run;
	
	data _null_;
	 set sysparm;
	 put param= value=;
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
