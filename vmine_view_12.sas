
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_view_12
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

%macro vmine_view_12;

/*	proc sql;*/
/*	  connect to oledb(init_string=&emine.);*/
/*	  create table practice_&do_practice_id. as select * from connection to oledb*/
/*	  (	*/
/*		select  *	               */
/*		from    dbo.tstPracticePartnerView*/
/*		where 	kpracticeid = &do_practice_id. and*/
/*				maxprocessid > &maxprocessid. and */
/*		  		(diag1 is not null and proccd not in ('ADBT','ADMIN','APS00','BANK','BIO-F','BRP','CANCE','CAP','COLRC','CONSU','COPAY',*/
/*													  'DBERR','DEB/A','DEBTR','DIS','DOT','ERROR','FILLO','FIN','FMLA','FORMS','INS R',*/
/*													  'INT','INTER','LAB F','MED','MED F','MED R','MISC','NO SH','NOCHA','NSF','NSF C',*/
/*													  'NSF D','OV','OVERP','PAST','POSTE','PROBI','PT RE','PTREF','QUEST','REF I',*/
/*													  'REF R','REFIN','REFPT','REFUN','REM','RET C','RETCK','RETUR','RTNC','SMALL',*/
/*													  'TAKEB','TBO','TRANA','TRANS','UT CL','WRI','WRONG')) and*/
/*				(diag1 not in ('') and proccd not in ('ADBT','ADMIN','APS00','BANK','BIO-F','BRP','CANCE','CAP','COLRC','CONSU','COPAY',*/
/*													  'DBERR','DEB/A','DEBTR','DIS','DOT','ERROR','FILLO','FIN','FMLA','FORMS','INS R',*/
/*													  'INT','INTER','LAB F','MED','MED F','MED R','MISC','NO SH','NOCHA','NSF','NSF C',*/
/*													  'NSF D','OV','OVERP','PAST','POSTE','PROBI','PT RE','PTREF','QUEST','REF I',*/
/*													  'REF R','REFIN','REFPT','REFUN','REM','RET C','RETCK','RETUR','RTNC','SMALL',*/
/*													  'TAKEB','TBO','TRANA','TRANS','UT CL','WRI','WRONG')) and*/
/*				proccd not in ('ADBT','ADMIN','APS00','BANK','BIO-F','BRP','CANCE','CAP','COLRC','CONSU','COPAY',*/
/*								'DBERR','DEB/A','DEBTR','DIS','DOT','ERROR','FILLO','FIN','FMLA','FORMS','INS R',*/
/*								'INT','INTER','LAB F','MED','MED F','MED R','MISC','NO SH','NOCHA','NSF','NSF C',*/
/*							    'NSF D','OV','OVERP','PAST','POSTE','PROBI','PT RE','PTREF','QUEST','REF I',*/
/*							    'REF R','REFIN','REFPT','REFUN','REM','RET C','RETCK','RETUR','RTNC','SMALL',*/
/*							    'TAKEB','TBO','TRANA','TRANS','UT CL','WRI','WRONG') and*/
/*				chrg_type <> 'E'*/
/*	   );*/
/*	quit;*/

	proc sql;
		connect to oledb(init_string=&emine.);
		create table practice_&do_practice_id. as select * from connection to oledb
		(
			exec dbo.sp_PracticePartner_Claims &do_practice_id., &maxprocessid.
		);
	quit;

%mend vmine_view_12;
