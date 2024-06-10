
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_pgf_manual.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load PGF data for CCCPP        
|
| INPUT:    CCCPP PGF files
|
| OUTPUT:   practice_(IDS) dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 13JUL2011 - Brian Stropich  - Clinical Integration  1.0.01
|             Created macro 
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
|             Future enhancment - use sasfilelayout from dataformat - 5 STANDARD_BasicPlus
|                      create 5 macro layouts and toggle between the 5 different layouts
|                      named macro within to link with the dataformat table
|
+-----------------------------------------------------------------------HEADER*/

%macro edw_pgf_manual;

	%macro directory_assignment;
	
		*--------------------------------------------------------------------------------
		| Directory and file assignment 
		|
		| The logic will create a sample file to determine delimiter
		+------------------------------------------------------------------------------*;
	
		%global destdir destdir2 sample_file; 	  
	  
		data _null_;
		  %if "&filename." = "" %then %do;
		    call symput('destdir2',"dir /b &file_directory.\*.* /b");  
		  %end;
		  %else %do; 
		    call symput('destdir2',"dir /b &file_directory.\&filename. ");
		  %end;
		  call symput('destdir',"&file_directory.\"); 
		run;  
		
		filename indata pipe "&destdir2.";  		

		data pgf_files (drop=x)
             sample_file;  
		infile indata truncover;
		input file_extract $100.; 
		x=ranuni(0); 
		p=scan(file_extract,1,'-')*1;
		if p=&do_practice_id.;
		drop p;
		run;

		proc sort data = sample_file;
		by x;
		run;

		data _null_;
		set sample_file (obs=1);
		call symput('sample_file',trim(file_extract)); 
		run;
		
		%put NOTE: sample_file = &sample_file. ;
	  
	%mend directory_assignment; 

	%macro diag_standard_basicplus(m_invar,m_outvar);

		*--------------------------------------------------------------------------------
		| Diagnosis Cleanup for Standard Basic Plus 
		+------------------------------------------------------------------------------*;
	
		&m_invar.=compress(&m_invar.);
		if &m_invar. in: ('0','1','2','3','4','5','6','7','8','9','V') then do;
		if substr(&m_invar.,4,1)='.' and length(&m_invar.) in (5,6) or length(&m_invar.)=3 then &m_outvar.=&m_invar.; *good values*;
		else if length(&m_invar.) in (4,5) then &m_outvar.=substr(&m_invar.,1,3)||'.'||substr(&m_invar.,4); *add period*;
		else &m_outvar.=&m_invar.; *bad values, output as is*;
		end;
		else if &m_invar. =: 'E' then do;
		if substr(&m_invar.,5,1)='.' and length(&m_invar.)=6 or length(&m_invar.)=4 then &m_outvar.=&m_invar.; *good values*;
		else if length(&m_invar.)=5 then &m_outvar.=substr(&m_invar.,1,4)||'.'||substr(&m_invar.,5); *add period*;
		else &m_outvar.=&m_invar.; *bad values, output as is*;
		end;
		else &m_outvar.=&m_invar.; *bad values, output as is*;
		
		if substr(&m_outvar.,4,1)='.' and length(&m_outvar.) = 4 then &m_outvar.=substr(&m_outvar.,1,3); *remove decimals*;
		
	%mend diag_standard_basicplus;


	%macro determine_delimiter;

		*--------------------------------------------------------------------------------
		| Determine delimiter of the file
		|
		| The logic is only expecting 3 types of delimiters - csv, pipe, tab
		+------------------------------------------------------------------------------*;
		
		%global dlm firstobs; 
		filename trans1 "&file_Directory.\&sample_file.";

		data sample_records;
		 length dlm $10.;
		 infile trans1  lrecl=1000  firstobs=1 obs=2;
		 input testvar $100.;

		 dlmpipe=index(testvar,'|');
		 dlmcsv=index(testvar,'",');
		 dlmcsv2=index(testvar,',');

		 if dlmpipe>dlmcsv then dlm="pipe";
		 else if dlmcsv>dlmpipe then dlm="csv";
		 else if dlmcsv2>dlmpipe then dlm="csv"; 
		 else dlm="tab";
		run;

		data sample_records;
		set sample_records; 
		number=substr(left(compress(testvar,'"-')),1,5);
		number=compress(number,"'")*1;
		if number > 0 then firstobs='1';
		else firstobs='2';
		run;

		data _null_;
		 set sample_records (firstobs=1);
		  call symput('firstobs',firstobs);
		run;

		data _null_;
		 set sample_records (firstobs=2);
		  call symput('dlmtype',dlm);
		run;

		%if %upcase(&dlmtype) = CSV %then %let dlm = %str(',');
		%else %if %upcase(&dlmtype) = PIPE %then %let dlm = %str('|');
		%else %if %upcase(&dlmtype) = TAB %then %let dlm = %str('09'x);

		%put NOTE: dlmtype = &dlmtype. ;
		%put NOTE: dlm = &dlm. ;
		%put NOTE: firstobs = &firstobs. ;

	%mend determine_delimiter;
	

	%macro clean_dates;

	   format dob svcdt mmddyy10.;
	   _svcdt =scan(_svcdt,1,'');
	   _dob   =scan(_dob,1,'');
	   svcdt  =input(_svcdt,anydtdte10.); 
	   dob    =input(_dob,anydtdte10.); 

	%mend clean_dates;


	%macro standard_basicplus;

		%put NOTE: dlm = &dlm.;
		%put NOTE: destdir = &destdir.;
		%put NOTE: destdir2 = &destdir2.;

		data practice_&do_practice_id.;		
		length fil2read $100. filename $50. system $30. filed $8. phone $10. ssn memberid $9. ;
		set pgf_files ;
		fil2read="&destdir." || file_extract; 		
		infile dummy filevar=fil2read truncover dlm=&dlm. firstobs = &firstobs. lrecl=1000 missover dsd end=lastrec;
		do until (lastrec);
		input
		npi       :$10.
		npi2	  :$10.	
		tin       :$9.
		provname  :$42.
		_memberid :$11.
		patient_id:$25.
		_phone    :$15.
		_dob      :$10.
		sex       :$1.
		lname  	  :$25.
		fname     :$15.
		address1  :$50.
		address2  :$50.
		city      :$25.
		state     :$2.
		zip       :$5.
		email     :$50.
		_svcdt    :$15.
		_diag1    :$6.
		_diag2    :$6.
		_diag3    :$6.
		proccd    :$5.
		procmod1  :$2.
		procmod2  :$2.
		pos       :$2.
		_units    :$5.  ;
		
		filename=file_extract; 
		system="PGF";
		provname=upcase(provname);
		practice_id = &do_practice_id.;
		client_key = &client_id.;
		mname = '';
		source = "P";
		historical=0;
		group_id = &do_practice_id.;
		ssn = compress(_memberid,' ()-');
		memberid = compress(_memberid,' ()-');
		units = _units*1;
		phone = compress(_phone,' ()-');
		filed=substr(scan(filename,2,'-'),1,8);
		
		%clean_dates; 
		
		%diag_standard_basicplus(_diag1,diag1);
		%diag_standard_basicplus(_diag2,diag2);
		%diag_standard_basicplus(_diag3,diag3); 
		
		output;
		end;
		rename procmod1=mod1 procmod2=mod2;
		drop _:  file_extract ;
		run;

	%mend standard_basicplus;

	%directory_assignment;
	%determine_delimiter;
	%standard_basicplus;

%mend edw_pgf_manual;
