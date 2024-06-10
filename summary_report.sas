
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  summary_report.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  
|                        
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro summary_report;

/**********************************************
%let vlink_client_name = nsap;
%let vmine_client_id = 4;
%include "M:\ci\programs\StandardMacros\clinical_integration_in.sas";
**********************************************/

%let bcolor  = cx13478C;
%let bcolor2 = very light grey;
%let tcolor  = white;
%let fcolor2 = black;

%create_formats(datain=vmine.practice, dataout=work.PracXwalk, fmtname=PracWalk, label=Name, length=75, start=PracticeID);

data summary_report_header;
client="NSAP";
desc="A Summary of the Clinical Integration process for March 2010.";
user="Brian Stropich";
run;

data _null_;
yearmonthid=put(today(),yymmn6.);
call symput('summreportyearmonthid',left(trim(yearmonthid)));
run;

%put NOTE: yearmonthid = &summreportyearmonthid. ;

proc sort data = ciref.Clinical_integration_history (where=(yearmonthid="&summreportyearmonthid"))
	  out  = summary_report;
 by clientid stepid yearmonthid systemid practiceid descending start_ts;
run;

data summary_report;
 set summary_report;
 by clientid stepid yearmonthid systemid practiceid descending start_ts;
 if first.practiceid;
run;

data summary_report;
 set summary_report;
 pracID = left(put(practiceid,5.));
 practicename = put(pracID,$PracWalk.); 
run; 

ods layout start;
title; footnote;
options symbolgen mprint msglevel=i orientation='landscape' nodate nonumber;
options leftmargin=1in 	rightmargin=1in topmargin=0.25in	bottommargin=.25in;
ods escapechar "^";

filename xl "&sasrpts.\SummaryReport_&summreportyearmonthid..pdf";
ods pdf  file=xl startpage=no style=sasweb pdftoc=1 columns=1  author='Valence Health' Subject='PGF File Upload Status' Title='Upload Summary';

title1 c=&bcolor 	h=12pt       f="times"	   j=c 'Clinical Integration'  ; 
title2 c=&bcolor justify=left 	 h=10pt  f="times"	"Client: NSAP"   h=14pt j=c 'Process Summary Report'  h=10pt j=r "Prepared: %sysfunc(today(),mmddyy10.)"; 
title3 c=&bcolor justify=center  '^S={preimage="\\ebicompute\Projects\tools\images\PGF_PDFHEADER.gif"}';
footnote1 		 justify=center  '^S={preimage="\\ebicompute\Projects\tools\images\PGF_PDFHEADER.gif"}';
footnote2 		 justify=left 	 h=8pt	f="times"	"Valence Health" 													j=r h=8pt "Clinical Integration Summary - ^{thispage}"; 

proc report
   contents='Initiative Summary'
   data=summary_report_header
   missing
   noheader
   nowd
   split="*"
   style(report)=[rules       =none
                  frame       =void 
                  just        =l
                  cellspacing =0.00in
                  cellpadding =0.00in
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(column)=[font_size   =10pt
                  font_face   ="times"];

column client desc user;
define client           / page
   style=[cellwidth  =7.0in
          font_weight=bold
          foreground =&fcolor2
          just=l
          pretext="Client Name:  "]; 
define desc           / group
   style=[cellwidth  =7.0in
          font_weight=bold
          foreground =&fcolor2
          just=l
          pretext="Description:  "];
define user           / group
   style=[cellwidth  =7.0in
          font_weight=bold
          foreground =&fcolor2
          just=l
          pretext="User Name:  "];
run;

ods region width=8in height=0.5in y=3in x=0in;
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] Step 1 - Provider:}";

 proc report
   contents='Setup Participant Parameters'
   data=summary_report (where=(stepid=1))
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(header)=[ font_face="times"  ]
   style(column)=[font_size   =9pt
                  font_weight =medium
				  font_face="times"
                  just        =l];

column 
       stepid 
       step_description 
       issue_description
	   file_name
       dataset_cnts;
define stepid     / display
   "^S={font_weight=bold
        font_size  =9pt 
        background =&bcolor2
		foreground =&fcolor2
        just       =c
        posttext=""Step ID^S={}"
   style=[cellwidth  =.70in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define step_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Step Description^S={}"
   style=[cellwidth  =2.50in
          just=l];
define issue_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Status Description^S={}"
   style=[cellwidth  =1.5in
          just=l];
define file_name    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}File Name^S={}"
   style=[cellwidth  =1.5in
          just=l];
