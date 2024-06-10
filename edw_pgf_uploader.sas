
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  edw_pgf_uploader.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load Lab data - 100001 NSUHS Soft Lab           
|
| INPUT:    NSUHS Soft Lab tab delimited files
|
| OUTPUT:   claims_&group dataset
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

%macro edw_pgf_uploader;

	%let dataformatgroupdesc = PGFUPLOADER;

	%if &deliverytypeid ne 2 %then %do; /** 6 - vmine file repository **/
	  %edw_pgf_manual;
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
		run;	
	  %end;
	  %else %do;
		data _null_; 
		call symput('uploader_dir',"M:\&client.\sasdata\CIETL\claims\PGF\uploader");
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

	data list (keep=libname memname); 
	  set sashelp.vtable;
	  if (upcase(libname) in ("UPLOADER") and substr(upcase(memname),1,2) = "PM") ;  
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
	%if &maxprocessid ne 0 and &maxprocessid ne 1 %then %do;  
	
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
		
	%end;

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
		mod1     = mod1;
		mod2     = procmod2;
		payorid1='';
		payorname1='';
		system="VGF"; 
		practice_id=&do_practice_id;
		client_key=&client_id.;
		provname = provname;
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
		
		run;

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
		%send_email_alert;
/*
		%bpm_additional_validations(validation_rule=59,validation_count=0);
*/
		%let err_fl=1;
		%set_error_flag;
		%on_error(ACTION=ABORT);
		
	%end;
	
	%end; /** end - pgf uploader **/

%mend edw_pgf_uploader;


