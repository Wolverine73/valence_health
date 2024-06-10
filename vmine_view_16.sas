
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_16
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from AltaPoint vmine view  
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
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|
| 19MAR2012 - Winnie Lee
|			1. Modified to pull from a SQL store procedure instead of a SQL view. 
|
| 17JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Modified to pull from new standardized store procedure
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_16;
	
	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
	------------------------------------------------------------------------SASDOC*; 
	proc sql;
		connect to oledb(init_string=&emine.);
		create table practice_&do_practice_id. as select * from connection to oledb
		(	
			exec dbo.sp_MicroMD_Claims &do_practice_id., &maxprocessid.
		);
	quit;

%mend vmine_view_16;





