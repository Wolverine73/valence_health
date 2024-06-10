
/*HEADER------------------------------------------------------------------------
|
| program:  oledb_init_string_new.sas
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
| 01SEP2012 - Brian Stropich  - Clinical Integration  1.0.01
|
+-----------------------------------------------------------------------HEADER*/

%macro oledb_init_string_new;

   data temp00;
     set history.oledb_init_string (rename = (&sas_mode. = assignment_value));
   run;
   
   data _null_;
     set temp00  end=eof;
     i+1;
     ii=left(put(i,4.));
     call symput(trim(assignment_macro),trim(assignment_value)); 
     call symput('globalvar'||ii,trim(assignment_macro));     
     call symput('globalassign'||ii,trim(assignment_value));
     call symput('libname_type'||ii,trim(libname_type));
     if eof then call symput('globalvar_total',ii);
   run;
   
   options nomprint nomlogic nosymbolgen ;
   
   %do globvar = 1 %to &globalvar_total. ;
       %global &&globalvar&globvar ;
   %end;   
   
   %do globvar = 1 %to &globalvar_total. ;
       %put NOTE: &&globalvar&globvar = &&globalassign&globvar ;
   %end;
   
   options mprint mlogic symbolgen ;
  
   %test;

   %mvarexist(SAS_MODE); 
   %if &mvarexist. %then %do;
	 %if %upcase(&sas_mode)=TEST %then %do;
		%*SASDOC--------------------------------------------------------------------------
		| Reset Standard and Client Macros for user and development environments                   
		------------------------------------------------------------------------SASDOC*; 
		**proc catalog catalog=work.sasmacr kill force;
		**run;
		proc catalog catalog=work.sasmacr ;
		delete test.macro ;
		run;

		%if %upcase(&sysuserid.)=BSTROPICH or %upcase(&sysuserid.)=WLEE 
		 or %upcase(&sysuserid.)=BFLETCHER or %upcase(&sysuserid.)=AALONGI %then %do;
			options sasautos = ("M:\CI\programs\Development\&sysuserid.\sas\StandardMacros" sasautos);
		%end;
		%else %do;
			options sasautos = ("M:\CI\programs\Development\StandardMacros" sasautos);
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


   %*SASDOC--------------------------------------------------------------------------
   | client information                  
   ------------------------------------------------------------------------SASDOC*;    
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
   
  
   
   *SASDOC--------------------------------------------------------------------------
   | Determine if clientname has been assigned for initializing vportal and manual
   ------------------------------------------------------------------------SASDOC*; 
   %mvarexist(CLIENTNAME);    
   %if &mvarexist. %then %do;
		%global vportal manual ; 
		%let vportal=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=&clientname.Portal;" );
		%let manual =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=fg_&clientname;" ); 
   %end;

%mend oledb_init_string_new;

