/*******************************************************************************************\
*	Program: 		excel_import_export.sas													*
*																							*
*	Location: 		M:\CI\programs\StandardMacros											*
*																							*
*	Application: 	1) Import a sheet from an MS Excel file to a SAS Data Set.				*
*		   		 	2) Export a SAS Data Set to a sheet in an MS Excel file.				*
*																							*
*	How to Use: 	1) Make sure to issue this command: 									*
*					   options sasautos = ("M:\CI\programs\StandardMacros" sasautos);		*
*					2) TASK. Enter the desired task - import or export (case IN-sensitive).	*
*					3) FILE. Enter the full filename (.xls extension only).					*
*					4) SHEET. Enter the desired sheet name (not to exceed 31 characters).	*
*					5) DS. Enter the SAS Data Set name (not to exceed 32 characters).		*
*					       You can add (drop/keep = <var1, ...) data set options!			*
*																							*
*	Limitations:	1) This method exports .xlsx files that cannot be opened in Excel.		*
*					   However, the exported file can be imported successfully.				*
*					2) When exporting a file to Excel the sheet name cannot contain blanks.	*
*					   However, the sheet name of imported file can contain blanks.			*
\*******************************************************************************************/
%macro excel_import_export
(task = 
,file = 
,sheet = 
,ds = 
);
%if %qupcase(&task) = IMPORT %then %do;
	libname xls OLEDB INIT_STRING = "Provider = Microsoft.ACE.OLEDB.12.0; 
							  Data Source = &file; 
					  Extended Properties = 'Excel 12.0'" CELLPROP=VALUE;
	data &ds;
	set xls."&sheet.$"n;
	run;
	libname xls clear;
%end;
%if %qupcase(&task) = EXPORT %then %do;
	libname xls OLEDB INIT_STRING = "Provider = Microsoft.ACE.OLEDB.12.0; 
							  Data Source = &file; 
					  Extended Properties = 'Excel 12.0'" CELLPROP=VALUE;
	data xls.&sheet;
	set &ds;
	run;
	libname xls clear;
%end;
%put NOTE: *** TASK --> &task;
%put NOTE: *** FILE --> &file;
%put NOTE: *** SHEET --> &sheet;
%put NOTE: *** SAS Data Set --> &ds;
%mend excel_import_export;
%excel_import_export
(task =
,file =
,sheet =
,ds =
)
