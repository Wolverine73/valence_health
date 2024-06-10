
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_vmine_directory.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:   
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|              
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro create_vmine_directory;

   proc sql; 
      create table vmine_parms as
      select distinct 
      a.isprocessed, 
      a.dateprocessed,
      a.dataerrors, 
      a.dateentered,
      a.receiptkey as file_name,  
      substr(scan(a.receiptkey,2,'-'),1,8) as file_date,
      a.FilePath,
      b.practiceid,  
      b.name as practicename, 
      c.clientid, 
      c.clientname, 
      d.versionid, 
      e.name as systemname, 
      e.systemid,
	  d.DirectoryPath
      from vmine.ExtractedFileList a
         inner join vmine.Practice  b on a.practiceid=b.practiceid
         inner join vmine.Client c   on b.clientid=c.clientid 
         inner join vmine.Version d  on a.versionid=d.versionid
         inner join vmine.System e   on d.systemid=e.systemid
      where c.clientid = &client_id. 
        and b.Termed = 0
      order by e.name, a.receiptkey;
   quit;

   data vmine_parms ; 
     set vmine_parms ; 
	 if upcase(DirectoryPath)='MEDISOFT16' then do;
	   DirectoryPath='Medisoft'; 
	 end;
	 else if upcase(DirectoryPath)='LYTEC2010' then do;
	   DirectoryPath='Lytec'; 
	 end;
   run; 

   data vmine_parms;
      set vmine_parms;
      old=compress(scan(filepath,8,'\'));
      if upcase(old) = 'OLD' then delete;
      drop old;
   run;

   data vmine_libnames;
      length sasdirectory saslibname client_dir sasdirectory $100 ;
      set vmine_parms (keep = filepath directorypath systemname systemid);

	  client_dir="&client_dir."; 
	  sasdirectory=trim(left(client_dir))||"\"||trim(left(directorypath));  
      saslibname='libname _'||trim(left(systemid))||' "'||trim(left(sasdirectory))||'"; ' ; 
      
      keep saslibname sasdirectory directorypath ;
   run;
   
   proc sort data =  vmine_libnames nodupkey;
      by saslibname ;
   run;


   data _null_;
      set vmine_libnames  end=eof;
      i+1;
      ii=left(put(i,4.));
      call symput('libname'||ii,trim(saslibname));
      call symput('directory'||ii,trim(sasdirectory));
      if eof then call symput('directory_total',ii);
   run;
   
   %do i = 1 %to &directory_total. ;
     x "if not exist &&directory&i mkdir &&directory&i";
     &&libname&i 
   %end;

%mend create_vmine_directory;

