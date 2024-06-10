
/*HEADER------------------------------------------------------------------------
|
| Program:  HL7Load.sas
|
| Location: M:\CI\programs\StandardMacros
+--------------------------------------------------------------------------------
| History:  
| 30AUG2011 - Brandon Barber / Production
| 
+--------------------------------------------------------------------------------
| Notes:  
| 30AUG2011 - Brandon Barber
|			  If your name is not Brandon Barber, DO NOT MODIFY THIS CODE.
|
+-----------------------------------------------------------------------HEADER*/


%macro HL7Load(Client,ClientID);

options error=2 noxwait;
libname memdb oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQLCI;Initial Catalog=EAVHL7Master";

%if "&ClientID." = "4" %then %do;

	libname labout "M:\NSAP\sasdata\CI\CIETL\lab";

%end;

%else %if "&ClientID." = "6" %then %do;

	libname labout "M:\CCCPP\sasdata\CIETL\lab";

%end;

%else %if "&ClientID." = "7" %then %do;

	libname labout "M:\OHG\SASDATA\CIETL\Lab";

%end;

%else %if "&ClientID." = "8" %then %do;

	libname labout "M:\Exempla\SASDATA\CIETL\lab";

%end;
    
 %else %if "&ClientID." = "11" %then %do;

	libname labout "M:\Ingalls\sasdata\CIETL\lab";

%end;

%macro diagcd_cleanup(m_invar,m_outvar);
                  &m_invar.=compress(&m_invar.);
                  if &m_invar. in: ('0','1','2','3','4','5','6','7','8','9','V') then do;
                        if substr(&m_invar.,4,1)='.' and length(&m_invar.) in (5,6) or length(&m_invar.)=3 then &m_outvar.=&m_invar.; /*good values*/
                        else if length(&m_invar.) in (4,5) then &m_outvar.=substr(&m_invar.,1,3)||'.'||substr(&m_invar.,4); /*add period*/
                        else &m_outvar.=&m_invar.; /*bad values, output as is*/
                  end;
            else if &m_invar. =: 'E' then do;
                        if substr(&m_invar.,5,1)='.' and length(&m_invar.)=6 or length(&m_invar.)=4 then &m_outvar.=&m_invar.; /*good values*/
                        else if length(&m_invar.)=5 then &m_outvar.=substr(&m_invar.,1,4)||'.'||substr(&m_invar.,5); /*add period*/
                        else &m_outvar.=&m_invar.; /*bad values, output as is*/
                  end;
                  else &m_outvar.=&m_invar.; /*bad values, output as is*/
%mend diagcd_cleanup;

%let maxID = 0;

%if %sysfunc(exist(labout.&client._HL7)) %then %do;

	proc sql noprint;
	 select max(ID)
	 into:maxID
	 from labout.&client._HL7;
	quit;

		%end;

%put &maxID.;

data lab1 (compress=yes);
length 	PatientAccountNumber InternalPatientID ExternalPatientID AlternatePatientID $20. SendingFacility ReceivingFacility SendingApplication ReceivingApplication 
		AlternateFacility $50. AccountNumber $10. FName MName $15. LName $25. NPI NPI_ $10. upin_ $6. ProvFirst $15. ProvLast $25. Sex $1. 
		SSN $9. Address1-Address2 $50. City $25. State $2. Zip $5. phone $10. AttendingNumber $15. AttendingLastName $25. 
		AttendingFirstName $15. AttendingIDCode OrderingProvider $15. Diag1 $6. TestName TestName_ $50. TestNum $20. proccd $5. SubtestName 
		SubtestName_ $50. SubtestNum $20. Units $20. Unit_Desc $50. Normal_High_Low $25. Result $10. Result_Abnormal_CD OBR_ResultStatus OBX_ResultStatus $1. 
		DOB ReceivedDate Obs_Start_Date Obs_End_Date Observation_Date Transaction_Date svcdt 4.
		provid $10. provname $50. loinccd $7.
		;
set memdb.LabTestResultMaster (where = (ClientID=&ClientID. and ID > &maxID.));

