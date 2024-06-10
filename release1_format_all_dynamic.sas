/*--------------------------------------------------------------------------------------------------------------------------*/
/* 23MAR2012 - LS create per KN.  This formats the vguidelineinput claims query once for all Release 1.0 Processes.			*/
/*  		   This also includes level2 flags on the care elements 														*/
/* 29MAR2012 - LS modify & implement EM's dynamic format logic into split process 											*/
/* 01MAY2012 - LS add "distinct" to final sql datastep of chunking process in order to get rid of numerous dups				*/
/* 08MAY2012 - LS per dw KN/TB modify logic to no longer pull edw_labclme from cistage but from work library instead		*/
/* 22MAY2012 - LS per KN include POS into formatting '																		*/
/* 06JUL2012 - EM Keeping OBX_F2																							*/
/*--------------------------------------------------------------------------------------------------------------------------*/

%macro release1_format_all_dynamic;

/*--------------------------------------------------------------------------------------------------*/
/* Separate out cistage.edw_labclme into 3 parts, assign formats separpately, append back together	*/
/*--------------------------------------------------------------------------------------------------*/

%macro split(ndsn=);
	data 	%do i = 1 %to &ndsn.;
				dsn&i. 
			%end;
		;
	retain x;
	set /*cistage.*/edw_labclme
		nobs=nobs;

	if _n_ eq 1 then do;
		if mod(nobs,&ndsn.) eq 0
		then x=int(nobs/&ndsn.);
		else x=int(nobs/&ndsn.)+1;
	end;

	if _n_ le x then output dsn1;

	%do i = 2 %to &ndsn.;
		else if _n_ le (&i.*x)
		then output dsn&i.;
	%end;
	run;
%mend split;
%split (ndsn = 3);


/*************************************************************************************************************************/
/*CONDITION FORMATTING																									 */
/*Get the maximum number of conditions per indicator-code --  the number of times a code is used as a different condition*/
/*************************************************************************************************************************/
%macro format_elements (cond_indsn=, cond_outdsn=, ce_indsn = , ce_outdsn = , dsn_final =  );

	%let CPT_CD=0;
	%let DIAG_CD=0;
	%let LOINC_CD=0;
	%let REVCD_CD=0;
	%let SURG_CD=0;
	%let POS_CD = 0;

	%let CPT = 0;
	%let DIAG = 0;
	%let LOINC = 0;
	%let REVCD = 0;
	%let SURG = 0;
	%let POS = 0;

		/*clean up indicator lists*/
		data &client._conditions (rename = (code1=code indicator1=indicator));
		set control.%sysfunc(strip(&client.))_conditions;

		/* Only run prospective needed conditions if it's not guidelines day */
