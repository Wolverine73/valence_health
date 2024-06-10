
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_27
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
| 20JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Modified to pull from new standardized store procedure
|			2. Filter logic already included in new standardized store procedure 
| 
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_27;

	%*SASDOC--------------------------------------------------------------------------
	| Determine if the PM System for the practice is Medisoft or Medisoft 16. 
	| The indicator is created within vmine_pmsystem_information macro. 
	------------------------------------------------------------------------SASDOC*; 
	data _null_;
	  set vmine_practice_information (where=(PracticeID = &do_practice_id.));  
	  call symput('view_condition',trim(left(view_condition)));
	run;

	
	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
	------------------------------------------------------------------------SASDOC*; 

	%if &view_condition = 1 %then %do;  

		%if &maxprocessid. = 0 or &maxprocessid. = 1 %then %do;  
			proc sql;
				connect to oledb(init_string=&emine.);
				create view AltaPoint8 as select * from connection to oledb
				(	
					exec dbo.sp_AltaPoint8_Claims &do_practice_id., &maxprocessid.
				);

				create view AltaPoint as select * from connection to oledb
				(
					exec dbo.sp_AltaPoint_Claims &do_practice_id., &maxprocessid.
				);
			quit;


			proc sql;
				create table practice_&do_practice_id. as 
				(
					select *
					from AltaPoint8

					union all

					select *
					from AltaPoint
				);
			quit;
		%end;
		%else %do;
			proc sql;
				connect to oledb(init_string=&emine.);
				create table practice_&do_practice_id. as select * from connection to oledb
				(	
					exec dbo.sp_AltaPoint_Claims &do_practice_id., &maxprocessid.
				);
			quit;
		%end;

	%end;
	%else %do;  
/*		proc sql;*/
/*		connect to oledb(init_string=&emine.);*/
/*		create table practice_&do_practice_id. as select * from connection to oledb*/
/*		(	*/
/*		select *	               */
/*		from    dbo.tstAltaPointView*/
/*		where 	kpracticeid = &do_practice_id. and*/
/*				maxprocessid > &maxprocessid. and*/
/*				code_type = 'CH'*/
/*		);*/
/*		quit;*/

		proc sql;
			connect to oledb(init_string=&emine.);
			create table practice_&do_practice_id. as select * from connection to oledb
			(
				exec dbo.sp_AltaPoint8_Claims &do_practice_id., &maxprocessid.
			);
		quit;
	%end;


%mend vmine_view_27;





