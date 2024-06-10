/*HEADER------------------------------------------------------------------------
|
| program:  Most_seen_last_v2_1.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Most Seen Last Attribution logic for guidelines                     
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
| 07192011 - Erin Murphy  - Clinical Integration  1.0.01
|            1. Added PFK-specific attribution logic for guidelines run
|			    client macro resolves to 'Caresource' 'Molina' 'Unison'
| 25OCT2011 - Erin Murphy  - Included reporting format for attribution for Exempla
| 14NOV2011 - Erin Murphy  - Converted char memberid to numeric memberid for PFK payors
| 16JAN2012 - EM Exempla calls the v3 most_seen_last macro - converting to EDW
| 06FEB2012 - EM in badgroups2, memberid_c was being called but was never created, substituted with put(memberid,16.)
+-----------------------------------------------------------------------HEADER*/
%macro most_seen_last_v2_1;
	%if %upcase(&client)=CARESOURCE or %upcase(&client)=MOLINA or %upcase(&client)=UNISON %then %do;

		proc datasets library=work;
		delete Elig_: eligprovgroup
			   bad_:
			   group_:
		;
		run;
		quit;
		/*-------------------------------------------------------*
		*--------------------------------------------------------*
		******** Group Eligibility - Most visited Group **********
		*--------------------------------------------------------*
		*--------------------------------------------------------*/
		/*provgroup = provid_id|groupid|avar1|avar2|avar3|PFK_provid|PFK_provspec);*/

		Data eligprovgroup (keep= memberid svcdt provgroup groupid provid &var.);
		set g1 (rename = (provid=provgroup));		
		length groupid $12. provid $12.;

			provid = scan(provgroup,1,"|");
/*			provid = scan(provgroup,6,"|");*/
			groupid = scan(provgroup,2,"|");

/*			if groupid not in ('9999999999','999999999999','NG99999999',''); /*** Valid Group Y/N - Map to Eligible Group ***/*/;
			if &var. ge 1; *LS 3.4.2011 changed to ge instead of =.  Can change back;
		run;

		proc summary data = eligprovgroup nway missing;
		class memberid groupid svcdt;
		var &var.;
		output out = elig_group1a (drop = _:) sum=;
		run;

		proc sort data = elig_group1a out = elig_group1 nodupkey;
		by memberid descending &var. groupid descending svcdt;
		run;

/*		members latest service date with provider-group*/
		data latest_grpdt;	
		  LENGTH FMTNAME $12. TYPE $1 start $29. label $40.;
		  set elig_group1;
		    KEEP START LABEL TYPE FMTNAME ;
		    RETAIN FMTNAME "latest_grpdt"  TYPE "C";
			by memberid descending &var. groupid descending svcdt;
				if first.&var.;
				length  memberid_c $16.;
				memberid_c = put(memberid,16.);

				memgroup = strip(strip(memberid_c) || "|" || strip(groupid));
				memgroupdt = strip(strip(memberid_c) || "|" || strip(groupid) || "|" || strip(put(svcdt,mmddyy10.)));
				    start = memgroup;
					label = memgroupdt;
				output;
		  		if _n_ = 1 then do;
				   start = "other";
				   label = "";
			   	   output;
		  		end;
		run;
		proc sort data=latest_grpdt nodupkey;
		by start;
		run;
		proc format cntlin=latest_grpdt;
		run;

		data elig_group2;
		set elig_group1;
/*			&var. = 1;*/
		run;

		proc summary data = elig_group2 nway missing;
		class memberid groupid;
		var &var.;
		output out = elig_group3 (drop = _:) sum=;
		run;

		proc sort data = elig_group3;
		by memberid &var. groupid;
		run;

		data elig_group4;
		set elig_group3;
		by memberid &var. groupid;
		if last.memberid;
		run;

			/*** Identify members attributed to groups '999999999999','NG99999999' -- regroup to valid groups, or dummy out ***/
			data bad_groups1 (keep = memberid);
			set elig_group4;
			where groupid in ('999999999999','NG99999999');
			run;

				data regroup;
				  LENGTH FMTNAME $7. TYPE $1 start $16. label $1.;
				  set bad_groups1;
				    KEEP START LABEL TYPE FMTNAME ;
				    RETAIN FMTNAME "regroup"  TYPE "C";
						length  memberid_c $16.;
						memberid_c = put(memberid,16.);
					    start = memberid_c;
						label = "Y";
						output;
				  		if _n_ = 1 then do;
						   start = "other";
						   label = "N";
					   	   output;
				  		end;
				run;
				proc sort data=regroup nodupkey;
				by start;
				run;
				proc format cntlin=regroup;
				run;

				data bad_groups2;
				set elig_group3;
				where put(put(memberid,16.),$regroup.) = "Y";
					format svcdt mmddyy10.;
