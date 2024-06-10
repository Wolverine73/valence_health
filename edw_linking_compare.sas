

%macro edw_linking_compare;

cells = 7;

/*lname*/
if soundex(lname) = "" or soundex(memlname) = "" then do;
	weight1 = 0;
	cells = cells - 1;
		end;
else if soundex(lname) = soundex(memlname) then weight1 = lname_Bayes;
else weight1 = lname_Bayes*(-1); 

/*fname*/
nickname1 = put(fname,$NickName.);
nickname2 = put(nickname1,$NickName.);
nickname3 = put(memfname,$NickName.);
nickname4 = put(nickname3,$NickName.);

/* !!!! Same list exist in the above thecleaner_lname macro. If you update this, update the above too !!!! */
IF lname NOT in ("AHN","BAE","BAEK","BAN","BANG","BEA","BYUN",
				 "CHA","CHAE","CHAN","CHANG","CHEN","CHO","CHOE","CHOI","CHON","CHONG","CHOW","CHUN","CHUNG","DO","EAP","EUM",
				 "HA","HAHN","HAN","HONG","HUH","HWANG","IMM","JANG","JEON","JEONG","JI","JIN","JO","JOO","JU","JUN","JUNG",
				 "KANG","KAO","KHAN","KIM","KO","KOH","KONG","KOO","KU","KUK","KWAK","KWAN","KWON","KYE",
				 "LAM","LEE","LI","LIM","LIU","MA","MIN","MOON","MYONG","OH","PAIK","PAK","PARK","PHAN","RHEE","RYOO","RYU",
				 "SEO","SHIM","SHIN","SIM","SOHN","SON","SONG","SUH","SUK","SUL","TSAO","UM",
				 "WANG","WHANG","WON","WOO","YANG","YI","YIM","YOO","YOON","YU","YUM","YUN")
THEN DO;
	if soundex(fname) = "" or soundex(memfname) = "" then do;
		weight2 = 0;
		cells = cells - 1;
			end;
	else if (sex in ("M","F") and memsex in ("M","F") and sex ne memsex) then weight2 = fname_Bayes*(-1);
	else if (soundex(fname) = soundex(memfname) or soundex(fname) = soundex(nickname3) or soundex(fname) = soundex(nickname4)) then weight2 = fname_Bayes;
	else if nickname1 ne "NOMTCH" then do;
		if (soundex(nickname1) = soundex(memfname) or soundex(nickname1) = soundex(nickname3) or soundex(nickname1) = soundex(nickname4)) then weight2 = fname_Bayes;
		else if nickname2 ne "NOMTCH" then do;
			if (soundex(nickname2) = soundex(memfname) or soundex(nickname2) = soundex(nickname3) or soundex(nickname2) = soundex(nickname4)) then weight2 = fname_Bayes;
			else weight2 = fname_Bayes*(-1); 
				end;
		else weight2 = fname_Bayes*(-1); 
					end;
	else weight2 = fname_Bayes*(-1); 
END;
ELSE DO;
	if fname = "" or memfname = "" then do;
		weight2 = 0;
		cells = cells - 1;
			end;
	else if (sex in ("M","F") and memsex in ("M","F") and sex ne memsex) then weight2 = fname_Bayes*(-1);
	else if (fname = memfname or fname = nickname3 or fname = nickname4) then weight2 = fname_Bayes;
	else if nickname1 ne "NOMTCH" then do;
		if (nickname1 = memfname or nickname1 = nickname3 or nickname1 = nickname4) then weight2 = fname_Bayes;
		else if nickname2 ne "NOMTCH" then do;
			if (nickname2 = memfname or nickname2 = nickname3 or nickname2 = nickname4) then weight2 = fname_Bayes;
			else weight2 = fname_Bayes*(-1); 
				end;
		else weight2 = fname_Bayes*(-1); 
					end;
	else weight2 = fname_Bayes*(-1); 
END;


/*address*/
if address1 = "" or memaddress1 = "" then do;
	weight3 = 0;
	cells = cells - 1;
		end;
else if soundex(upcase(compbl(compress(address1,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890 ")))) = 
	soundex(upcase(compbl(compress(memaddress1,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890 ")))) and 
		substr(address1,1,indexc(address1,"QWERTYUIOPLKJHGFDSAZXCVBNM")-2) = substr(memaddress1,1,indexc(memaddress1,"QWERTYUIOPLKJHGFDSAZXCVBNM")-2)
			then weight3 = 0.9621*address1_Bayes;
else if ((soundex(upcase(compbl(compress(address1,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890 ")))) = 
	soundex(upcase(compbl(compress(memaddress1,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890 "))))) and 
		soundex(upcase(compbl(compress(address1,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890 ")))) not in ("POBOX","PO","BOX"))
			then weight3 = 0.8997*address1_Bayes;
else do;
	weight3 = 0;
	cells = cells - 1;
		end;
/*else weight3 = address1_Bayes*(-1); */

/*city/zip*/
if (city = "" or memcity = "") and (zip = "" or memzip = "" or zipcitydistance(zip,memzip) = .) then do;
	weight4 = 0;
	cells = cells - 1;
		end;
else if zip ne '' and zip=memzip then weight4 = zip_Bayes;
else if 0 le zipcitydistance(zip,memzip) le 10 then weight4 = zip_Bayes;
else if city = memcity then weight4 = city_Bayes;
else if zip ne "" and memzip ne "" then weight4 = zip_Bayes*(-1); 
else weight4 = city_Bayes*(-1);

/*phone*/
if phone = "" or memphone = "" then do;
	weight5 = 0;
	cells = cells - 1;
		end;
else if phone = memphone then weight5 = phone_Bayes;
else do;
	weight5 = 0;
	cells = cells - 1;
		end;
/*else weight5 = phone_Bayes*(-1); */

/*DOB*/
if DOB = . or memDOB = . then do;
	weight6 = 0;
	cells = cells - 1;
		end;
else if DOB = memDOB then weight6 = DOB_Bayes;
else weight6 = DOB_Bayes*(-1);

/*state*/
if state = "" or memstate = "" then do;
	weight7 = 0;
	cells = cells - 1;
		end;
else if state = memstate then weight7 = state_Bayes;
else weight7 = state_Bayes*(-1);

MatchScore = sum(of weight1-weight7);
MaxScore = sum(fname_Bayes,lname_Bayes,dob_Bayes,address1_Bayes,max(city_Bayes,zip_Bayes),state_Bayes,phone_Bayes);

drop 	fname_Bayes lname_Bayes dob_Bayes address1_Bayes city_Bayes state_Bayes zip_Bayes phone_Bayes
		nickname1-nickname4;

%mend edw_linking_compare;
