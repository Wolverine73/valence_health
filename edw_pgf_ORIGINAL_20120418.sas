
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_pgf.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:           
|
| INPUT:    
|
| OUTPUT:   claims_&data_source dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 01DEC2011 - Brian Stropich  - Clinical Integration  1.0.01
|             Created edw_pgf_uploader macro 
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
+-----------------------------------------------------------------------HEADER*/

%macro edw_pgf;

	%macro edw_pgf_uploader;

		%if &deliverytypeid ne 2 %then %do; 
		%end;
		%else %do; /** begin - pgf uploader **/

		*SASDOC--------------------------------------------------------------------------
		| Create filename assignment
		--------------------------------------------------------------------------SASDOC*;	
		%macro filename_assign;
		  %global uploader_dir ;
		  %if &client_id = 4 %then %do;
			data _null_; 
			call symput('uploader_dir',"M:\&client.\sasdata\CI\CIETL\claims\PGF\uploader");
			call symput('uploader_list',"dir /b M:\&client.\sasdata\CI\CIETL\claims\PGF\uploader\*.*"); 
			run;	
		  %end;
		  %else %do;
			data _null_; 
			call symput('uploader_dir',"M:\&client.\sasdata\CIETL\claims\PGF\uploader");
			call symput('uploader_list',"dir /b M:\&client.\sasdata\CIETL\claims\PGF\uploader\*.*"); 
			run;	
		  %end;

		  %put NOTE: uploader_dir = &uploader_dir. ;
		%mend filename_assign;
		%filename_assign;

		%set_error_flag;
		%on_error(ACTION=ABORT);

		*SASDOC-------------------------------------------------------------------------
		| Create list of SAS datasets for the workflow                        
		|------------------------------------------------------------------------SASDOC*;
		libname uploader "&uploader_dir.";  
		filename indata pipe "&uploader_list.";  		

		data list  ;  
		infile indata truncover;
		input memname $50.; 
		memname=upcase(scan(memname,1,'.'));
		if substr(upcase(memname),1,2) = "PM";
                libname='UPLOADER'; 
		run;

		data list2;
		  set list;

		  datasourceid=substr(scan(memname,1,'_'),3)*1;	  
		  filename=substr(memname,3); 	  
		  filename=trim(translate(filename,'-','_'));   
		  file_in="&filename.";
		  file_in=scan(file_in,1,'.');

		  if file_in ne '' then do;
		    if scan(file_in,1,'.')=filename;
		  end;
		  else do;
		    if datasourceid=&do_practice_id.; 
		  end;
		run;  

		*SASDOC-------------------------------------------------------------------------
		| Validate if SAS datasets have been processed in a previous workflow   
		| maxprocessid values: 0=DNE within EDW 
		|                      1=1st cycle exist within EDW only ssn members exist
		|                      2=2nd cycle exist within EDW all members exist
		|------------------------------------------------------------------------SASDOC*;
		%if &maxprocessid ne 0 and &maxprocessid ne 1 and %length(&filename) > 0  %then %do; 

			proc sql noprint;
			  create table uploader_history as
			  select distinct client_key, practice_id, filename
			  from cihold.hold_encounter_header_detail
			  where practice_id = &do_practice_id. 
			    and client_key = &client_id.; 
			quit;

			data uploader_history;
			  set uploader_history ;
			  x=index(filename,'.');
			  if x > 0 then do;
			    filename=substr(filename,1,x-1);
			  end;   
			run;

			proc sql noprint;
			  create table list2 as
			  select *
			  from list2
			  where filename not in (select filename
						 from   uploader_history);
			quit;
			
			%check_issue_count(dataset_in=list2, validation=70);

		%end;
		
		%macro diag_missing_decimals;

		   array diag  {*} diag1-diag3 ;
		   array indx  {*} i1-i3 ;
		   array lngth {*} l1-l3 ;
		   array subt  {*} $1 sub1-sub3 ;

		   do j = 1 to dim(diag) ;
		     indx{j}=indexc(diag{j},".");
		     lngth{j}=length(diag{j});
			 subt{j} =substr(diag{j},1,1);
			 diag{j}=upcase(compress(cats(diag{j}),'/\ '));
			 if indx{j} = 0 then do; 
				 if subt{j} ne 'E' then do;
			       if lngth{j} > 3 and indx{j} = 0 then do;
				 diag{j}=substr(diag{j},1,3)||"."||substr(diag{j},4);
			       end; 
				 end;
				 else do;  
			       if lngth{j} > 4 and indx{j} = 0 then do;
				 diag{j}=substr(diag{j},1,4)||"."||substr(diag{j},5);
			       end; 
				 end;
			 end;
		   end;

		   drop i1-i3 l1-l3 sub1-sub3 j;

		%mend diag_missing_decimals;

		*SASDOC-------------------------------------------------------------------------
		| Process new SAS datasets for the workflow                         
		|------------------------------------------------------------------------SASDOC*;
		%let memname_total = 0;

		data _null_;
		  set list2 end=eof;
		  i+1;
		  ii=left(put(i,4.));
		  call symput('memname'||ii,left(trim(memname))); 
		  if eof then call symput('memname_total',ii);
		run;

		%put NOTE: memname_total = &memname_total. ;

		%if &memname_total. ne 0 %then %do;	

			data claims_pgfuploader;
			  set %do z = 1 %to &memname_total;
				uploader.&&memname&z   
			      %end;;
			run;

			*SASDOC--------------------------------------------------------------------------
			| Determine diagnosis variables per pm system - practice.   
			+------------------------------------------------------------------------SASDOC*;
			proc contents data = claims_pgfuploader
			out  = contents_diag (keep = name) noprint;
			run;

			proc sql noprint;
			  select distinct(name), count(*) into : diag_names separated by ' ',  : diag_total 
			  from contents_diag
			  where substr(upcase(name),1,4)='DIAG'
			  and substr(upcase(name),6,1)='';
			quit;

			%put NOTE: diag_names = &diag_names ;
			%put NOTE: diag_total = &diag_total ;

			data practice_&do_practice_id.;
			set claims_pgfuploader;
			length 
			mname	$1.
			chartnum	$15. 
			ssn $9. 
			provid	$10.
			proccd $5. 
			claimnum  $10. 
			system $50. ;
			format submit dollar20.2;

			chartnum = ''; 
			mname	 = ''; 
			if upcase(sex) in ("M", "F") then sex=upcase(sex);
			else sex=("U");
			
			fname=upcase(fname);
			lname=upcase(lname);
			address1=upcase(address1);
			address2=upcase(address2);
			city=upcase(city);
			state=upcase(state);
			sex=upcase(sex);
			
			ssn      = cats(compress(memberid,'-'));
			provid	 = cats(npi);
			npi      = cats(npi);
			provfirst= '';
			provlast = '';   
			units    = 1;
			submit   = 0; 
			claimnum = '';  
			upin     = '';
			source   = 'P'; 
			payorid1='';
			payorname1='';
			system="VGF"; 
			practice_id=&do_practice_id;
			client_key=&client_id.;
			provname = provname;
			diag1=compress(diag1,'/\ ');
			diag2=compress(diag2,'/\ ');
			diag3=compress(diag3,'/\ ');
			source_type='Uploader';  /** for the sorting routine later - edw_claims_transformation.sas **/

			if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = ''; 
			x=index(filename,'.');
			if x > 0 then do;
			    filename=upcase(substr(filename,1,x-1));
			end; 
			else do;
			    filename=upcase(filename);
			end;
			filed=scan(scan(filename,1,'T'),2,'-');

			%if &do_practice_id. = 675 %then %do;
				%do diag = 1 %to &diag_total.; 
				    if diag&diag. ='V252' then diag&diag. ='V25.2';
					if diag&diag. ='V258' then diag&diag. ='V25.8';  
				%end;
			%end;
			
			%if &do_practice_id. = 563 %then %do;
				%diag_missing_decimals;
			%end;

			run;
			
			proc contents data = practice_&do_practice_id. out = contents1 (keep = name) noprint;
			run;
			
			proc sql noprint;
			select count(*) into: cnt_mod2 separated by ''
			from contents1
			where upcase(name)='MOD2';
			quit;
			
			%put NOTE: cnt_mod2 = &cnt_mod2. ;
			
			%if &cnt_mod2. = 0 %then %do;
			  data practice_&do_practice_id.;
			  set practice_&do_practice_id.;
			  mod2='';
			  run;
			%end;

			proc sort data = primary_provider_xref 
				  out  = tin_assignment (keep = datasourceid tin) nodupkey;
			by datasourceid tin;
			run;

			%let tin_count=0;

			proc sql noprint;
			select count(*) into: tin_count separated by ''
			from tin_assignment;
			quit;

			%put NOTE: tin_count = &tin_count. ;

			%if &tin_count. = 1 %then %do;

				proc sql noprint;
				select tin into: tin_assignment separated by ''
				from tin_assignment;
				quit;

				data practice_&do_practice_id.;
				set practice_&do_practice_id.;
				tin="&tin_assignment.";
				run;

			%end;	

		%end;
		%else %do;		

			data practice_&do_practice_id. ;
			x=1;
			run; 

			%put ERROR:  No datasets exist for practice - &do_practice_id. ;

			%macro send_email_alert;
				filename mail_out email to="bstropich@valencehealth.com" cc="gliu@valencehealth.com" subject="CIO Work Flow &wflow_exec_id. - No datasets exist for PGF Uploader";
					data _null_;
				file mail_out lrecl=32767;  
				put "practice ID = &do_practice_id.";
				put "system ID = &system_id.";
				run;
			%mend send_email_alert;
			%**send_email_alert;
			
			%let err_fl=1;
			%set_error_flag;
			%on_error(ACTION=ABORT);

		%end;

		%end; /** end - pgf uploader **/

	%mend edw_pgf_uploader;



	%macro edw_pgf_manual;

		%macro directory_assignment;

			*--------------------------------------------------------------------------------
			| Directory and file assignment 
			|
			| The logic will create a sample file to determine delimiter
			+------------------------------------------------------------------------------*;

			%global destdir destdir2 sample_file; 	  

			data _null_;
			  %if %length(&filename) > 0 %then %do;
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
		
		%macro diag_standard_basic2(diag=);

			format _diag $10.;
			_diag=upcase(&diag); 


			/*  fix period problems */
			if length(&diag) <= 6 and length(&diag) > 3 and ANYdigit(substr(&diag, 2,1)) = 1 and ANYdigit(substr(&diag, 3,1)) = 1  then do; /* valid code */
			  if index(_diag,".") in (.,0) and length(&diag) >= 4 and _diag ne '' then do;  /* no period in text and long enough for period */
			    if substr(_diag,1,1) = "E" and length(&diag) >=5 then _Diag = substr(cats(_diag),1,4)||"."||substr(cats(_diag),5);/* put the period in E codes E000.0*/
			    else if substr(_diag,1,1) = "E" and length(&diag) =4 then _Diag=_diag;  /* E code is correct E000 */
			    else _Diag = substr(cats(_diag),1,3)||"."||substr(cats(_diag),4); /* For Diagnosis codes with add the period at character 4 Works for V codes*/ 
			  end;
			  else do;/* with periods */
			    if substr(_diag,1,1) = "E" and length(&diag) =5 and index(_diag,".")=5 then _diag=compress(_diag,"."); /* remove last period E000. */
			    if length(&diag)=4 and index(_diag,".")=4 then _diag=compress(_diag,"."); /* 000. remove period */
			  end; /* end with periods */
			end; /* end valid code*/

				;
			&diag=_diag; /* return the cleaned value */
			drop _diag ;

		%mend diag_standard_basic2;

		%macro diag_standard_basic1;

		   array diag  {*} diag1-diag3 ;
		   array indx  {*} i1-i3 ;
		   array lngth {*} l1-l3 ;
		   array subt  {*} $1 sub1-sub3 ;

		   do j = 1 to dim(diag) ;
		     indx{j}=indexc(diag{j},".");
		     lngth{j}=length(diag{j});
			 subt{j} =substr(diag{j},1,1);
			 diag{j}=upcase(compress(cats(diag{j}),'/\ '));
			 if indx{j} = 0 then do; 
				 if subt{j} ne 'E' then do;
			       if lngth{j} > 3 and indx{j} = 0 then do;
				 diag{j}=substr(diag{j},1,3)||"."||substr(diag{j},4);
			       end; 
				 end;
				 else do;  
			       if lngth{j} > 4 and indx{j} = 0 then do;
				 diag{j}=substr(diag{j},1,4)||"."||substr(diag{j},5);
			       end; 
				 end;
			 end;
		   end;

		   drop i1-i3 l1-l3 sub1-sub3 j;

		%mend diag_standard_basic1;

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
			
			fname=upcase(fname);
			lname=upcase(lname);
			address1=upcase(address1);
			address2=upcase(address2);
			city=upcase(city);
			state=upcase(state);
			sex=upcase(sex);

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



		%macro standard_basic;

			%put NOTE: dlm = &dlm.;
			%put NOTE: destdir = &destdir.;
			%put NOTE: destdir2 = &destdir2.;

			%if &do_practice_id = . %then %let do_practice_id=0;

			data practice_&do_practice_id.;		
			length fil2read $100. filename $50. system $30. filed $8. phone $10. ssn memberid $9. mod1 mod2 $2.;
			set pgf_files ;
			fil2read="&destdir." || file_extract; 		
			infile dummy filevar=fil2read truncover firstobs=&firstobs dlm=&dlm. lrecl=410 missover dsd end=lastrec;
			do until (lastrec);
			input
			   npi: 		$10.	
			   npi2: 		$10.	
			   tin:			$9. 
			   provname: 	$42.
			   _memberid:	$20.
			   _phone: 		$20.	
			   _dob: 		$10.	
			   sex: 		$1.	
			   lname: 		$25.	
			   fname: 		$15.
			   address1:	$50.
			   address2:  	$50.
			   city:		$25.
			   state: 		$2.	
			   zip: 		$5.	
			   _svcdt: 		$10.	
			   diag1: 		$6.	
			   diag2: 		$6.	
			   diag3: 		$6.	 
			   proccd: 		$5.	
			   procmod1: 	$4.
			   pos:  		$2.	
			   _units:  	$5.	 ;

			filename=file_extract; 
			system="PGF";
			provname=upcase(provname); 
			tin=compress(tin,'-');
			if sex in ("F","f") then sex = "F";
			else if sex in ("M","m") then sex = "M";
			else sex = "U";
			practice_id = &do_practice_id.;
			client_key = &client_id.;
			mname = '';
			source = "P";
			historical=0;
			group_id = &do_practice_id.;
			ssn = compress(_memberid,' ()-');
			if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then ssn = "";
			memberid = ssn;	
			units = _units*1;
			if substr(_phone,1,1)='0' then do;
			  _phone=left(substr(_phone,2)); /*** phones for exempla have prefix of 0 ***/
			end;
			phone = compress(_phone,' ()-');
			filed=substr(scan(filename,2,'-'),1,8);
			procmod2='';
			
			fname=upcase(fname);
			lname=upcase(lname);
			address1=upcase(address1);
			address2=upcase(address2);
			city=upcase(city);
			state=upcase(state);
			sex=upcase(sex);

			%clean_dates;

			%diag_standard_basic1;
			%diag_standard_basic2(diag=diag1);
			%diag_standard_basic2(diag=diag2);
			%diag_standard_basic2(diag=diag3);
			mod1=compress(procmod1,'()');
			mod2=compress(procmod2,'()');
			output;
			end;

			drop _:  file_extract procmod1 procmod2;
			run;

		%mend standard_basic;


		%directory_assignment;
		%determine_delimiter;
		%&sassubfilelayout.;

	%mend edw_pgf_manual;


	%if &deliverytypeID. = 2 %then %do;
		%edw_pgf_uploader;
	%end;
	%else %do; /** 5 - autoput (pgf manual), 6 - vmine file repository **/
		%edw_pgf_manual;
	%end;

%mend edw_pgf;


