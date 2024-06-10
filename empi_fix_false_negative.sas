
/*HEADER------------------------------------------------------------------------
|
| program:  empi_fix_false_negative.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Fix patient key false negatives
|
| logic:    
|
| input:    Macro parameters and /or SQL server practices
|           client_id   - the client id from vmine (e.g., 4=NSAP) 
|           wflow_exec_id - bpm work flow identifier
|           sk_prcs_ctrl_id - bpm process identifier
|                        
| output:   
|
| usage:     
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 06MAY2012 - G Liu - Clinical Integration 1.2.01 H02
|			  Original
+-----------------------------------------------------------------------HEADER*/


*SASDOC-----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*;
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*; 
%bpm_environment; 

*SASDOC--------------------------------------------------------------------------
| 
|
| 
------------------------------------------------------------------------SASDOC*; 
%macro empi_fix_false_negative;
	%bpm_process_control(timevar=START);

	%let sasprogramby='EMPI FIX FN';

	%let chrx_xref_cnt=0;
	proc sql noprint;
		select	count(*)
		into	:chrx_xref_cnt separated by ','
		from	vh_empi.patient_false_negative
		where	updated_wflow_exec_id=.
		and		client_key=&client_id.;
	quit;
	%put NOTE: Count in Patient False Negative table = &chrx_xref_cnt.;

	%let src_record_cnt=&chrx_xref_cnt.;

 %IF &chrx_xref_cnt=0 %THEN %DO;
	%put NOTE: There are no false negative patient keys to fix.;
 %END;
 %ELSE %DO;
	*SASDOC-------------------------------------------------------------------------
	| Update old mapping and insert new mapping of person_key to patient_key in VH_EMPI
	------------------------------------------------------------------------SASDOC*;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute (	update 	vh_empi.dbo.person_patient_map
					set		delete_flag=1, updated_wflow_exec_id=&wflow_exec_id., updated_on=getdate(), updated_by=&sasprogramby.
					from	vh_empi.dbo.person_patient_map a inner join
							vh_empi.dbo.patient_false_negative(nolock) b on a.client_key=b.client_key and a.patient_key=b.patient_key and a.delete_flag=0
					where	b.client_key=&client_id.
					and		b.updated_wflow_exec_id is null
				)
		by oledb;
	quit;

	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	insert	vh_empi.dbo.person_patient_map
						(	client_key, person_key, patient_key, delete_flag, created_wflow_exec_id, created_by	
					select	a.client_key, a.person_key, b.patient_key_xref, 0, &wflow_exec_id., &sasprogramby.
					from	vh_empi.dbo.person_patient_map a inner join
							vh_empi.dbo.patient_false_negative(nolock) b on a.client_key=b.client_key and a.patient_key=b.patient_key and a.delete_flag=1
					where	a.updated_wflow_exec_id=&wflow_exec_id.
				)
		by oledb;
	quit;

	*SASDOC-------------------------------------------------------------------------
	| Sync EDW to VH_EMPI
	------------------------------------------------------------------------SASDOC*;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update	ciedw.dbo.person_member_map
					set		member_key=b.patient_key, updated_on=b.created_on, updated_by=&sasprogramby.
					from	ciedw.dbo.person_member_map a inner join
							vh_empi.dbo.person_patient_map(nolock) b on a.client_key=b.client_key and a.person_key=b.person_key
					where	b.created_wflow_exec_id=&wflow_exec_id.
				)
		by oledb;
	quit;

	*SASDOC-------------------------------------------------------------------------
	| Update MEMBER_COMMENT_EVENT
	| This paragraph should be deprecated when member comment has PERSON_KEY
	------------------------------------------------------------------------SASDOC*;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute (	update	ciedw.dbo.member_comment_event
					set		patient_key=b.patient_key_xref,
							updated_by=&sasprogramby.,
							update_date=getdate()
					from	ciedw.dbo.member_comment_event a, vh_empi.dbo.patient_false_negative b
					where	a.patient_key=b.patient_key
					and		a.client_id=&client_id.
					and		b.updated_on is null
					and		b.client_key=&client_id.
				)
		by oledb;
	quit;

	*SASDOC-------------------------------------------------------------------------
	| Update FN table with updated to mark fix completion
	------------------------------------------------------------------------SASDOC*;
	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
	%end;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	select	distinct client_key, patient_key
					into	cihold.dbo.saswrk_bulkload_&wflow_exec_id.
					from	vh_empi.dbo.person_patient_map
					where	client_key=&client_id.
					and		updated_wflow_exec_id=&wflow_exec_id.
					and		delete_flag=1
				)
		by oledb;

		execute	(	update	vh_empi.dbo.patient_false_negative
					set		updated_wflow_exec_id=&wflow_exec_id., updated_on=getdate(), updated_by=&sasprogramby.
					from	vh_empi.dbo.patient_false_negative a inner join
							cihold.dbo.saswrk_bulkload_&wflow_exec_id. b on a.client_key=b.client_key and a.patient_key=b.patient_key
				)
		by oledb;
	quit;


	*SASDOC-------------------------------------------------------------------------
	| Update FN table with updated to mark fix completion
	------------------------------------------------------------------------SASDOC*;
	proc sql;
		create table eel_patient_key_fixed as
		select	patient_key
		from	vh_empi.patient_false_negative
		where	client_key=&client_id.
		and		updated_wflow_exec_id=&wflow_exec_id.;
	quit;

	%bulkload_to_cio(&wflow_exec_id.,eel_patient_key_fixed);
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update 	vh_empi.dbo.patient
					set		delete_flag=1, updated_wflow_exec_id=&wflow_exec_id., updated_on=getdate(), updated_by=&sasprogramby.
					from	vh_empi.dbo.patient p inner join
							cihold.dbo.saswrk_bulkload_&wflow_exec_id. on a.patient_key=b.patient_key
				)
		by oledb;
	quit;

	/* Do not delete records from ciedw.member table just yet because other tables have records tie to the member keys */
	

	proc sql noprint;
		select	count(*)
		into	:tgt_record_cnt separated by ','
		from	eel_patient_key_fixed;
	quit;

	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
	%end;
 %END;

	%bpm_process_control(timevar=COMPLETE);
%mend empi_fix_false_negative;

%empi_fix_false_negative;
