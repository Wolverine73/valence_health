
/*HEADER------------------------------------------------------------------------
|
| program:  dq_create_reports.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create the PDF report for the data quality process
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
| 01APR2010 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
| 24AUG2011 - Nick Williams - Clinical Integration 1.0.02
|             Added in vMine Load Report code thats being incorporated into DQ report.
|             Adjusted ods region for detail regarding data warnings to fix overlapping
|             issue that appears sometimes.
|             Adjusted ods region when data rows to be display have more observations then
|             can fit on a single page.
|   
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro dq_create_reports;



	*--------------------------------------------------------------------------------
	| Issue Count
	+------------------------------------------------------------------------------*;
	%local issue_count regionvar;

	%let regionvar=1;
	
	%let issue_count=0;

	proc sql noprint;
	  select count(*) into: issue_count
	  from summary_validation 
	  where data_validation ne '';
	quit;

	%put NOTE: issue_count = &issue_count. ;

    *SASDOC--------------------------------------------------------------------
    | DQ Data Size Check - The purpose of this macro is to check the counts of
    | rows in a dataset to see how much of it we can print on a pdf page. This
    | routine will be used by report produced here.
    +--------------------------------------------------------------------SASDOC*;
    %macro dqdatasize_check (indsn=,rchk=,mvar=,);

	
    %mvarexist(&mvar.); 
    %if &mvarexist. ne 0 %then %symdel &mvar. ;
	%global &mvar ;

    %countobs(dsn=&indsn.,macvar=dqrptrectotal);

    %if &dqrptrectotal. gt &rchk. %then %do;
        %splitdsnbyobs(dsn=&indsn.,splitby=&rchk.,macvar=&mvar.);
    %end;
	%else %do;
		%let &mvar=0;		
	%end;

    %put Final value of &mvar. is: &&&mvar. ;

    %mend dqdatasize_check;

        
	*--------------------------------------------------------------------------------
	| Overall Summary Report - Page 1
	+------------------------------------------------------------------------------*;
	ods proclabel  'Submission Summary';
	ods layout start;
	ods region width=8in height=0.20in y=0in x=0in;
	ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
	        Overall File Upload Status: &status  }";
	ods region width=8in height=7in y=0.1in x=0in;

    %dqdatasize_check (indsn=summary_validation,rchk=26,mvar=sumvar_chk);
	%countobs(dsn=summary_validation,macvar=sum_obs);

    %if &sumvar_chk gt 1 and &sum_obs gt 0 %then %do;
        %do ll = 1 %to &sumvar_chk. ;
            %if &ll gt 1 %then %do;
                ods layout end;
                ods pdf startpage=now;
                ods layout start ;

            	ods region width=8in height=0.20in y=0in x=0in;
            	ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
            	        Overall File Upload Status (Continued) : &status  }";
            	ods region width=8in height=7in y=0.1in x=0in;
            %end;
            
        	proc report data = summary_validation&ll split='*' nowd
        	style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
        	style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
        	style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
        	column data_assessment data_validation validation count percent rptpct;
        		define data_assessment / display 'Data Element' style=[cellwidth=60mm] ;
        		define data_validation / display 'Assessment' style=[cellwidth=30mm];
        		define validation      / display 'Result' style=[cellwidth=25mm];
        		define count	       / display 'Records' style=[cellwidth=40mm] format=comma10.;
        		define percent 	       / noprint analysis sum;
        		define rptpct	       / computed '% of Records' style=[cellwidth=40mm]	format=percent6.1;
        		compute rptpct;
        			rptpct = percent.sum / 100;
        		endcomp;
        		compute data_validation;
        			if data_validation ne ' ' then do;
        				call define(_ROW_,'STYLE','style={background=GWH font_weight=bold}');
        			end;
        		endcomp;
        	run;
        %end;

        ods region x=0in y=6.00in height=0.25in width=8in;
    	ods pdf text = "~{style [just=left verticalalign=bottom  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
    	ods layout end;

    %end;

    %else %do;

		%if &sum_obs gt 0 %then %do;

		proc report data = summary_validation split='*' nowd
		style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ]
		style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ]
		style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
		column data_assessment data_validation validation count percent rptpct;
			define data_assessment / display 'Data Element' style=[cellwidth=60mm] ;
			define data_validation / display 'Assessment' style=[cellwidth=30mm];
			define validation      / display 'Result' style=[cellwidth=25mm];
			define count	       / display 'Records' style=[cellwidth=40mm] format=comma10.;
			define percent 	       / noprint analysis sum;
			define rptpct	       / computed '% of Records' style=[cellwidth=40mm]	format=percent6.1;
			compute rptpct;
				rptpct = percent.sum / 100;
			endcomp;
			compute data_validation;
				if data_validation ne ' ' then do;
					call define(_ROW_,'STYLE','style={background=GWH font_weight=bold}');
				end;
			endcomp;
		run;
	  %end;	 
    ods region x=0in y=6.00in height=0.25in width=8in;
	ods pdf text = "~{style [just=left verticalalign=bottom  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
	ods layout end;
    %end;


	*--------------------------------------------------------------------------------
	| Descriptive Statistics - Page 2
	+------------------------------------------------------------------------------*; 
	%if &facility_indicator = 1 %then %do;

	ods layout start;
	ods region width=8in height=0.20in y=0in x=0in;
	ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
	        Hospital Validation:}";
	ods region width=8in height=7in y=0.1in x=0in;
	
	
		proc report data=dq_hospital nowd; 
		column _name_ rate;
		define _name_ / "Statistic" format=$reportfmt.;
		define rate / "Distribution Rate" width =30 center format=percent10.2;
		run;
 		
		ods pdf startpage=now;

		proc report data=all1 nowd;
		column _name_ definition;
		define _name_ / "Term" format=$reportfmt.;
		define definition / "Definition" format=$define.;
		run;
	
	ods region width=8in height=0.25in y =6.25in x=0in;
	ods pdf text = "~{style [just=left verticalalign=top  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
	ods layout end;	

	%end;

	
	*--------------------------------------------------------------------------------
	| Descriptive Statistics - Page 2
	+------------------------------------------------------------------------------*; 
	%countobs(dsn=ds_all,macvar=ds_all_obs);

    %if &ds_all_obs gt 0 %then %do;

	ods layout start;
	ods region width=8in height=0.20in y=0in x=0in;
	ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
	        Descriptive Statistics:}";
	ods region width=8in height=7in y=0.1in x=0in;

	proc report data = ds_all split='*' nowd
	style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
	style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
	style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
	column  textdesc textvalue;
		define textdesc  / display 'Description' style=[cellwidth=60mm] ;
		define textvalue / display 'Value' style=[cellwidth=90mm];
	run;
	
	ods region width=8in height=0.25in y =6.25in x=0in;
	ods pdf text = "~{style [just=left verticalalign=top  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
	ods layout end;	

	%end;
	
	*--------------------------------------------------------------------------------
	| NPI Frequency Statistics - Page 3
	+------------------------------------------------------------------------------*; 
	ods layout start;
	ods region width=8in height=0.20in y=0in x=0in;
	ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
	        NPI Information:}";
	ods region width=8in height=7in y=0.1in x=0in;

	%countobs(dsn=pm_&practice.,macvar=pm_obs);

/*    %if &pm_obs gt 0 %then %do;*/

	%if %sysfunc(exist(pm_&practice.)) and  &pm_obs. gt 0 %then %do;
		proc freq data= pm_&practice. noprint;
		  tables npi_provname / missing  out = npi_provname;
		run;
	%end;

	%countobs(dsn=npi_provname,macvar=npiprov_obs);
	%dqdatasize_check (indsn=npi_provname,rchk=26,mvar=npiprovn_chk);

    %if &npiprovn_chk. gt 1 and &npiprov_obs gt 0 %then %do;	    
        %do ll = 1 %to &npiprovn_chk. ;
            %if &ll gt 1 %then %do;
                ods layout end;
                ods pdf startpage=now;
                ods layout start ;

            	ods region width=8in height=0.20in y=0in x=0in;
            	ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
            	        NPI Information (Continued) :}";
            	ods region width=8in height=7in y=0.1in x=0in;
            %end;

        	proc report data = npi_provname&ll split='*' nowd
        	style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
        	style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
        	style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
        	column  npi_provname count percent;
        		define npi_provname  / display 'NPI - Provider' style=[cellwidth=90mm] ;
        		define count / display 'Counts' style=[cellwidth=30mm];
        		define percent / display 'Percents' style=[cellwidth=30mm] format=8.2;
        	run;
            
        %end;

    	ods region width=8in height=0.25in y =6.25in x=0in;
    	ods pdf text = "~{style [just=left verticalalign=top  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
    	ods layout end;	

    %end;

    %else %do;


	    %if &npiprov_obs gt 0 %then %do;
			proc report data = npi_provname split='*' nowd
			style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
			style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
			style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
			column  npi_provname count percent;
				define npi_provname  / display 'NPI - Provider' style=[cellwidth=90mm] ;
				define count / display 'Counts' style=[cellwidth=30mm];
				define percent / display 'Percents' style=[cellwidth=30mm] format=8.2;
			run;
			
			ods region width=8in height=0.25in y =6.25in x=0in;
			ods pdf text = "~{style [just=left verticalalign=top  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
			ods layout end;	
		%end;

    %end;

	*--------------------------------------------------------------------------------
	| Provide Listing  Historical Claims - Page 4 
	+------------------------------------------------------------------------------*; 
	%if &dqprovcols. gt 0 %then %do;

        %do j = 1 %to &dqprovcols. ;
        ods pdf startpage=yes;
        ods layout start;

            ods region width=8in height=0.20in y=0in x=0in;
            ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor]
                    Provider Frequency Historical Claims:}";
            ods region width=8in height=7in y=0.1in x=0in;

            proc report data = dqprov&j split='*' nowd
            style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ]
            style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ]
            style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left];
            column  &dqprov_vars. count totalrecs percent ;
                define count     / display  'Counts' format=comma10. ;
                define totalrecs / display  'Total Records' format=comma10. ;
                define percent   / display  'Percentage'  format=percentn8.1;

            run;
        ods layout end;
        %end;	
	%end;

	*SASDOC--------------------------------------------------------------------
	|  Claims summary by svcdt - Page 5 (additional pages if necessary)	
	+--------------------------------------------------------------------SASDOC*;
	%if &dqclmsumcols. gt 0 %then %do;
	ods pdf startpage=no;
	ods layout start ;
	ods region x=0 pct height=100 pct
	y=0 pct width =100 pct;

	ods pdf text="~{style [just=left font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor]
			Claims Summarization by Service Date:}";

	ods text='~{newline 2}';
	ods noproctitle;


	%do j = 1 %to &dqclmsumcols. ;

	*SASDOC--------------------------------------------------------------------
	| At the start of nth dataset insert a new page as all output wont fit on one
	| page.
	+--------------------------------------------------------------------SASDOC*;	
	%if %sysfunc(mod(&j.,6))=0 %then %do;
	ods layout end;	
	ods pdf startpage=now;
	ods layout start ;
	ods pdf text="~{style [just=left font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor]
			Claims Summarization by Service Date (continued):}";
	ods text='~{newline 2}';
	ods noproctitle;

	%end;

	
	*SASDOC--------------------------------------------------------------------
	| define ods region for data to be printed in.
	+--------------------------------------------------------------------SASDOC*;
	%macro create_border(x=,y=,hgt=,width=);
	ODS REGION x=&x in height=&hgt in
	y=&y in width =&width in;
	%MEND create_border;

	%macro set_region;
	
	%if &regionvar. = 1 %then %create_border(x=0.5, y=0.5, hgt=6, width=3.5);	
	%if &regionvar. = 2 %then %create_border(x=1.25, y=0.5, hgt=6, width=3.5);
	%if &regionvar. = 3 %then %create_border(x=2, y=0.5, hgt=6, width=3.5);
	%if &regionvar. = 4 %then %create_border(x=2.75, y=0.5, hgt=6, width=3.5);
	%if &regionvar. = 5 %then %create_border(x=3.5, y=0.5, hgt=6, width=3.5);	

	%if &regionvar. > 5 %then %do;	
	/*if gt 5 then then reset to region#1 and assign regionvar to 1*/
	%let regionvar = 1;	
	%create_border(x=0.5, y=0.5, hgt=6, width=3.5);
	%end;

	%put NOTE: Inside set_region - regionvar = &regionvar. ;

	%mend set_region;

	%set_region;


	proc report data = dqclmsum&j nowd 
	style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left ] 
	style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=left font_weight=bold ] 
	style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left];
	column svcdt count ;
		define svcdt     / display 'Service Date (Year-Month)' ;
		define count     / display 'Claim Count' ;
	run;

	/*	increment regionvar so that next region is defined properly*/
	%let regionvar = %eval(&regionvar.+1);
	
	%put NOTE: Inside do loop - regionvar = &regionvar. ;

	%end;

	ods layout end;	
	
	ods pdf startpage=now;

	%end;
	
	%if &practice. ne 0 %then %do;  /** only vmine practices **/
	
		%if %sysfunc(exist(work.fn_controlcharts_filedt)) %then %do;
			*--------------------------------------------------------------------------------
			| Quality Control: Fraction Nonconforming Control Charts - Page 4
			+------------------------------------------------------------------------------*;
			
			ods layout start;
			ods region width=8in height=0.20in y=0in x=0in;
			ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
				Quality Control:}";
			ods region width=8in height=7in y=0.1in x=0in; 
			
			proc report data = quality_control_definitions split='*' nowd
			style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
			style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
			style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
			column  string_text ;
				define string_text  / display 'Quality Control Chart - Definitions' style=[cellwidth=150mm] ; 
			run;

            ods region x=0in y=6.00in height=0.25in width=8in;
            ods pdf text = "~{style [just=left verticalalign=bottom  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
            ods layout end;
			
			ods layout start;
			ods region width=8in height=0.20in y=0in x=0in;
			ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
				Quality Control - Fraction Nonconforming Control Charts:}";
			ods region width=8in height=7in y=0.1in x=0in;
			 
			%countobs(dsn=fn_controlcharts_filedt,macvar=fn_obs);

			%if &fn_obs. gt 0 %then %do;
				proc report data = fn_controlcharts_filedt split='*' nowd
				style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ]
				style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ]
				style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
				column  data_element flag_reason fncc_indicator ;
					define data_element  / display 'Data Element' style=[cellwidth=60mm] ;
					define flag_reason / display 'Indicator Reason' style=[cellwidth=30mm];
					define fncc_indicator / display 'QC Inidicator' style=[cellwidth=30mm];
				run;

				ods region width=8in height=0.25in y =6.25in x=0in;
				ods pdf text = "~{style [just=left verticalalign=top  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
				ods layout end;
			%end;
		%end;


		%countobs(dsn=qc_movingrange_filedt,macvar=qc_obs);

		%if &qc_obs. gt 0 %then %do;		
			*--------------------------------------------------------------------------------
			| Quality Control: Individual Value and Moving Range Control Charts - Page 5
			+------------------------------------------------------------------------------*; 
			ods layout start;
			ods region width=8in height=0.20in y=0in x=0in;
			ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
				Quality Control - Individual Value and Moving Range Control Charts:}";
			ods region width=8in height=7in y=0.1in x=0in;

            %dqdatasize_check (indsn=qc_movingrange_filedt,rchk=26,mvar=qcfiledt_chk);

            %if &qcfiledt_chk. gt 1 %then %do;
                %do ll = 1 %to &qcfiledt_chk. ;
                    %if &ll gt 1 %then %do;
                        ods layout end;
                        ods pdf startpage=now;
                        ods layout start ;

            			ods region width=8in height=0.20in y=0in x=0in;
            			ods pdf text="~{style [just=l font_weight=bold font_size=9pt  font_face='Times' foreground=&bcolor] 
            				Quality Control - Individual Value and Moving Range Control Charts (Continued):}";
            			ods region width=8in height=7in y=0.1in x=0in;
                    %end;
        			proc report data = qc_movingrange_filedt&ll split='*' nowd
        			style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
        			style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
        			style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
        			column  level npi flag_reason clm_flag  ;
        				define level  / display 'Data Level' style=[cellwidth=40mm] ;
        				define npi  / display 'NPI' style=[cellwidth=60mm] ;
        				define flag_reason  / display 'Indicator Reason' style=[cellwidth=30mm] ;
        				define clm_flag / display 'CLM Indicator' style=[cellwidth=30mm];
        			run;                    
                %end;

    			ods region width=8in height=0.25in y =6.25in x=0in;
    			ods pdf text = "~{style [just=left verticalalign=top  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
    			ods layout end;	

            %end;

            %else %do;
    			proc report data = qc_movingrange_filedt split='*' nowd
    			style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
    			style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
    			style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
    			column  level npi flag_reason clm_flag  ;
    				define level  / display 'Data Level' style=[cellwidth=40mm] ;
    				define npi  / display 'NPI' style=[cellwidth=60mm] ;
    				define flag_reason  / display 'Indicator Reason' style=[cellwidth=30mm] ;
    				define clm_flag / display 'CLM Indicator' style=[cellwidth=30mm];
    			run;

    			ods region width=8in height=0.25in y =6.25in x=0in;
    			ods pdf text = "~{style [just=left verticalalign=top  font_weight=bold font_size=8pt  font_face='times' foreground=&bcolor]Detail regarding data warnings is provided on the pages that follow}";
    			ods layout end;	
            %end;
		%end;
	%end;
	

	%if &issue_count ne 0 %then %do;

		*--------------------------------------------------------------------------------
		| Create looping variable of validation issues 
		+------------------------------------------------------------------------------*;
		data _null_;
		  set summary_validation (where=(data_validation ne '')) end=eof;
		  varindex=index(data_variable,'_');
		  freq_variable=trim(substr(data_variable,varindex+1));
		  issue_variable='issue'||trim(substr(data_variable,varindex));
		    i+1;
		    ii=left(put(i,4.));
		    call symput('valvar'||ii,left(trim(data_variable)));
			call symput('freqvar'||ii,left(trim(freq_variable)));
			call symput('issuevar'||ii,left(trim(issue_variable)));
			call symput('assessvar'||ii,left(trim(data_assessment)));
		    if eof then call symput('issue_total',ii);
		run;

		%do j = 1 %to &issue_total. ;
			%if %upcase(&&freqvar&j) = SVCDT99 %then %do;
			
			%end;
			%else %do;
			
				*--------------------------------------------------------------------------------
				| Frequency Reports - Page 6+
				+------------------------------------------------------------------------------*;			
				ods layout start;
				ods region width=8in height=0.5in y=0.5in x=0in;
				ods pdf text="~{style [just=l font_weight=bold font_size=8pt  font_face='Times' foreground=&bcolor] &&assessvar&j.  - Invalid Profile}";
				
				proc freq data = pm_&practice. (where=(upcase(&&valvar&j.) = 'INVALID')) noprint;
				  tables &&issuevar&j / missing out=&&issuevar&j;
				  tables &&freqvar&j /  missing out=&&freqvar&j;
				run;
				
				proc sql noprint;
				  select count(*) into: pmsystemtotal
				  from pm_&practice.;
				quit;

				data &&issuevar&j ;
				  set &&issuevar&j ;
				  pmsystemtotal = &pmsystemtotal. ;
				run;
				
				*--------------------------------------------------------------------------------
				| Description of Issues
				+------------------------------------------------------------------------------*;	
				ods region width=8in height=2in y=.75in x=0;	
				
				proc report data = &&issuevar&j nowd split='*'
				style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ] 
				style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ] 
				style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
				column &&issuevar&j count percent pmsystemtotal rptpct;
					define &&issuevar&j 	/ display 'Type' style=[cellwidth=60mm];
					define count		/ display 'Invalid Records' style=[cellwidth=40mm] format=comma10.;
					define percent 		/ noprint analysis sum;
					define pmsystemtotal	/ display 'Total Records' style=[cellwidth=30mm] format=comma10. ;
					define rptpct		/ computed '% of Invalid' style=[cellwidth=30mm] format=percentn8.1;
					compute rptpct;
						rptpct = (count/pmsystemtotal) ;
					endcomp;						
				run;	
					
				*--------------------------------------------------------------------------------
				| Content of Issues
                | 04MAY2011 N.Williams - If data contents of issue is too many to print on a single 
                | page spilit out the observations and 
				+------------------------------------------------------------------------------*;			
				proc sql noprint;
				  select count(*) into: freqtot
				  from &&freqvar&j ;
				quit;


                %if &freqtot. gt 15 %then %do;
                    %splitdsnbyobs(dsn=&&freqvar&j,splitby=30,macvar=dqissuecols);
                    %do ll = 1 %to &dqissuecols. ;
                        %if &ll eq 1 %then %do;
                            ods layout end;
                            ods pdf startpage=now;
                            ods layout start ;
                            
                            ods region width=8in height=0.20in y=0in x=0in;
                            ods pdf text="~{style [just=l font_weight=bold font_size=8pt  font_face='Times' foreground=&bcolor] &&assessvar&j.  - Invalid Value Listing}";
	                        ods region width=8in height=7in y=0.1in x=0in;

                        %end;
                        %if &ll gt 1 %then %do;
                            ods layout end;
                            ods pdf startpage=now;
                            ods layout start ;
                            
                            ods region width=8in height=0.20in y=0in x=0in;
    				        ods pdf text="~{style [just=l font_weight=bold font_size=8pt  font_face='Times' foreground=&bcolor] &&assessvar&j.  - Invalid Value Listing (Continued)}";
    				        ods region width=8in height=7in y=0.1in x=0in;

                        %end;

                        proc report data = &&freqvar&j&&ll nowd split='*'
                        style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ]
                        style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ]
                        style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
                        column &&freqvar&j count ;
                            define &&freqvar&j / display 'Value' style=[cellwidth=60mm];
                            define count / display 'Records' style=[cellwidth=40mm] 	format=comma10.;
                        run;                        
                    %end;
                %end;

                %else %do;
                    ods region width=8in height=0.5in y=2.75in x=0in;
                    ods pdf text="~{style [just=l font_weight=bold font_size=8pt  font_face='Times' foreground=&bcolor] &&assessvar&j.  - Invalid Value Listing}";
                    ods region width=8in height=3.75in y=3.0in x=0in;

                    proc report data = &&freqvar&j nowd split='*'
                    style(report)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=center ]
                    style(header)=[ borderwidth=0 background=&bcolor foreground=&tcolor font_face="times" font_size=8pt just=center font_weight=bold ]
                    style(column)=[ borderwidth=0 background=white background=white font_face="times" font_size=8pt just=left]						;
                    column &&freqvar&j count ;
                        define &&freqvar&j / display 'Value' style=[cellwidth=60mm];
                        define count / display 'Records' style=[cellwidth=40mm] 	format=comma10.;
                    run;
                %end; 	

			    ods layout end;
			%end;
		%end;
	
	%end;

%mend dq_create_reports;