/*		%if &client_run_day. ne &day_run. %then %do; */
/*			where is_prospective = 1;*/
/*		%end;*/

		length code1 $10. indicator1 $10.;
			code1 = code;
			if substr(strip(indicator),1,4) = "DIAG" then do;
				indicator1 = "DIAG";
			end;
			else if substr(strip(indicator),1,3) = "CPT" or strip(indicator) = "HCPCS" then do;
				indicator1 = "CPT";
			end;
			else do;
				indicator1 = indicator;
			end;
			drop code
				 indicator;
		run;

		proc sort data = &client._conditions;
		  by indicator code;
		run;

		data Diagnosis_condition_val;
		set &client._conditions;
		  by indicator code;
		  retain count;

			if first.code then do;
				count = .;
			end;

			count + 1;
			
			length dx_condition $70.;
			dx_condition = catx("~",condition,any_dx_on,any_dx_off,any_proc_on,any_proc_off,create_elig);

		run;

		proc sort data = Diagnosis_condition_val 
				  out = maxcond (keep = indicator count);
		by indicator descending count;
		run;

		/*List of the max number of iterations of code type*/
		data maxcond1;
		set maxcond;
		by indicator descending count;
		if first.indicator;
		run;

		data _null_;
		set maxcond1 end=eof;
	      g+1; 
	      ii=left(put(g,4.));
		  ind=strip(indicator);
	      call symput('indcond'||ii,trim(left(ind)));
	 
	      if eof then call symput('totalindcond',ii);
		run;
		%put &totalindcond.;

		/*CREATE CONDITION FORMATS*/
		%do i = 1 %to &totalindcond.;
			proc sql noprint ;
		       select strip(put(count,4.))
		           into :&&indcond&i from maxcond1 
				   where indicator = "&&indcond&i";
			quit;
		%end;

		/*Rename the macros that represent the number of codes per indicator based on if they're a care element or condition*/
		%let CPT_CD = &CPT.;
		%let DIAG_CD = &DIAG.;
		%let LOINC_CD = &LOINC.;
		%let REVCD_CD = &REVCD.;
		%let SURG_CD = &SURG.;
		%let POS_CD = &POS.;

		/*Create the formats for all care elements and indicator types*/
		%if &CPT_CD. ^= 0 %then %do;
			%do k = 1 %to &CPT_CD.;
				data _valcond&k.cpt; 
				set Diagnosis_condition_val;
					if strip(indicator)="CPT" and count=&k. then output _valcond&k.cpt;
				run;
				%mk_fmt(dsn=_valcond&k.cpt,start=code,label=dx_condition,fmtname=valcond&k.cpt,type=C,library=work,Other="");
			%end;
		%end;

		%if &DIAG_CD. ^= 0 %then %do;
			%do j = 1 %to &DIAG_CD.;
				data _valcond&j.dgn;
				set Diagnosis_condition_val;
					if strip(indicator)="DIAG" and count = &j. then output _valcond&j.dgn;
				run;

				%mk_fmt(dsn=_valcond&j.dgn,start=code,label=dx_condition,fmtname=valcond&j.dgn,type=C,library=work,Other="");

			%end;
		%end;

		%if &LOINC_CD. ^= 0 %then %do;
			%do l = 1 %to &LOINC_CD.;
				data _valcond&l.loinc; 
				set Diagnosis_condition_val;
					if strip(indicator)="LOINC" and count=&l. then output _valcond&l.loinc;
				run;
				%mk_fmt(dsn=_valcond&l.loinc,start=code,label=dx_condition,fmtname=valcond&l.loinc,type=C,library=work,Other="");
			%end;
		%end;	

		%if &REVCD_CD. ^= 0 %then %do;
			%do m = 1 %to &REVCD_CD.;
				data _valcond&m.rev; 
				set Diagnosis_condition_val;
					if strip(indicator)="REVCD" and count=&m. then output _valcond&m.rev;
				run;
				%mk_fmt(dsn=_valcond&m.rev,start=code,label=dx_condition,fmtname=valcond&m.rev,type=C,library=work,Other="");
			%end;
		%end;

		%if &SURG_CD. ^= 0 %then %do;
			%do n = 1 %to &SURG_CD.;
				data _valcond&n.surg; 
				set Diagnosis_condition_val;
					if strip(indicator)="SURG" and count=&n. then output _valcond&n.surg;
				run;
				%mk_fmt(dsn=_valcond&n.surg,start=code,label=dx_condition,fmtname=valcond&n.surg,type=C,library=work,Other="");
			%end;
		%end;

		%if &POS_CD. ^= 0 %then %do;
			%do o = 1 %to &POS_CD.;
				data _valcond&o.pos; 
				set Diagnosis_condition_val;
					if strip(indicator)="POS" and count=&o. then output _valcond&o.pos;
				run;
				%mk_fmt(dsn=_valcond&o.pos,start=code,label=dx_condition,fmtname=valcond&o.pos,type=C,library=work,Other="");
			%end;
		%end;

	data _null_;
		CPT_CD_C = &CPT_CD. * 1;
		DIAG_CD_C = &DIAG_CD. * &number_diags.;
		LOINC_CD_C = &LOINC_CD. * 1;
		REVCD_CD_C = &REVCD_CD. * 1;
		SURG_CD_C = &SURG_CD. * &number_surgs.;
		POS_CD_C = &POS_CD. * 1;

		call symputx('CPT_CD_C',CPT_CD_C);
		call symputx('DIAG_CD_C',DIAG_CD_C);
		call symputx('LOINC_CD_C',LOINC_CD_C);
		call symputx('REVCD_CD_C',REVCD_CD_C);
		call symputx('SURG_CD_C',SURG_CD_C);
		call symputx('POS_CD_C',POS_CD_C);
	run;

	%put &CPT_CD_C.;
	%put &DIAG_CD_C.;
	%put &LOINC_CD_C.;
	%put &REVCD_CD_C.;
	%put &SURG_CD_C.;
	%put &POS_CD_C.;


	/*data step version of the EDW query*/
	data &cond_outdsn. (drop=_:) ;
	set &cond_indsn.
		(keep=member_key sex svcdt client_key diag1-diag&number_diags.
			%if %QUPCASE(&Lab_data.) = Y %then %do; 
				loinc 
			%end;

			proccd revcd mod1 surg1 

			%if &number_surgs. > 1 %then %do; 
				- surg&number_surgs.
			%end;
			
			admdt2 disdt2 majcat provspec encounter_key dis_cond pos provid source tin dob1 max_proc_date value_character value_numeric databand 
			units normal_range abnormal_values OBX_F2
		);

		/*keep care element & condition combination*/
		length 	position
				any_dx_on
				any_dx_off
				any_proc_on
				any_proc_off
				create_elig
				3.
				condition $30.

				/*create the number of fields that could possibly have values*/
				%if &CPT_CD. ^= 0 %then %do;
					_cond_cpt1
					%if &CPT_CD_C. > 1 %then %do;
						- _cond_cpt&CPT_CD_C.
					%end; 
				%end;
				%if &DIAG_CD. ^= 0 %then %do;
					_cond_diag1
					%if &DIAG_CD_C. > 1 %then %do;
						- _cond_diag&DIAG_CD_C. 
					%end; 
				%end;
				%if &LOINC_CD. ^= 0 %then %do;
					_cond_loinc1
					%if &LOINC_CD_C. > 1 %then %do;
						- _cond_loinc&LOINC_CD_C. 
					%end; 
				%end;
				%if &REVCD_CD. ^= 0 %then %do;
					_cond_rev1
					%if &REVCD_CD_C. > 1 %then %do;
						- _cond_rev&REVCD_CD_C. 
					%end; 
				%end;
				%if &SURG_CD. ^= 0 %then %do;
					_cond_surg1
					%if &SURG_CD_C. > 1 %then %do;
						- _cond_surg&SURG_CD_C.
					%end;
				%end;
				%if &POS_CD. ^= 0 %then %do;
					_cond_pos1
					%if &POS_CD_C. > 1 %then %do;
						- _cond_pos&POS_CD_C.
					%end;
				%end;
				$70.;

		/*create array lists*/
		array dgn{*} $ diag1-diag&number_diags.;
		
		array srg{*} $ surg1
		%if &number_surgs. > 1 %then %do;
			- surg&number_surgs.
		%end;
		;
	
		array cond{*} $		%if &CPT_CD. ^= 0 %then %do;
								_cond_cpt1
								%if &CPT_CD_C. > 1 %then %do;
									-_cond_cpt&CPT_CD_C.
								%end; 
							%end;
							%if &DIAG_CD. ^= 0 %then %do;
								_cond_diag1
								%if &DIAG_CD_C. > 1 %then %do;
									-_cond_diag&DIAG_CD_C. 
								%end; 
							%end;
							%if &LOINC_CD. ^= 0 %then %do;
								_cond_loinc1
								%if &LOINC_CD_C. > 1 %then %do;
									-_cond_loinc&LOINC_CD_C. 
								%end; 
							%end;				
							%if &REVCD_CD. ^= 0 %then %do;
								_cond_rev1
								%if &REVCD_CD_C. > 1 %then %do;
									-_cond_rev&REVCD_CD_C. 
								%end; 
							%end;
							%if &SURG_CD. ^= 0 %then %do;
								_cond_surg1
								%if &SURG_CD_C. > 1 %then %do;
									-_cond_surg&SURG_CD_C.
								%end;
							%end;
							%if &POS_CD. ^= 0 %then %do;
								_cond_pos1
								%if &POS_CD_C. > 1 %then %do;
									-_cond_pos&POS_CD_C.
								%end;
							%end;
							;

		/**apply formats to all fields in all records**/		
		/********************************************************* PROCEDURE CODES **********************************************************/
		/*   Conditions  */
			%if &CPT_CD. ^= 0 %then %do;
				%do k = 1 %to &CPT_CD.;
					%if %sysfunc(cexist(work.formats.valcond&k.cpt.formatc)) %then %do;
						_cond_cpt&k. = put(proccd,$valcond&k.cpt.);
					%end;
				%end;
			%end;

		/********************************************************* DIAGNOSIS CODES **********************************************************/
		/*   Conditions  */
			%if &DIAG_CD. ^= 0 %then %do;
				_dgcd = &CPT_CD_C.+1; /*set the position in the array -- sum of the preceding code types*/
				%do j = 1 %to &DIAG_CD.;
					%if %sysfunc(cexist(work.formats.valcond&j.dgn.formatc)) %then %do;
						do _dgcd1 = 1 to &number_diags.; /*move through the number of diagnosis codes in the data*/	

							cond{_dgcd}=compbl(put(dgn{_dgcd1}, $valcond&j.dgn.)||'~'||_dgcd1);

							if substr(left(cond{_dgcd}),1,1)='~' then cond{_dgcd} = '';

							_dgcd + 1; /*moving through the array*/
						end;
					%end;
				%end;
			%end;

		/********************************************************** LOINC CODES *************************************************************/
		/*   Conditions  */	
			%if &LOINC_CD. ^= 0 %then %do;
				%do l = 1 %to &LOINC_CD.;
					%if %sysfunc(cexist(work.formats.valcond&l.loinc.formatc)) and %QUPCASE(&Lab_data.) = Y %then %do;
						_cond_loinc&l. = put(loinc,$valcond&l.loinc.);
					%end;
				%end;
			%end;
		/********************************************************** REVENUE CODES ***********************************************************/
		/*   Conditions  */
			%if &REVCD_CD. ^= 0 %then %do;
				%do m = 1 %to &REVCD_CD.;
					%if %sysfunc(cexist(work.formats.valcond&m.rev.formatc)) %then %do;
						_cond_rev&m. = put(revcd,$valcond&m.rev.);
					%end;
				%end;
			%end;
		/********************************************************* SURGICAL CODES***********************************************************/
		/*   Conditions  */
			%if &SURG_CD. ^= 0 %then %do;
				_sgcd = &CPT_CD_C. + &DIAG_CD_C. + &LOINC_CD_C. + &REVCD_CD_C. + 1; /*set the position in the array -- sum of the preceding code types*/
				%do n = 1 %to &SURG_CD.;
					%if %sysfunc(cexist(work.formats.valcond&n.surg.formatc))  %then %do;

						do _sgcd1=1 to &number_surgs.; /*move through the number of diagnosis codes in the data*/
							cond{_sgcd}=compbl(put(srg{_sgcd1}, $valcond&n.surg.)||'~'||_sgcd1);

							if substr(left(cond{_sgcd}),1,1)='~' then cond{_sgcd} = '';

							_sgcd + 1;
						end;
					%end;
				%end;
			%end;
		/********************************************************** POS CODES ***********************************************************/
		/*   Conditions  */
			%if &POS_CD. ^= 0 %then %do;
				%do o = 1 %to &POS_CD.;
					%if %sysfunc(cexist(work.formats.valcond&o.pos.formatc)) %then %do;
						_cond_pos&o. = put(pos,$valcond&o.pos.);
					%end;
				%end;
			%end;

		/*keep care element & condition combination for diagnosis codes*/
		_condmisscnt=0;

		do _r=1 to (&CPT_CD_C. + &DIAG_CD_C. + &LOINC_CD_C. + &REVCD_CD_C. + &SURG_CD_C. + &POS_CD_C.); /*# of condition fields in array*/
			if cond{_r} ^= "" then _condmisscnt+1;
		end;

		if _condmisscnt gt 0 then do;
			do _r=1 to (&CPT_CD_C. + &DIAG_CD_C. + &LOINC_CD_C. + &REVCD_CD_C.+ &SURG_CD_C.+ &POS_CD_C.);
				if not missing(cond{_r}) then do;
				/*if a claim line has 1 or more conditions, output only multiple lines of the conditions -- do not output a line 
			  	  where one field did not return a condition*/

				/* LS remove 1 from variables below */
					condition =strip(scan(cond{_r},1,"~"));
					any_dx_on =strip(scan(cond{_r},2,"~"));
					any_dx_off =strip(scan(cond{_r},3,"~"));
					any_proc_on =strip(scan(cond{_r},4,"~"));
					any_proc_off =strip(scan(cond{_r},5,"~"));
					create_elig =strip(scan(cond{_r},6,"~"));
		
					/*assign the position of diagnosis conditions*/
					if &CPT_CD_C. < _r < (&CPT_CD_C.+&DIAG_CD_C.+1) then do;					
						position=strip(scan(cond{_r},7,"~"));
					end;
					output &cond_outdsn.; /*keeping this output line in the do loop ensures that only lines with a condition are populated are ouput*/
				end; 
			end;
		end;

		else if _condmisscnt le 0 then output &cond_outdsn.;
		/*output only 1 record (no duplicate lines) of claims with no conditions*/
	run;

	/*delete the temp datasets */
	%delfmts;


	/*******************************************************************************************************************************/
	/*CARE ELEMENT FORMATTING																									   */
	/*Get the maximum number of care elements per indicator-code --  the number of times a code is used as a different care element*/
	/*******************************************************************************************************************************/


	%let CPT = 0;
	%let DIAG = 0;
	%let LOINC = 0;
	%let REVCD = 0;
	%let SURG = 0;
	%let POS = 0;

	%let CPT_CE=0;
	%let DIAG_CE=0;
	%let LOINC_CE=0;
	%let REVCD_CE=0;
	%let SURG_CE=0;
	%let POS_CE=0;

		data &client._careelements (rename = (code1=code indicator1=indicator));
			set control.%sysfunc(strip(&client.))_careelements;

			/* If it's not a guidelines day then only run prospective needed care elements */
