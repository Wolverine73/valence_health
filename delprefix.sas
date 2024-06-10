/*HEADER------------------------------------------------------------------------
|
| program:  delprefix.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Macro to delete prefixes inbetween guideline runs.                     
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
| 01SEP2011 - Erin Murphy - Guideline Development.
| 			  This macro is implemented into the 2.1 Guideline Shell. 
+-----------------------------------------------------------------------HEADER*/
%macro delprefix;
	data temp;
	set sashelp.vmacro;
	where name in ('PREFIX')
		  and scope not in ('AUTOMATIC');
	run;
	data _null_;
		set temp;
		call symdel(name);
	run;
%mend delprefix;
