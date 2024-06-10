
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_libnames.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Location of and initializes all CHISQL connection paramaters.
|
| logic:    Assigns OLEDB strings for connecting to the SQL Server which are
|           used in either the libname assignment or sql pass through
|
| input:    clientname is optional          
|
| output:   vmine vlink emine forms webparam vportal manual
|
+--------------------------------------------------------------------------------
| history:  
|
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_libnames;

	%oledb_init_string;
	libname ids  oledb init_string=&ids. preserve_tab_names=yes;
	libname emine  oledb init_string=&emine. preserve_tab_names=yes;

%mend vmine_libnames;

