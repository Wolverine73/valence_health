
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  exclude_patients.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Create formats to exclude home health and nursing home patients from guidelines
|
| LOGIC:    Create formats to exclude home health and nursing home patients 
|           
| INPUT:    labclme dataset         
|
| OUTPUT:   nursing home and home health patient formats
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 27MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created exclude patients macro
|
|             
+-----------------------------------------------------------------------HEADER*/



%macro exclude_patients;

	proc summary data=patex (keep=memberid nursingpat_exclude) nway missing;
		class memberid;
		var nursingpat_exclude;
		output out=nursingpat_exclude (drop=_type_ _freq_) sum=;
	run;

	%create_formats(datain=nursingpat_exclude, dataout=nursfmt, where= where nursingpat_exclude ge 1 and nursingpat_exclude not in (.,-0,0), 
	 fmtname=nursfmt, type=C, label=YN, start_length=9, label_length=1,start=memberid, date=);

	Data patex;
	set dw.labclme;
	procn = proccd *1 ;

	if ((&stdtc. - 365) <= svcdt < &enddtc.) then do;
		if (proccd in ('99301','99302','99303','99304','99305','99306','99307','99308',
					   '99309','99310','99311','99312','99313','99315','99316','99318') or 
			pos in ('31','32','34')) then nursingpat_exclude = 1;


		if (procn in (99341:99345,99347:99353,99374:99375,99500:99602) or pos = '12') then
			Homehealth_exclude=1 ;
		     
	end;
	run;

	proc summary data=patex (keep=memberid Homehealth_exclude) nway missing;
		class memberid;
		var Homehealth_exclude;
		output out=Homehealthpat_exclude (drop=_type_ _freq_) sum=;
	run;

	%create_formats(datain=Homehealthpat_exclude, dataout=homefmt, where= where Homehealth_exclude ge 1 and Homehealth_exclude not in (.,-0,0), 
	fmtname=homefmt, type=C, label=YN, start_length=9, label_length=1,start=memberid, obs=50, date=);

%mend exclude_patients;
