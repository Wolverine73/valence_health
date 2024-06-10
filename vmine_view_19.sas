/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_19
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from Aprima(Formerly imedica) vmine view  
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
| 24AUG2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
| 12JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Modified to pull from new standardized store procedure 
|
| 07JUN2012 - B Sahulcik - Clinical Integration 1.2.01
|			  If 1 datasourceid has data in both Aprima (iMedica) and Aprima2011, we null out
|				PATID from old system, and only keep PATID from new system. EMPI database
|				only stores 1 set of system_person_id for each datasourceid. These
|				old datasourceid that violates the rule of 1 datsourceid to 1 database system
|				needs to have slightly different rule.
|
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_19;

	/*SASDOC--------------------------------------------------------------------------
	| Determine if the PM System for the practice is Medisoft or Medisoft 16. 
	| The indicator is created within vmine_pmsystem_information macro. 
	--------------------------------------------------------------------------SASDOC*/ 
	data _null_;
	set vmine_practice_information (where=(PracticeID = &do_practice_id.));  
	call symput('view_condition',trim(left(view_condition)));
	run;

	%put NOTE: view_condition = &view_condition.;
	
	/*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data from the PM System view
	--------------------------------------------------------------------------SASDOC*/

	%if &view_condition. = 1 %then %do;  

	    /** for full history - check to see if practice was formerly medisoft **/
		%if &maxprocessid. = 0 or &maxprocessid. = 1 %then %do;  

			proc sql;
				connect to oledb(init_string=&emine.);

				create view Aprima2011 as select *, 0 as iMedica_old_system from connection to oledb
				(
					exec dbo.sp_Aprima2011_Claims &do_practice_id., &maxprocessid.
				);

				create view iMedica as select *, 1 as iMedica_old_system from connection to oledb
				(
					exec dbo.sp_iMedica_Claims &do_practice_id., &maxprocessid.
				);
			quit;

			data practice_&do_practice_id.(drop=iMedica_old_system);
				set Aprima2011 iMedica;
				if iMedica_old_system=1 then patid='';
				/* do not store patid for old system. only store patid for the current (new) system */
			run;
		%end;
		%else %do;
			proc sql;
				connect to oledb(init_string=&emine.);
				create table practice_&do_practice_id. as select * from connection to oledb
				(	
					exec dbo.sp_Aprima2011_Claims &do_practice_id., &maxprocessid.		
				);
			quit;
		%end;
	%end;
	%else %do; 
		proc sql;
			connect to oledb(init_string=&emine.);
			create table practice_&do_practice_id. as select * from connection to oledb
			(	
				exec dbo.sp_iMedica_Claims &do_practice_id., &maxprocessid.		
			);
		quit;
	%end;

%mend vmine_view_19;
