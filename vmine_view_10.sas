
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_10
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from Misys vmine view  
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

%macro vmine_view_10;

	
	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
	------------------------------------------------------------------------SASDOC*; 
	proc sql;
		connect to oledb(init_string=&emine.);
		create table practice_&do_practice_id. as select * from connection to oledb
		(
			exec dbo.spmisys &do_practice_id., &maxprocessid. 
		);
	quit;
	
	proc sql;
	  create table practice_&do_practice_id.  as           	
		select *	               
		from    practice_&do_practice_id.
		where 	(kpracticeid = &do_practice_id. and 
		  		maxprocessid > &maxprocessid. and
				proccd not in ('','ADX','DNKA')) or 
				(kpracticeid = &do_practice_id. and 
		  		maxprocessid > &maxprocessid. and
				proccd in ('','ADX','DNKA') and submit2 > 0) ;
	quit;	


%mend vmine_view_10;
