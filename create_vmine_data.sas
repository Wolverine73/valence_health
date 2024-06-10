
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_vmine_data.sas
|
| LOCATION: M:\CI\programs\ClientMacros
|
| PURPOSE:  
|         
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

%macro create_vmine_data;   
   
   *SASDOC--------------------------------------------------------------------------
   | Creating parameters for the step 2 vmine looping process as well as
   | for the validation of missing or corrupted files.
   |
   ------------------------------------------------------------------------SASDOC*;
   data step2_vmine;
     length fsdirectory sasprogram vminemacro sqllog fspipe $100 ;
     set vmine_parms (keep = filepath systemname systemid file_date); 

     
     **general information *******************************;
     i=index(filepath,'vMine');
     client=scan(filepath,2,'\');
     subfolder=scan(filepath,6,'\');
     practice=compress(scan(filepath,7,'\'));
     
     **fs   information **********************************;
     fsdirectory=trim(left(substr(filepath,1,i+5)))||trim(left(subfolder))||"\"||trim(left(practice))||"\vMine\";
     sqllog=trim(left(substr(filepath,1,i+5)))||trim(left(subfolder))||"\"||trim(left(practice))||"\sql.log";
     fspipe='dir '||trim(left(fsdirectory))||'*.* /b' ;
     
     **sas2 information **********************************;
     sasprogram='vmine_'||lowcase(trim(left(subfolder)))||'.sas';
     vminemacro='%vmine_'||lowcase(trim(left(subfolder)))||
              '(practice='||trim(left(practice))||
              ' ,system='||trim(left(systemid))||
              ' ,library=_'||trim(left(systemid))||           
              ' ,dataout=claims_'||trim(left(practice))||'); ' ;
                  
     day=put(day(date()),Z2.);
     month=put(month(date()),Z2.);
     year=put(year(date()),4.);

     rundate=intnx('month1.1',date(),0);** present first of the month;
	  rundate_fmt=put(rundate,mmddyy10.);
	  prevrundate=intnx('month1.1',date(),-2);** two months ago first of the month;
	  prevrundate_fmt=put(prevrundate,mmddyy10.);
     filedate=input(file_date, YYMMDD8.);
	  filedate_fmt=put(filedate,mmddyy10.);
     
     drop i ;
   run;   
   
   ** filter files = 
   	1. filter for the month 
   	2. filter out termed 
   	3. filter out removed  
   	4. determine missing;  

   *SASDOC--------------------------------------------------------------------------
   | Create two data sets for the vmine files. 
   | 1.  Files available for the month
   | 2.  Files available for previous months (termed, removed, missing)
   |
   ------------------------------------------------------------------------SASDOC*;   	
   data step2_vmine step2_vmine_other;
     set step2_vmine;
     if filedate ge rundate then output step2_vmine;
     else output step2_vmine_other;
   run; 
   
   data step2_vmine_other2;
    set step2_vmine_other;
    if filedate ge prevrundate;
   run; 
   
   proc sort data = step2_vmine_other2 ;
     by systemid practice descending filedate;
   run;
   
   proc sort data = step2_vmine_other2 nodupkey;
     by systemid practice ;
   run;
   
   proc sort data = step2_vmine;
     by systemid practice;
   run;
   
   
   *SASDOC--------------------------------------------------------------------------
   | Create data set that contains the last two months of missing files 
   |
   ------------------------------------------------------------------------SASDOC*; 
   data step2_vmine_missing_last2month;
     merge step2_vmine        (in=a keep=systemid practice)
     	   step2_vmine_other2 (in=b);
     by systemid practice;
     if b and not a;
   run;
   
   *SASDOC--------------------------------------------------------------------------
   | Send email to CI user of missing files                               
   |
   ------------------------------------------------------------------------SASDOC*;             
   %let vmine_missing=0;
   
   proc sql noprint;
    select count(*) into: vmine_missing
    from step2_vmine_missing_last2month;
   quit;
   
   %put NOTE:  vmine_missing = &vmine_missing.;     

   %if &vmine_missing ne 0 %then %do;  
   	%put NOTE: Missing Files Exist for the Monthly vMine CI Process ;
   	%create_formats(datain=vmine.practice, dataout=work.PracXwalk, fmtname=PracWalk, label=Name, length=75, start=PracticeID);
   
   	data missing_report;
   	set step2_vmine_missing_last2month;
   	practicename = put(practice,$PracWalk.); 
   	run;
   
   	data _null_;
   	set missing_report;
   	file "&sasrpts.\MissingReport_&CLIENTNAMEFOLDER._vmine.txt" ;
   	put @1 systemid @10 systemname @50 practice @60 practicename;
   	run;
   
   	%email_parms(
   	em_to=&primary_programmer_email,
   	em_subject=Clinical Integration - Missing vMine Practice Files,
   	em_msg=%str(Attached is a list of missing files for the past two months for systems and practices.),
   	em_attach=%str(&sasrpts.\MissingReport_nsap_vmine.txt));
   %end;
   %else %do;     
   	%put NOTE: No Missing Files Exist for the Monthly vMine CI Process ;
   %end;

   *SASDOC--------------------------------------------------------------------------
   | Creating the macro calls for the various PM Systems and practices  
   |
   ------------------------------------------------------------------------SASDOC*; 
   proc sort data = step2_vmine 
             out  = step2_vminemacros (keep = vminemacro)
             nodupkey;
     by vminemacro;
   run;
   
   data global_vmine;
     set step2_vminemacros end=eof;
     i+1;
     ii=left(put(i,4.));
     v='vminemacro'||ii; 
   run;   

   proc sql noprint;
     select v into: global_vmine separated by ' '
     from global_vmine ;
   quit;

   %put global_vmine = &global_vmine. ;

   %global vminemacro_total &global_vmine. ;

   data _null_;
     set global_vmine end=eof;
     call symput(v,trim(vminemacro));
     if eof then call symput('vminemacro_total',ii);
   run; 


   
   
%mend create_vmine_data;