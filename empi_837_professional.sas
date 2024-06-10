/*HEADER------------------------------------------------------------------------
|
| program:  empi_837_professional.sas
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
| 08NOV2011 - Winnie Lee  - Clinical Integration  1.0.01
|             Initiated
|
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
+-----------------------------------------------------------------------HEADER*/

%macro empi_837_professional(client_id=);

	%if &client_id. = 6 %then %do;

	%end;

%mend empi_837_professional;
