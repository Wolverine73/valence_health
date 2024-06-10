/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_patient_profiler.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Create patient profiler datasets and update with dummy data
|
| INPUT:    labclme, member and dummyroster datasets         
|
| OUTPUT:   datasets:  memberlookup,patientdetails,provider_elig_smry,provider_age_smry,patientprovider
|                      member_diagnosis,member_specialty
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JUN2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created patient profiler macro
| 08NOV2011 - Mark Logsdon - changed one length in patient details: provspecdesc $25.;
|             
+-----------------------------------------------------------------------HEADER*/
 
%macro create_patient_profiler(dummyNPI=);

	%*SASDOC----------------------------------------------------------------------
	| Update member table with dummy patient data                                              
	+----------------------------------------------------------------------SASDOC*;

	data memberlookup;
		set member.member (keep=memberid fname lname dob phone address1 address2 zip city state)
		    Dummy.DummyRoster (keep=memberid2 fname lname dob phone address1 address2 zip city state rename=(memberid2=memberid));
		length membername $42.;
		membername = cats(lname) || ", " || cats(fname);
	run;

	
	
	%*SASDOC----------------------------------------------------------------------
	| Create patient provider dataset                                              
	+----------------------------------------------------------------------SASDOC*;

	Data _ProfilerData;
		set dw.labclme;
		where put(memberid,$dummyYN.) = "Y" and provid = "&dummyNPI.";
		format DOB mmddyy10.;
		DOB = input(put(memberid,$dummyDOB.),mmddyy10.);
		provid = "9999999999";
	run;


	Data ProfilerData;
		set dw.labclme (in=a)
			_ProfilerData (in=b);
		length membername $42. ;
		if a then membername = cats(put(memberid,$lname.)) || ", " || cats(put(memberid,$fname.)) ;
		if b then do;
			membername = cats(put(memberid,$dummynm.));
			memberid = put(memberid,$dummyid.);
		end;
		if sensitive NE 1;
	run;

	proc sort data = ProfilerData (keep = memberid membername dob provid proccd svcdt diag1) out=PP1;
		by memberid provid svcdt;
	run;

	proc print data = PP1 (obs=5);
		where provid = "9999999999";
	run;

	Data PatientProvider (keep=memberid membername dob pcpid membername last_date last_dx_3 last_dx_3_desc);
		set PP1 ;
		length pcpid $10.;
		format last_date mmddyy10.;
		by memberid provid svcdt;;
		pcpid = provid;
		last_dx_3 = substr(diag1,1,3);
		last_dx_3_desc = put(last_dx_3,$diag5cd.);
		last_date = svcdt;
		if memberid = "" then delete;
		if put(provid,$provyn.)="Y" or provid = "9999999999";
		if last.provid;
	run;

	proc print data = PatientProvider (obs=50);
		where pcpid = "9999999999";
	run;

	%*SASDOC----------------------------------------------------------------------
	| Update patient details with dummy patient data                                              
	+----------------------------------------------------------------------SASDOC*;

	Data patientDetails (compress=yes) ;
		set dw.labclme (keep=memberid dob ProvID svcdt provspec proccd diag1 diag2 diag3 source sensitive );
		where sensitive NE 1;
		length procdesc diag1desc $50. provspecdesc $25.;
		if memberid Not in ("");
		provname = put(provID,$provname.);
		*_lname = put(memberid,$lname.);
		*_fname = put(memberid,$fname.);
		provspecdesc=put(provspec,$specd.);
		diag1desc=put(diag1,$diag5cd.);
		*diag2desc=put(diag2,$diag5cd.);
		*diag3desc=put(diag3,$diag5cd.);
		procdesc=put(proccd,$cpt.);
	run;

	data dummypatdets1;
		set patientdetails;
		where put(memberid,$dummyYN.) = "Y";
		if provid = "&dummyNPI." then provid = "9999999999";
		DOB = input(put(memberid,$dummyDOB.),mmddyy10.);
		memberid = put(memberid,$dummyid.);
	run;


	proc sort data = dummypatdets1  ; 
		by memberid source svcdt provid ;
	run;

	proc summary data =  dummypatdets1 nway ;
		where provid ne "&dummyNPI.";
		class memberid source provid;
		output out = dummypatdets2;
	run;

	proc sort data = dummypatdets2;
		by memberid source provid;
	run;

	data dummypatdets3;
		set dummypatdets2;
		retain case;
		by memberid source provid;
		if first.source then case=0;
		case=case+1;
	run;

	data provnm_fmt; 
		set dummypatdets3; 
		length fmtname $6 type $1 label 4. start $25.;
		keep start label type fmtname;
		retain fmtname "provnm" TYPE "C";
		start= memberid||"||"||provid||"||"||source;
		label= case;
		output;
	run;

	proc format cntlin = provnm_fmt; run; 

	data dummypatdets4 (compress=yes);
		set dummypatdets1;
		if provid = "9999999999" then do;
		   	provname = cats ("&client") || ", ProviderElig" ;
		end; else
		if source = "P" then do; 
			count = put(memberid||"||"||provid||"||"||source,$provnm.);
			provname = cats("&client") || ", Provider"||count ;
			provid = "DUMMY";
		end; else
		if source = "L" then do;
		    count = put(memberid||"||"||provid||"||"||source,$provnm.);
			provname = cats("&client") || ", LabProv"||count ;
			provid = "DUMMY";
		end; else
		if source = "H" then do;
			count = put(memberid||"||"||provid||"||"||source,$provnm.);
			provname = cats("&client") || ", HosProv"||count ;
			provid = "DUMMY";
		end;
	run;

	Proc datasets  ;
		Append base= patientdetails (compress=yes)
		Data= dummypatdets4 (drop =  count compress=yes);
	Quit;



	%*SASDOC----------------------------------------------------------------------
	| Create patient specialty dataset                                             
	+----------------------------------------------------------------------SASDOC*;

	Data Spec1;
		set patientdetails (keep = memberid provid provspec svcdt source sensitive);
		where memberid NE "" and svcdt NE . and (put(provid,$provyn.) = 'Y' or provid in ("9999999999","DUMMY")) and source ="P" and sensitive NE 1;
		count =1;
	run;

	proc sort data=Spec1;
		by memberid provspec svcdt;
	run;

	proc summary data=Spec1 (keep=memberid provspec svcdt count) nway missing;
		by memberid provspec svcdt;
		var count;
		output out= Spec2 (drop = _type_ _freq_) sum= ;
	run;

	data spec3;
		set spec2;
		count = 1;
		specdesc = put(provspec,$specd.);
	run;

	proc summary data=Spec3 nway missing;
		by memberid provspec specdesc;
		var count;
		output out= Member_Specialty (drop = _type_ _freq_) sum= ;
	run;

	proc datasets library=work;
		delete spec1-spec3 ;
		run;
	quit;

	%*SASDOC----------------------------------------------------------------------
	| Create patient diagnosis dataset                                              
	+----------------------------------------------------------------------SASDOC*;

	Data Dx1;
		set patientdetails(keep = memberid svcdt diag1 diag2 diag3 source provid sensitive );
		where memberid NE "" and svcdt NE . and (put(provid,$provyn.) = 'Y' or provid in ("9999999999","DUMMY")) and source ="P" and sensitive NE 1;
	run;

	Data Dx2;
		set Dx1 (keep = memberid svcdt diag1 rename = (diag1 = dx))
			Dx1 (keep = memberid svcdt diag2 rename = (diag2 = dx))
			Dx1 (keep = memberid svcdt diag3 rename = (diag3 = dx));
		count=1;
		if dx = "" then delete;
		dx_3 =substr(dx,1,3);
	run;

	proc sort data=Dx2;
		by memberid dx_3 svcdt;
	run;

	proc summary data=Dx2 (keep=memberid dx_3 svcdt count) nway missing;
		by memberid dx_3 svcdt;
		var count;
		output out= Dx3 (drop = _type_ _freq_) sum= ;
	run;

	data Dx4;
		set Dx3;
		count = 1;
	run;

	proc summary data=Dx4 nway missing;
		by memberid dx_3;
		var count;
		output out= Dx5 (drop = _type_ _freq_) sum= ;
	run;

	proc sort data=dx5;
		by memberid descending count ;
	run;

	data Member_Diagnosis;
		set dx5;
		by memberid descending count ;
		retain rank;
		if first.memberid then rank = 1;
		else rank = rank + 1;
		dx_3_desc = put(dx_3,$diag5cd.);
		if rank <= 5 ;
	run;

	proc datasets library=work;
		delete dx1-dx5 ;
		run;
	quit;


	%*SASDOC----------------------------------------------------------------------
	| Create provider eligibility summary                                               
	+----------------------------------------------------------------------SASDOC*;

	proc sort data = dw.labclme out = labclme;
		by provid memberid svcdt;
	run;

	data labclme1;
	 set labclme;
	 procn = proccd * 1;
	 svcyear = year(svcdt);
	 svcqtr = qtr(svcdt);
	 svcperiod = put(svcyear,4.)||"-Q"||put(svcqtr,1.);
	 patients = 1;
	 new=(procn in (99201:99205,99381:99387,99341:99345) );
	run;

	/* Summarize by provider and member, retaining only
	   one new flag per member and qtr. */
	proc sql;
	create table provider_member_smry as
	 select provid,svcperiod,memberid,max(new) as new,1 as ctr
	  from labclme1
	   group by provid,svcperiod,memberid
		order by memberid,provid,svcperiod;
	quit;

	proc summary data = provider_member_smry nway missing completetypes;
		class provid svcperiod new;
		var ctr;
		output out = provsmry (drop = _type_ rename=(_freq_ = patient_count)) sum=;
	run;
	 
	data provsmry1;
		length patient_type $11;
		set provsmry (drop=ctr);
		provname=put(provid,$provname.);
		if provname ne " " and svcperiod ge "&startqtr.";
		if new = 1 then patient_type = 'New';
		else patient_type = 'Established';
	run;

	Data provsmry_dummy;
		set provsmry1;
		where provid = "&dummyNPI.";
		provid = "9999999999";
		provname = cats ("&clientname") || ", ProviderElig" ;
	run;

	Data provider_elig_smry;
		set provsmry1 provsmry_dummy;
	run;


	%*SASDOC----------------------------------------------------------------------
	| Create patient age summary by provider                                             
	+----------------------------------------------------------------------SASDOC*;

	data labclme2;
	 set labclme;
	 svcyear = year(svcdt);
	 svcqtr = qtr(svcdt);
	 svcperiod = put(svcyear,4.)||"-Q"||put(svcqtr,1.);
	 if svcperiod ge "&startqtr.";
	 age = int((svcdt - dob) / 365.25);
	 agegroup = put(age,agefmtB.);
	 if agegroup ne 'Unknown';
	 patients = 1;
	 procn = proccd*1;
	 new=(procn in (99201:99205,99381:99387,99341:99345) );

	run;

	/* Summarize by provider and member, retaining only
	   one new flag per member and qtr. */;

	proc sort data = labclme2 out = provmember_sort;
		by provid memberid descending svcdt;
	run;

	data provmember_sort;
		set provmember_sort;
		by provid memberid;
		if first.memberid;
	run;

	proc summary data = provmember_sort nway missing completetypes;
		class provid agegroup;
		var patients;
		output out = provsmry10 (drop = _type_ rename=(_freq_ = patient_count)) sum=;
	run;
	 
	data provsmry11;
		set provsmry10 ;
		provname=put(provid,$provname.);
		if provname ne " " ;
	run;

	Data provsmry_dummy;
		set provsmry11;
		where provid = "&dummyNPI.";
		provid = "9999999999";
		provname = cats ("&clientname") || ", ProviderElig" ;
	run;

	Data provider_age_smry;
		set provsmry11 provsmry_dummy;
	run;

	
	%*SASDOC----------------------------------------------------------------------
	| Create indexes                                              
	+----------------------------------------------------------------------SASDOC*;
	*Generate memberlookup;
	proc sql;	
		drop index memberid from memberlookup;
		create index memberid on memberlookup (memberid);
	run;
	
	*Generate PatientProvider;
	proc sql;
		drop index memberid from PatientProvider;
		drop index pcpid from PatientProvider;
		drop index mempcpid from PatientProvider;
		create index memberid on PatientProvider (memberid);
		create index pcpid on PatientProvider (pcpid);
		create index mempcpid on PatientProvider (memberid,pcpid);
	run;

	*Generate Member_Specialty;
	proc sql;
		drop index memberid from Member_Specialty;
		create index memberid on Member_Specialty (memberid);
	run;

	*Generate Member_Diagnosis;
	proc sql;
		drop index memberid from Member_Diagnosis;
		create index memberid on Member_Diagnosis (memberid);
	run;
	
	*Generate PatientDetails;
	proc sql;
		drop index memberid from PatientDetails;
		drop index svcdt from PatientDetails;
		drop index proccd from PatientDetails;
		drop index mem_dt_proc from PatientDetails;
		create index memberid on PatientDetails (memberid);
		create index svcdt on PatientDetails (svcdt);
		create index proccd on PatientDetails (proccd);
		create index mem_dt_proc on PatientDetails (memberid,svcdt,proccd);
	run;
	
	*Generate provider summary;
	proc sql;	
		drop index provid from provider_elig_smry;
		create index provid on provider_elig_smry (provid);
	run;

    proc sql;	
		drop index provid from provider_age_smry;
		create index provid on provider_age_smry (provid);
	run;

	quit;

	%*SASDOC----------------------------------------------------------------------
	| Copy datasets and indexes to the Portal                                              
	+----------------------------------------------------------------------SASDOC*;

	proc copy in=work out=portal ;
		select memberlookup;
	run;

	proc copy in=work out=portal ;
		select PatientProvider;
	run;
	proc copy in=work out=portal ;
		select Member_Specialty;
	run;
	proc copy in=work out=portal ;
		select Member_Diagnosis;
	run;
	proc copy in=work out=portal;
		select PatientDetails;
	run;
		proc copy in=work out=portal;
	     select provider_elig_smry;
	run;
	proc copy in=work out=portal ;
	     select provider_age_smry;
	run;
	

	%mend create_patient_profiler;



