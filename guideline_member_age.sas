/*HEADER------------------------------------------------------------------------
|
| program:  guideline_member_age.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create Roster of Members for Age Based Guidelines, calculate member age
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
| 18OCT2011 - Nick Williams - Original
|             
|
|
+-----------------------------------------------------------------------HEADER*/

%macro guideline_member_age(recreate);

    %countobs(dsn=mbrsage,macvar=mbrsagevar);

    %if (&mbrsagevar. le 0 or &recreate eq 1) %then %do;
        %let init_string1=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=sqlcidev;Initial Catalog=CIEDW_BL_TEST;");
/*        %let init_string1=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=CIEDW;");*/
        %isnull(enddt);
        %if &enddt_isnull %then %let enddt = "&sysdate9"d;        
        proc sql;
        connect to oledb(init_string = &init_string1.);
        create table mbrsage as
        select distinct member_key format 16.,
               datepart(dob) format= mmddyy10. as dob,
               sex,
               int(yrdif(calculated dob,&enddt.,'Actual')) as mage
        from connection to oledb
        (select distinct member_key, sex,dob from dbo.Member where client_key = &client_key.);
        disconnect from oledb;
        quit;
    %end;

%mend guideline_member_age;