define dataset_cnts    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Frequency^S={}"
   style=[cellwidth  =.90in
          just=l];
run;

ods region width=8in height=0.5in y=3in x=0in;
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] Step 2 - vMine:}";

 proc report
   contents='Setup Participant Parameters'
   data=summary_report (where=(stepid=2))
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(header)=[ font_face="times"  ]
   style(column)=[font_size   =9pt
                  font_weight =medium
				  font_face="times"
                  just        =l];

column 
       stepid 
       step_description 
       systemid
       practiceid
       issue_description
	   file_name
       dataset_cnts;
define stepid     / display
   "^S={font_weight=bold
        font_size  =9pt 
        background =&bcolor2
		foreground =&fcolor2
        just       =c
        posttext=""Step ID^S={}"
   style=[cellwidth  =.70in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define step_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Step Description^S={}"
   style=[cellwidth  =2.50in
          just=l];
define systemid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}System ID^S={}"
   style=[cellwidth  =.90in
          just=l];
define practiceid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Practice ID^S={}"
   style=[cellwidth  =.90in
          just=l];
define issue_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Status Description^S={}"
   style=[cellwidth  =1.5in
          just=l];
define file_name    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}File Name^S={}"
   style=[cellwidth  =1.5in
          just=l];
define dataset_cnts    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Frequency^S={}"
   style=[cellwidth  =.90in
          just=l];
			compute issue_description;
				if issue_description ne "Complete" then do;
					call define(_ROW_,'STYLE','style={background=GWH font_weight=bold}');
				end;
			endcomp;
			
			compute dataset_cnts;
				if dataset_cnts < 1 then do;
					call define(_ROW_,'STYLE','style={background=GWH font_weight=bold}');
				end;
			endcomp;			
          
run;

ods region width=8in height=0.5in y=3in x=0in;
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] Step 3 - PGF:}";

 proc report
   contents='Setup Participant Parameters'
   data=summary_report (where=(stepid=3))
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(header)=[ font_face="times"  ]
   style(column)=[font_size   =9pt
                  font_weight =medium
				  font_face="times"
                  just        =l];

column 
       stepid 
       step_description 
       systemid
       practiceid
       issue_description
	   file_name
       dataset_cnts;
define stepid     / display
   "^S={font_weight=bold
        font_size  =9pt 
        background =&bcolor2
		foreground =&fcolor2
        just       =c
        posttext=""Step ID^S={}"
   style=[cellwidth  =.70in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define step_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Step Description^S={}"
   style=[cellwidth  =2.50in
          just=l];
define systemid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}System ID^S={}"
   style=[cellwidth  =.90in
          just=l];
define practiceid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Practice ID^S={}"
   style=[cellwidth  =.90in
          just=l];
define issue_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Status Description^S={}"
   style=[cellwidth  =1.5in
          just=l];
define file_name    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}File Name^S={}"
   style=[cellwidth  =1.5in
          just=l];
define dataset_cnts    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Frequency^S={}"
   style=[cellwidth  =.90in
          just=l];
run;


ods region width=8in height=0.5in y=3in x=0in;
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] Step 4 - vMine and PGF:}";

 proc report
   contents='Setup Participant Parameters'
   data=summary_report (where=(stepid=4))
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(header)=[ font_face="times"  ]
   style(column)=[font_size   =9pt
                  font_weight =medium
				  font_face="times"
                  just        =l];

column 
       stepid 
       step_description 
       systemid
       practiceid
       issue_description
	   file_name
       dataset_cnts;
define stepid     / display
   "^S={font_weight=bold
        font_size  =9pt 
        background =&bcolor2
		foreground =&fcolor2
        just       =c
        posttext=""Step ID^S={}"
   style=[cellwidth  =.70in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define step_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Step Description^S={}"
   style=[cellwidth  =2.50in
          just=l];
define systemid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}System ID^S{}"
   style=[cellwidth  =.90in
          just=l];
define practiceid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Practice ID^S={}"
   style=[cellwidth  =.90in
          just=l];
define issue_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Status Description^S={}"
   style=[cellwidth  =1.5in
          just=l];
