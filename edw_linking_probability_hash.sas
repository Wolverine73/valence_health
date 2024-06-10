/*HEADER------------------------------------------------------------------------
|
| program:  edw_linking_probability_hash.sas
|
| location: M:\ci\programs\EDW
|
| purpose:  EDW Linking Algorithm and Member DQ Checks
|
| logic:    
|
| input:  	member related data from practice, hosptial, and lab sources    
|			required variables: 
|				ssn fname mname lname sex dob address1 address2 city state zip phone
|				source historical group_id practice_id patient_key dq_member_flag claim_key svcdt 
|			optional variables: 
|				enterprise_member_id system_member_id source_system_id
|                        
| output:  	updated incoming SAS datasets 
|
| notes:    The difference with the "join" version is that for Tertiary, we start off with matching
|			non-null last name AND non-null sex. Otherwise, last name will create way too many
|			permutation and it blows up when the number of patients to be linked are big
|
+--------------------------------------------------------------------------------
| history:  
|
| XXDEC2011 - G Liu - Clinical Integration (CIO)
|       	  Original
| 04APR2012 - G Liu - Clinical Integration 1.1.01
|			  For source=P, create new member keys as long as name, sex, dob are valid, and 
|				either address or phone is valid, for source='P'
| 27APR2012 - G Liu - Clinical Integration 1.2.01
|			  For source=P, create new member keys as long as we have a system_person_id,
|				and do not create the same member key with different system_person_id.
| 29JUN2012 - G Liu - Clinical Integration 1.4.01 
|			  Logic to create new member key is taken out of this macro and placed in edw_linking.sas
|				to allow conditional run of this macro but still create new member key if needed.
|			  Pure CA payer data will never need to run through probability linking, hence there
|				will never be $mscore. Without $mscore, this macro will bomb, but we still need to
|				create new member keys based on system_person_id.
+-----------------------------------------------------------------------HEADER*/

