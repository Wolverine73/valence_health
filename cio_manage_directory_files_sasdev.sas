
options noxwait;

libname cio "\\sas2\ci\programs\EDW";

%macro cio_manage_directory_files;

	data _null_;
	  set cio.cio_directory  end=eof;
	  where environment='SASDEV';
	    i+1;
	    ii=left(put(i,4.)); 
		call symput('dir'||ii,trim(dir));
		call symput('days'||ii,trim(days));
	    if eof then call symput('dir_total',ii);
	run;
	
	%put NOTE: dir_total = &dir_total. ;

	%do j = 1 %to &dir_total. ;
		
		%let file_directory=&&dir&j. ; 
		%let days=&&days&j. ; 
		
		%put NOTE: file_directory = &file_directory. ;
		%put NOTE: days = &days. ;

		data _null_; 
		  call symput('sas_dir',"dir  &file_directory.\*.* ");    
		run;  

		filename indata pipe "&sas_dir.";  
		
		data file_directory; 
		  length filename $50. deletefiles $100.;
		  format date mmddyy10.;
		  infile indata truncover;
		  input File_Extract $100.;
			date2=scan(File_Extract,1,' ');
			date=input(date2,mmddyy10.);
			time=scan(File_Extract,2,' ');
			ampm=scan(File_Extract,3,' ');
			size=compress(scan(File_Extract,4,' '),',')*1;
			filename=scan(File_Extract,5,' ');  
			ext=lowcase(scan(filename,2,'.'));
			deletefiles="&file_directory."||"\"||trim(left(filename));
			if index(filename,'.') > 0 and size > 0;
		run;
		
		data file_directory;
		set file_directory;
			if date < today() - &days. ; /**or  ext ne 'sas7bdat';**/
			drop date2 ;
		run;

		proc sql noprint;
		select count(*) into: file_directory_cnt
		from file_directory;
		quit;

		%put NOTE: file_directory_cnt = &file_directory_cnt. ;

		%if &file_directory_cnt. ne 0 %then %do;

			%put NOTE: Remove &file_directory_cnt files from &file_directory. ;

			%let deletefiles_total=0;

			data _null_;
			  set file_directory  end=eof;
			    i+1;
			    ii=left(put(i,4.)); 
				call symput('deletefiles'||ii,trim(deletefiles));
			    if eof then call symput('deletefiles_total',ii);
			run;

			%do i = 1 %to &deletefiles_total. ;
			    x "del &&deletefiles&i"; 
			%end;

		%end;

	%end;

%mend cio_manage_directory_files;

%cio_manage_directory_files; 