/*					memgroup = strip(strip(memberid_c) || "|" || strip(groupid));*/
					memgroup = strip(strip(put(memberid,16.)) || "|" || strip(groupid));
					svcdt = input(scan(put(memgroup,$latest_grpdt.),3,"|"),mmddyy10.);

					drop memgroup;
				run;

				proc sort data = bad_groups2 out = bad_groups3;
				where groupid not in ('999999999999','NG99999999');
				by memberid descending &var. descending svcdt;
				run;

			/***************************************************************************************************************
			 ******* Members 1) attributed to dummy groupids, and 2) REMAPPED to VALID groupids (most, latest seen) ********
			 ***************************************************************************************************************/
			data bad_groups4 (drop = &var. svcdt);
			set bad_groups3;
			  by memberid descending &var. descending svcdt;
			  if first.memberid;
			run;

			/************************************************************
			 ******** All members mapped only to DUMMY groupids *********
			 ************************************************************/
			data bad_groups5;
			merge bad_groups2 (in = a drop = &var. svcdt)	/*original list of bad groupids*/
				  bad_groups4 (in = b);	/*mapped to valid groupids*/
				by memberid;
				if a and not b;	/*all members with '999999999999','NG99999999' groupids*/
			run;

			proc sort data = bad_groups5 nodupkey;
			by memberid groupid;
			run;



				/*** Identify members attributed to more than one group ***/
				data elig_group3a;
				set elig_group3;
				where put(put(memberid,16.),$regroup.) = "N";
				run;

				proc summary data = elig_group3a nway missing;
				class memberid &var.;
				output out = elig_ties1 (drop = _type_);
				run;

				data elig_ties2 (drop = &var.);
				set elig_ties1;
				where _freq_ > 1;
				var = &var.;	/*Identify members seen MOST by two or more groups*/
				run;

				data group_tiebreaker1 (keep = memberid);
				merge elig_ties2 (in = a)
					  elig_group4 (in = b where = (put(put(memberid,16.),$regroup.) = "N"));
					by memberid;
					if var = &var.;	/*If var = &var. then the member has been seen most by two or more providers, need to determine latest seen of these*/
				run;

				%let obs = 0;
				data _null_;
				set elig_group4;
				n=_n_;
				call symput('obs',n);
				run;
				%put &obs.;

				%if &obs = 0 %then %do;
				data latest_groupid;	/*members seen most by 2 or more groups, need to run through tiebreaker*/
				  LENGTH FMTNAME $14. TYPE $1 start $16. label $1.;
				  	FMTNAME = "latest_groupid";
					TYPE ="C";
					start = "other";
					label = "N";
				run;
				%end;

				%else %do;
				data latest_groupid;	/*members seen most by 2 or more groups, need to run through tiebreaker*/
				  LENGTH FMTNAME $14. TYPE $1 start $16. label $1.;
				  set group_tiebreaker1;
				    KEEP START LABEL TYPE FMTNAME ;
				    RETAIN FMTNAME "latest_groupid"  TYPE "C";
					length  memberid_c $16.;
					memberid_c = put(memberid,16.);
				    start = memberid_c;
					label = "Y";
					output;
			  		if _n_ = 1 then do;
					   start = "other";
					   label = "N";
				   	   output;
			  		end;
				run;
				%end;

				proc sort data=latest_groupid nodupkey;
				by start;
				run;
				proc format cntlin=latest_groupid;
				run;

				proc sort data = elig_group2 out = group_tiebreaker2 (drop = provgroup &var.);
				where put(put(memberid,16.),$regroup.) = "N";
				by memberid groupid descending svcdt;
				run;

				data group_tiebreaker3;	/*take the latest service date of the member-groups*/
				set group_tiebreaker2;
				by memberid groupid descending svcdt;
				  if first.groupid;
				run;

				proc sort data = elig_group3 out = group_tiebreaker3a;	/*take the number of visits of the member-groups*/
				where put(put(memberid,16.),$regroup.) = "N";
				by memberid groupid;
				run;

				data group_tiebreaker3b;
				merge group_tiebreaker3 (in = a)
					  group_tiebreaker3a (in = b);
					by memberid groupid;
				run;

				data group_tiebreaker4;	/*members seen most by two or more providers, merged to latest service dates and number of encounters*/
				merge group_tiebreaker1  (in = a)
					  group_tiebreaker3b (in = b);
					by memberid;
					if a;
				run;

				proc sort data = group_tiebreaker4;
				by memberid descending svcdt groupid;
				run;

			/********************************************************************************************************
			 ******** Members 1) seen most by two or more providers, and 2) Mapped to Latest Valid Provider *********
			 ********************************************************************************************************/
			data group_tiebreaker5 (keep = memberid groupid);	/*all members with 1 most seen, *latest* attributable group*/
			set group_tiebreaker4;
			by memberid descending svcdt groupid;
			  if first.memberid;
			run;

			/*******************************************************
			 *** All members with 1 most seen attributable group ***
			 *******************************************************/
			data elig_group5 (drop = &var.);
			set elig_group4;
			where put(put(memberid,16.),$latest_groupid.) = "N" and put(put(memberid,16.),$regroup.) = "N";
			run;

		/*** Most Seen Latest Group ***/
		data elig_group6;
		set elig_group5
			group_tiebreaker5
			bad_groups4
			bad_groups5;
		run;

		proc sort data = elig_group6;
		by memberid groupid;
		run;

		/*-----------------------------------------------------------------------------------*
		*------------------------------------------------------------------------------------*
		******** Provider Eligibility - Most visited Physician within Attributed Group *******
		*------------------------------------------------------------------------------------*
		*------------------------------------------------------------------------------------*/
		/*provgroup = provid_id|groupid|avar1|avar2|avar3|PFK_provid|PFK_provspec);*/

		proc summary data=eligprovgroup nway missing;
		class memberid provgroup svcdt;
		var &var.;
		output out = elig_prov1 (drop=_type_ _freq_) sum=;
		run;

		Data elig_prov2 (drop = dt);
		set elig_prov1;
		length provid1 $81.;
