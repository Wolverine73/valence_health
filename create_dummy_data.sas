/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_dummy_data.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Create dummy data roster and formats for portal
|
| INPUT:    labclme dataset         
|
| OUTPUT:   datasets:  dummyroster
|           formats:   dummyID,dummynm,dummyYN,dummyDOB
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JUN2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created dummy data macro
|             
+-----------------------------------------------------------------------HEADER*/
 
%macro create_dummy_data(dummyNPI=);

	%*SASDOC----------------------------------------------------------------------
	| Create dummy data roster                                              
	+----------------------------------------------------------------------SASDOC*;
 
	Data DummyRoster1;
		set dw.labclme (keep= memberid provid sex);
		where provid = "&dummyNPI.";
	run;

	proc sort data = DummyRoster1 out=DummyRoster2 nodupkey;
		by memberid;
	run;

	Data DummyRoster3 (keep=memberid);
		set DummyRoster2;
	run;
	
	%*SASDOC----------------------------------------------------------------------
	| Modify patient information                                             
	+----------------------------------------------------------------------SASDOC*;

	Data DummyRoster4;
		merge DummyRoster3 (in=a) member.member (in=b keep=memberid dob sex);
		by memberid;
		if a;
		count=input(_n_, $20.);
		if sex="M" then do;
		  fname=put(count, $malenm.);
		end;
		if sex="F" then do;
		  fname=put(count, $femalenm.);
		end;
		lname=put(count, $lastnm.);
		length membername $42.;
		membername = cats(lname) || ", " || cats(fname);

		daysadd=int(ranuni(1)*30);
		randomvar = (ranuni(0)*10000);
		Memberid2 = "D" || put (ceil (ranuni(1) * 1e9), z9.);
		dob=dob+daysadd;
		phone = "9999999999";
		address1 = "123 Maple Street";
		Address2 = "";
		ZIP = "60661";
		City = "Dalton";
		State = "GA";
		*if dob = . or sex = "" then delete; *Removed 5/27/10 by KG;
	run;

	Data Dummy.DummyRoster;
		set DummyRoster4;
	run;

	%*SASDOC----------------------------------------------------------------------
	| Create dummy patient formats    
	| 1.  Dummy ID     
 	| 2.  Dummy name  
 	| 3.  Dummy Y/N  
	| 4.  Dummy dob  
	+----------------------------------------------------------------------SASDOC*;

	%create_formats(datain=Dummy.DummyRoster, dataout=Dummy.dummyID, where=,fmtname=dummyID, type=C, label=memberid2, start_length=10, label_length=10, start=memberid, obs=50, date=);
	%create_formats(datain=Dummy.DummyRoster, dataout=Dummy.dummynm, where=,fmtname=dummynm, type=C, label=membername, start_length=10, label_length=42, start=memberid, obs=50, date=);
	*%create_formats(datain=Dummy.DummyRoster, dataout=Dummy.dummyYN, where=,fmtname=dummyYN, type=C, label=YN, start_length=10, label_length=1, start=memberid, obs=50, date=);
	

	*4.  In Member Table--Y/N;
	 data Dummy.dummyYN;
		LENGTH FMTNAME $7. TYPE $1 label $1. start $10.;
	  set Dummy.DummyRoster (keep = memberid  );
	   KEEP START LABEL TYPE FMTNAME ;
	  RETAIN FMTNAME 'dummyYN'  TYPE 'C';
	  if memberid NE "" then do;
	    start = memberid;
		label = 'Y';
		output;
	  end;
	  if _n_ = 1 then do;
	   start = "other";
	   label = 'N';
	   output;
	  end;
	run;

	proc sort data=Dummy.dummyYN out=Dummy.dummyYN ;
	by start;
	run;
	proc print data=Dummy.dummyYN (obs=50);
	run;
	PROC FORMAT CNTLIN=Dummy.dummyYN ;
	RUN;
	proc contents data=Dummy.dummyYN ;
	run;


	data Dummy.dummyDOB;
	set Dummy.DummyRoster; 
	length fmtname $8 type $1 label $10. start $10.;
	keep start label type fmtname;
	retain fmtname 'dummyDOB' TYPE 'C';
	start=memberid;
	label= put(DOB,mmddyy10.);
	output;
	if _n_ = 1 then do;
	   start = "other";
	   label = ".";
	   output;
	end;

	run;

	proc sort data = dummy.dummyDOB nodupkey;
	by start;
	run;

	proc format cntlin = dummy.dummyDOB; run;

	proc print data= dummy.dummyDOB (obs=50);
	run;

    proc contents data = dummy.dummyDOB; run;
	
%mend create_dummy_data;
