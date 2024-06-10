
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  create_member_data.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:  Create member dataset containing unique patient information
|
| INPUT:    allclaims dataset 
|
| OUTPUT:   member dataset 
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 19MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created member data macro
|
+-----------------------------------------------------------------------HEADER*/

%macro create_member_data;   
   
   *SASDOC--------------------------------------------------------------------------
   | Determine unique members by ssn, name and dob
   +------------------------------------------------------------------------SASDOC*;

	data member1 ;
		set dw.&allclaims_dataset. (keep=system practiceid memberid  lname fname dob sex svcdt address1 address2 city state zip phone);
		where (lname NE "" and fname NE "" and dob NE .) or memberid NE "";
		length ID2 $50.;
		dob_c=put(dob,DATE9.);

		Lastname=upcase(compress(lname,,'ka'));
		firstname=upcase(compress(fname,,'ka'));
		Soundex_F1=cats(Soundex(Firstname));
		if length(Soundex_F1)>=4 then Soundex_F2=substr(Soundex_F1,1,4);
		else if length(Soundex_F1)=3 then Soundex_F2=compress(Soundex_F1||"0");
		else if length(Soundex_F1)=2 then Soundex_F2=compress(Soundex_F1||"00");
		else if length(Soundex_F1)=1 then Soundex_F2=compress(Soundex_F1||"000");
		else if length(Soundex_F1)=0 then Soundex_F2=compress(Soundex_F1||"0000");

		Soundex_L1=cats(Soundex(LastName));
		if length(Soundex_L1)>=4 then Soundex_L2=substr(Soundex_L1,1,4);
		else if length(Soundex_L1)=3 then Soundex_L2=compress(Soundex_L1||"0");
		else if length(Soundex_L1)=2 then Soundex_L2=compress(Soundex_L1||"00");
		else if length(Soundex_L1)=1 then Soundex_L2=compress(Soundex_L1||"000");
		else if length(Soundex_L1)=0 then Soundex_L2=compress(Soundex_L1||"0000");

		ID=cats(Soundex_L2,Soundex_F2,dob_c);
		ID2 = cats(memberid) || "_" || cats(ID);
	run;

	Data SSN other;
		set member1;
		count= 1;
		if cats(memberid) not in ('','000000000','000000001','999999999','NA','N/A','NONE','NOT OBTAI','NIA','NO SS#','WIILNOT G','WILL NOT','Z') and substr(memberid,1,5) NE 'xxxxx' then output SSN;
		else output other;
	run;

	proc summary data= SSN nway missing;
		class memberid lname fname dob;
		var count;
		output out=SSN2 (drop= _type_ _freq_) sum=;
	run;

	Data SSN3;
		set SSN2;
		if lname NE "" and fname NE "" and dob NE . then rank= 1;
		else if dob NE . then rank= 2;
		else if lname NE "" and fname NE "" then rank= 3;
		else rank = 4;
	run;

	proc sort data=SSN3 out= SSN4;
		by memberid rank descending count ;
	run;

	data unique1 (drop= rank count);
		set SSN4;
		format status $5.;
		by memberid rank descending count ;
		if first.memberid and last.memberid then status = "NODUP";
		else status = "DUP";
		if first.memberid then output;
	run;

   *SASDOC--------------------------------------------------------------------------
   | Get first and last svcdts for each member 
   +------------------------------------------------------------------------SASDOC*;

	proc sort data=member1 out = dates1;
		by memberid svcdt;
	run;

	Data dates2 (keep=memberid  sex firstdt lastdt address1 address2 city state zip phone system filename);
		set dates1 ;
		by memberid svcdt;
		retain firstdt lastdt ;
		format firstdt lastdt mmddyy10.;
		if first.memberid then do;
			firstdt=.;
			lastdt=.;
			address1 = "";
			address2 = "";
			city = "";
			state = "";
			zip = "";
		end;
		firstdt=min(firstdt,svcdt);
		lastdt=max(lastdt,svcdt);
		if last.memberid;
	run;

	data unique2;
		merge unique1 (in=a) dates2 (in=b);
		by memberid;
		if a;
	run;
	
   *SASDOC--------------------------------------------------------------------------
   | Create unique ID and output member table 
   +------------------------------------------------------------------------SASDOC*;

	Data member.member (DROP=dob_c Lastname firstname Soundex_F1 Soundex_F2 Soundex_L1 Soundex_L2);
		set unique2;
		dob_c=put(dob,DATE9.);
		Lastname=upcase(compress(lname,,'ka'));
		firstname=upcase(compress(fname,,'ka'));
		Soundex_F1=cats(Soundex(Firstname));
		if length(Soundex_F1)>=4 then Soundex_F2=substr(Soundex_F1,1,4);
		else if length(Soundex_F1)=3 then Soundex_F2=compress(Soundex_F1||"0");
		else if length(Soundex_F1)=2 then Soundex_F2=compress(Soundex_F1||"00");
		else if length(Soundex_F1)=1 then Soundex_F2=compress(Soundex_F1||"000");
		else if length(Soundex_F1)=0 then Soundex_F2=compress(Soundex_F1||"0000");

		Soundex_L1=cats(Soundex(LastName));
		if length(Soundex_L1)>=4 then Soundex_L2=substr(Soundex_L1,1,4);
		else if length(Soundex_L1)=3 then Soundex_L2=compress(Soundex_L1||"0");
		else if length(Soundex_L1)=2 then Soundex_L2=compress(Soundex_L1||"00");
		else if length(Soundex_L1)=1 then Soundex_L2=compress(Soundex_L1||"000");
		else if length(Soundex_L1)=0 then Soundex_L2=compress(Soundex_L1||"0000");

		ID=cats(Soundex_L2,Soundex_F2,dob_c);
	run;

   
%mend create_member_data;


