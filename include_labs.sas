%macro include_labs;


%let init_string1=%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=sqlcidev;Initial Catalog=CIEDW;" );
libname lab 'M:\exempla\sasdata\CIETL\lab\labcorp';
libname test 'M:\CI\sasdata\ValenceBaseMeasures\Guideline Development';

%let stdt= '01Jun2010'd;
%let enddt= '01Jun2011'd;
%let sqlstdt= '01Jun2010';
%let sqlenddt= '01Jun2011';
%let client_key = 8;

proc sql noprint;
connect to oledb(init_string=&init_string1.);
create table lab_edw as  
	 select member_key format 16. as memberid
			,datepart(service_date) format mmddyy10. as svcdt 
			,test_name format $250. as test_name
			,cpt_code format $5. as cpt_code
			,lab_code format $7. as lab_code
			,value format $250. as value_character 
			,input(value,best16.) as value_numeric 
			,lab_rslt_key format 8. as encounter_key
			
			
		from connection to oledb  
			(select 
			     member_key
				,service_date 
				,test_name
				,cpt_code
				,lab_code
				,value
				,created_on
				,updated_on
			    ,lab_rslt_key 
		
			   	
					from dbo.LAB_RESULT 
					where
					client_key = &client_key. and
					((service_date between &sqlstdt. and &sqlenddt.) or (created_on between &sqlstdt. and 
&sqlenddt.) or (updated_on between &sqlstdt. and &sqlenddt.)))
	 				order by memberid, svcdt;
					
					disconnect from oledb;
					quit;
%mend include_labs;
