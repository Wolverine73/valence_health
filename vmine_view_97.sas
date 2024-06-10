
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_97
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from MedInformatix vmine view  
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
| 31AUG2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_97;

	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
	------------------------------------------------------------------------SASDOC*; 
	proc sql;
	  connect to oledb(init_string=&emine.);
	  create table practice_&do_practice_id. as select * from connection to oledb
	  (	
		select *	               
		from    dbo.tstMedInformatixView
		where kpracticeid = &do_practice_id.
		  and diag1   <> ''
		  and proccd  <> ''
		   and maxprocessid > &maxprocessid.
	  );
	quit;


%mend vmine_view_97;
