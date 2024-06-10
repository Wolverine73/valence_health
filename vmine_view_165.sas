/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_165
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from PPMISAV vmine view  
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
| 25MAY2012 - Valence Health  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_165;

	proc sql;
		connect to oledb(init_string=&emine.);
			create table practice_&do_practice_id. as select * from connection to oledb
			(	
				exec dbo.sp_PPMISAV_Claims &do_practice_id., &maxprocessid.
			)
		;
	quit;

%mend vmine_view_165;
