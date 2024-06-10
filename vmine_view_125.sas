
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_125
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from PBSI vmine view  
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
| 01SEP2011 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_125;

	
	*SASDOC--------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
    | PROCEDURE_TYPE = 'C' - This will select only charges (including non-billable 
    | and/or $0.00 services like PQRI, etc.).  
	+--------------------------------------------------------------------SASDOC*;

	proc sql;
	  connect to oledb(init_string=&emine.);
	  create table practice_&do_practice_id. as select * from connection to oledb
	  (	
		exec dbo.sp_PBSI_Claims &do_practice_id., &maxprocessid.
	  );
	quit;


%mend vmine_view_125;
