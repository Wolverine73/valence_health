
/*HEADER------------------------------------------------------------------------
|
| program:  edw_pgf_edmis.sas
|
| location: M:\ci\programs\standardmacros
|
| purpose:  load pgf data for edw process - edimis          
|
| input:    text files  
|
| output:   claims2 and cistage datasets
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 20JAN2011 - Robyn Stellman  - Clinical Integration  1.0.01
|             Initiated
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
+-----------------------------------------------------------------------HEADER*/

%macro edw_pgf_edimis;
	
%put NOTE: GROUP ID = &vlink_id.;
%put NOTE: PRACTICE ID = &practice_id.;
%put NOTE: filename = &filename.;

%global DirectoryPath;

	*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	--------------------------------------------------------------------------SASDOC*;

%if "&filename." = "" %then %do ;

	data _null_;
		call symput('edimis_dir',"dir \\fs\&client_name.\Data\CI\PGF\Auto\&practice_id.\*.* /b");
		call symput('edimis_fil2',"\\fs\&client_name.\Data\CI\PGF\Auto\&practice_id.\");
		call symput('DirectoryPath',"\\fs\&client_name.\Data\CI\PGF\Auto\&practice_id.\");
	run;

%end;
%else %do;

	data _null_;
		call symput('edimis_dir',"dir %trim(&pmdir.)\*.* /b");
		call symput('edimis_fil2',"%trim(&pmdir.)\");
		call symput('DirectoryPath',"%trim(&pmdir.)\");
	run;

%end;

	%put NOTE: edimis_dir = &edimis_dir.;
	%put NOTE: edimis_fil2 = &edimis_fil2.;
	%put NOTE: directorypath = &directorypath.;


	%set_error_flag;
	%on_error(ACTION=ABORT);
	
	*SASDOC-------------------------------------------------------------------------
	| Read in text files                          
	|------------------------------------------------------------------------SASDOC*;
	filename indata pipe "&edimis_dir";

	data claimraw(compress=yes drop=File_Extract);
	  length fil2read $100. filename $22. filed $8. filedt svcdt 8. ;
	  format filedt svcdt mmddyy10.;
	  infile indata truncover ;
	  input File_Extract $100.;
	  fil2read="&edimis_fil2" || File_Extract;

	  %if "&filename." ne ""  %then %do;
        if fil2read = "&edimis_fil2"||"&filename.";
	  %end; 

	  infile dummy filevar=fil2read truncover delimiter='|' dsd lrecl=1000 end=lastrec firstobs = 2;
	  do until (lastrec);
	    Input

		claimnum: $36.
		linenum: $36.
		upin: $6.
		npi: $10.
		tin: $9.
		provlast: $35.
		provfirst: $25.
		practiceid: $10.
		practicename: $25.
		_ssn: $15.
		address1: $50.
		address2: $50.
		city: $20.
		state: $2.
		zip: $10.
		_phone: $13.
		_dob: $10.
		sex: $1.
		lname: $25.
		fname: $15.
		mname: $1.
		_svcdt: $10.
		_diag1: $6.
		_diag2: $6.
		_diag3: $6.
		_proccd: $10.
		mod1: $2.
		pos: $2.
		payorid1: $36.
		payorname1: $50.
		submit: 10.
		units: 8.
		;

	  	filed =scan(file_extract,2,'_');
	  	filedt = input(filed,mmddyy10.);
	  	filename = file_extract;

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
      practice_key = &vlink_id.;
      run;
/*
  data ci_start_date;
	  format start_date mmddyy10.  ;
	  set ciedw.client (where = (client_key=&client_id. ));
		  start_date=datepart(ci_start_date);	  
		  keep start_date;
	run;

  data claimraw;
	  if _n_ = 1 then set ci_start_date ;
         set claimraw;
			  client_key = &client_id;
			  practice_id = &do_practice_id.;
			  practice_key=&vlink_id.;
			  if svcdt >= start_date ;
			  %edw_npi_cleansing_rules;
    run;
*/	

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


		system = 'EDIMIS';

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
                                                m_mtd_concat,
                                                );
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

  %lname_correct_scrubbing(   claims,
                                          ssn,
                                          memberid,
                                          %bquote(a.memberid),
                                          memberid,
                                          %bquote(memberid is not null),
                                          %bquote(a.memberid=b.memberid),
                                          %bquote(a.memberid=c.memberid),
                                          memberid
                                          );

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

%mend edw_pgf_edimis;


