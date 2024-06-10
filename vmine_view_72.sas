/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_72
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from MPMOffice vmine view  
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
| 21JAN2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 17JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Modified to pull from new standardized store procedure 
| 
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_72;

/*	proc sql;*/
/*		connect to oledb(init_string=&emine.);*/
/*			create table practice_&do_practice_id. as select * from connection to oledb*/
/*			(	*/
/*				exec dbo.spMPMOffice &do_practice_id., &maxprocessid.*/
/*			)*/
/*		;*/
/*	quit;*/

	proc sql;
		connect to oledb(init_string=&emine.);
			create table practice_&do_practice_id. as select * from connection to oledb
			(	
				exec dbo.sp_MPMOffice_Claims &do_practice_id., &maxprocessid.
			)
		;
	quit;

%mend vmine_view_72;
