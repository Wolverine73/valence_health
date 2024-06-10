
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
| 01FEB2010 - Brian Stropich  - Clinical Integration  1.0.01
|
| 07JUN2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Modified the options to print the resolution of the macro variables in the log. 
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
| 26APR2012 - G Liu - Clinical Integration 1.2.01
|			  Added vh_empi 
|			  Added bcp version for CIHold
|
| 06JUN2012 - Fletcher - Clinical Integration 1.2.01
|			  Added vh_payer
| 06SEP2012 - Fletcher - EMR
|			  Added vhstage_emr
|			  Added bcp version for vhstage_emr
+-----------------------------------------------------------------------HEADER*/

%macro bpm_environment;

	options noxwait nolabel fullstimer compress=yes mprint mlogic /*nosymbolgen*/ symbolgen msglevel=i error=2 ls=120 ps=60; /* 07JUN2011 - WLee - modified to print out the resolution of the macro variables in the log*/
	
	%put NOTE: SYSUSERID =  &SYSUSERID.;
	
	%get_sysparm;
	%oledb_init_string;
	%bpm_initialize_variables;

	libname ids     oledb init_string=&ids.   	preserve_tab_names=yes readbuff=10000; 
	libname vlink   oledb init_string=&vlink.  	preserve_tab_names=yes readbuff=10000;
	libname vsource oledb init_string=&vsource.	preserve_tab_names=yes readbuff=10000;
	libname emine   oledb init_string=&emine. 	preserve_tab_names=yes readbuff=10000;
	libname vbpm    oledb init_string=&vbpm.   	preserve_tab_names=yes insertbuff=10000 readbuff=10000;	
	libname ciedw   oledb init_string=&ciedw.  	preserve_tab_names=yes insertbuff=10000 readbuff=10000;	
	libname cihold  oledb init_string=&cihold. 	preserve_tab_names=yes insertbuff=10000 readbuff=10000; 	
	libname vh_empi oledb init_string=&vh_empi.	preserve_tab_names=yes insertbuff=10000 readbuff=10000; 
    libname vh_payer oledb init_string=&vh_payer.	preserve_tab_names=yes insertbuff=10000 readbuff=10000; 		
	libname bcphold oledb Provider=SQLOLEDB.1 properties=(&bcphold.) BULKLOAD=YES schema=dbo;
 /* libname bcpemr oledb Provider=SQLOLEDB.1 properties=(&bcpemr.) BULKLOAD=YES schema=staging; */
	libname cistage "&cistage.";
	libname cistaget "&cistaget.";
	libname ci      "&cistage.";
	libname fmt     "M:\dw\Formats"; 
	libname history "M:\CI\sasdata\CIDataQuality";	
	libname fg_guide oledb init_string=&fg_guide.   preserve_tab_names=yes readbuff=10000;
	
	%mvarexist(SAS_MODE); 
   	%if &mvarexist. %then %do;
 		%if %upcase(&sas_mode)=TEST %then %do; 
 		
			libname edi  	 oledb init_string=&edi. 	preserve_tab_names=yes insertbuff=10000 readbuff=10000;
			libname dmart    oledb init_string=&data_mart.  preserve_tab_names=yes insertbuff=10000 readbuff=10000;
			libname fg_guide oledb init_string=&fg_guide.   preserve_tab_names=yes readbuff=10000;
			libname vh_empi  oledb init_string=&vh_empi.	preserve_tab_names=yes insertbuff=10000 readbuff=10000;
			libname vh_payer oledb init_string=&vh_payer.	preserve_tab_names=yes insertbuff=10000 readbuff=10000;
			libname bcpemr oledb Provider=SQLOLEDB.1 properties=(&bcpemr.) BULKLOAD=YES schema=staging;
		%end;
	%end;	
	
	%include "M:\dw\Formats\programs\ssn_memberid_fmt.sas";	

	%proc_format(datain=fmt.fnameGender);
	%proc_format(datain=fmt.zipcodes);
	
	
%mend bpm_environment;

