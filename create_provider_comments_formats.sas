/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_provider_comments_formats.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Create provider comments formats (refused,expired,nopat)
|
| INPUT:    membercomments dataset          
|
| OUTPUT:   provider comments formats
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 26MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created provider comments formats macro
|             
+-----------------------------------------------------------------------HEADER*/

%macro create_provider_comments_formats;

	data membercomment;
		set sasbi.membercomment;
		length mem_pcp $21. mem_guide $14.;
		mem_guide = cats(memberid)||"||"||cats(guideline_key);
		mem_pcp = cats(memberid)||"||"||cats(pcpid);
	run;

	%*SASDOC----------------------------------------------------------------------
	| 1. Create patient expired format     
	| 2. Create patient refused/contraindicated format                                               
	| 3. Create no longer patient format     
	+----------------------------------------------------------------------SASDOC*;

	%create_formats(datain=membercomment, dataout=expiredfmt, where=where comment_key = 4, fmtname=expired, type=C, label=YN, start_length=9, label_length=1,	start=memberid, obs=50, date=);
	%create_formats(datain=membercomment, dataout=refusedfmt, where=where comment_key in (1,5), fmtname=refused, type=C, label=YN, start_length=14, label_length=1,	start=mem_guide, obs=50, date=);
	%create_formats(datain=membercomment, dataout=nopatfmt, where=where comment_key = 6, fmtname=nopat, type=C, label=YN, start_length=21, label_length=1,	start=mem_pcp, obs=50, date=);

%mend create_provider_comments_formamts;
