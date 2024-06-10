/*HEADER------------------------------------------------------------------------
|
| program:  empi_837_institutional.sas
|
| location: M:\ci\programs\standardmacros
|
| purpose:  assign appropriate enterprise_member_id system_member_id source_system_id depending upon client           
|
| input:    PatientAccountNumber, MedicalRecordNumber
|
| output:   enterprise_member_id system_member_id source_system_id
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 15NOV2011 - Winnie Lee  - Clinical Integration  1.0.01
|             Initiated
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
+-----------------------------------------------------------------------HEADER*/

%macro empi_837_institutional(client_id=);

	%if &client_id. = 6 %then %do;
		length system_member_id $50. source_system_id $3.;

			 if index(fac_name,"FLORIDA") 	   ge 1 then source_system_id = "400";
		else if index(fac_name,"CLEVELAND")    ge 1 then source_system_id = "050";
		else if index(fac_name,"FAIRVIEW") 	   ge 1 or 	
				index(fac_name,"LUTHERAN") 	   ge 1 then source_system_id = "210";
		else if index(fac_name,"LAKEWOOD") 	   ge 1 then source_system_id = "230";
		else if index(fac_name,"MARYMOUNT")    ge 1 then source_system_id = "240";
		else if index(fac_name,"EDINA") 	   ge 1 then source_system_id = "250";
		else if index(fac_name,"HILLCREST")    ge 1 then source_system_id = "310";
		else if index(fac_name,"EUCLID") 	   ge 1 then source_system_id = "320";
		else if index(fac_name,"HURON")		   ge 1 then source_system_id = "330";
		else if index(fac_name,"SOUTH POINTE") ge 1 or
				index(fac_name,"SOUTHPOINTE")  ge 1 then source_system_id = "340";

		if source_system_id = 50 then system_member_id = substr(MedicalRecordNumber,2,8);
		else system_member_id = MedicalRecordNumber;

		keep  	system_member_id source_system_id;
		drop	patientaccountnumber medicalrecordnumber;
	%end;

%mend empi_837_institutional;
