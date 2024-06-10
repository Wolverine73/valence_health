
/*HEADER------------------------------------------------------------------------
|
| program:  nsap_clinical_integration_in.sas
|
| location: M:\CI\programs\ClientMacros
|
| purpose:  To define a standard environment, common parameters, macros for the 
|           clinical integration programs.
|
| logic:    Uses the two input parameters called vlink_client_name and vmine_client_id 
|           to look up all the necessary environment and parameter information within sql server - chisql 
|           within sql server - chisql for the client.
|
| input:    parameters:  
|            vlink_client_name 
|            vmine_client_id
|
|           data source: 
|            vmine.client      
|            vmine.Practice     
|            vmine.ExtractedFileList     
|            vmine.Version     
|            vmine.System       
|                        
| output:   ci_parms     
|           vmine_parms
|           vmine_libnames  
|
| usage:    The program will be called at the begining of the program level
|           parameter file using %include. 
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 22JUN2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created and updated Code to Business Requirements Specifiation for all Clients
|
| 16FEB2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Modified libname to point to IDS database instead of vMine database
| 
+-----------------------------------------------------------------------HEADER*/

%macro clinical_integration_in;

   %*SASDOC----------------------------------------------------------------------
   | Create GLOBAL variables for datasources.  
   | 
   | 
   +---------------------------------------------------------------------SASDOC*;
   %GLOBAL clientid clientname directorypath clientnamefolder  monthbase monthload rptbase
           macro_standard macro_client reportvmine saslogs saslsts sasrpts err_fl 
           allclaims_dataset ciref logdate step_counts primary_programmer_email program_name_step program_name program_log ;
		   

   %let err_fl=0;
   %let macro_standard=M:\CI\programs\StandardMacros;
   %let macro_client=M:\CI\programs\ClientMacros;
  
 
   *SASDOC--------------------------------------------------------------------------
   | Initialize Options and Macros and Formats
   +------------------------------------------------------------------------SASDOC*;
   options noxwait mprint nomlogic nosymbolgen msglevel=i error=2 ls=100  ;
   options sasautos = ("&macro_standard." "&macro_client." sasautos);   
   
   %let primary_programmer_email=%str(&ci_user.@valencehealth.com);

      
   *SASDOC--------------------------------------------------------------------------
   | OLEDB Assignments 
   +------------------------------------------------------------------------SASDOC*;
   %oledb_init_string; 	

/*   libname vmine  oledb init_string=&vmine. preserve_tab_names=yes;*/
   libname ids  oledb init_string=&ids. preserve_tab_names=yes; /*16FEB2011 WLee - modified to call IDS instead*/
   libname vlink  oledb init_string=&vlink.;
   libname vportal oledb init_string=&vportal.;
   libname manual oledb init_string=&manual.;
   libname forms oledb init_string=&forms.;	
   libname webparam oledb init_string=&webparam.;
   
 
	
   *SASDOC--------------------------------------------------------------------------
   | CIETL Libname and Filename Assignments 
   +------------------------------------------------------------------------SASDOC*;   
  
    %if %upcase("&clientname.") = "NSAP" %then %do;
   		libname prov      "M:\&clientname.\sasdata\CI\CIETL\provider";
		libname provfmt   "M:\&clientname.\sasdata\CI\CIETL\provider\Formats";
		libname portal    "M:\&clientname.\sasdata\CI\Portal\PortalOut";
		libname dw        "M:\&clientname.\sasdata\CI\CIETL\dw";
		libname member    "M:\&clientname.\sasdata\CI\CIETL\member";
	%end; %else %do;
		libname prov      "M:\&clientname.\sasdata\CIETL\provider";
		libname provfmt   "M:\&clientname.\sasdata\CIETL\provider\Formats";
		libname portal    "M:\&clientname.\sasdata\Portal\PortalOut";
		libname dw        "M:\&clientname.\sasdata\CIETL\dw";
		libname member    "M:\&clientname.\sasdata\CIETL\member";
	%end;

   libname dwfmt     "M:\dw\formats";
   libname ciref     "M:\CI\sasdata\CIReference";
   libname sasbi     "\\ebicompute\Projects\&clientname.\data";
   libname parm      "\\ebicompute\Projects\Tools\parms";
   libname dummy 	 "M:\&clientname.\sasdata\CI\Portal\Dummy";
   libname sformat 	 "M:\sample\CI\Programs\formats";

   *SASDOC--------------------------------------------------------------------------
   | PGF Libname and Filename 
   +------------------------------------------------------------------------SASDOC*;
  
   %create_pgf_libnames;

   
    *SASDOC--------------------------------------------------------------------------
   | Vmine Libname and Filename 
   +------------------------------------------------------------------------SASDOC*;
   
    %create_vmine_libnames(vmine_client_name=&clientname., vmine_client_id=&vmine_client_id.);
 
   *SASDOC--------------------------------------------------------------------------
   | Formats Assignments 
   +------------------------------------------------------------------------SASDOC*;
   	%include "M:\dw\Formats\programs\ssn_memberid_fmt.sas";
   
   %proc_format(datain=dwfmt.diag5cd);
   %proc_format(datain=dwfmt.procfmt);
   %proc_format(datain=dwfmt.specdesc);
   %proc_format(datain=sformat.malenm);
   %proc_format(datain=sformat.femalenm);
   %proc_format(datain=sformat.lastnm);

   *SASDOC--------------------------------------------------------------------------
   | 
   +------------------------------------------------------------------------SASDOC*;
   
	data _null_;
     logdate=put(today(),YYMMDD10.);
     logdate=compress(logdate,"-");
     all="allclaims_&clientname._";
     allclaims_dataset=left(trim(all))||left(trim(logdate));
     call symput('allclaims_dataset',left(trim(allclaims_dataset)));
     call symput('logdate',left(trim(logdate)));
    run;   
    
    proc format;
		value agefmtA
		0 - 18 = '0 - 18 Yrs'
		18<-44 = '19 - 44 Yrs'
		45<-64 = '45 - 64 Yrs'
		64<-high = '65+ Yrs'
		other='Unknown';
	run;
	 
	proc format;
		value agefmtB
		0 - 18 = '0 - 18 Yrs'
		18<-29 = '19 - 29 Yrs'
		29<-39 = '30 - 39 Yrs'
		39<-49 = '40 - 49 Yrs'
		49<-64 = '50 - 64 Yrs'
		64<-high = '65+ Yrs'
		other='Unknown';
	run; 
  
   	%let startqtr = 2006-Q4;
	%let manual_goal = .75;

%mend clinical_integration_in;
				
 

