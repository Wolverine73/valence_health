

/*HEADER------------------------------------------------------------------------
|
| program:  vmine_new_practices
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the medisoft pm system practice data   
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
+-----------------------------------------------------------------------HEADER*/

%macro vmine_new_practices;

	proc sql noprint;
	 create table  vmine_new_practices as
	 select clientname, systemname, practiceid, practicename, count(*) as count
	 from vmine_practice_information 
	 group by clientname, systemname, practiceid, practicename
	 having count > 1;
	quit;

	data _null_;
	  set vmine_parms;
	  put  "NOTE: *************************************************************";
	  put  "NOTE: Practices that were processed: ";
	  put  "NOTE: " _n_ clientname systemname practiceid practicename @95 DateEntered;
	  put  "NOTE: *************************************************************";
	run;

	data _null_;
	  set vmine_new_practices;
	  put  "WARNING: *************************************************************";
	  put  "WARNING: New Practices: ";
	  put  "WARNING: " _n_ clientname systemname practiceid practicename  ;
	  put  "WARNING: *************************************************************";
	run;

%mend vmine_new_practices;
