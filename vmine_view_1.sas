
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_1
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from medisoft vmine view  
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
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
| 02MAY2012 - G Liu - Clinical Integration 1.2.01
|			  If 1 datasourceid has data in both Medisoft and Medisoft16, we null out
|				PATID from old system, and only keep PATID from new system. EMPI database
|				only stores 1 set of system_person_id for each datasourceid. These
|				old datasourceid that violates the rule of 1 datsourceid to 1 database system
|				needs to have slightly different rule.
|
| 17JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Modified to pull from new standardized store procedure
|			2. Filter logic already included in new standardized store procedure 
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_1;

	%*SASDOC--------------------------------------------------------------------------
	| Determine if the PM System for the practice is Medisoft or Medisoft 16. 
	| The indicator is created within vmine_pmsystem_information macro. 
	------------------------------------------------------------------------SASDOC*; 
	data _null_;
	  set vmine_practice_information (where=(PracticeID = &do_practice_id.));  
	  call symput('view_condition',trim(left(view_condition)));
	run;
	
	
	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data for Medisoft 16 
	| or Medisoft PM System view - dependent on the version ID assigned to 
	| the practice
	------------------------------------------------------------------------SASDOC*; 

	%if &view_condition = 1 %then %do;  

	    /** for full history - check to see if practice was formerly medisoft **/
		%if &maxprocessid. = 0 or &maxprocessid. = 1 %then %do;  

/*			proc sql;*/
/*			  connect to oledb(init_string=&emine.);*/
/*			  create view v_practice_&do_practice_id. as select * from connection to oledb*/
/*			  (	*/
/*				select *, 0 as medisoft_old_system	               */
/*				from    dbo.tstMedisoft16View*/
/*				where kpracticeid = &do_practice_id.*/
/*				  and maxprocessid > &maxprocessid. */
/**/
/*				 union all*/
/**/
/*				select *, 1 as medisoft_old_system*/
/*				from    dbo.tstMedisoftView*/
/*				where kpracticeid = &do_practice_id.*/
/*				  and maxprocessid > &maxprocessid. */
/*			  )*/
/*			%if &do_practice_id. = 634 %then %do;*/
/*				where proccd ne '' */
/*				  and proccd ne '00000'*/
/*				  and substr(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9') ;*/
/*			%end;*/
/*			%else %if &do_practice_id. = 256 %then %do;*/
/*				where submit2 >= 0*/
/*					  and proccd ne ''*/
/*					  and proccd ne '00000'*/
/*					  and substr(proccd,3,1) in ('0','1','2','3','4','5','6','7','8','9')*/
/*			%end;*/
/*			%else %do;*/
/*				where submit2 >= 0*/
/*					  and proccd ne ''*/
/*					  and proccd ne '00000'*/
/*					  and substr(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9')*/
/*			%end;*/
/*			;quit;*/

			proc sql;
				connect to oledb(init_string=&emine.);

				create view Medisoft16 as select *, 0 as medisoft_old_system from connection to oledb
				(
					exec dbo.sp_Medisoft16_Claims &do_practice_id., &maxprocessid.
				);

				create view Medisoft as select *, 1 as medisoft_old_system from connection to oledb
				(
					exec dbo.sp_Medisoft_Claims &do_practice_id., &maxprocessid.
				);


			quit;

			data practice_&do_practice_id.(drop=medisoft_old_system);
				set Medisoft16 Medisoft;
				if medisoft_old_system=1 then patid='';
				/* do not store patid for old system. only store patid for the current (new) system */
			run;
		%end;
		%else %do;	
			proc sql;
				connect to oledb(init_string=&emine.);
				create table practice_&do_practice_id. as select * from connection to oledb
				(
					exec dbo.sp_Medisoft16_Claims &do_practice_id., &maxprocessid.
				);
			quit;

/*			  (	*/
/*				select *	               */
/*				from    dbo.tstMedisoft16View*/
/*				where kpracticeid = &do_practice_id.*/
/*				  and maxprocessid > &maxprocessid.*/
/*			  )*/
/*			%if &do_practice_id. = 634 %then %do;*/
/*				where proccd ne '' */
/*				  and proccd ne '00000'*/
/*				  and substr(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9') ;*/
/*			%end;*/
/*			%else %if &do_practice_id. = 256 %then %do;*/
/*				where submit2 >= 0*/
/*					  and proccd ne ''*/
/*					  and proccd ne '00000'*/
/*					  and substr(proccd,3,1) in ('0','1','2','3','4','5','6','7','8','9')*/
/*			%end;*/
/*			%else %do;*/
/*				where submit2 >= 0*/
/*					  and proccd ne ''*/
/*					  and proccd ne '00000'*/
/*					  and substr(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9')*/
/*			%end;*/
/*			;quit;*/
		%end;
	%end;
	%else %do;  
		proc sql;
			connect to oledb(init_string=&emine.);
			create table practice_&do_practice_id. as select * from connection to oledb
			(
				exec dbo.sp_Medisoft_Claims &do_practice_id., &maxprocessid.
			);
		quit;
/*			  (	*/
/*				select *	               */
/*				from    dbo.tstMedisoftView*/
/*				where kpracticeid = &do_practice_id.*/
/*				  and maxprocessid > &maxprocessid.*/
/*			  )*/
/*			%if &do_practice_id. = 634 %then %do;*/
/*				where proccd ne '' */
/*				  and proccd ne '00000'*/
/*				  and substr(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9') ;*/
/*			%end;*/
/*			%else %if &do_practice_id. = 256 %then %do;*/
/*				where submit2 >= 0*/
/*					  and proccd ne ''*/
/*					  and proccd ne '00000'*/
/*					  and substr(proccd,3,1) in ('0','1','2','3','4','5','6','7','8','9')*/
/*			%end;*/
/*			%else %do;*/
/*				where submit2 >= 0*/
/*					  and proccd ne ''*/
/*					  and proccd ne '00000'*/
/*					  and substr(proccd,2,1) in ('0','1','2','3','4','5','6','7','8','9')*/
/*			%end;*/
/*			;quit;*/
	
	%end;	

%mend vmine_view_1;
