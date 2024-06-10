
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_20
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from medware vmine view  
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
| 17JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Modified to pull from new standardized store procedure
|			2. Filter logic already included in new standardized store procedure 
|                         
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_20;

/*	proc sql;*/
/*	  connect to oledb(init_string=&emine.);*/
/*	  create table practice_&do_practice_id. as select * from connection to oledb*/
/*	  (	*/
/*		select *	               */
/*		from    dbo.tstMedwareView*/
/*		where kpracticeid = &do_practice_id. */
/*		  and maxprocessid > &maxprocessid. */
/*		  and substring(proccd,2,1) in ('1','2','3','4','5','6','7','8','9','0')*/
/*	  );*/
/*	quit;*/

	proc sql;
		connect to oledb(init_string=&emine.);
		create table practice_&do_practice_id. as select * from connection to oledb
		(	
			exec dbo.sp_Medware_Claims &do_practice_id., &maxprocessid.
		);
	quit;

%mend vmine_view_20;
