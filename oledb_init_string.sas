
/*HEADER------------------------------------------------------------------------
|
| program:  oledb_init_string.sas
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
| 07JUN2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Modified the TEST mode for EMINE to point to SQLCIDEV instead because dev environment
|				now has more new files loaded.
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
| 06SEP2012 - Fletcher - Clinical Integration 1.2.01
|			  Added vhstage_emr
|			  Added bcp version for vhstage_emr
+-----------------------------------------------------------------------HEADER*/

%macro oledb_init_string;

   %global vmine vlink emine forms webparam serverstring vbpm ciedw chisql sqlci cihold edi eav vh_empi bcphold vminebpm cistage cistaget vh_payer
           sql_dir sql_load_dir ids idsprod data_mart client_name client_short_name client fg_guide edw_directory
		   vsource vh_emr bcpemr; 

   %let vmine    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vMine;" );  
   %let vlink    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vLinkNSAP;" ); 
   %let vsource  =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vLinkNSAP;" ); 
   %let forms    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=FormGenerator;");
   %let webparam =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=sasbiweb;");   
   %let ids      =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=IntegrationDataSource;"); 
   %let idsprod  =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=IntegrationDataSource;"); 
   %let fg_guide =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=fg_Guidelines;"); 
   
   %let vbpm     =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=BPMMetaData;");
   %let ciedw    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=CIEDW;");  
   %let cihold   =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=CIHold;");  
   %let edi		 =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=EDI;");  
   %let eav		 =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=EAVHL7Master;"); 
   %let vh_empi	 =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=VH_EMPI;");
   %let vh_payer =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=VHSTAGE_PAYER;");
   %let vh_emr   =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=VHSTAGE_EMR;");  
   %let chisql   =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;");
   %let sqlci    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;");
   /* BULKLOAD OPTION= BCP  */
   %let bcphold	 =%str("data source"="SQL-CI" "Integrated Security"=SSPI "Initial Catalog"=CIHold);
   %let bcpemr	 =%str("data source"="SQL-CI" "Integrated Security"=SSPI "Initial Catalog"=VHSTAGE_EMR);
   
   %let cistage  =%str(f:\sastemp\cistaging\prod);
   %let cistaget =%str(f:\sastemp\cistaging\prod);
   %let sql_dir  =%str(\\sql-ci\temp\ciedw);
   %let sql_load_dir =%str(C:\temp\ciedw);
   %let edw_directory=%str(M:\CI\programs\EDW);
 
   %test;

   %mvarexist(SAS_MODE); 
   %if &mvarexist. %then %do;
	 %if %upcase(&sas_mode)=TEST %then %do;
	   %let vbpm     =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=BPMMetaData;");
	   %let ciedw    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=CIEDW;"); 
	   %let cihold   =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=CIHold;"); 
	   %let edi   	 =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=EDI;"); 
	   %let eav   	 =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=EAVHL7Master;"); 
	   %let vh_empi	 =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=VH_EMPI;");
	   %let vh_payer =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=VHSTAGE_PAYER;");	   
	   %let vh_emr   =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;Initial Catalog=VHSTAGE_EMR;");
	   %let sqlci    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCIDEV;");
	   %let ids      =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=DEVSERV1;Initial Catalog=IntegrationDataSource;"); 
	   %let vsource  =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=DEVSERV1;Initial Catalog=vSource;"); 
	/* BULKLOAD OPTION= BCP  */	   
	   %let bcphold	 =%str("data source"="SQLCIDEV" "Integrated Security"=SSPI "Initial Catalog"=CIHold);
	   %let bcpemr	 =%str("data source"="SQLCIDEV" "Integrated Security"=SSPI "Initial Catalog"=VHSTAGE_EMR);	   

	   %let cistage  =%str(f:\sastemp\cistaging\test);
  	   %let cistaget =%str(f:\sastemp\cistaging\test);
	   %let sql_dir  =%str(\\sqlcidev\temp\ciedw);
	   %let sql_load_dir =%str(C:\temp\ciedw);
	   %let edw_directory=%str(M:\CI\programs\Development\EDW);


 	   %*SASDOC--------------------------------------------------------------------------
 	   | Reset Standard and Client Macros to Test environment                   
	   ------------------------------------------------------------------------SASDOC*; 
           **proc catalog catalog=work.sasmacr kill force;
           **run;
           proc catalog catalog=work.sasmacr ;
             delete test.macro ;
           run;

		%if %upcase(&sysuserid.)=BSTROPICH or %upcase(&sysuserid.)=WLEE or %upcase(&sysuserid.)=BFLETCHER or %upcase(&sysuserid.)=GLIU %then %do;
			options sasautos = ("M:\CI\programs\Development\&sysuserid.\sas\StandardMacros" "M:\CI\programs\Development\&sysuserid.\sas\ClientMacros" sasautos);
		%end;
		%else %do;
			options sasautos = ("M:\CI\programs\Development\StandardMacros" "M:\CI\programs\Development\ClientMacros" sasautos);
		%end;

           
           %test;
	 %end;
 	   %*SASDOC--------------------------------------------------------------------------
 	   | this was added when testing sas_mode prod on SASDEV
 	   | only f-drive will be used for skelta prod or sas2 prod
	   ------------------------------------------------------------------------SASDOC*; 
	 %if %upcase(&SYSHOSTNAME.) = SASDEV %then %do; 
	   %let cistage  =%str(f:\sastemp\cistaging\test);
  	   %let cistaget =%str(f:\sastemp\cistaging\test);
  	 %end;
   %end; 
   
   %mvarexist(SAS_MODE);
   %if &mvarexist. %then %do;

		   proc sql noprint;
		     connect to oledb(init_string=&ciedw.);
		     select client_name, 
		            client_name, 
		            client_short_name, 
		            data_mart 
		     into :client_name separated by '', 
		          :client separated by '', 
		          :client_short_name separated by '', 
		          :data_mart separated by ''
		     from connection to oledb
		     (	
			select client_name, client_short_name, client_short_name, data_mart
			from  [dbo].[client]  
			where client_key=&client_id. 
		     );
		   quit;

		   %put NOTE: Client Name = %bquote(&client_name.);
		   %put NOTE: Client Short Name = %bquote(&client_short_name.);
		   %put NOTE: Client = %bquote(&client.);
		   %put NOTE: Data Mart = &data_mart.;

		  %if %upcase(&sas_mode)=TEST %then %do;
		   %let data_mart   =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=devserv1;Initial Catalog=&data_mart.;");
		  %end;
		  
		  %else %do;
		   %let data_mart   =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=&data_mart.;");		    
		  %end;
   %end;
   
   %mvarexist(CLIENT_ID); 
   %if &mvarexist. %then %do; 
   
		%*SASDOC--------------------------------------------------------------------------
		| Connect to SQL Server to retreive the server string for pm system views
		------------------------------------------------------------------------SASDOC*; 
		proc sql;
              connect to oledb(init_string=&ids.);
		  create table serverstring as select * from connection to oledb
		  (	
			select *	               
			from    dbo.client
			where clientid = &CLIENT_ID. 
		  );
		quit;

		%mvarexist(SAS_MODE); 
		%if &mvarexist. %then %do; 
		  %if %upcase(&sas_mode)=TEST %then %do;
			data serverstring;
			 set serverstring;
/*			 connectionstring="data source=SQL-CI;initial catalog=CIMaster;Integrated Security=SSPI;";*/
			 connectionstring="data source=SQLCIDEV;initial catalog=CIMaster;Integrated Security=SSPI;";
/*			 connectionstring="data source=SQLCIDEV;initial catalog=CIMaster2ndFullLoadBackUp;Integrated Security=SSPI;";*/

			run;	
		  %end;	
		%end;
		   
		data serverstring; 
		  set serverstring; 
		  xx=index(connectionstring,'uid=');
		  serverstring=substr(connectionstring,1,xx-1);
		  call symput('serverstring',trim(serverstring));
		run;

		%let emine    =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;&serverstring. " ); 
   
   %end;
   
   
   *SASDOC--------------------------------------------------------------------------
   | Determine if clientname has been assigned for initializing vportal and manual
   ------------------------------------------------------------------------SASDOC*; 
   %mvarexist(CLIENTNAME);    
   %if &mvarexist. %then %do;
		%global vportal manual ; 
		%let vportal=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=&clientname.Portal;" );
		%let manual =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=fg_&clientname;" ); 
   %end;

%mend oledb_init_string;

