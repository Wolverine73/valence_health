
/*HEADER------------------------------------------------------------------------
|
| program:  edw_procedure_cd.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Load practice data into the CIEDW header and detail tables  
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
| 01FEB2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/
 
%*SASDOC----------------------------------------------------------------------
| define sas macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\ci\programs\standardmacros" "M:\ci\programs\clientmacros" sasautos);
options mlogic mprint symbolgen;


*SASDOC--------------------------------------------------------------------------
| standard assignments 
|
+------------------------------------------------------------------------SASDOC*;   
%let sysparm=%str(client_id=4 sas_mode=test); 
%bpm_environment;


*SASDOC--------------------------------------------------------------------------
| Macro:  edw_procedure_cd  
|  
| Update, insert, and delete procedure codes within the ciedw.procedure_cd table 
| 
+------------------------------------------------------------------------SASDOC*;

%macro edw_procedure_cd;


	*SASDOC--------------------------------------------------------------------------
	| Drop the table cihold.dbo.procfmt 
	+------------------------------------------------------------------------SASDOC*;
	proc sql;
	connect to oledb(init_string=&sqlci.);
	execute (
		drop table [cihold].[dbo].[procfmt]  
	) 
	by oledb; 
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Create the table cihold.dbo.procfmt 
	+------------------------------------------------------------------------SASDOC*;
	proc sql;
	connect to oledb(init_string=&sqlci.);
	execute (
			select procedure_code, procedure_code_description
			into [cihold].[dbo].[procfmt] 
			from [ciedw].[dbo].[procedure_cd]
			where 1 = 2
			) 
	by oledb; 
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Retrieve update procedure code information
	+------------------------------------------------------------------------SASDOC*;
	data procfmt;
	  set fmt.procfmt;
	  procedure_code=left(start);
	  procedure_code_description=left(upcase(label));
	run;

	proc sort data =  procfmt nodupkey ;
	  by procedure_code;
	run;

	proc sql noprint;
	  insert into cihold.procfmt
	  (
	    procedure_code,
	    procedure_code_description
	  )
	  select
	    procedure_code,
	    procedure_code_description
	  from procfmt  ;
	quit;


	*SASDOC--------------------------------------------------------------------------
	| Delete any procedures that no longer exists 
	+------------------------------------------------------------------------SASDOC*; 
	proc sql;
	connect to oledb(init_string=&sqlci.);
	execute (
			delete from ciedw.dbo.procedure_cd 	
			where procedure_code not in  (
			select b.procedure_code 
			from cihold.dbo.procfmt b)
			) 
	by oledb; 
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Update descriptions of procedures that exists
	+------------------------------------------------------------------------SASDOC*;  
	proc sql;
	connect to oledb(init_string=&sqlci.);
	execute (
			update ciedw.dbo.procedure_cd 
			set procedure_code_description = b.procedure_code_description     
			from ciedw.dbo.procedure_cd a     
			inner join 
			cihold.dbo.procfmt b on          
			a.procedure_code=b.procedure_code 
			) 
	by oledb; 
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Insert any new procedures that exists
	+------------------------------------------------------------------------SASDOC*;   
	proc sql;
	connect to oledb(init_string=&sqlci.);
	execute (
			insert into ciedw.dbo.procedure_cd	
			select a.procedure_code, a.procedure_code_description, null, null, getdate(), 'test', getdate(), 'test'
			from cihold.dbo.procfmt  a 
			where a.procedure_code not in  (
			select b.procedure_code 
			from ciedw.dbo.procedure_cd b)
		) 
	by oledb; 
	quit;

%mend edw_procedure_cd



