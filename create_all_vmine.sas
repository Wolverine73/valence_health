/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_all_vmine.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:  To combine vmine data 
|
| INPUT:    vmine practice sas datasets 
|
| OUTPUT:   combined vmine temporary sas dataset
|           combined practice data for each pm system
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 02JUN2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created Vmine macro
|
|             
+-----------------------------------------------------------------------HEADER*/


%macro create_all_vmine;
		
   *SASDOC--------------------------------------------------------------------------
   | Create Vmine Libnames for each pm system 
   +------------------------------------------------------------------------SASDOC*;
	proc sql noprint;
	  create table vtable as 
	  select *
	  from sashelp.vtable; 
	quit;

      data vmlist1(keep=libname memname system)  vmlist2(keep=libname memname rename =memname = clmname) ;
        set vtable;
		where substr(libname,1,1) = '_';
        if substr(upcase(memname),1,6) = "VMINE_" then do;
            system = scan(memname,2,'_');
            output vmlist1; 
        end;
        if substr(upcase(memname),1,7) = "CLAIMS_" then output vmlist2; 
      run;

      proc sort data = vmlist1;
            by libname memname;
      run;
      
      data vmlist1a;
        set vmlist1;
        by libname memname;
        if last.libname;
      run;

      proc sort data = vmlist2;
            by libname;
      run;

      data vmlist;
        merge vmlist1a(in=a) vmlist2(in=b);
        by libname;
        if a;
      run;

      data vmlist ;
        set vmlist;
        allds=left(trim(libname))||"."||left(trim(memname));
        setds=left(trim(libname))||"."||left(trim(clmname));
        check1=input(scan(clmname,2,"_"),8.);
        if check1 > 0;
      run;
      
      proc sort data = vmlist;
        by system;
      run;

      proc sort data = vmlist 
              out  = libname_loop (keep = libname) nodupkey;
        by libname;
      run;

      data _null_;
        set libname_loop end=eof;
        i+1;
        ii=left(put(i,4.));
        call symput('libname_loop'||ii,trim(libname));
        if eof then call symput('libname_loop_total',ii);
      run;

      %put NOTE: libname_loop_total = &libname_loop_total. ;

      %do j = 1 %to &libname_loop_total. ;

            %put NOTE: libname = &&libname_loop&j ;

            data temp01;
             set vmlist;
             where libname="&&libname_loop&j";
            run;

            data _null_;
              set temp01  end=eof;
			  allds1 = substr(allds,1,index(allds,'ALL')+2);
			  allds2 = compress(allds1||"_"||&logdate);	       
              call symput('templatevmine',trim(setds));
              call symput('allvmine',trim(allds2));
			  call symput('system',trim(system));			   
            run;

            %put NOTE: allvmine = &allvmine. ;
            %put NOTE: templatevmine = &templatevmine. ;
			%put NOTE: system = &system.;
			
			*SASDOC--------------------------------------------------------------------------
			| Combine vmine practice data for each pm system
			------------------------------------------------------------------------SASDOC*;
            data &allvmine. (compress=yes 
                              keep=system filename claimnum linenum
                              ssn memberid lname fname dob sex address1 address2 city state zip phone
                              provid upin npi tin provname
                              svcdt diag1-diag3 _proccd proccd mod1 pos units
                              submit payorname1 payorid1 system );
              set &templatevmine. (obs=0);
            run;

            data _null_ ; 
              set temp01 ;
              call execute("proc append base=&allvmine. force data="||setds||";run;");  
            run;

			*SASDOC--------------------------------------------------------------------------
		    | Update system name
		    +------------------------------------------------------------------------SASDOC*;
			
		    data &allvmine.(drop = system rename = (_system = system));
			    set &allvmine.;
				length _system $10.;
				_system = "&system.";
			run;

			 *SASDOC--------------------------------------------------------------------------
		    | Combine all vmine systems into one dataset
		    +------------------------------------------------------------------------SASDOC*;
			
			%if j = 1 %then %do;
				data vmineall (compress=yes drop = _filed);
					length  _filed filed $8. practiceID 3. ;
					set
					&allvmine. (obs =0);
					_filed = cats(cats(substr(filename,index(filename,'-')+1,8)));
					filed = cats(substr(_filed,5,2) || substr(_filed,7,2) || substr(_filed,1,4));
					practiceID = cats(substr(filename,1,index(filename,'-') - 1)) * 1;
				 
				run;
		    %end;

			Proc datasets  ;
				Append base= vmineall force
				Data= &allvmine;
			Quit;

       %end;
			
	   	    *SASDOC--------------------------------------------------------------------------
		    | Create filed and practiceID fields
		    +------------------------------------------------------------------------SASDOC*;

	  	data vmineall (compress=yes drop = _filed);
			set vmineall;
			length system $10.   _filed filed $8. practiceID 3. ;
			_filed = cats(cats(substr(filename,index(filename,'-')+1,8)));
			filed = cats(substr(_filed,5,2) || substr(_filed,7,2) || substr(_filed,1,4));
			practiceID = cats(substr(filename,1,index(filename,'-') - 1)) * 1;
		run;


		   *SASDOC--------------------------------------------------------------------------
		   | Verify npi/tin numbers
		   +------------------------------------------------------------------------SASDOC*;
		
		proc summary data=vmineall nway missing;
			class provname npi upin tin;
			id filename system;
			output out = clmprovcheck (drop=_type_ rename=_freq_=cnt);
		run;

		proc sort data = clmprovcheck;
			by system filename;
		run;

		proc print data=clmprovcheck;
			title 'Provider vMine data';
		run;

		proc sort data = prov.provider out = provider nodupkey;
			by npi;
		run;

		proc sort data = provider;
			by tin;
		run;

		proc print data = provider;
			var tin npi provname practice ;
		run;


%mend create_all_vmine;
 


