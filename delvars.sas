/*HEADER------------------------------------------------------------------------
|
| program:  delvars.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Macro to delete macro variables in between guideline runs.                     
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
| 01SEP2011 - Lori Sifuentes - Guideline Development.
| 			  This macro is implemented into the 2.1 Guideline Shell. 
|             Please place Client Specific Macros into your program/shell.
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 11JAN2012 - Erin Murphy  - Clinical Integration  1.1.02
			  Added all client macros possible to be resolved
+-----------------------------------------------------------------------HEADER*/
%macro delvars;
data temp;
	set sashelp.vmacro;
	where name not in  (	
	'ENDDT',
	'STDT',
	'CLIENT',
	'LASTPER',
	'CURPER',
	'PERIOD',
	'RPTPERIOD',
	'SYS_SQL_IP_ALL',
	'SYS_SQL_IP_STMT',
	'DATE_RUN',
	'DATERUN',
	'SYSDBMSG',
	'SYSDBRC', 
	'ALL',                    
	'ALL_HOSPICE_EXCLUDE',    
	'ALL_NURSING_EXCLUDE',
	'ASSIGNMENTFILE',
	'CREATEG0FILE',
	'DUMMYNPI',               
	'FORMAT_HOMEHEALTH',      
	'FORMAT_NURSING',        
	'GUIDELINE_COMMENT_FILE', 
	'GUIDELINE_CONFIG_FILE',  
	'GUIDELINE_LIBNAME',
	'GUIDELIBNAME',
	'GUIDELIBNAMEV2',
	'GUIDELIBNAMEV3',
	'LAB_DATA', 
	'LAB_RESULTS',            
	'LAG_NUMBER',             
	'LAG_UNITS',              
	'LOCATION',          
	'MEASURE_LEVEL',          
	'NUMBER_DIAGS',
	'PORTAL_TABLES',
	'RUN_DAY',
	'RX_DATA', 
	'TRIGGER_COMMENTS',
	'VERSION_HYBRID',
	'SK_PRCS_CTRL_ID',
	'WFLOW_EXEC_ID',
	'SAS_PRGM_ID',
	'CLIENT_ID',
	'SAS_MODE',
	'SRC_RECORD_CNT',
	'TGT_RECORD_CNT',
	'DATE',
	'ERR_FL',
	'ERR_FL_L',
	'CIEDW',
	'FG_GUIDE',
	'CIHOLD',
	'CHISQL',
	'SQL-CI',
	'VBPM',
	'DATA_MART',
	'SQLCI',
	'CLIENT_KEY',
	'PAYER_KEY',
	'NUMBER_SURGS',
	'CLIENT_ID')

	 and scope not in   ('AUTOMATIC');
run;
data _null_;
	set temp;
	call symdel(name);
run;
%mend delvars;