define file_name    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}File Name^S={}"
   style=[cellwidth  =1.5in
          just=l];
define dataset_cnts    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Frequency^S={}"
   style=[cellwidth  =.90in
          just=l];
run;

ods region width=8in height=0.5in y=3in x=0in;
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] Step 5 - Excel Reports:}";

 proc report
   contents='Setup Participant Parameters'
   data=summary_report (where=(stepid=5))
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(header)=[ font_face="times"  ]
   style(column)=[font_size   =9pt
                  font_weight =medium
				  font_face="times"
                  just        =l];

column 
       stepid 
       step_description  
       issue_description
       file_name ;
define stepid     / display
   "^S={font_weight=bold
        font_size  =9pt 
        background =&bcolor2
		foreground =&fcolor2
        just       =c
        posttext=""Step ID^S={}"
   style=[cellwidth  =.70in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define step_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Step Description^S={}"
   style=[cellwidth  =2.50in
          just=l];
define issue_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Status Description^S={}"
   style=[cellwidth  =1.5in
          just=l];
define file_name    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}File Name^S={}"
   style=[cellwidth  =1.5in
          just=l];
run;


ods region width=8in height=0.5in y=3in x=0in;
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] Step 6 - Member:}";

 proc report
   contents='Setup Participant Parameters'
   data=summary_report (where=(stepid=6))
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(header)=[ font_face="times"  ]
   style(column)=[font_size   =9pt
                  font_weight =medium
				  font_face="times"
                  just        =l];

column 
       stepid 
       step_description 
       systemid
       practiceid
       issue_description
	   file_name
       dataset_cnts;
define stepid     / display
   "^S={font_weight=bold
        font_size  =9pt 
        background =&bcolor2
		foreground =&fcolor2
        just       =c
        posttext=""Step ID^S={}"
   style=[cellwidth  =.70in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define step_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Step Description^S={}"
   style=[cellwidth  =2.50in
          just=l];
define systemid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}System ID^S{}"
   style=[cellwidth  =.90in
          just=l];
define practiceid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Practice ID^S={}"
   style=[cellwidth  =.90in
          just=l];
define issue_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Status Description^S={}"
   style=[cellwidth  =1.5in
          just=l];
define file_name    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}File Name^S={}"
   style=[cellwidth  =1.5in
          just=l];
define dataset_cnts    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Frequency^S={}"
   style=[cellwidth  =.90in
          just=l];
run;


ods region width=8in height=0.5in y=3in x=0in;
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] }";
ods pdf text="^{style [just=l font_weight=bold font_size=10pt  font_face='Times' foreground=&bcolor] Step 7 - Guidelines:}";

 proc report
   contents='Setup Participant Parameters'
   data=summary_report (where=(stepid=7))
   nowd
   split="*"
   style(report)=[rules       =all
                  frame       =box
                  background  =_undef_
                  just        =l
                  font_size   =9pt
                  leftmargin  =0.00in
                  rightmargin =0.00in
                  topmargin   =0.00in
                  bottommargin=_undef_
                  asis        =off]
   style(header)=[ font_face="times"  ]
   style(column)=[font_size   =9pt
                  font_weight =medium
				  font_face="times"
                  just        =l];

column 
       stepid 
       step_description 
       systemid
       practiceid
       issue_description
	   file_name
       dataset_cnts;
define stepid     / display
   "^S={font_weight=bold
        font_size  =9pt 
        background =&bcolor2
		foreground =&fcolor2
        just       =c
        posttext=""Step ID^S={}"
   style=[cellwidth  =.70in
          just       =r
          posttext   ="^S={}^_^_^_^S={}"];
define step_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Step Description^S={}"
   style=[cellwidth  =2.50in
          just=l];
define systemid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}System ID^S{}"
   style=[cellwidth  =.90in
          just=l];
define practiceid    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Practice ID^S={}"
   style=[cellwidth  =.90in
          just=l];
define issue_description    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Status Description^S={}"
   style=[cellwidth  =1.5in
          just=l];
define file_name    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}File Name^S={}"
   style=[cellwidth  =1.5in
          just=l];
define dataset_cnts    / display
   "^S={font_weight=bold
        background =&bcolor2
		foreground =&fcolor2
        just       =c}Frequency^S={}"
   style=[cellwidth  =.90in
          just=l];
run;

ods pdf close;


%mend summary_report;