/*			%if &client_run_day. ne &day_run. %then %do; */
/*				where is_prospective = 1;*/
/*			%end;*/

			length code1 $10. indicator1 $10.;

				code1 = code;
				if substr(strip(indicator),1,4) = "DIAG" then do;
					indicator1 = "DIAG";
				end;
				else if substr(strip(indicator),1,3) = "CPT" or strip(indicator) = "HCPCS" then do;
					indicator1 = "CPT";
				end;
				else do;
					indicator1 = indicator;
				end;

				drop code  indicator;
		run;

		proc sort data = &client._careelements;
		  by indicator code;
		run;

		data Care_elements_val;
			set &client._careelements;
			by indicator code;
			retain count;

			if first.code then do;
				count = .;
			end;

			count + 1;
			
			length care_element $70.;
			care_element = catx("~",strip(care_granular),strip(rev_flag),strip(delete_prospective),strip(hcpcs),strip(cpt2));			
		run;

		proc sort data = Care_elements_val 
			out = maxce (keep = indicator count);
			by indicator descending count;
		run;

		/*List of the max number of iterations of code type*/
		data maxce1;
		set maxce;
		by indicator descending count;
		if first.indicator;
		run;

		data _null_;
		set maxce1 end=eof;
	      g+1; 
	      ii=left(put(g,4.));
		  ind=strip(indicator);
	      call symput('indce'||ii,trim(left(ind)));
	 
	      if eof then call symput('totalindce',ii);
		run;
		%put &totalindce.;

		/*CREATE CARE ELEMENT FORMATS*/
		%do i = 1 %to &totalindce.;
			proc sql noprint ;
		       select strip(put(count,4.))
		           into :&&indce&i from maxce1 
				   where indicator = "&&indce&i";
			quit;
		%end;

		/*Rename the macros that represent the number of codes per indicator based on if they're a care element or condition*/
		%let CPT_CE = &CPT.;
		%let DIAG_CE = &DIAG.;
		%let LOINC_CE = &LOINC.;
		%let REVCD_CE = &REVCD.;
		%let SURG_CE = &SURG.;
		%let POS_CE = &POS.;

		/*Create the formats for all care elements and indicator types*/
		%if &CPT_CE. ^= 0 %then %do;
			%do k = 1 %to &CPT_CE.;
				data _valce&k.cpt; 
				set Care_elements_val;
					if strip(indicator)="CPT" and count=&k. then output _valce&k.cpt;
				run;
				%mk_fmt(dsn=_valce&k.cpt,start=code,label=care_element,fmtname=valce&k.cpt,type=C,library=work,Other="");
			%end;
		%end;

		%if &DIAG_CE. ^= 0 %then %do;
			%do j = 1 %to &DIAG_CE.;
				data _valce&j.dgn;
				set Care_elements_val;
					if strip(indicator)="DIAG" and count = &j. then output _valce&j.dgn;
				run;

				%mk_fmt(dsn=_valce&j.dgn,start=code,label=care_element,fmtname=valce&j.dgn,type=C,library=work,Other="");

			%end;
		%end;

		%if &LOINC_CE. ^= 0 %then %do;
			%do l = 1 %to &LOINC_CE.;
				data _valce&l.loinc; 
				set Care_elements_val;
					if strip(indicator)="LOINC" and count=&l. then output _valce&l.loinc;
				run;
				%mk_fmt(dsn=_valce&l.loinc,start=code,label=care_element,fmtname=valce&l.loinc,type=C,library=work,Other="");
			%end;
		%end;

		%if &REVCD_CE. ^= 0 %then %do;
			%do m = 1 %to &REVCD_CE.;
				data _valce&m.rev; 
				set Care_elements_val;
					if strip(indicator)="REVCD" and count=&m. then output _valce&m.rev;
				run;
				%mk_fmt(dsn=_valce&m.rev,start=code,label=care_element,fmtname=valce&m.rev,type=C,library=work,Other="");
			%end;
		%end;

		%if &SURG_CE. ^= 0 %then %do;
			%do n = 1 %to &SURG_CE.;
				data _valce&n.surg; 
				set Care_elements_val;
					if strip(indicator)="SURG" and count=&n. then output _valce&n.surg;
				run;
				%mk_fmt(dsn=_valce&n.surg,start=code,label=care_element,fmtname=valce&n.surg,type=C,library=work,Other="");
			%end;
		%end;

		%if &POS_CE. ^= 0 %then %do;
			%do o = 1 %to &POS_CE.;
				data _valce&o.pos; 
				set Care_elements_val;
					if strip(indicator)="POS" and count=&o. then output _valce&o.pos;
				run;
				%mk_fmt(dsn=_valce&o.pos,start=code,label=care_element,fmtname=valce&o.pos,type=C,library=work,Other="");
			%end;
		%end;
	data _null_;
		CPT_CE_C = &CPT_CE. * 1;
		DIAG_CE_C = &DIAG_CE. * &number_diags.;
		LOINC_CE_C = &LOINC_CE. * 1;
		REVCD_CE_C = &REVCD_CE. * 1;
		SURG_CE_C = &SURG_CE. * &number_surgs.;
		POS_CE_C = &POS_CE. * 1 ;

		call symputx('CPT_CE_C',CPT_CE_C);
		call symputx('DIAG_CE_C',DIAG_CE_C);
		call symputx('LOINC_CE_C',LOINC_CE_C);
		call symputx('REVCD_CE_C',REVCD_CE_C);
		call symputx('SURG_CE_C',SURG_CE_C);
		call symputx('POS_CE_C',POS_CE_C);
	run;

	%put &CPT_CE_C.;
	%put &DIAG_CE_C.;
	%put &LOINC_CE_C.;
	%put &REVCD_CE_C.;
	%put &SURG_CE_C.;
	%put &POS_CE_C.;

	data &ce_outdsn. (drop=_:) ;
	set &ce_indsn.
		
		(keep = member_key sex svcdt client_key diag1-diag&number_diags.
			%if %QUPCASE(&Lab_data.) = Y %then %do; 
				loinc 
			%end;

			proccd revcd mod1 surg1 
			%if &number_surgs. > 1 %then %do;
				- surg&number_surgs.
			%end;
		

			admdt2 disdt2 majcat provspec encounter_key dis_cond pos provid source tin dob1 max_proc_date value_character value_numeric
			databand condition position any_dx_on any_dx_off any_proc_on any_proc_off create_elig units normal_range abnormal_values OBX_F2
		);

		/*keep care element & condition combination*/
		length 	rev_flag
				delete_prospective
				hcpcs
				cpt2
				3.
				care_element 
				$30.

				/*create the number of fields that could possibly have values*/
				%if &CPT_CE. ^= 0 %then %do;
				   	_ce_cpt1
					%if &CPT_CE_C. > 1 %then %do;
						-_ce_cpt&CPT_CE_C.  
					%end; 
				%end;
				%if &DIAG_CE. ^= 0 %then %do;
					_ce_diag1 
					%if &DIAG_CE_C. > 1 %then %do;
						-_ce_diag&DIAG_CE_C. 
					%end; 
				%end;
				%if &LOINC_CE. ^= 0 %then %do;
					_ce_loinc1 
					%if &LOINC_CE_C. > 1 %then %do;
						-_ce_loinc&LOINC_CE_C. 
					%end; 
				%end;
				%if &REVCD_CE. ^= 0 %then %do;
					_ce_rev1 
					%if &REVCD_CE_C. > 1 %then %do;
						-_ce_rev&REVCD_CE_C. 
					%end; 
				%end;
				%if &SURG_CE. ^= 0 %then %do;
					_ce_surg1 
					%if &SURG_CE_C. > 1 %then %do;
						-_ce_surg&SURG_CE_C. 
					%end;
				%end;
				%if &POS_CE. ^= 0 %then %do;
					_ce_pos1 
					%if &POS_CE_C. > 1 %then %do;
						-_ce_pos&POS_CE_C. 
					%end;
				%end;
				$70.;

		array dgn{*} $ diag1-diag&number_diags.;

		array srg{*} $ surg1
						%if &number_surgs. > 1 %then %do;
							-surg&number_surgs.
						%end;
						;

		array careele{*} $	%if &CPT_CE. ^= 0 %then %do;
							   	_ce_cpt1
								%if &CPT_CE_C. > 1 %then %do;
									-_ce_cpt&CPT_CE_C.  
								%end; 
							%end;
							%if &DIAG_CE. ^= 0 %then %do;
								_ce_diag1 
								%if &DIAG_CE_C. > 1 %then %do;
									-_ce_diag&DIAG_CE_C. 
								%end; 
							%end;
							%if &LOINC_CE. ^= 0 %then %do;
								_ce_loinc1 
								%if &LOINC_CE_C. > 1 %then %do;
									-_ce_loinc&LOINC_CE_C. 
								%end; 
							%end;
							%if &REVCD_CE. ^= 0 %then %do;
								_ce_rev1 
								%if &REVCD_CE_C. > 1 %then %do;
									-_ce_rev&REVCD_CE_C. 
								%end; 
							%end;
							%if &SURG_CE. ^= 0 %then %do;
								_ce_surg1 
								%if &SURG_CE_C. > 1 %then %do;
									-_ce_surg&SURG_CE_C. 
								%end;
							%end;
							%if &POS_CE. ^= 0 %then %do;
								_ce_pos1 
								%if &POS_CE_C. > 1 %then %do;
									-_ce_pos&POS_CE_C. 
								%end;
							%end;
							;

		/**apply formats to all fields in all records**/
		/********************************************************* PROCEDURE CODES **********************************************************/
		/*      Care Elements      */		
			%if &CPT_CE. ^= 0 %then %do;
				%do k = 1 %to &CPT_CE.;
					%if %sysfunc(cexist(work.formats.valce&k.cpt.formatc)) %then %do;
						_ce_cpt&k. = put(proccd,$valce&k.cpt.);
					%end;
				%end;
			%end;

		/********************************************************* DIAGNOSIS CODES **********************************************************/
		/*      Care Elements      */
			%if &DIAG_CE. ^= 0 %then %do;
				_dgce = &CPT_CE_C.+1; /*set the position in the array -- sum of the preceding code types*/
				%do j = 1 %to &DIAG_CE.;
					%if %sysfunc(cexist(work.formats.valce&j.dgn.formatc)) %then %do;
						do _dgce1=1 to &number_diags.; /*move through the number of diagnosis codes in the data*/	

							careele{_dgce}=compbl(put(dgn{_dgce1}, $valce&j.dgn.)||'~'||_dgce1);


							if substr(left(careele{_dgce}),1,1)='~' then careele{_dgce} = '';

							_dgce + 1; /*moving through the array*/
						end;
					%end;
				%end;
			%end;

		/********************************************************** LOINC CODES *************************************************************/
		/*      Care Elements      */ 
			%if &LOINC_CE. ^= 0 %then %do;
				%do l = 1 %to &LOINC_CE.;
					%if %sysfunc(cexist(work.formats.valce&l.loinc.formatc)) and %QUPCASE(&Lab_data.) = Y %then %do;
						_ce_loinc&l. = put(loinc,$valce&l.loinc.);
					%end;
				%end;
			%end;

		/********************************************************** REVENUE CODES ***********************************************************/
		/*      Care Elements      */ 
			%if &REVCD_CE. ^= 0 %then %do;
				%do m = 1 %to &REVCD_CE.;
					%if %sysfunc(cexist(work.formats.valce&m.rev.formatc)) %then %do;
						_ce_rev&m. = put(revcd,$valce&m.rev.);
					%end;
				%end;
			%end;

		/********************************************************* SURGICAL CODES ***********************************************************/
		/*      Care Elements      */ 
			%if &SURG_CE. ^= 0 %then %do;
				_sgce = &CPT_CE_C. + &DIAG_CE_C. + &LOINC_CE_C. + &REVCD_CE_C. + 1; /*set the position in the array -- sum of the preceding code types*/
				%do n = 1 %to &SURG_CE.;
					%if %sysfunc(cexist(work.formats.valce&n.surg.formatc)) %then %do;

						do _sgce1=1 to &number_surgs.; /*move through the number of diagnosis codes in the data*/
							careele{_sgce}=compbl(put(srg{_sgce1}, $valce&n.surg.)||'~'||_sgce1);

							if substr(left(careele{_sgce}),1,1)='~' then careele{_sgce} = '';

							_sgce + 1;
						end;
					%end;
				%end;
			%end;
		/********************************************************** POS CODES ***********************************************************/
		/*      Care Elements      */ 
			%if &POS_CE. ^= 0 %then %do;
				%do o = 1 %to &POS_CE.;
					%if %sysfunc(cexist(work.formats.valce&o.pos.formatc)) %then %do;
						_ce_pos&o. = put(pos,$valce&o.pos.);
					%end;
				%end;
			%end;
		/*keep care element & condition combination for diagnosis codes*/
		_cemisscnt=0;

		do _q=1 to (&CPT_CE_C.+&DIAG_CE_C.+&LOINC_CE_C.+&REVCD_CE_C.+&SURG_CE_C. +&POS_CE_C.); /*# of care elements fields in array*/
			if careele{_q} ^= "" then _cemisscnt+1;
		end;

		if _cemisscnt gt 0 then do;
			do _q=1 to (&CPT_CE_C.+&DIAG_CE_C.+&LOINC_CE_C.+&REVCD_CE_C.+&SURG_CE_C. +&POS_CE_C.);
				if not missing(careele{_q}) then do;

				/*if a claim line has 1 or more care elements, output only multiple lines of the conditions -- do not output a line 
			  	  where one field did not return a condition*/
					care_element = strip(scan(careele{_q},1,"~"));
					rev_flag = strip(scan(careele{_q},2,"~"));
					delete_prospective = strip(scan(careele{_q},3,"~"));
					hcpcs = strip(scan(careele{_q},4,"~"));
					cpt2 = strip(scan(careele{_q},5,"~"));
					output &ce_outdsn.;					
				end; 
			end;			
		end;

		else output &ce_outdsn.;
	run;

	/*delete the temp datasets */
	%delfmts;

	proc sql;
	create table &dsn_final. as select distinct * from &ce_outdsn.
	where not 
		(value_character = ''
		and value_numeric = .
		and condition = '' 	
		and care_element = '')
	order by member_key , svcdt;
	quit;

%mend format_elements;
%format_elements(cond_indsn= dsn1, cond_outdsn = cond1, ce_indsn =cond1 , ce_outdsn = ce_out1 , dsn_final = edw_g0  );
%format_elements(cond_indsn= dsn2, cond_outdsn = cond2, ce_indsn =cond2 , ce_outdsn = ce_out2 , dsn_final = edw_g02  );
%format_elements(cond_indsn= dsn3, cond_outdsn = cond3, ce_indsn =cond3 , ce_outdsn = ce_out3 , dsn_final = edw_g03  );

/*---------------------------------------------------------*/
/* Append datasets back together - they are already sorted */
/*---------------------------------------------------------*/

proc append
	base = edw_g0
	data = edw_g02;
run;
proc append
	base = edw_g0
	data = edw_g03;
run;

data cistage.edw_g0;
set edw_g0;
run;


/* Clean up the datasets */
proc datasets library=work;
	delete dsn1 dsn2 dsn3 cond1 cond2 cond3 edw_g02 edw_g03;
run;
quit;


%mend release1_format_all_dynamic;
