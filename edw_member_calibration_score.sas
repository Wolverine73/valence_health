
/*HEADER------------------------------------------------------------------------
|
| program:  edw_member_calibration_score.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create mscore dataset which hosts the calibrations needed for 
|           the member linking algorithm
|
| logic:     
|
| input:    
|                         
| output:   
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2012 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

data PM_clm2;
set PM_clm;
/*%thecleaner();*/
%edw_linking_cleaner_addr();
%edw_linking_cleaner_city();
%edw_linking_cleaner_dob();
%edw_linking_cleaner_fls();
%edw_linking_cleaner_phone();
%edw_linking_cleaner_state();
%edw_linking_cleaner_zip();
lsound1 = soundex(lname);
fsound1 = soundex(fname);
RID_ = _n_;
run;

%*SASDOC----------------------------------------------------------------------
| Probabilistic Values    
| 
+----------------------------------------------------------------------SASDOC*;

%let RID = ;

proc sql noprint;
select count(*)
into :RID
from PM_clm2;
quit;

%put NOTE: RID = &RID.;

%*SASDOC----------------------------------------------------------------------
| Macro - Block    
| 
+----------------------------------------------------------------------SASDOC*;

%macro block(blockvar);

	%let where = ;
	%let missing = ;
	%if &blockvar. = dob %then %do;
		%let where = dob.EID=lname.EID and dob.EID=phone.EID;
		%let missing = .;
	%end;
	%else %do;
		%if &blockvar. = lname %then %let where = lname.EID=dob.EID and lname.EID=phone.EID;
		%else %if &blockvar. = phone %then %let where = phone.EID=lname.EID and phone.EID=dob.EID;
		%let missing = "";
	%end;

	/*** set members to 50 to allow the cartesian product to process faster ***/
	%let firstobs = 1;
	%let lastobs  = 10;

	%let doloop = %eval(%sysfunc(ceil(&RID/&lastobs)));
	%put doloop = &doloop. ;
	%put firstobs = &firstobs. ;

	%local z;

	%do z = &firstobs %to &doloop;

		proc datasets library=work nolist;
		  delete membersubset;
		quit;
	
		/** subset the members for the subset macro **/
		data membersubset;
		 set PM_clm2 (firstobs = &firstobs. obs = &lastobs.); 
		run;
		
		proc datasets library=work nolist;
		  modify membersubset;
		  index create memberid; 
		quit;

		%macro subset(satellite_list);
		
		  %let j=0;
		
		  %do %while (%scan(&satellite_list, &j+1) ne );
		
		  %let j=%eval(&j+1);
		  %let input=%scan(&satellite_list,&j);


			proc datasets library=work nolist;
			  delete sub_&input.;
			quit;
			
			%if &j. = 1 %then %do ;
			
				/** need to join by block var to get universe of members needed for the satellite tables **/
				proc sql noprint;
				create table membersubset_&blockvar. as
				select 	distinct &blockvar..eid as memberid 
				from 	membersubset x,
					    member_&&blockvar. &blockvar.
				where 	x.&blockvar.=&blockvar..&blockvar. 
				  and   x.&blockvar. ne &missing. ;
				quit;
			
			%end;
	
			/** subset satellite tables for the universe of members of the block var for the join **/
			proc sql noprint;
			create table sub_&input.  as
			select distinct a.*
			from member_&input. a
			where eid in (select distinct(memberid) from membersubset_&blockvar. );
			quit;

			proc sort data = sub_&input. ;
			by eid;
			run;

			proc datasets library=work nolist;
			  modify sub_&input.;
			  index create EID; 
			quit;

		  %end;
		
		%mend subset;

		%subset(fname lname dob address1 city state zip phone sex);


		proc sql noprint;
		create table x&z as
		select 	distinct 
			x.*,
			&blockvar..EID as memEID,
			a.address1 as memaddress1,
			a.address1_Bayes,
			b.city as memcity,
			b.city_Bayes,
			dob.DOB as memDOB,
			dob.DOB_Bayes,
			d.fname as memfname,
			d.fname_Bayes,
			lname.lname as memlname,
			lname.lname_Bayes,
			phone.phone as memphone,
			phone.phone_Bayes,
			g.state as memstate,
			g.state_Bayes,
			h.zip as memzip,
			h.zip_Bayes,
			i.sex as memsex
		from 	PM_clm2 (firstobs = &firstobs. obs = &lastobs.) x,
		    	Sub_Address1 		a,
			Sub_City 		b,
			Sub_DOB 		dob,
			Sub_fname 		d,
			Sub_lname 		lname,
			Sub_phone 		phone,
			Sub_state 		g,
			Sub_zip 		h,
			Sub_sex 		i
		where 	x.&blockvar.=&blockvar..&blockvar. 
		  and   (&blockvar..EID=a.EID and &blockvar..EID=b.EID and &blockvar..EID=d.EID and 
			 &blockvar..EID=g.EID and &blockvar..EID=h.EID and &blockvar..EID=i.EID and &where.)
		  and x.&blockvar. ne &missing. ;
		quit;

		%let firstobs = %eval(&lastobs + 1);
		%let lastobs  = %eval(&lastobs + 10);

	%end;

	data Iterate (compress=yes);
	 set %do j = 1 %to &doloop; x&j %end;;
	run; 

	proc datasets library=work nolist;
	 delete %do k = 1 %to &doloop; x&k %end; (memtype = data);
	quit;  

	proc append base=MatchMaker1 data=Iterate force; 
	run;

	proc datasets nolist library=work;
	delete Iterate;
	run;
	quit;

%mend block;
%block(dob);
%block(phone);
%block(lname);


%*SASDOC----------------------------------------------------------------------
| Compare and Score   
| 
+----------------------------------------------------------------------SASDOC*;

data MatchedWeights;
set MatchMaker1;
%edw_linking_compare;
run;

%macro scoreloop;

	%do mscore = 1 %to 40;

		data Probabilistic;
		set MatchedWeights (keep = memberid memEID matchscore ageR cells);  

		if (matchscore*10) ge &mscore. then Match_det = 1;
		else Match_det = 0;
		if memberid = memEID then Match_ssn = 1;
		else Match_ssn = 0;

		if Match_det = 1 and Match_ssn = 1 then tp = 1;
		else if Match_det = 1 and Match_ssn = 0 then fp = 1;
		else if Match_det = 0 and Match_ssn = 1 then fn = 1;
		else tn = 1;
		count = 1;
		test = &i.;
		/*test = -1;		missing DOB only*/
		level = &mscore.;

		run;

		proc summary data=Probabilistic;
		class ageR cells;				/*omit ageR for missing DOB only*/
		vars tp fp fn tn count;
		id test level;
		output out=bsb.AgeR&mscore. (drop = _type_ _freq_) sum=;
		run;

	%end;

	proc datasets nolist library=work;
	delete PM_clm2 MatchMaker1 MatchedWeights Probabilistic
			;
	run;
	quit;

%mend scoreloop;

%scoreloop;