PatientAccountNumber 	= cats(PID_F18_C1);
InternalPatientID 		= cats(PID_F3_C1);
ExternalPatientID 		= cats(PID_F2_C1);
AlternatePatientID 		= cats(PID_F4_C1);
SSN 					= cats(PID_F19_C1);
fname 					= cats(PID_F5_C1);
mname 					= cats(PID_F5_C3);
lname 					= cats(PID_F5_C2);
sex 					= cats(PID_F8_C1);
DOB 					= input((substr(PID_F7_C1,5,2)||"/"||substr(PID_F7_C1,7,2)||"/"||substr(PID_F7_C1,1,4)),mmddyy10.);
address1 				= cats(PID_F11_C1);
address2 				= cats(PID_F11_C2);
city 					= cats(PID_F11_C3);
state 					= cats(PID_F11_C4);
zip 					= cats(PID_F11_C5);
phone 					= cats(PID_F13_C1);
AlternateFacility 		= cats(PID_F3_C5);

AttendingNumber 		= cats(PV1_F7_C1);
AttendingLastName 		= cats(PV1_F7_C2);
AttendingFirstName 		= cats(PV1_F7_C3);
AttendingIDCode 		= cats(PV1_F7_C13);
NPI 					= cats(PV1_F8_C1);

SendingFacility 		= cats(MSH_F4_C1);
ReceivingFacility 		= cats(MSH_F6_C1);
SendingApplication 		= cats(MSH_F3_C1);
ReceivingApplication 	= cats(MSH_F5_C1);

AccountNumber 			= cats(ORC_F21_C3);
Transaction_Date 		= input((substr(ORC_F9_C1,5,2)||"/"||substr(ORC_F9_C1,7,2)||"/"||substr(ORC_F9_C1,1,4)),mmddyy10.);

testName 				= cats(OBR_F4_C2);
testName_ 				= cats(OBR_F4_C5);
testNum 				= cats(OBR_F4_C1);
ReceivedDate 			= input((substr(OBR_F14_C1,5,2)||"/"||substr(OBR_F14_C1,7,2)||"/"||substr(OBR_F14_C1,1,4)),mmddyy10.);
Obs_Start_Date 			= input((substr(OBR_F7_C1,5,2)||"/"||substr(OBR_F7_C1,7,2)||"/"||substr(OBR_F7_C1,1,4)),mmddyy10.);
Obs_End_Date 			= input((substr(OBR_F8_C1,5,2)||"/"||substr(OBR_F8_C1,7,2)||"/"||substr(OBR_F8_C1,1,4)),mmddyy10.);
OBR_ResultStatus 		= cats(OBR_F25_C1);
OrderingProvider 		= cats(OBR_F16_C13);
upin_ 					= cats(OBR_F16_C1);
provfirst				= cats(OBR_F16_C3);
provlast 				= cats(OBR_F16_C2);
if provfirst ne "" then provname = cats(provlast) || ", " || cats(provfirst);
else provname			= cats(provlast);

if substr(cats(OBR_F16_C8),index(cats(OBR_F16_C8),"~")+1,1) ne "^" then NPI_ = substr(cats(OBR_F16_C8),index(cats(OBR_F16_C8),"~")+1,10);

subtestName 			= cats(OBX_F3_C5);
subtestName_ 			= cats(OBX_F3_C2);
subtestNum 				= cats(OBX_F3_C4);
units 					= cats(OBX_F6_C1);
unit_Desc 				= cats(OBX_F6_C2);
result 					= cats(OBX_ResultData);
Result_Abnormal_CD 		= cats(OBX_F8_C1);
OBX_ResultStatus 		= cats(OBX_F11_C1);
Observation_Date 		= input((substr(OBX_F14_C1,5,2)||"/"||substr(OBX_F14_C1,7,2)||"/"||substr(OBX_F14_C1,1,4)),mmddyy10.);

svcdt 					= Obs_Start_Date;

if upcase(cats(MSH_F4_C1)) = "LABCORP" then do;

	provid 				= NPI;
	loinccd				= cats(OBX_F3_C1);
	diag1 				= "";
	proccd 				= "";
	Normal_High_Low		= cats(OBX_F7_C1);

		end;

else if upcase(cats(MSH_F4_C1)) = "QUEST DIAGNOSTICS" then do;

