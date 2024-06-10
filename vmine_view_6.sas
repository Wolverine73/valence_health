
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_6
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from practice point manager (PPM) vmine view  
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
| 23AUG2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_6;

	
	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
	------------------------------------------------------------------------SASDOC*; 
/*	proc sql;*/
/*	  connect to oledb(init_string=&emine.);*/
/*	  create table practice_&do_practice_id. as select * from connection to oledb*/
/*	  (	*/
/*		select *	               */
/*		from    dbo.tstPPMView*/
/*		where kpracticeid = &do_practice_id.*/
/*		  and maxprocessid > &maxprocessid. */
/*	  );*/
/*	quit;*/

	proc sql;
		connect to oledb(init_string=&emine.);
		create table practice_&do_practice_id. as select * from connection to oledb
		(	
			exec dbo.sp_PracticePointManager_Claims &do_practice_id., &maxprocessid.
		);
	quit;

%mend vmine_view_6;
