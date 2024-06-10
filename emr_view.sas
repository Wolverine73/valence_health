
/*HEADER------------------------------------------------------------------------
|
| program:  emr_view
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Feed the linking program EMR data only
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
| 01SEP2012 - Valence Health  - EMR
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

%macro emr_view;

	
	%*SASDOC--------------------------------------------------------------------------
	| Connect to SQL Server to retreive the person demographic data from EMR
	------------------------------------------------------------------------SASDOC*; 

	proc sql;
		connect to oledb(init_string=&vh_emr);
		create table emr_demographics as 
		 select . as PERSON_KEY,             
				SSN,
				FNAME,
				MNAME,
				LNAME,
				SEX,
				input(dob,yymmdd10.) as dob,
				DATE_OF_DEATH,
				Address1,  
				Address2,
				Address3,
				City,
				State,
				Zip,
				COUNTRY,
				Phone,
				PATIENT_SOURCE_KEY,
				DATA_SOURCE_ID,
				CLIENT_KEY,
				PATIENT_DEMOGRAPHICS_KEY
		from connection to oledb
		(	
			exec dbo.sp_Person_Demographics &practice_id., &client_id. 
		);
	quit;

%mend emr_view;