%macro edw_linking_probability_hash;
	%macro fieldcount(input);

		%let dsn_id=%sysfunc(open(sasPL_&input.));
		%let alias_sum=%sysfunc(attrn(&dsn_id.,nobs));
		%let dsn_rc=%sysfunc(close(&dsn_id.));

		%put NOTE: alias_sum = &alias_sum.;

		%if &alias_sum. ge 1 %then %do;

			proc sql noprint;
			  create table &input._edw as
			  select 	distinct a.patient_key format 16., &input., sum(a.counter) as counter										
			  from 		sasPL_&input. a
			  group by patient_key, &input.																				
			  order by patient_key, &input. ;

			  create table member_&input. as
			  select	patient_key, &input., counter/sum(counter) format 10.8 as &input._Bayes
			  from		&input._edw
			  group by 	&input.
			  order by 	patient_key, &input.;

			  create table distinct_&input. as
			  select	distinct &input. as &input.
			  from		member_&input.
			  where		&input. is not null;
	  		quit;

			proc datasets library=work nolist; 
			  delete &input._edw; 
			quit;

		%end; 

	%mend fieldcount;

	%fieldcount(FName);
	%fieldcount(LName);
	%fieldcount(DOB);
	%fieldcount(Address1);
	%fieldcount(City);
	%fieldcount(State);
	%fieldcount(Zip);
	%fieldcount(Phone);
	%fieldcount(Sex);

	/* If there are more than 5 fnames and DOBs in a single member key, that member key must have multiple patients 
		in it. Don't use this member key for linking purposes, because it can create massive cartesian products. Then
		we end up splitting them back out in member fix anyway, so, it's a waste of resources to use them as linking
		candidates. Exclude them. */
	%let el_badmk_multpat=0;
	proc sql noprint;
		create table el_badmk_fname as
		select	patient_key, count(*) as fname_badcnt
		from	member_fname
		group by 1
		having	fname_badcnt ge 4;
		create table el_badmk_dob as
		select	patient_key, count(*) as dob_badcnt
		from	member_dob
		group by 1
		having	dob_badcnt ge 4;
		select	a.patient_key
		into	:el_badmk_multpat separated by ','
		from	el_badmk_fname a, el_badmk_dob b
		where	a.patient_key=b.patient_key;
	quit;

	*SASDOC--------------------------------------------------------------------------
	| Member field blocking for comparison to existing member satellite combinations
	|  1.  create index on member input datasets
	|  2.  loop through each set of 10 RIDs
	|  3.  append to final dataset
	+------------------------------------------------------------------------SASDOC*;  
	%macro el_sat_value_hash(m_var);
		if _n_=0 then set member_&m_var.(keep=patient_key &m_var. &m_var._bayes rename=(&m_var.=mem&m_var.));
		declare hash hbeg_&m_var.(dataset:"member_&m_var.( where=(mem&m_var. is not null and put(put(patient_key,z16.),$elphmk.)='1') keep=patient_key &m_var. &m_var._bayes rename=(&m_var.=mem&m_var.))", multidata:'y');
		hbeg_&m_var..defineKey("mem&m_var.");
		hbeg_&m_var..defineData("mem&m_var.",'patient_key',"&m_var._bayes");
		hbeg_&m_var..defineDone();
		call missing(mem&m_var., patient_key, &m_var._bayes);
	%mend el_sat_value_hash;
	%macro el_sat_mklookup_hash(m_var);
		if _n_=0 then set member_&m_var.(keep=patient_key &m_var. &m_var._bayes rename=(&m_var.=mem&m_var.));
		declare hash hsat_&m_var.(dataset:"member_&m_var.(where=(put(put(patient_key,z16.),$elphmk.)='1') keep=patient_key &m_var. &m_var._bayes rename=(&m_var.=mem&m_var.))", multidata:'y');
		hsat_&m_var..defineKey('patient_key');
		hsat_&m_var..defineData("mem&m_var.","&m_var._bayes");
		hsat_&m_var..defineDone();
		call missing(mem&m_var., patient_key, &m_var._bayes);
	%mend el_sat_mklookup_hash;
	%macro el_null_sat_prob(m_var);
		call missing(mem&m_var., patient_key, &m_var._bayes);
	%mend;
	%macro el_loop_sat(m_macro);
		%&m_macro.(fname);
		%&m_macro.(lname);
		%&m_macro.(sex);
		%&m_macro.(dob);
		%&m_macro.(address1);
		%&m_macro.(city);
		%&m_macro.(state);
		%&m_macro.(zip);
		%&m_macro.(phone);
	%mend el_loop_sat;
	%macro el_satdistinct_value_hash(m_var);
		if _n_=0 then do;
			set distinct_&m_var.;
		end;
		declare hash hdis_&m_var.(dataset:"distinct_&m_var.");
		hdis_&m_var..defineKey("&m_var.");
		hdis_&m_var..defineData("&m_var.");
		hdis_&m_var..defineDone();
		call missing(&m_var.);
	%mend el_satdistinct_value_hash;
	%macro el_satdistinct_modprob_hash(m_var);
		if hdis_&m_var..find()=0 then mod_&m_var._Bayes=&m_var._Bayes; 
	  %if &m_var.=dob %then %do;
		else if &m_var.=. then mod_&m_var._Bayes=0; 
	  %end;
	  %else %do;
		else if &m_var.='' then mod_&m_var._Bayes=0; 
	  %end;
		else mod_&m_var._Bayes=1;
	%mend el_satdistinct_modprob_hash;
	%macro el_sat_findmatch(m9_blocking,m9_begvar,m9_matchvars);
		%do l=1 %to %length(%str(&m9_matchvars.));
			%let m9_matchvar&l.=%scan(&m9_matchvars.,&l.);
			%if &&m9_matchvar&l= %then %do; 
				%let m9_matchvarnum=%eval(&l.-1);
				%let l=%eval(%length(%str(&m9_matchvars.))+1); 
			%end;
		%end;
		rc_&m9_blocking._&m9_begvar.=hbeg_&m9_begvar..find(key:&m9_begvar.);
		if rc_&m9_blocking._&m9_begvar.=0 then do while (rc_&m9_blocking._&m9_begvar.=0);		
		  %do s=1 %to &m9_matchvarnum.;
			rc_&m9_blocking._&&m9_matchvar&s..=hsat_&&m9_matchvar&s...find();
			if rc_&m9_blocking._&&m9_matchvar&s..=0 %if &m9_blocking.=TERTIARY and %upcase(&&m9_matchvar&s..)=SEX %then %do; and sex=memsex %end;
			then do while (rc_&m9_blocking._&&m9_matchvar&s..=0);
		  %end;

				%el_loop_sat(el_satdistinct_modprob_hash);
				%edw_linking_compare;
				linking_permutation_cnt+1; /* for tracking */
				cells_distinct=0;
				if fname ne '' and memfname ne '' then cells_distinct=cells_distinct+1; else mod_fname_Bayes=0;
				if lname ne '' and memlname ne '' then cells_distinct=cells_distinct+1; else mod_lname_Bayes=0;
				if dob ne . and memdob ne . then cells_distinct=cells_distinct+1; else mod_dob_Bayes=0;
				if address1 ne '' and memaddress1 ne '' then cells_distinct=cells_distinct+1; else mod_address1_Bayes=0;
				if state ne '' and memstate ne '' then cells_distinct=cells_distinct+1; else mod_state_Bayes=0;
				if phone ne '' and memphone ne '' then cells_distinct=cells_distinct+1; else mod_phone_Bayes=0;
				if city ne '' and memcity ne '' or zip ne '' and memzip ne '' then cells_distinct=cells_distinct+1;
					else do;
						if city='' or memcity='' then mod_city_Bayes=0;
						if zip='' or memzip='' then mod_zip_Bayes=0;
					end;

				MaxScore = sum(mod_fname_Bayes,mod_lname_Bayes,mod_dob_Bayes,mod_address1_Bayes,max(mod_city_Bayes,mod_zip_Bayes),mod_state_Bayes,mod_phone_Bayes);

				if matchscore ge (put(put(put(cats(cells),$1.)||put(cats(ageR),$4.),$5.),$mscore.)*1) and
					not ( weight2 lt 0 and weight6 lt 0 and abs(dob-memdob) gt 30 ) and
				  %if &m9_blocking.=PRIMARY %then %do;
					matchscore gt sum(weight4,weight6,weight7)
					then do;
						pl_rank=600;
						output cistaget.OverThreshold_&wflow_exec_id.;
					end;
				  %end;
				  %else %if &m9_blocking.=SECONDARY %then %do;
					matchscore gt sum(weight4,weight5,weight7)
					then do;
						pl_rank=620;
						output cistaget.OverThreshold_&wflow_exec_id.;
					end;
				  %end;
				  %else %if &m9_blocking.=TERTIARY %then %do;
					matchscore gt sum(weight1,weight4,weight7)
					then do;
						pl_rank=640;
						output cistaget.OverThreshold_&wflow_exec_id.;
					end;
				  %end;
				else if put(put(put(cats(cells),$1.)||put(cats(ageR),$4.),$5.),$mscore.) = put(put(cats(cells),$1.)||put(cats(ageR),$4.),$5.) and
					matchscore ge 3 
				then do;
					pl_rank=700;
					output cistaget.OverThreshold_&wflow_exec_id.;
				end;
				else if lname ne "" and fname ne "" and dob ne . and sex in ("M","F") then do;
				  %if %upcase(&source.)=P %then %do; /* only create new MK for P */
					if maxscore ge input(put(put(put(cats(cells_distinct),$1.)||put(cats(ageR),$4.),$5.),$mscore.),8.) 
					then do;
						pl_rank=800;
						output cistaget.UnderThreshold_NewMK_&wflow_exec_id.;
					end;
					else if put(put(put(cats(cells_distinct),$1.)||put(cats(ageR),$4.),$5.),$mscore.) = put(put(cats(cells_distinct),$1.)||put(cats(ageR),$4.),$5.) and 
						maxscore ge 3 
					then do;
						pl_rank=850;
						output cistaget.UnderThreshold_NewMK_&wflow_exec_id.;
					end;
				  %end;
					/*else if address1 ne '' and city ne '' and zip ne '' or phone ne '' then output UnderThreshold_NL_&wflow_exec_id.;*/
					/*else output UnderThreshold_NL_&wflow_exec_id.;*/
				end;
				/*else output UnderThreshold_NL_&wflow_exec_id.;*/

		  %do s= &m9_matchvarnum. %to 1 %by -1;
				rc_&m9_blocking._&&m9_matchvar&s..=hsat_&&m9_matchvar&s...find_next();
			end;
		  %end;
			rc_&m9_blocking._&m9_begvar.=hbeg_&m9_begvar..find_next(key:&m9_begvar.);
		end;
		else if lname ne "" and fname ne "" and dob ne . and sex in ("M","F") then do;
			if fname ne '' then cells_distinct=cells_distinct+1;
			if lname ne '' then cells_distinct=cells_distinct+1;
			if dob ne . then cells_distinct=cells_distinct+1;
			if address1 ne '' then cells_distinct=cells_distinct+1;
			if city ne '' or zip ne '' then cells_distinct=cells_distinct+1;
			if state ne '' then cells_distinct=cells_distinct+1;
			if phone ne '' then cells_distinct=cells_distinct+1;

		  %if %upcase(&source.)=P %then %do; /* only create new MK for P */
			if maxscore ge input(put(put(put(cats(cells_distinct),$1.)||put(cats(ageR),$4.),$5.),$mscore.),8.) 
			then do;
				pl_rank=825;
				output cistaget.UnderThreshold_NewMK_&wflow_exec_id.;
			end;
			else if put(put(put(cats(cells_distinct),$1.)||put(cats(ageR),$4.),$5.),$mscore.) = put(put(cats(cells_distinct),$1.)||put(cats(ageR),$4.),$5.) and 
				maxscore ge 3 
			then do;
				pl_rank=875;
				output cistaget.UnderThreshold_NewMK_&wflow_exec_id.;
			end;
		  %end;
			/*else if address1 ne '' and city ne '' and zip ne '' or phone ne '' then output UnderThreshold_NL_&wflow_exec_id.;*/
			/*else output UnderThreshold_NL_&wflow_exec_id.;*/
		end;
		drop rc_:;
	%mend el_sat_findmatch;

	*SASDOC--------------------------------------------------------------------------
	| Client-specific match scoring
	+------------------------------------------------------------------------SASDOC*;  
	%macro elph_execute_subset(m_rid_beg,m_rid_end);
		options bufsize=128k compress=no bufno=1k;
		data elph_want_dob(keep=dob hlo label fmtname1 rename=(fmtname1=fmtname dob=start))
			 elph_want_phone(keep=phone hlo label fmtname2 rename=(fmtname2=fmtname phone=start))
			 elph_want_lname(keep=lname hlo label fmtname3 rename=(fmtname3=fmtname lname=start));
			set pm_roster4(keep=rid_ dob phone lname) end=lstobs;
			where &m_rid_beg. le rid_ le &m_rid_end.;
			fmtname1='elphdob'; fmtname2='$elphph'; fmtname3='$elphln';
			label='Y'; hlo=' ';
			if dob ne . then output elph_want_dob;
			if phone ne '' then output elph_want_phone;
			if lname ne '' then output elph_want_lname;
			if lstobs then do;
				dob=.; phone='?'; lname='?'; label='N'; output;
			end;
		run;

		%macro elph_find_want_mk(m_var,m_fmt);
			proc sort data=elph_want_&m_var. nodup; by fmtname hlo start label;
			proc format cntlin=elph_want_&m_var.;
			run;

			data v_elph_want_&m_var._data / view=v_elph_want_&m_var._data;
				set member_&m_var.(keep=&m_var. patient_key);
			  %if %upcase(&m_var.)=DOB %then %do;
				if put(&m_var.,&m_fmt..)='Y';
			  %end;
			  %else %do;
				where put(&m_var.,&m_fmt..)='Y';
			  %end;
				keep patient_key;
			run;
		%mend;
		%elph_find_want_mk(dob,elphdob);
		%elph_find_want_mk(phone,$elphph);
		%elph_find_want_mk(lname,$elphln);

		data v_elph_want_mk / view=v_elph_want_mk;
			set v_elph_want_dob_data v_elph_want_phone_data v_elph_want_lname_data;
			where patient_key not in (&el_badmk_multpat.);
			format start label $16.;
			fmtname='$elphmk'; start=put(patient_key,z16.); label='1';
			keep fmtname start label;
		run;

		proc sort data=v_elph_want_mk out=elph_want_mk nodup; by fmtname start label; run;
		proc format cntlin=elph_want_mk; run;

		options bufsize=128k compress=yes bufno=1k;
		data cistaget.OverThreshold_&wflow_exec_id.(keep=rid matchscore patient_key pl_rank)
			 cistaget.UnderThreshold_NewMK_&wflow_exec_id.(keep=RID &el_syspersid_var. fname lname sex dob pl_rank)
			 UnderThreshold_NL_&wflow_exec_id.;
			%el_sat_value_hash(dob);
			%el_sat_value_hash(phone);
			%el_sat_value_hash(lname);
			%el_loop_sat(el_sat_mklookup_hash);
			%el_loop_sat(el_satdistinct_value_hash);
			do while (not lstobs);
				format loop_datetimeRID block_datetime1-block_datetime3 datetime. block_time loop_time 8. linking_permutation_cnt comma10.;
				%el_loop_sat(el_null_sat_prob);
				set pm_roster4(where=(&m_rid_beg. le rid_ le &m_rid_end.)) end=lstobs;

				linking_permutation_cnt=0;
				%el_sat_findmatch(PRIMARY, dob, fname lname sex address1 city state zip phone);
					block_datetime1=datetime();
					block_time=block_datetime1-block_datetime3;
					if block_time gt 10 then put rid_= "PRIMARY   " dob= linking_permutation_cnt= block_time= "seconds";

				linking_permutation_cnt=0;
				%el_sat_findmatch(SECONDARY, phone, fname lname sex dob address1 city state zip);
					block_datetime2=datetime();
					block_time=block_datetime2-block_datetime1;
					if block_time gt 10 then put rid_= "SECONDARY " phone= linking_permutation_cnt= block_time= "seconds";

				linking_permutation_cnt=0;
				%el_sat_findmatch(TERTIARY, lname, sex fname dob address1 city state zip phone);
					block_datetime3=datetime();
					block_time=block_datetime3-block_datetime2;
					if block_time gt 10 then put rid_= "TERTIARY  " lname= sex= linking_permutation_cnt= block_time= "seconds";

					loop_time=datetime()-loop_datetimeRID;
					loop_datetimeRID=datetime();
					if loop_time gt 10 then do; 
						put rid_= "PST LOOP  " fname= lname= sex= dob= phone= loop_time= "seconds";
						put ' ';
					end;
			end;
			drop loop_datetimeRID loop_time block_datetime: block_time linking_permutation_cnt;
			stop;
		run;

		proc append base=OverThreshold data=cistaget.OverThreshold_&wflow_exec_id. force;
		proc append base=UnderThreshold_NewMK data=cistaget.UnderThreshold_NewMK_&wflow_exec_id. force;
		run;

		proc datasets lib=cistaget nolist;
			delete OverThreshold_&wflow_exec_id. UnderThreshold_NewMK_&wflow_exec_id.;
		quit;
	%mend elph_execute_subset;

	%macro elph_loop_subset;
		%if %sysfunc(exist(OverThreshold)) %then %do;
			proc sql; drop table OverThreshold; quit;
		%end;
		%if %sysfunc(exist(UnderThreshold_NewMK)) %then %do;
			proc sql; drop table UnderThreshold_NewMK; quit;
		%end;

		%let elph_num_of_rids=500;
		%let elph_num_of_loops=%eval(%sysfunc(min(15,%sysfunc(ceil(&linknum./&elph_num_of_rids.)))));
		%let elph_num_of_rids=%eval(%sysfunc(ceil(&max_ridnum./&elph_num_of_loops.)));

		%do elph=1 %to &elph_num_of_loops;
			%if &elph.=1 %then %do;
				options mprint nosymbolgen nomlogic;
			%end;
			%else %do;
				options nomprint nosymbolgen nomlogic;
			%end;
			%let beg=%eval((&elph.-1)*&elph_num_of_rids.+1);
			%let end=%eval(&elph.*&elph_num_of_rids.);
			%if &elph.=&elph_num_of_loops. %then %let end=&max_ridnum.;
			%put Performing subset # &elph. of &elph_num_of_loops. with RIDs &beg. to &end.;
			%elph_execute_subset(&beg.,&end.);
		%end;
	%mend elph_loop_subset;

	options bufsize=128k compress=yes bufno=1k nosymbolgen;
	%elph_loop_subset;
	options bufsize=32k bufno=1 mprint symbolgen;

	proc sort data=OverThreshold; by rid matchscore patient_key;
	data MatchMaker3(keep=RID patient_key pl_rank) MM3fmt(keep=fmtname RID label rename=(RID=start));
	  set OverThreshold;
	  by RID matchscore;
	  fmtname='$mm3fmt';
	  label='Y';
	  if last.RID;
	run;

	*SASDOC--------------------------------------------------------------------------
	| Attach linked patient_key to original records 
	+------------------------------------------------------------------------SASDOC*;  
	%hash_crosswalk(m_inset=PM_clm2,m_outset=MatchMaker4,m_lookupset=MatchMaker3,m_keyvar=RID,m_datavar=VID,m_keepvar=claim_key);

	proc append base=all_mk_update data=MatchMaker4 force; run;
%mend edw_linking_probability_hash;
