
/*HEADER------------------------------------------------------------------------
|
| program:  outlier_comments.sas
|
| location: \\sas2\CI\programs\StandardMacros
|
| purpose:  Create a list of updates from the guideline programs/comments for the outlier report
+----------------------------------------------------------------------------------------------------------------------------------------------------
| *HISTORY:  
| 01JUN2012 - EM creates a dates table if one does not exist
| HISTORY*
/*+-----------------------------------------------------------------------------------------------------------------------------------------HEADER*/

%macro outlier_comments(client=,folder=);
 
	%macro existduh;
	/*Create the dates table if it doesn't exist*/
		%if %sysfunc(exist(&folder..dates)) = 0 %then %do;
			data &folder..dates;
			length guideline_key $15. guideline $30. daterun prior_date_run 8.;
			format daterun prior_date_run mmddyy10.;
			guideline_key = "XXX.X.X.X.X";
			guideline = "";
			daterun = '01jan2000'd;
			prior_date_run = '31dec1999'd;
			run;
		%end;
	%mend;
	%existduh;

	proc sql noprint;
	  select count(*) into: comment_cnt
	  from &folder..dates
	  where guideline_key="&guideline_key.";
	quit;
	
	%put NOTE: comment_cnt = &comment_cnt. ;
	
	%if &comment_cnt. = 0 %then %do;
		proc sort data = &folder..dates (where=(prior_date_run ne .)) out = temp nodupkey;
		  by prior_date_run;
		run;

		data temp;
		 set temp (obs=1);
		 guideline_key="&guideline_key.";
		run;
		
		data &folder..dates;
		 set &folder..dates temp;
		run;
	%end;

	/* Latest Date Run */
	data _null_;
	set &folder..dates;
	where guideline_key="&guideline_key.";
	call symput('last_date',daterun);
	run;
	%put &last_date.;

	%if 
		%UPCASE(&client.)=ADVENTIST or
		(%UPCASE(&client.)=EXEMPLA and &legacy. = Y) or
		%UPCASE(&client.)=NSAP or
		%UPCASE(&client.)=OHG or
/*		%UPCASE(&client.)=PHS or*/
		%UPCASE(&client.)=STLUKES or
		%UPCASE(&client.)=HOLYREDEEMER %then %do;
		filename DATAFILE "&include.";
	%end;
	%else %do;
		filename DATAFILE &include.;
	%end;

	data comments1_&prefix.;
	retain COMMENT_TYPE .
	       COMMENT_TYPE_1_NB COMMENT_TYPE_2_NB LINE_NB 0;
	infile DATAFILE end=EOF_DATAFILE truncover;
	input;
	RX_HEADER_SASDOC=rxparse("'*HISTORY'|'HISTORY*'");
		if (rxmatch(RX_HEADER_SASDOC,upcase(_INFILE_)) ne 0) then do;
			RX_HEADER_ST=rxparse("'*HISTORY'");
			RX_HEADER_EN=rxparse("'HISTORY*'");
			if (rxmatch(RX_HEADER_ST,upcase(_INFILE_)) ne 0) then do;
		      COMMENT_TYPE=1;
		      LINE_NB=0;
		      COMMENT_TYPE_1_NB=COMMENT_TYPE_1_NB+1;
			end;
			else if (rxmatch(RX_HEADER_EN,upcase(_INFILE_)) ne 0) then do;
					COMMENT_TYPE=2;
		            LINE_NB=0;
		            COMMENT_TYPE_2_NB=COMMENT_TYPE_2_NB+1;
			end;
		end;
		if (COMMENT_TYPE ne .) and (rxmatch(RX_HEADER_SASDOC,upcase(_INFILE_)) eq 0) then do;
		   COMMENT=_INFILE_;
		   LINE_NB=LINE_NB+1;
	/*	   if (COMMENT_TYPE eq 1) then COMMENT_TYPE_NB=COMMENT_TYPE_1_NB;*/
	/*	   else if (COMMENT_TYPE eq 2) then COMMENT_TYPE_NB=COMMENT_TYPE_2_NB;*/

		   if COMMENT_TYPE = 1;
		   output comments1_&prefix.;
		end;
	run;

	data comments2_&prefix.;
	set comments1_&prefix. (keep = comment);
	format date mmddyy10.;
	retain date;

	if _n_ = 1 then date = .;

	if substr(compress(scan(comment,1,"|")," |"),1,1) in ("0","1","2","3") then do;
		if input(substr(compress(scan(comment,1,"|")," |"),1,9),date9.) >= '01JAN2000'd then do;
			date = input(substr(compress(scan(comment,1,"|")," |"),1,9),date9.);
		end;
	end;

	comments = strip(left(compress(comment,"|")));
	if comments = "" or date < &last_date. then delete;
	row = _n_;
	run;

	proc sort data = comments2_&prefix.;
	by date row;
	run;

	data comments_date;
	set comments2_&prefix.;
	  by date row;
	  retain count;
		if first.date then do;
			count = .;
		end;

		count + 1;
	run;
		
		proc sql;
		create table a as
		  select distinct count
		  from comments_date
			order by count desc;
		quit;

		proc sql noprint;
			select max(count) into :cnt
			  from a;
		quit;
		%put &cnt.;

	proc transpose data=comments2_&prefix. out=comments3_&prefix. (drop=_name_) prefix=C;
	by date;
	var comments;
	run;



	%macro l;
		data comments_&prefix. (keep = date text guideline_key cur_date_run);
		set comments3_&prefix.;
			if date = . then do;
				cur_date_run = &date_run.;
				guideline_key = "&guideline_key.";
			end;
			else do;
				if date >= &last_date.;
				text = strip(strip(left(C1))	%if &cnt. > 1 %then %do i=2 %to &cnt.;
													||strip(left(C&i.))
													%if &i = &cnt. %then %do;
														)
													%end;
												%end;
												%else %do;
												)
												%end;
												;
	/*						guideline_key = "&&glkey&glloop.";*/
				guideline_key = "&guideline_key.";
			    cur_date_run = &date_run.;
			end;
		run;

		
		proc datasets library=work;
		%do i=1 %to 3;
			delete Comments&i._:;
		%end;
		run;
		quit;

		data dates_&prefix.;
		format cur_date_run mmddyy10.;
		  cur_date_run = &date_run.;
		  guideline_key= "&guideline_key.";
		run;

	%mend;
	%l;

%mend;