/*		  &var. = 1;*/
		  dt = put(svcdt,yymmdd10.);
		  provid1 = strip(strip(substr(provgroup,1,10)) || "|" || strip(dt) || "|" || strip(substr(provgroup,12)));
		run;

			proc sort data = elig_prov2;	/*use service date in this dataset later on as tiebreaker*/
			by memberid descending &var. provgroup descending svcdt provid1;
			run;

			data latest_dt;	/*members latest service date with provider-group*/
			  LENGTH FMTNAME $9. TYPE $1 start $85. label $87.;
			  set elig_prov2;
			    KEEP START LABEL TYPE FMTNAME ;
			    RETAIN FMTNAME "latest_dt"  TYPE "C";
				by memberid descending &var. provgroup descending svcdt provid1;
					if first.&var.;
					length  memberid_c $16.;
					memberid_c = put(memberid,16.);
					memprovgroup = strip(strip(memberid_c) || "|" || strip(provgroup));
					    start = memprovgroup;
						label = provid1;
					output;
			  		if _n_ = 1 then do;
					   start = "other";
					   label = "";
				   	   output;
			  		end;
			run;
			proc sort data=latest_dt nodupkey;
			by start;
			run;
			proc format cntlin=latest_dt;
			run;

		proc summary data=elig_prov2 nway missing;
		class memberid provgroup;
		var &var. ;
		output out = elig_prov3 (drop=_type_ _freq_) sum=;
		run;

		data elig_prov4;
		set elig_prov3;
		length groupid $12. /* provspec $2.*/;
			groupid = scan(provgroup,2,"|");
