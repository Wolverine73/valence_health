
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  pgf_edmis.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Load PGF data - Edimis          
|
| INPUT:    Edimis text files
|
| OUTPUT:   claims_&group dataset
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 19MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created Edimis macro 
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro pgf_edimis(group= );
	
	*SASDOC--------------------------------------------------------------------------
	| Create libnames based on client value and assigned formats
	--------------------------------------------------------------------------SASDOC*;
	data _null_;
		call symput('edimis_dir',"dir \\fs\&clientname.\Data\CI\PGF\Edimis\*.* /b");
		call symput('edimis_fil2',"\\fs\&clientname.\Data\CI\PGF\Edimis\");
	run;
	
	
	*SASDOC-------------------------------------------------------------------------
	| Read in text files                          
	|------------------------------------------------------------------------SASDOC*;
	filename indata pipe "&edimis_dir";

	data claimraw(compress=yes drop=File_Extract);
	  length fil2read $100. filename $22. filed $8. filedt 8. ;
	  format filedt mmddyy10.;
	  infile indata truncover ;
	  input File_Extract $100.;
	  fil2read="&edimis_fil2" || File_Extract;
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
	  	output;
	  end;
	run;
	
*SASDOC **************************************************************************
* Clean Up Last Names (Step 1 of 2 - Scrub extraneous digits)
* Shorter last names retained digits from previous longer last names
* This step has to be right after reading the original input files, because the 
*  order of the original rows in each file has to remain the same.
***************************************************************************SASDOC*;
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
	  run;



	*SASDOC-------------------------------------------------------------------------
	|  Create data warehouse fields                                           
	|------------------------------------------------------------------------SASDOC*;

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

	data claims (compress=yes 
				  keep = system claimnum linenum filed filename
						 ssn memberid lname fname mname dob sex phone address1 address2 city state zip
						 provname npi upin tin svcdt diag1 diag2 diag3 proccd _proccd mod1 pos units submit payorid1 payorname1);
		set claimraw;

		length 	system $10. 
				ssn memberid $9. lname $25. fname $15. mname $1.   sex $1. phone $10. 
				provname $42. npi $10. upin $6. tin $9. 
				 diag1-diag3 $6. _proccd $10. proccd $5. mod1 $2. units submit 8. pos $2. 
				payorid1 $36. payorname1 $50. dob svcdt 8. ;
			
		format dob svcdt mmddyy10. submit dollar13.2;
		ssn = compress(_ssn,"-");

		if ssn in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid = "";
		else memberid = ssn;

		proccd	 = upcase(trim(substr(_proccd,1,5)));
		phone = compress(_phone,"()-");

		provname = trim(provlast)||","||trim(provfirst);
		dob = input(cats(substr(_dob,1,index(_dob," ") - 1)),mmddyy10.);
		*svcdt = input(cats(substr(_svcdt,1,index(_svcdt," ") - 1)),mmddyy10.);
		 
		*dob =  input(compress(_dob,'-'),yymmdd8.);
		svcdt =  input(compress(_svcdt,'/'),yymmdd8.);

		if sex in ("F","f") then sex = "F";
		else if sex in ("M","m") then sex = "M";
		else sex = "U";

		    %diagcd_cleanup(_diag1,diag1);
            %diagcd_cleanup(_diag2,diag2);
            %diagcd_cleanup(_diag3,diag3);


		system = 'EDIMIS';

	run;

*SASDOC **************************************************************************
*  Clean Up Last Names (Step 2 of 2 - Fill in last name digits scrubbed away)
*  Sometimes 1 or 2 digits are scrubbed because coincidentally they are at the same
*  positions as the previous patient, and we erroneously assumed that they were
*  carried over from previous patient.
*  Try group by SSN first, then try by DOB||SEX||FNAME||CITY
***************************************************************************SASDOC*;

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


	*SASDOC-------------------------------------------------------------------------
	| Validation of npi and tin numbers                          
	|------------------------------------------------------------------------SASDOC*;

	proc sort data=prov.provider nodupkey out=prov (keep=upin tin npi provname practice);
	  *where prvtermdt > today();
	  by npi tin;
	run;

	proc print data=prov;
	run;

	proc summary data=claims nway missing;
	  class provname upin npi tin ;
	  output out = clmprovcheck (drop=_type_ rename=_freq_=cnt);
    run;

	proc print data=clmprovcheck;
	run;
	
	data claims2 (compress=yes);
	  set claims;
	  length provspec $2. provid $10.;
	  if provname = "," then provname = '';

	  if tin ne '363191013' then tin = '363191013';
	  if provname in ('EDWARDS,ELENA') then do;
	    if npi ne '1568524098' then npi = '1568524098'; 
	  end;
	  if npi = '1033180351' then do;
		  provname = 'LINCHEVSKAYA,M.D.ALEXANDRA';
	  end;
	  if npi = '1326019407' then do;
	   provname = 'Lansky, M.D.Olga';
	   provname = 'LANSKY, M.D.OLGA';
	  end;
	  if provname in ('GOLDMAN,JAROSLAV') then do;
		if npi ne '1639140403' then npi = '1639140403';
	  end;
	  if provname in ('POOLE,JERRY') then do;
	 	if npi ne '1710952999' then npi = '1710952999';
	  end;
		 
	  provspec = put(npi,$provspec.);
	  provid = npi;
	run;

	proc summary data=claims2 nway missing;
	  class  provname provspec tin npi upin ;
	  output out=provcheck (drop=_type_ rename=_freq_=cnt compress=yes);
	run;

	proc print data=provcheck;
	  title 'Check Provider Formats';
	run;

	
	*SASDOC-------------------------------------------------------------------------
	|  Remove duplicates and output final dataset                         
	|------------------------------------------------------------------------SASDOC*;

	proc sort data=claims2;
	  by memberid svcdt lname fname dob proccd mod1;
	run;

	data edimis.claims_&group (compress=yes) 
		 dups (compress=yes);
	  set claims2;
	  by memberid svcdt lname fname dob proccd mod1;
	  if first.mod1 and last.mod1 then dupcount=.;
	  else if first.mod1 then dupcount =0 ;
	  else dupcount = 1;

	  if first.mod1 then output  edimis.claims_&group.;
	  if dupcount ne . then output dups;
	run;


 	*SASDOC--------------------------------------------------------------------------
	| Call SAS Macros - Create Data Quality Report                           
	|------------------------------------------------------------------------SASDOC*;
	%dq_report(client=&vmine_client_id., pgf_practice= edimis.claims_&group.);

%mend pgf_edimis;
