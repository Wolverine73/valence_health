/*HEADER------------------------------------------------------------------------
|
| program:  edw_empi_extract.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Create staging dataset for EMPI data  
|
| logic:    If EMPI data source exists, execute %empi_client_&client_id. macro
|              
| input:    Macro parameters
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|                        
| output:   EMPI staging dataset (cistage.empi_&client_id._&wflow_exec_id.)
|			Dataset from client-specific macro needs to have at least the
|				following variables:
|				file_received_date (datetime)
|				enterprise_member_id (char, max 50)
|				ssn, fname, mname, lname, sex, dob
|				address1, address2, city, state, zip, phone
|			If EMPI has system_member_id mapping to enterprise_member_id, you can
|				optionally create a cistage.empi_&client_id._&wflow_exec_id._syspersid
|				(or &incoming._syspersid) with the following 2 variables:
|				source_system_id (char, max 50)
|				system_member_id (char, max 50)
|				parent_source_system_id (optional if exists, char, max 50)
|				parent_system_member_id (optional if exists, char, max 50)
|			If EMPI has crosswalk for collapsed enterprise_member_id, you can
|				optionally create a cistage.empi_&client_id._&wflow_exec_id._xref
|				(or &incoming._xref) with the following 2 variables:
|				enterprise_member_id (char, max 50)
|				parent_enterprise_member_id (char, max 50)
|
+--------------------------------------------------------------------------------
| history:  
|
| 07NOV2011 - G Liu - Clinical Integration 2.0.01
|             Original
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 06MAY2012 - G Liu - Clinical Integration 1.2.01
|			  Add practice_id initialized from client_empi_check macro 
|			  Move source and target counts to client macro
+-----------------------------------------------------------------------HEADER*/

options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);

%bpm_environment;

%macro edw_empi_extract;
  %client_empi_check(&client_id.);
  %let practice_id=&empi_datasource_id.;

  %bpm_process_control(timevar=START);

  %IF &client_with_empi_indicator. %THEN %DO;

	%empi_client_&client_id.(cistage.empi_&client_id._&wflow_exec_id.);

	%If %sysfunc(exist(cistage.empi_&client_id._&wflow_exec_id._syspersid)) %Then %Do;
		%let dsn_id=%sysfunc(open(cistage.empi_&client_id._&wflow_exec_id._syspersid));
		%let dsn_parent_varind=%sysfunc(varnum(&dsn_id.,parent_source_system_id));
		%let dsn_rc=%sysfunc(close(&dsn_id.));

		%if &dsn_parent_varind.=0 %then %do;
			data cistage.empi_&client_id._&wflow_exec_id._syspersid;
				set cistage.empi_&client_id._&wflow_exec_id._syspersid;
				format parent_source_system_id parent_system_member_id $1.;
				call missing(parent_source_system_id,parent_system_member_id);
			run;
		%end;
	%End;

	%set_error_flag;
	%on_error(ACTION=ABORT);
  %END;

  %bpm_process_control(timevar=COMPLETE);
%mend edw_empi_extract;

%edw_empi_extract;