/*			provspec = scan(provgroup,7,"|");*/
/*			if provspec in ('21','62','32') then rank = 1;*/
/*			else rank = 0;*/
		run;

		/*Merge by groupid provid*/
		proc sort data=elig_group6;
		by memberid groupid;
		run;
		proc sort data=elig_prov4;
		by memberid groupid;
		run;

		Data elig_provgroup1;
		merge elig_group6 (in=a) 
			  elig_prov4 (in=b);
		by memberid groupid;
		if a;
/*		pcp1=pcpid;*/
/*		*if a or b;*/
/*		*if pcpid = pcp2 then match = 1;*/
/*		*else match = 2;*/
		run;

		proc sort data = elig_provgroup1 out = elig_provgroup2;
		by memberid groupid descending &var. provgroup;
		run;

		data elig_provgroup3 (drop = memprovgroup dt);
		set elig_provgroup2;
		length memprovgroup $81.;
		format svcdt mmddyy10.;
			memprovgroup = strip(strip(put(memberid,16.)) || "|" || strip(provgroup));
			if put(memprovgroup,$Latest_dt.) ne "" then dt = scan(put(memprovgroup,$Latest_dt.),2,"|");
			svcdt = input(dt,yymmdd10.);
		run;

		proc sort data = elig_provgroup3;
		by memberid descending &var. descending svcdt provgroup;
		run;

			/********************************************************************
			 *** Members with 1 most seen, latest attributable valid provider ***
			 ********************************************************************/
			data elig_provgroup4 
				 prov_tiebreaker1 (keep = memberid);
			set elig_provgroup3;
			by memberid descending &var. descending svcdt provgroup;
				 if first.memberid and scan(provgroup,1,"|") ^= "9999999999" then output elig_provgroup4;
			else if first.memberid and scan(provgroup,1,"|") = "9999999999" then output prov_tiebreaker1;
			run;

				data dummy_first;	/*members with most seen, latest attributable physician is a dummy id*/
				  LENGTH FMTNAME $11. TYPE $1 start $16. label $1.;
				  set prov_tiebreaker1;
				    KEEP START LABEL TYPE FMTNAME ;
				    RETAIN FMTNAME "dummy_first"  TYPE "C";
						length  memberid_c $16.;
						memberid_c = put(memberid,16.);
					    start = memberid_c;
						label = "Y";
						output;
			  		if _n_ = 1 then do;
					   start = "other";
					   label = "N";
				   	   output;
			  		end;
				run;
				proc sort data=dummy_first nodupkey;
				by start;
				run;
				proc format cntlin=dummy_first;
				run;

				data prov_tiebreaker2;	/*grab only valid providers associated to members*/
				set elig_provgroup3;
				  if put(put(memberid,16.),$dummy_first.) = "Y";
				  if scan(provgroup,1,"|") = "9999999999" then delete;
				run;

				proc sort data = prov_tiebreaker2 out = prov_tiebreaker3;
				by memberid descending &var. descending svcdt;
				run;

			/*******************************************************************************************************
			 *** Members 1) mapped to dummyid, and 2) remapped to valid most seen, lastest attributable provider ***
			 *******************************************************************************************************/
			data prov_tiebreaker4;
			set prov_tiebreaker3;
			  by memberid descending &var. descending svcdt;
			  if first.memberid;
			run;

				data dummy_mems1 (keep = memberid);
				set elig_provgroup4
					prov_tiebreaker4;
				run;

				proc sort data = dummy_mems1 nodupkey;
				by memberid;
				run;

				data prov_tiebreaker5;	/*all members NOT attributed to valid providerIDs, will move through guidelines with dummy provid and be attributed*/
										/*to PCP in eligibility table*/
										/*the members are already attributed to the correct group (merged to elig_group6)*/
				merge dummy_mems1 (in = a)
					  elig_provgroup3 (in = b);
					by memberid;
					if b and not a;
				run;

				proc sort data = prov_tiebreaker5;
				by memberid descending &var. descending svcdt;
				run;

			/*********************************
			 *** Members mapped to dummyid ***
			 *********************************/
			data prov_tiebreaker6;
			set prov_tiebreaker5;
			by memberid descending &var. descending svcdt;
			if first.memberid;
			run;


		/*** Most Seen Latest Provider-Group ***/
		data elig_provgroup5;
		set elig_provgroup4		/*most seen, latest valid attributable provider*/
			prov_tiebreaker4	/*most seen, latest valid attributable provider, '9999999999' is most seen provider*/
			prov_tiebreaker6	/*most seen, latest attributable provider is '9999999999'*/
			;
		rename provgroup = pcpid;
		run;

		proc sort data = elig_provgroup5 out = elig5;
		by memberid;
		run;
	%end;

	%else %if %qupcase(&client)=EXEMPLA %then %do;
		%most_seen_last_S;
	%end;

	%else %do;
		Data elig_dt1 (keep= memberid provid svcdt);
		set g1;

		/*if provspec not in (&rank1. &rank2. &rank3.) then delete*/
		if put(provid,$provyn.) = "Y" and source = "P";
		if &var. ge 1; /*LS 3.4.2011 changed to ge instead of =*/
		%if "&client."="NSAP" or "&client."="nsap"  %then %do;
			if put(provid, $provtype.) in ("P", "V");
		%end;
		%if "&client."="St Lukes" or "&client."="StLukes"  %then %do;
			if put(provid, $RptCode.) in ("NotManual");
		%end;
		%if %QUPCASE("&client.")="EXEMPLA" %then %do;
			if put(provid,$RptCode.) in ("P","V");
		%end;
		run;

		proc sort data = elig_dt1 out=elig_dt2 nodupkey;
		by memberid provid svcdt ;
		run;

		data elig_dt3;
		set elig_dt2;
		by memberid provid svcdt ;
		if last.provid and last.svcdt;
		rename provid = pcpid;
		run;

		proc summary data=g1 nway missing;
		class memberid svcdt provid;

		where &var. ge 1 and put(provid,$provyn.) = "Y" and source = "P" and provspec in (&rank1. &rank2. &rank3.)
			%if "&client."="NSAP" or "&client."="nsap"  %then %do;
				and put(provid, $provtype.) in ("P", "V");
			%end;
			%if "&client."="St Lukes" or "&client."="StLukes"  %then %do;
				and put(provid, $RptCode.) in ("NotManual");
			%end;
			%if %QUPCASE("&client.")="EXEMPLA" %then %do;
				and put(provid,$RptCode.) in ("P","V");
			%end;		
			;

		var &var. ;
		output out = elig1 (drop=_type_ _freq_) sum=;
		run;


		/*15JUL2011 - LS incorporate if/else logic to not reset the &var macro variable when the &attrib_weight macro variable is greater than 1
		 to take into account attribution upweighting (of certain visits coded with preventative E/M codes).
		 Otherwise keep as original and reset the &var to equal 1 - summing on distinct days a member has with a provider.*/
		%if &attrib_weight > 1 %then %do;
			Data elig2;
			set elig1;
			rename provid = pcpid;
			run;
		%end;
		%if &attrib_weight = 1 %then %do;
			Data elig2;
			set elig1;
			&var. = 1;
			rename provid = pcpid;
			run;
		%end;

		proc summary data=elig2 nway missing;
		class memberid pcpid;
		var &var. ;
		output out = elig3 (drop=_type_ _freq_) sum=;
		run;

		proc sort data=Elig_dt3;
		by memberid pcpid;
		run;

		proc sort data=elig3;
		by memberid pcpid;
		run;

		Data elig4a;
		merge elig3 (in=a) Elig_dt3 (in=b);
		by memberid pcpid;
		if a;
		pcp1=pcpid;
		run;

				/*************
				**************
				CHANGE PROVIDER SPECIALTY HEIRARCHY BY CLIENT
				*************
				*************/
		Data elig4;
		set elig4a;
		provspec = put(pcpid,$provspec.);
		if provspec not in (&rank1. &rank2. &rank3.) then delete;
		if provspec in (&rank1.) then rank=1;
		else if provspec in (&rank2.) then rank=2;
		else if provspec in (&rank3.) then rank=3;
		run;

		%provider_comments;

		proc sort data=elig4;
		by memberid rank descending &var. descending svcdt;
		run;

		Data elig5;
		set elig4;
		by memberid rank descending &var. descending svcdt; 
		if first.memberid;
		run;
	%end;
%mend most_seen_last_v2_1;
