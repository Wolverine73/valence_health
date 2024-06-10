
/*HEADER------------------------------------------------------------------------
|
| program:  bpm_environment.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Location of and initializes all CHISQL connection paramaters.
|
| logic:    Assigns OLEDB strings for connecting to the SQL Server which are
|           used in either the libnae assignment or sql pass through
|
| input:    clientname is optional          
|
| output:   vmine vlink emine forms webparam vportal manual
|
+--------------------------------------------------------------------------------
| history:  
|
| 01SEP2012 - Brian Stropich  - Clinical Integration  1.0.01
|
+-----------------------------------------------------------------------HEADER*/

%macro bpm_environment_new;

	options noxwait nolabel fullstimer compress=yes mprint mlogic symbolgen msglevel=i error=2 ls=120 ps=60;	
	%put NOTE: SYSUSERID =  &SYSUSERID.;	
	libname history "M:\CI\sasdata\CIDataQuality";	
	%get_sysparm;
	%oledb_init_string_new;
	%bpm_initialize_variables;
	
	%do libs = 1 %to &globalvar_total. ;
		%if &&libname_type&libs = 1 %then %do;
		  libname  &&globalvar&libs    oledb init_string=&&globalassign&libs   	preserve_tab_names=yes insertbuff=10000 readbuff=10000;
		%end;
		%else %if &&libname_type&libs = 2 %then %do;
		  libname &&globalvar&libs    "&&globalassign&libs";
		%end;
		%else %if &&libname_type&libs = 3 %then %do;
		  libname &&globalvar&libs oledb provider=sqloledb.1 properties=(&&globalassign&libs) bulkload=yes schema=dbo;
		%end;
		%else %if &&libname_type&libs = 4 %then %do;
		%end;
	%end;
	
	libname dmart    oledb init_string=&data_mart.  preserve_tab_names=yes insertbuff=10000 readbuff=10000;
	%include "M:\dw\Formats\programs\ssn_memberid_fmt.sas";	
	%proc_format(datain=fmt.fnameGender);
	%proc_format(datain=fmt.zipcodes);
	
%mend bpm_environment_new;

