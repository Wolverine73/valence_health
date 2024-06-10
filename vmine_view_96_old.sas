
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_96

| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from Greenway vmine view  
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
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_96;

	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
	------------------------------------------------------------------------SASDOC*; 
	proc sql;
	  connect to oledb(init_string=&emine.);
	  create table practice_&do_practice_id. as select * from connection to oledb
	  (	
		select  *	               
		from    dbo.tstGreenwayView
		where kpracticeid = &do_practice_id.
		  and proccd <> ''
		  and maxprocessid > &maxprocessid.
		  and VoidServiceDetailID=0
	  );
	quit;


%mend vmine_view_96;
