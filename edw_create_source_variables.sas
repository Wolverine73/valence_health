
/*HEADER------------------------------------------------------------------------
|
| program:  edw_create_source_variables.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:   
|
| logic:     
|           
|
| input:               
|
| output:    
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro edw_create_source_variables(in_dataset1=);

	  proc contents data = &in_dataset1 
                    out  = contents1 (keep = name varnum) noprint;
	  run;

	  proc sort data = contents1 ;
        by varnum ;
	  run;	

	  data _null_;
	    set contents1 end=eof;
	    src_name="src_"||upcase(trim(name)) ; 
	    i+1;
	    ii=left(put(i,4.));	 
	    call symput('src_name'||ii,trim(src_name));
		call symput('name'||ii,trim(name));
	    if eof then call symput('name_total',ii);	 
	  run;

	  data &in_dataset1 ;
	    set &in_dataset1 ;
		%do name = 1 %to &name_total. ;
		  &&src_name&name = &&name&name ;
		%end;
	  run;

	  data &in_dataset1 ;
	    retain 
		%do name = 1 %to &name_total. ;
		 &&name&name  &&src_name&name
		%end;;
	    set &in_dataset1 ;
	  run;

	  data null;
	    date=put(today(),date9.);
	    call symput('date',date);
	  run;

	  proc sql;
	    create table &in_dataset1. as
	    select a.* ,  
	    input("&date."||put(time(),time16.6),datetime22.3) as CREATED_ON format datetime22.3,
	    "BPM - SAS" as CREATED_BY, 
	    input("&date."||put(time(),time16.6),datetime22.3) as UPDATED_ON format datetime22.3,
	    "BPM - SAS" as UPDATED_BY  
	    from &in_dataset1. as a  ; 
	  quit;

%mend edw_create_source_variables;