if "&ClientID." = "6" and cats(AccountNumber) in ("390008","308192","303174","304232","301977") then delete;

	provid 				= NPI_;
	loinccd				= cats(OBX_F3_C1);
	proccd 				= cats(OBR_F44_C1);
	if cats(OBX_F7_C1) = "" and cats(OBX_F7_C2) = "" then Normal_High_Low = cats(OBX_F7_C3);
	else Normal_High_Low = cats(OBX_F7_C1) || "-" || cats(OBX_F7_C2);
	%diagcd_cleanup(DG1_F3_C1,diag1);

		end;

else if "&ClientID." = "6" then do;

	provid 				= NPI;
	loinccd				= cats(OBR_F4_C4);
	diag1 				= "";
	proccd 				= "";
	Normal_High_Low		= cats(OBX_F7_C1);

		end;

else if upcase(cats(MSH_F3_C1)) = "LAB" and upcase(cats(MSH_F4_C1)) = "IMH" then do;

	provid 				= NPI;
/*	loinccd				= put(cats(OBX_F3_C1),$.);*/
	diag1 				= "";
	proccd 				= "";
	Normal_High_Low		= cats(OBX_F7_C1);

		end;

format 	DOB ReceivedDate Obs_Start_Date Obs_End_Date Observation_Date Transaction_Date svcdt mmddyy10.
		PatientAccountNumber InternalPatientID ExternalPatientID AlternatePatientID $20. SendingFacility ReceivingFacility AlternateFacility
		SendingApplication ReceivingApplication $50. AccountNumber $10. FName MName $15. LName $25. NPI NPI_ $10. upin_ $6. ProvFirst $15. 
		ProvLast $25. Sex $1. AttendingNumber $15. AttendingLastName $25. AttendingFirstName $15. AttendingIDCode OrderingProvider $15. 
		SSN $9. Address1 $50. City $25. State $2. Zip $5. phone $10. Diag1 $6. TestName TestName_ $50. TestNum $20.
		SubtestName SubtestName_ $50. SubtestNum $20. Units $20. Unit_Desc $50. Normal_High_Low $25. Result $10. Result_Abnormal_CD OBR_ResultStatus OBX_ResultStatus $1.
		provid $10. provname $50. loinccd $7.
		;

drop 	PID_F11_C1 PID_F11_C2 PID_F11_C3 PID_F11_C4 PID_F11_C5 PID_F13_C1 PID_F18_C1 PID_F19_C1 PID_F2_C1 PID_F3_C1 PID_F3_C5 PID_F4_C1 PID_F5_C1 PID_F5_C2 
		PID_F5_C3 PID_F7_C1 PID_F8_C1 
		MSH_F3_C1 MSH_F4_C1 MSH_F5_C1 MSH_F6_C1 MSH_F9_C1 MSH_F9_C2 MSH_F12_C1 
		DG1_F3_C1 DG1_F3_C2 DG1_F3_C3 DG1_F3_C4 
		ORC_F9_C1 ORC_F12_C1 ORC_F12_C2 ORC_F12_C3 ORC_F12_C8 ORC_F12_C9 ORC_F12_C10 ORC_F12_C15 ORC_F21_C1 ORC_F21_C3
		OBR_F14_C1 OBR_F16_C1 OBR_F16_C2 OBR_F16_C3 OBR_F16_C8 OBR_F16_C13 OBR_F25_C1 OBR_F44_C1 OBR_F4_C1 OBR_F4_C2 OBR_F4_C4 OBR_F4_C5 OBR_F7_C1 OBR_F8_C1 
		OBX_F11_C1 OBX_F14_C1 OBX_F3_C1 OBX_F3_C2 OBX_F3_C4 OBX_F3_C5 OBX_F6_C1 OBX_F6_C2 OBX_F7_C1 OBX_F7_C2 OBX_F7_C3 OBX_F8_C1 OBX_RESULTDATA 
		PV1_F7_C1 PV1_F7_C2 PV1_F7_C3 PV1_F7_C13 PV1_F8_C1 PV1_F8_C2 PV1_F8_C3 PV1_F8_C13 
		clientID messageID AttendingNumber AttendingLastName AttendingFirstName AttendingIDCode NPI NPI_ upin_ unit_desc Obs_Start_Date Obs_End_Date ReceivedDate
		;
run;

proc append base=labout.&client._HL7 data=lab1 force;
run;

/*data labout.&client._HL7 (compress=yes);*/
/*set lab1;*/
/*run;*/

%mend HL7Load;      
