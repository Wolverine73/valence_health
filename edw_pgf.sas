
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
|             Implement into Production xxx
|
| 20JUL2012 - Winnie Lee - Release 1.3 H01
|				Update &PPX_PRIMARY join between tblGroups and CIEDW.Practice table
|				on PRACTICE_KEY to VSOURCE_PRACTICE_KEY
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.2.01
|             Added standard_athena for st. lukes
|             Added new validation 103 for pgf files with 0 records
|
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
			call symput('uploader_dir',"M:\&client_short_name.\sasdata\CI\CIETL\claims\PGF\uploader");
			call symput('uploader_list',"dir /b M:\&client_short_name.\sasdata\CI\CIETL\claims\PGF\uploader\*.*"); 
			run;	
		  %end;
		  %else %do;
			data _null_; 
			call symput('uploader_dir',"M:\&client_short_name.\sasdata\CIETL\claims\PGF\uploader");
			call symput('uploader_list',"dir /b M:\&client_short_name.\sasdata\CIETL\claims\PGF\uploader\*.*"); 
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
		    if upcase(scan(file_in,1,'.'))=upcase(filename);
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
			  %if %length(&filename) = 0 %then %do;
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
			 else if dlmcsv2>dlmpipe and &do_practice_id. ne 1288 then dlm="csv"; 
			 else dlm="tab";
			run;
			
			%check_issue_count(dataset_in=sample_records, validation=103);

			data sample_records;
			set sample_records; 
			number=substr(left(compress(testvar,'"-')),1,5);
			number=compress(number,"'")*1;
			if number > 0 then firstobs='1';
			else firstobs='2';
			run;
			
			proc sql noprint;
			select count(*) into: count_obs separated by ''
			from sample_records;
			quit;

			%put NOTE: count_obs = &count_obs. ;			

			data _null_;
			%if &dataformatid. = 7 %then %do;
				set sample_records (obs=1);
			%end;
			%else %do;
			 	set sample_records (firstobs=1);
			%end;
			%if &do_practice_id. = 1288 %then %do;
				call symput('firstobs',2); /*** This PGF has a blank line on the first line of every file ***/
			%end;
			%else %do;
				call symput('firstobs',firstobs);
			%end;
			run;

			data _null_;
			%if &dataformatid. = 9  or &do_practice_id. = 1288 or &dataformatid. = 35 %then %do;
				set sample_records (firstobs=1);
			%end;
			%else %do;
				set sample_records (firstobs=2);
			%end;
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
			
			mrn_count = 0;

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
				_units    :$5.  
				;

				filename=file_extract; 
				system="PGF";
				provname=upcase(provname);
				practice_id = &do_practice_id.;
				client_key = &client_id.;
				mname = '';
				patient_id = left(patient_id);
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

				if patient_id ne '' then mrn_count + 1;

				%clean_dates; 

				%diag_standard_basicplus(_diag1,diag1);
				%diag_standard_basicplus(_diag2,diag2);
				%diag_standard_basicplus(_diag3,diag3); 

				output;
			end;

			call symput('mrn_count',cats(mrn_count));

			rename procmod1=mod1 procmod2=mod2;
			drop _:  file_extract mrn_count;
			run;

			%if &mrn_count. = . %then %let mrn_count = 0;

			%put NOTE: Record count with MRN for PGF Standard Basic Plus - &mrn_count.;
			
			%if &mrn_count ne 0 %then %do;
				proc datasets nolist;
					modify practice_&do_practice_id.;
						rename patient_id = system_member_id;
				quit;
			%end;

		%mend standard_basicplus;



		%macro standard_basic;

			%put NOTE: dlm = &dlm.;
			%put NOTE: destdir = &destdir.;
			%put NOTE: destdir2 = &destdir2.;

			%if &do_practice_id = . %then %let do_practice_id=0;

			data practice_&do_practice_id.;		
			length fil2read $100. filename $50. system $30. filed $8. phone $10. ssn memberid $9. mod1 mod2 $2. tin $9.;
			set pgf_files ;
			fil2read="&destdir." || file_extract; 		
			infile dummy filevar=fil2read truncover firstobs=&firstobs dlm=&dlm. lrecl=410 missover dsd end=lastrec;
			do until (lastrec);
			input
			   npi: 		$10.	
			   npi2: 		$10.	
			   _tin:		$10. 
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

			tin=compress(_tin,'-');
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

			drop _:  file_extract procmod1 procmod2 _tin;
			run;

		%mend standard_basic;


		%macro edw_pgf_KLOBilling;

			%put NOTE: dlm = &dlm.;
			%put NOTE: destdir = &destdir.;
			%put NOTE: destdir2 = &destdir2.;

			data practice_&do_practice_id.;		
			length fil2read $100. filename $50. system $10. filed $8.;
			set pgf_files;

			filename=file_extract; 
			filed=substr(scan(filename,2,'-'),1,8);
			chkdate='20110301';

			fil2read="&destdir." || file_extract; 		
			infile dummy filevar=fil2read truncover dlm=&dlm. firstobs = &firstobs. lrecl=1000 dsd end=lastrec;
			do until (lastrec);
				input

				%if filed < chkdate %then %do;
					claimnum: $upcase5.
					itemnum: $upcase1.
					_provid: $15.
					npi: $10.
					tin: $9.
					provlast: $upcase25.
					provfirst: $upcase15.
					payorid1: $upcase9.							
					payorname1: $upcase35.
					npayorid1: $upcase5.	
					instype1: $upcase2.
					relationshipcode1: $upcase2.
					patid1: $upcase19.
					payorid2: $upcase9.
					payorname2: $upcase35.
					npayorid2: $upcase5.
					instype2: $upcase2.
					relationshipcode2: $upcase2.							
					patid2: $upcase19.
					payorid3: $upcase9.							
					payorname3: $upcase35.
					npayorid3: $upcase5.
					instype3: $upcase2.
					relationshipcode3: $upcase2.
					patid3: $upcase19.
					ssn: $upcase9.
					patlast: $upcase35.
					patfirst: $upcase15.							
					patmid: $upcase1.
					patdob : mmddyy10.						
					patsex: $upcase1.
					tos: $upcase1. 
					svcdt:  mmddyy10.
					proccd: $upcase5.
					mod1: $upcase2.
					quantity: 3.  
					billamt: 10.
					_diag1: $upcase6.	
					_diag2: $upcase6.
					_diag3: $upcase6.
					_diag4: $upcase6.
					_diag5: $upcase6.
					pos: $2.;
				%end;
				%else %do;
					claimnum: $upcase5.
					itemnum: $upcase1.
					_provid: $15.
					npi: $10.
					tin: $9.
					provlast: $upcase25.
					provfirst: $upcase15.
					payorid1: $upcase9.							
					payorname1: $upcase35.
					npayorid1: $upcase5.	
					instype1: $upcase2.
					relationshipcode1: $upcase2.
					patid1: $upcase19.
					payorid2: $upcase9.
					payorname2: $upcase35.
					npayorid2: $upcase5.
					instype2: $upcase2.
					relationshipcode2: $upcase2.							
					patid2: $upcase19.
					payorid3: $upcase9.							
					payorname3: $upcase35.
					npayorid3: $upcase5.
					instype3: $upcase2.
					relationshipcode3: $upcase2.
					patid3: $upcase19.
					ssn: $upcase9.
					patlast: $upcase35.
					patfirst: $upcase15.							
					patmid: $1.
					patdob : mmddyy10.						
					patsex: $upcase1.
					tos: $upcase1. 
					svcdt:  mmddyy10.
					proccd: $upcase5.
					mod1: $upcase2.
					quantity: 3.  
					billamt: 10.
					_diag1: $upcase6.	
					_diag2: $upcase6.
					_diag3: $upcase6.
					_diag4: $upcase6.
					_diag5: $upcase6.
					pos: $upcase2.;
				%end;
				;
			
			
			%do k = 1 %to 5;
				if index(_diag&k.,'.') in (4,5) then diag&k.=_diag&k.;
				else if trim(substr(_diag&k.,1,1)) in ('0','1','2','3','4','5','6','7','8','9','V') then do;
					_diag&k.=compress(_diag&k.,' ');
					if length(_diag&k.)>3 then do;
						d1=trim(substr(_diag&k.,1,3));
						d2=trim(substr(_diag&k.,4));
					end;
					else if length(_diag&k.)<=3 then diag&k.=_diag&k.;
					if d1 ne "" and d2 ne "" then diag&k.=trim(d1)||"."||trim(d2);
					else diag&k.=compress(_diag&k.,' ');
				end;
				else if trim(substr(_diag&k.,1,1)) in ('E') then do;
					_diag&k.=compress(_diag&k,' ');
					if length(_diag&k.) > 4 then do;
						d1=trim(substr(_diag&k.,1,4));
						d2=trim(substr(_diag&k.,5));
					end;
					else if length(_diag&k)<=4 then diag&k.=_diag&k.;
					if d1 ne "" and d2 ne "" then diag&k.=trim(d1)||"."||trim(d2);
					else diag&k.=compress(_diag&k.,' ');
				end;	
				else do;
					diag&k.=compress(_diag&k.,' ');
				end;
			%end;

			 
			length 	filed $8. source $1. 
					memberid $9. lname $25. fname $15. address1 address2 $50. city $25. state $2. zip $5. phone $10.
					provname $42. provid npi $10. upin $6. 
					_proccd $10. payorid1 $36. mod2 $2. units 8.; 
			format svcdt dob mmddyy10. submit 10.2;

			system="KLOBILLING";
			source="P";

			provlast = compress(provlast,',');
			if provlast ne '' and provfirst ne '' then provname = trim(provlast)||","||trim(provfirst);
			else if provlast ne '' and provfirst = '' then provname = trim(provlast);
			else if provlast = '' and provfirst ne '' then provname = trim(provfirst);
			else provname = '';
			provid = _provid;
			upin = '';

			lname=patlast;
			fname=patfirst;
			mi=patmid;
			if upcase(patsex) in ('F','M') then sex = patsex;
			else sex = 'U';
			dob=patdob;
			if ssn*1 in (.,0) then memberid="";
			else memberid = ssn;
			address1 = '';
			address2 = '';
			city = '';
			state = '';
			zip = '';
			phone = '';
			
			_proccd=proccd;
			mod2 = '';
			units=quantity;
			submit = billamt; 
				
			rel=relationshipcode1;

			client_key=&client_id. ;
			practice_key=&practice_key. ;
			practice_id=&do_practice_id. ;
			claim_source = &dataformatgroupid.;

			drop _provid patlast patfirst patmid patsex patdob relationshipcode1 _diag1-_diag5 d1 d2 quantity billamt tos;
			output;
			end;

			run;

		%mend edw_pgf_KLOBilling();



		%macro edw_pgf_HealthNautica;

			%put NOTE: dlm = &dlm.;
			%put NOTE: destdir = &destdir.;
			%put NOTE: destdir2 = &destdir2.;

			data raw;		
			length fil2read $100. filename $50. system $10. filed $8.;
			set pgf_files;
			fil2read="&destdir." || file_extract; 		
			infile dummy filevar=fil2read truncover dlm=&dlm. firstobs = &firstobs. lrecl=1000 dsd end=lastrec;
			do until (lastrec);
			input
				cnt: 8.
				table :$upcase100.
				var1: $upcase50.
				var2: $upcase50.
				var3: $upcase50.
				var4: $upcase50.
				var5: $upcase50.
				var6: $upcase50.
				var7: $upcase50.
				var8: $upcase50.
				var9: $upcase50.
				var10: $upcase50.
				var11: $upcase50.
				var12: $upcase50.
				var13: $upcase50.
				var14: $upcase50.
				var15: $upcase50.
			;

			filename=file_extract; 
			filed=substr(scan(filename,2,'-'),1,8);
			system = 'HNAUTICA';

			output;
			end;
			run;

			*SASDOC-------------------------------------------------------------------------
			| Create claims table                         
			|------------------------------------------------------------------------SASDOC*;
			data clms (compress=yes
						 keep = filename filed system 
								claimnum patlinkid npi provlast provfirst tin
								svcdt _proccd proccd mod1 units pos diag1-diag4 submit);
				set raw;
				where table="SRVCDETAIL";
				 
				length 	claimnum npi $10. provlast $25. provfirst $15. tin $9. 
						svcdate $10. svcdt 4. diag1-diag4 $6. _proccd $10. proccd $5. mod1 $2.
						units 8. submit 8.  pos $2.; *unitstypeind $5. tos $2.;
				format svcdt mmddyy10. submit dollar20.2;

				claimnum 	 = upcase(cats(var1));
				patlinkid 	 = upcase(cats(var2));
				svcdate 	 = cats(var3);
				_proccd 	 = upcase(cats(var4));
				proccd  	 = upcase(substr(_proccd,1,5));
				*provlinkid  = upcase(cats(var5));
				npi			 = var5;
				provlast	 = upcase(cats(var6));
				provfirst	 = upcase(cats(var7));
				tin			 = compress(var8,'-');
				units 	 	 = var9;
				pos 		 = upcase(cats(var10));
				diag1 		 = upcase(cats(var11));
				diag2 		 = upcase(cats(var12));
				diag3 		 = upcase(cats(var13));
				diag4 		 = upcase(cats(var14));
				submit 		 = var15;

				svcdt = input(svcdate,mmddyy10.);
				if index(_proccd,'-') not in (.,0) then do;
					mod1 = cats(substr(_proccd,index(_proccd,'-') + 1,2));
				end;
			run;

			proc sort data=clms;
				by patlinkid;
			run;
			*SASDOC-------------------------------------------------------------------------
			| Create patient table                       
			|------------------------------------------------------------------------SASDOC*;
			data pat (compress = yes
					  keep = filename patlinkid ssn lname fname mname dob sex /*phone*/);
				set raw;
				where table = 'PATIENT';
				length patlinkid $10. ssn $9. lname $25. fname $15. mname $1. dob 4. sex $1.;
					   
				format dob mmddyy10.;

				patlinkid = upcase(cats(var1));
				ssn 	  = compress(put(var2*1,z9.),'.');
				lname 	  = upcase(cats(var3));
				fname 	  = upcase(cats(var4));
				mname 	  = upcase(cats(var5));
				dob 	  = input(var6,mmddyy10.);
				sex 	  = upcase(cats(var7));
			run;


			proc sort data=pat nodupkey;
				by patlinkid;
			run;
			*SASDOC-------------------------------------------------------------------------
			| Create payor table                        
			|------------------------------------------------------------------------SASDOC*;
			data ins (compress = yes
					  keep = filename patlinkid payorname1 guarantortype payor_effdt payor_termdt);
			set raw;
				where table = 'PATSUBINS';
				length patlinkid $10. guarantortype $1. payorname1 $50.;
				format payor_effdt payor_termdt mmddyy10.; 
				patlinkid     = upcase(cats(var1));
				guarantortype = upcase(cats(var2));
				payorname1 	  = upcase(cats(var3));
				payor_effdt   = input(var4,mmddyy10.) ;
				payor_termdt  = input(var5,mmddyy10.) ;
			run;

			proc sort data=ins nodupkey out=ins2 (compress=yes);
				where guarantortype = 'P'; * SELECT PRIMARY INSURANCE ONLY;
				by patlinkid guarantortype payorname1 payor_effdt payor_termdt ;
			run;

			proc summary data=ins2 nway missing;
				class patlinkid payorname1 payor_effdt payor_termdt;
				output out=payorcheck (drop=_type_);
			run;

			data ins2B ;
				set ins2;
				%let firstp = 200401;
				call symput('lastp',put(today(),yymmn6.));
			run;

			*create record for each member month;
			data ins3 (drop=effmonth termmonth i j);
				set ins2B;

				if payor_termdt = . then payor_termdt = today() + 365;

				effmonth=input(put(payor_effdt, yymmn6.), 6.);
				termmonth=input(put(payor_termdt+1, yymmn6.), 6.); *many termdts are the last day of the month;

				do i  = &firstp to &lastp;
				if i = &firstp then j=0;
				j=j+1;
				if mod(i,100)=13 then i = i+88;
				monthid = i ;

				if effmonth <= monthid < termmonth then output ins3;

				end;
			run;

			*SASDOC-------------------------------------------------------------------------
			| Merge claims and patient tables and validate npi and tin numbers                          
			|------------------------------------------------------------------------SASDOC*;
			data clms2A (compress=yes) patonly (compress=yes);
				merge clms (in=a)
					  pat  (in=b drop=filename);
				by patlinkid;
				length memberid $9. provlast $25. provfirst $15. provname $42. upin $6. tin $9.;
				monthid = input(put(svcdt, yymmn6.), 6.);
				if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = '';
				else memberid = ssn;
				provname = cats(provlast) || ", " || cats(provfirst);
				
				if a then output clms2A;
				else if b and not a then output patonly;
			run;


			*SASDOC-------------------------------------------------------------------------
			| Merge claims and payor table                         
			|------------------------------------------------------------------------SASDOC*;
			proc sort data=clms2A out=clms2B;
				by patlinkid monthid;
			run;

			proc sort data=ins3 out=ins4;
				by patlinkid monthid;
			run;

			data claims2 (drop=patlinkid);
				length source mod2 $1. ;
				format address1 address2 $50. city $20. zip $5. phone $10. state $2. provid $10.;
				merge clms2B (in=a)
					  ins4  (in=b keep= patlinkid monthid payorname1);
				by patlinkid monthid;
				source = 'P';
				
		            mod2 = '';
				/** add blank geographic information to avoid validation issues **/

				address1 = '';
				address2 = '';
		 		city = '';
				state = '';
				zip = '';
				phone = '';
				provid = npi;
				client_key=&client_id. ;
				practice_key=&practice_key. ;
				practice_id=&do_practice_id. ;
				claim_source = &dataformatgroupid.;
				
				if a then output claims2;
			run;
			
			*SASDOC-------------------------------------------------------------------------
			|  Remove duplicates and output final dataset                         
			|------------------------------------------------------------------------SASDOC*;
			proc sort data=claims2 
			          out=practice_&do_practice_id.  nodupkey;
				by &byvars0;
			run;

		%mend edw_pgf_HealthNautica;


		%macro edw_pgf_Edimis;

			%put NOTE: dlm = &dlm.;
			%put NOTE: firstobs = &firstobs.;
			%put NOTE: destdir = &destdir.;
			%put NOTE: destdir2 = &destdir2.;

			data claimraw;		
			length fil2read $100. filename $50. system $10. filed $8.;
			set pgf_files;
			fil2read="&destdir." || file_extract; 		
			infile dummy filevar=fil2read truncover dlm=&dlm. firstobs = &firstobs. lrecl=1000 dsd end=lastrec;
			do until (lastrec);
			input
				claimnum: $36.
				linenum: $36.
				upin: $upcase6.
				npi: $10.
				tin: $9.
				provlast: $upcase35.
				provfirst: $upcase25.
				practiceid: $upcase10.
				practicename: $upcase25.
				_ssn: $15.
				address1: $upcase50.
				address2: $upcase50.
				city: $upcase20.
				state: $upcase2.
				zip: $10.
				_phone: $13.
				_dob: $10.
				sex: $upcase1.
				lname: $upcase25.
				fname: $upcase15.
				mname: $upcase1.
				_svcdt: $10.
				_diag1: $upcase6.
				_diag2: $upcase6.
				_diag3: $upcase6.
				_proccd: $upcase10.
				mod1: $upcase2.
				pos: $2.
				payorid1: $upcase36.
				payorname1: $upcase50.
				submit: 10.
				units: 8.
				;

			  	filename=file_extract; 
				filed=substr(scan(filename,2,'-'),1,8);
				system = 'EDIMIS';

				provname = trim(provlast)||","||trim(provfirst);

				svcdt =  input(compress(_svcdt,'/'),yymmdd8.);
				output;
			  end;
			run;

		    *SASDOC -------------------------------------------------------------------------
		    | Clean Up Last Names (Step 1 of 2 - Scrub extraneous digits)
		    | Shorter last names retained digits from previous longer last names
		    | This step has to be right after reading the original input files, because the 
		    |  order of the original rows in each file has to remain the same.
		    |--------------------------------------------------------------------------SASDOC*;
			data claimraw(drop=gb lname rtlname rtguess_lname rtfilename rename=(guess_lname=lname));
		    set claimraw;
		    format original_lname rtlname guess_lname rtguess_lname $25. rtfilename $22.;

		    original_lname=lname;
		    if length(lname) gt 19 and substr(lname,20,1)='T' and substr(lname,21)=substr(fname,1,length(substr(lname,21))) then lname=substr(lname,1,19);

		    retain rtlname rtguess_lname rtfilename;
		    if filename ne rtfilename then do;
		          rtfilename=filename;
		          rtlname=lname; guess_lname=lname; rtguess_lname=lname;
		    end;
		    else do;
		          if lname=rtlname then guess_lname=rtguess_lname;
		          else if length(lname) gt length(rtlname) then guess_lname=lname;
		          else do gb=length(lname) to 1 by -1;
		                if substr(lname,gb,1) ne substr(rtlname,gb,1) then do;
		                      guess_lname=substr(lname,1,gb);
		                      gb=0;
		                end;
		          end;
		          rtfilename=filename;
		          rtlname=lname; rtguess_lname=guess_lname;
		    end;
			client_key = &client_id.;
			practice_id = &do_practice_id.;
			practice_key = &practice_key.;
			run;


			*SASDOC-------------------------------------------------------------------------
			|  Create data warehouse fields                                           
			|------------------------------------------------------------------------SASDOC*;
			data claims (compress=yes 
						  keep = system claimnum linenum filed filename practice_id
								 ssn memberid lname fname mname dob sex phone address1 address2 city state zip
								 provname npi upin tin svcdt diag1 diag2 diag3 proccd _proccd mod1 pos units submit payorid1 payorname1
		                                     client_key);
			set claimraw;

			length 	system $10. 
					ssn memberid $9. lname $25. fname $15. mname $1.   sex $1. phone $10. 
					npi $10. upin $6. tin $9. 
					 diag1-diag3 $6. _proccd $10. proccd $5. mod1 $2. units submit 8. pos $2. 
					payorid1 $36. payorname1 $50. dob 8. ;
				
			format dob mmddyy10. submit dollar13.2;

		/*	npi_n = npi+0;
			if npi_n in (&provider_list.); */


			ssn = compress(_ssn,"-");

			if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
			else memberid = ssn;

			proccd	 = upcase(trim(substr(_proccd,1,5)));
			phone = compress(_phone,"()-");

			dob = input(cats(substr(_dob,1,index(_dob," ") - 1)),mmddyy10.);
			*svcdt = input(cats(substr(_svcdt,1,index(_svcdt," ") - 1)),mmddyy10.);
			 
			*dob =  input(compress(_dob,'-'),yymmdd8.);

			if sex in ("F","f") then sex = "F";
			else if sex in ("M","m") then sex = "M";
			else sex = "U";

	        %macro diagcd_cleanup(m_invar,m_outvar);
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
	        %mend diagcd_cleanup;
            %diagcd_cleanup(_diag1,diag1);
            %diagcd_cleanup(_diag2,diag2);
            %diagcd_cleanup(_diag3,diag3);

			run;

		    *SASDOC -------------------------------------------------------------------------
		    | Clean Up Last Names (Step 2 of 2 - Fill in last name digits scrubbed away)
		    | Sometimes 1 or 2 digits are scrubbed because coincidentally they are at the same
		    |  positions as the previous patient, and we erroneously assumed that they were
		    |  carried over from previous patient.
		    | Try group by SSN first, then try by DOB||SEX||FNAME||CITY
		    |--------------------------------------------------------------------------SASDOC*;

		  %macro lname_correct_scrubbing(m_input_set,
                                         m_mtd_nm,
                                         m_mtd_by,
                                         m_mtd_byc,
                                         m_mtd_lastby,
                                         m_mtd_checknull,
                                         m_mtd_aeqb,
                                         m_mtd_aeqc,
                                         m_mtd_concat);
		      proc sql;
		            create table &m_mtd_nm._x_lname as
		            select      &m_mtd_byc., lname, count(*) as rowcount
		            from  &m_input_set. a
		            where &m_mtd_checknull.
		            group by &m_mtd_byc., lname;

		            create table &m_mtd_nm._mult_lname as
		            select      *, min(length(lname)) as minlname, max(length(lname)) as maxlname
		            from  &m_mtd_nm._x_lname a
		            group by &m_mtd_byc.
		            having      count(*) ne 1;
		      quit;
		      
		      proc sort data=&m_mtd_nm._mult_lname out=&m_mtd_nm._minlname;
		            where length(lname)=minlname;
		            by &m_mtd_by. rowcount lname;
		      data &m_mtd_nm._minlname(keep=&m_mtd_by. lname rename=(lname=minlname));
		            set &m_mtd_nm._minlname;
		            by &m_mtd_by. rowcount lname;
		            if last.&m_mtd_lastby.;
		      proc sort data=&m_mtd_nm._mult_lname out=&m_mtd_nm._maxlname;
		            where length(lname)=maxlname;
		            by &m_mtd_by. rowcount lname;
		      data &m_mtd_nm._maxlname(keep=&m_mtd_by. lname rename=(lname=maxlname));
		            set &m_mtd_nm._maxlname;
		            by &m_mtd_by. rowcount lname;
		            if last.&m_mtd_lastby.;
		      run;
		      
		      proc sql;
		            create table &m_mtd_nm._corrected_lname as
		            select      &m_mtd_byc., a.lname, c.maxlname as corrected_lname
		            from  &m_mtd_nm._mult_lname a, &m_mtd_nm._minlname b, &m_mtd_nm._maxlname c
		            where &m_mtd_aeqb.
		            and         &m_mtd_aeqc.
		            and         substr(a.lname,1,a.minlname)=b.minlname
		            and         a.lname ne c.maxlname;
		      
		        update &m_input_set. a
		        set     lname=( select  corrected_lname
		                        from    &m_mtd_nm._corrected_lname b
		                        where   &m_mtd_aeqb. and a.lname=b.lname)
		        where   &m_mtd_concat.||lname in (      select  &m_mtd_concat.||lname
		                                                from    &m_mtd_nm._corrected_lname);
		      quit;
		  %mend lname_correct_scrubbing;

		  %lname_correct_scrubbing(claims,
                                   ssn,
                                   memberid,
                                   %bquote(a.memberid),
                                   memberid,
                                   %bquote(memberid is not null),
                                   %bquote(a.memberid=b.memberid),
                                   %bquote(a.memberid=c.memberid),
                                   memberid);

		  %lname_correct_scrubbing(   claims,
		                                          combo,
		                                          dob sex fname city,
		                                          %bquote(a.dob,a.sex,a.fname,a.city),
		                                          city,
		                                          %bquote(dob is not null and sex is not null and fname is not null and city is not null),
		                                          %bquote(a.dob=b.dob and a.sex=b.sex and a.fname=b.fname and a.city=b.city),
		                                          %bquote(a.dob=c.dob and a.sex=c.sex and a.fname=c.fname and a.city=c.city),
		                                          put(dob,mmddyy10.)||sex||fname||city
		                                          );
		                                          
			data claims2;
			  set claims;
			run;

			data practice_&do_practice_id. ;
			 format   provid $10.;
			  set claims2;
			  length source mod2 $1. ;
			  if provname = " ," then provname = '';
			  source = 'P';
			  
		        mod2 = '';
		        provid = npi;
			run;

		     proc sort data=practice_&do_practice_id. nodupkey;
		       by &byvars0;
		     run;

		%mend edw_pgf_Edimis;
		
		%macro standard_r1_v3;

			%put NOTE: dlm = &dlm.;
			%put NOTE: destdir = &destdir.;
			%put NOTE: destdir2 = &destdir2.;

			data practice_&do_practice_id.;		
			length fil2read $100. filename $50. system $30. filed $8. phone $10. ssn memberid $9. ;
			set pgf_files ;
			fil2read="&destdir." || file_extract; 		
			infile dummy filevar=fil2read truncover dlm=&dlm. firstobs = &firstobs. lrecl=1000 missover dsd end=lastrec;
			
			mrn_count = 0;

			do until (lastrec);
				input
				provid    :$10.
				npi2	  :$10.	
				TIN       :$10.
				provname  :$42.
				_memberid  :$11.
				patient_id :$25.
				_phone     :$15.
				_dob      :$10.
				sex       :$6.
				lname  :$35.
				fname :$25.
				address1  :$40.
				address2  :$40.
				city      :$30.
				state     :$2.
				zip       :$10.
				email     :$35.
				_svcdt    :$15.
				_diag1     :$upcase6.
				_diag2     :$upcase6.
				_diag3     :$upcase6.
				_diag4     :$upcase6.
				_diag5     :$upcase6.
				_diag6     :$upcase6.
				_diag7     :$upcase6.
				_diag8     :$upcase6.
				_diag9     :$upcase6.
				proccd    :$5.
				procmod1  :$2.
				procmod2  :$2.
				pos       :$2.
				units     :$5.
				payorid   :$10.
				payormame      : $50. 
				payortype      : $25.
				natpayorid     : $6. 
				transaction_id : $40.
				void           : $40.
				claim_number   : $40.
				line_number    : $40; 
				;

				filename=file_extract; 
				system="PGF";
				provname=upcase(provname);
				npi=provid;
				practice_id = &do_practice_id.;
				client_key = &client_id.;
				mname = '';
				patient_id = left(patient_id);
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

				if patient_id ne '' then mrn_count + 1;

				%clean_dates; 

				%diag_standard_basicplus(_diag1,diag1);
				%diag_standard_basicplus(_diag2,diag2);
				%diag_standard_basicplus(_diag3,diag3); 
				%diag_standard_basicplus(_diag4,diag4); 
				%diag_standard_basicplus(_diag5,diag5); 
				%diag_standard_basicplus(_diag6,diag6); 
				%diag_standard_basicplus(_diag7,diag7); 
				%diag_standard_basicplus(_diag8,diag8); 
				%diag_standard_basicplus(_diag9,diag9); 
				

				output;
			end;

			call symput('mrn_count',cats(mrn_count));

			rename procmod1=mod1 procmod2=mod2;
			drop _:  file_extract mrn_count;
			run;

			%if &mrn_count. = . %then %let mrn_count = 0;

			%put NOTE: Record count with MRN for PGF Standard Basic Plus - &mrn_count.;
			
			%if &mrn_count ne 0 %then %do;
				proc datasets nolist;
					modify practice_&do_practice_id.;
						rename patient_id = system_member_id;
				quit;
			%end;

		%mend standard_r1_v3;
		

		%macro standard_athena;

			data practice_&do_practice_id.;		
			length fil2read $100. filename $50. system $30. filed $8. phone $10. ssn memberid $9. ;
			set pgf_files ;
			fil2read="&destdir." || file_extract; 		
			infile dummy filevar=fil2read truncover dlm=&dlm. firstobs = &firstobs. lrecl=1000 missover dsd end=lastrec;
			
			mrn_count = 0;

			do until (lastrec);
				input
				provid	:$10.
				provname	:$upcase42.
				_memberid	:$11.
				patient_id	:$25.
				_phone	:$15.
				_dob	:$10.
				sex	:$upcase1.
				lname	:$upcase35.
				fname	:$upcase25.
				address1	:$upcase40.
				address2	:$upcase40.
				city	:$upcase30.
				state	:$upcase2.
				zip	:$10.
				email	:$35.
				_svcdt	:$15.
				_diag1	:$upcase6.
				_diag2	:$upcase6.
				_diag3	:$upcase6.
				_diag4	:$upcase6.
				_diag5	:$upcase6.
				_diag6	:$upcase6.
				_diag7	:$upcase6.
				_diag8	:$upcase6.
				proccd	:$5.
				pos_desc:$upcase50.
				payorid :$10.	
				payorname :$50.		
				payortype :$25.		
				claim_number	:$40.
				;

				filename=file_extract; 
				system="PGF";
				provname=upcase(provname);
				npi=provid;
				practice_id = &do_practice_id.;
				client_key = &client_id.;
				mname = '';
				patient_id = left(patient_id);
				source = "P";
				historical=0;
				group_id = &do_practice_id.;
				ssn = compress(_memberid,' ()-');
				memberid = compress(_memberid,' ()-');
				_units=1;
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

				mod1='';
				mod2='';

				if patient_id ne '' then mrn_count + 1;

				%clean_dates; 

				%diag_standard_basicplus(_diag1,diag1);
				%diag_standard_basicplus(_diag2,diag2);
				%diag_standard_basicplus(_diag3,diag3); 
				%diag_standard_basicplus(_diag4,diag4); 
				%diag_standard_basicplus(_diag5,diag5); 
				%diag_standard_basicplus(_diag6,diag6); 
				%diag_standard_basicplus(_diag7,diag7); 
				%diag_standard_basicplus(_diag8,diag8); 
				%**diag_standard_basicplus(_diag9,diag9); 			

				output;
			end;

			call symput('mrn_count',cats(mrn_count));
			drop  file_extract mrn_count;
			run;

			/** reference - http://www.dmerc.com/manual/poscode.htm **/

			data practice_&do_practice_id.;	
			set practice_&do_practice_id.;	 
			if patient_id='patientid' then delete;	/** because of the two header columns in the file **/
			if pos_desc = "WHMC OFFICE" then POS = '11';
			if pos_desc = "OFFICE" then POS = '11';
			if pos_desc = "CORNERSTONE HOSPITAL - IP" then POS = '21';
			if pos_desc = "METHODIST HOSPITAL S - IP" then POS = '21';
			if pos_desc = "TRIUMPH HOSPITAL SW - IP" then POS = '21';
			if pos_desc = "WEST HOU MED CENTER - IP" then POS = '21';
			if pos_desc = "WEST HOU MED CENTER - OP" then POS = '22';
			if pos_desc = "GOOD SHEPHERD HOME HEALTH SERVICES" then POS = '12';
			if pos_desc = "HEARTLAND  SHARPVIEW" then POS = '32';
			if pos_desc = "BEECHNUT MANOR" then POS = '32';
			if pos_desc = "WEST OAKS REHAB" then POS = '32';
			if pos_desc = "PARK MANOR OF WC" then POS = '32';
			if pos_desc = "FIRST COLONY REHAB" then POS = '32';
			if pos_desc = "REHAB MED-CARE, LLC" then POS = '11';
			if pos_desc = "ACC HEALTH SERVICES, INC" then POS = '12';
			if pos_desc = "EMERGENCY ROOM" then POS = '23';
			if pos_desc = "INPATIENT HOSPITAL" then POS = '21';			
			if pos_desc = "OUTPATIENT HOSPITAL" then POS = '22';
			if pos_desc = "PATIENTS HOME" then POS = '12';  
			if pos_desc = "COMPREHENSIVE INPATIENT REHABILITATION FACILITY" then POS='61';
			if pos_desc = "SKILLED NURSING FACILITY" then POS='31';
			if pos = ' ' then POS='11'; 
			drop _: ;
			run;
			
			proc sort data = practice_&do_practice_id. out = pos_desc (keep=pos_desc pos) nodupkey;
			by pos_desc;
			run;
			
			data _null_;
			set pos_desc;
			put _all_;
			run;			

		%mend standard_athena;		


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
