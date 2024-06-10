/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_143
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from SOS vmine view  
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
| 09MAY2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|  
| 17JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Modified to pull from new standardized store procedure
| 
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_143;

/*	proc sql;*/
/*		connect to oledb(init_string=&emine.);*/
/*			create table practice_&do_practice_id. as select * from connection to oledb*/
/*			(	*/
/*				exec dbo.spSOS &do_practice_id., &maxprocessid.*/
/*			)*/
/*		;*/
/*	quit;*/

	proc sql;
		connect to oledb(init_string=&emine.);
			create table practice_&do_practice_id. as select * from connection to oledb
			(	
				exec dbo.sp_SOS_Claims &do_practice_id., &maxprocessid.
			)
		;
	quit;

%mend vmine_view_143;
