
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_2
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create practice data from lytec vmine view  
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
| 14FEB2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Modified the CPT filtering logic by adding TransactionCode
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
| 02MAY2012 - G Liu - Clinical Integration 1.2.01
|			  If 1 datasourceid has data in both Medisoft and Medisoft16, we null out
|				PATID from old system, and only keep PATID from new system. EMPI database
|				only stores 1 set of system_person_id for each datasourceid. These
|				old datasourceid that violates the rule of 1 datsourceid to 1 database system
|				needs to have slightly different rule.
+-----------------------------------------------------------------------HEADER*/

%macro vmine_view_2;

	%*SASDOC--------------------------------------------------------------------------
	| Determine if the PM System for the practice is Lytec or Lytec 2010.
	| The indicator is created within vmine_pmsystem_information macro.  
	------------------------------------------------------------------------SASDOC*; 
	data _null_;
	  set vmine_practice_information (where=(PracticeID = &do_practice_id.));  
	  call symput('view_condition',trim(left(view_condition)));
	run;
	
	
	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the practice data for Lytec 2010 
	| or Lytec PM System view - dependent on the version ID assigned to 
	| the practice
	------------------------------------------------------------------------SASDOC*; 

	%if &view_condition = 1 %then %do; 	


	    /** for full history - check to see if practice was formerly medisoft **/
		%if &maxprocessid. = 0 or &maxprocessid. = 1 %then %do;  
			proc sql;
			  connect to oledb(init_string=&emine.);
			  create view v_practice_&do_practice_id. as select * from connection to oledb
			  (	
				select  	*, 0 as lytec_old_system
				from    	dbo.tstLytec2010View
				where 		kpracticeid = &do_practice_id. and 
					  		proccd <> '' and
					  		proccd = TransactionCode and
					  		maxprocessid > &maxprocessid. 

				 union all

				select  *, 1 as lytec_old_system        
				from    dbo.tstLytecView
				where kpracticeid = &do_practice_id.
				  and proccd <> ''
				  %if &do_practice_id. ne 61 %then %do;
				    and proccd = transactioncode
				  %end;
				  and maxprocessid > &maxprocessid. 
			  );
			quit;
			data practice_&do_practice_id.(drop=lytec_old_system);
				set v_practice_&do_practice_id.;
				if lytec_old_system=1 then patid='';
				/* do not store patid for old system. only store patid for the current (new) system */
			run;
		%end;
		%else %do;	
			proc sql;
			connect to oledb(init_string=&emine.);
			create table practice_&do_practice_id. as select * from connection to oledb
			(	
				select  	*	               
				from    	dbo.tstLytec2010View
				where 		kpracticeid = &do_practice_id. and 
					  		proccd <> '' and
					  		proccd = TransactionCode and
					  		maxprocessid > &maxprocessid. 
			);
			quit;
		%end;

	%end;
	%else %do;  
	 
		proc sql;
		  connect to oledb(init_string=&emine.);
		  create table practice_&do_practice_id. as select * from connection to oledb
		  (	
			select  *	               
			from    dbo.tstLytecView
			where kpracticeid = &do_practice_id.
			  and proccd <> ''
			  %if &do_practice_id. ne 61 %then %do;
			    and proccd = transactioncode
			  %end;
			  and maxprocessid > &maxprocessid. 
		  );
		quit;
	
	%end; 

%mend vmine_view_2;
