
/*HEADER------------------------------------------------------------------------
|
| program:  edw_claims_reprocess_error.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Fix member keys in FALSE POSITIVE table
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
| 25APR2011 - G Liu  - Clinical Integration  1.0.01
|             Original
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
| 08JUN2012 - G Liu - Clinical Integration 1.3.01            
| 			  Remove any update to CIEDW transaction tables. Now, all member keys
|				will be dependent on the join to ciedw.person_member_map
| 20AUG2012 - G Liu/B Fletcher - Clinical Integration 1.5.01
|			  Insert into PPM new mapping under the current running wflow_exec_id
|				instead of the wflow id that created the false positive record
|				to allow for manual wflow ids to trickle correctly downstream
| 20AUG2012 - G Liu - Clinical Integration 1.5.02 H03
|			  Construct member record dynamically based on metadata from table
|				vh_empi.dbo.patient_attribute_methodology
+-----------------------------------------------------------------------HEADER*/


/*SASDOC-----------------------------------------------------------------------
| Define SAS macros for program    
| 
+----------------------------------------------------------------------SASDOC*/
options sasautos = ("M:\CI\programs\StandardMacros" "M:\CI\programs\ClientMacros" sasautos);


/*SASDOC--------------------------------------------------------------------------
| Standard Assignments 
|
+------------------------------------------------------------------------SASDOC*/
%bpm_environment; 


%macro edw_claims_reprocess_error;
	%let sasprogramby='EMPI FIX FP';

	%let ecre_fp_cnt=0;
	proc sql noprint;
		select	count(distinct person_key)
		into	:ecre_fp_cnt separated by ','
		from	vh_empi.person_patient_false_positive
		where	updated_wflow_exec_id=.
		and		client_key=&client_id.;
	quit;
	%put NOTE: Count in FALSE POSITIVE table = &ecre_fp_cnt.;

	%let src_record_cnt=&ecre_fp_cnt.;

 %IF &ecre_fp_cnt.=0 %THEN %DO;
	%put NOTE: There are no patient keys to reprocess FALSE POSITIVE.;
 %END;
 %ELSE %DO;
	/*SASDOC-------------------------------------------------------------------------
	| Update old mapping and insert new mapping of person_key to patient_key in VH_EMPI
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	update 	vh_empi.dbo.person_patient_map
					set 	delete_flag=1, updated_wflow_exec_id=&wflow_exec_id., updated_on=getdate(), updated_by=&sasprogramby.
					from	vh_empi.dbo.person_patient_map(nolock) a inner join
							vh_empi.dbo.person_patient_false_positive(nolock) b on a.client_key=b.client_key and a.person_key=b.person_key and a.patient_key=b.patient_key and a.delete_flag=0
					where	b.client_key=&client_id.
					and		b.updated_wflow_exec_id is null
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	insert into vh_empi.dbo.person_patient_map
						(	client_key, person_key, patient_key, delete_flag, created_wflow_exec_id, created_by)
					select	distinct b.client_key, b.person_key, b.new_patient_key, 0, &wflow_exec_id., &sasprogramby.
					from	vh_empi.dbo.person_patient_map(nolock) a inner join
							vh_empi.dbo.person_patient_false_positive(nolock) b on a.client_key=b.client_key and a.person_key=b.person_key and a.patient_key=b.patient_key and
																				   a.updated_wflow_exec_id=&wflow_exec_id. and a.delete_flag=1
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	/*SASDOC-------------------------------------------------------------------------
	| Update FP table with updated to mark fix completion
	------------------------------------------------------------------------SASDOC*/
	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
	%end;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	select	distinct client_key, person_key, patient_key
					into	cihold.dbo.saswrk_bulkload_&wflow_exec_id.
					from	vh_empi.dbo.person_patient_map(nolock)
					where	client_key=&client_id.
					and		updated_wflow_exec_id=&wflow_exec_id.
					and		delete_flag=1
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update	vh_empi.dbo.person_patient_false_positive
					set		updated_wflow_exec_id=&wflow_exec_id., updated_on=getdate(), updated_by=&sasprogramby.
					from	vh_empi.dbo.person_patient_false_positive a inner join
							cihold.dbo.saswrk_bulkload_&wflow_exec_id. b on a.client_key=b.client_key and a.person_key=b.person_key and a.patient_key=b.patient_key
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	/*SASDOC-------------------------------------------------------------------------
	| Logically delete patient_key from VH_EMPI database
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		create table eel_patient_key_fixed as
		select	distinct patient_key
		from	vh_empi.person_patient_false_positive
		where	client_key=&client_id.
		and		updated_wflow_exec_id=&wflow_exec_id.;
	quit;

	%bulkload_to_cio(&wflow_exec_id.,eel_patient_key_fixed)
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update 	vh_empi.dbo.patient
					set		delete_flag=1, updated_wflow_exec_id=&wflow_exec_id., updated_on=getdate(), updated_by=&sasprogramby.
					from	vh_empi.dbo.patient p inner join
							cihold.dbo.saswrk_bulkload_&wflow_exec_id. a on p.patient_key=a.patient_key
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	/*SASDOC-------------------------------------------------------------------------
	| Construct patient record
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table construct_want_patient as
		select	*
		from	connection to oledb
				(	select	distinct client_key, patient_key
					from	vh_empi.dbo.person_patient_map(nolock)
					where	client_key=&client_id.
					and		created_wflow_exec_id=&wflow_exec_id.
					and		delete_flag=0
				);
	quit;
	%edw_construct_member_record(construct_want_patient,&client_id.,&wflow_exec_id.,&sasprogramby.)

	/*SASDOC-------------------------------------------------------------------------
	| Flip is_ci_data and is_payer_data.
	| This is not the best way to do this. When we split say husband and wife, we don't
	|	really know who has payer and who has CI only, etc. For now we just code it
	|	based on the old member key. Permanent solution should be something like
	|	Date of Death where EMPI database has tables that keeps track of these things
	|	by person key, and when we construct member record, these columns get 
	|	reconstructed based on what person key that rolls up to the member key.
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	select	distinct a.client_key, new_patient_key, patient_key as old_patient_key, b.is_ci_data, b.is_payer_data
					into	cihold.dbo.saswrk_false_positive_&wflow_exec_id.
					from	vh_empi.dbo.person_patient_false_positive(nolock) a, ciedw.dbo.member(nolock) b
					where	a.client_key=b.client_key and a.patient_key=b.member_key
					and		a.client_key=&client_id.
					and		a.updated_wflow_exec_id=&wflow_exec_id.
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		execute	(	update	ciedw.dbo.member
					set		is_ci_data=b.is_ci_data, is_payer_data=b.is_payer_data
					from	ciedw.dbo.member a, cihold.dbo.saswrk_false_positive_&wflow_exec_id. b
					where	a.client_key=b.client_key and a.member_key=b.new_patient_key
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)

	proc sql; drop table cihold.saswrk_false_positive_&wflow_exec_id.; quit;

	/*SASDOC-------------------------------------------------------------------------
	| Sync EDW to VH_EMPI
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update	ciedw.dbo.person_member_map
					set		member_key=b.patient_key, update_date=b.created_on, updated_by=&sasprogramby.
					from	ciedw.dbo.person_member_map(nolock) a inner join
							vh_empi.dbo.person_patient_map(nolock) b on a.client_key=b.client_key and a.person_key=b.person_key and b.delete_flag=0
					where	b.created_wflow_exec_id=&wflow_exec_id.
				)
		by oledb;
	quit;
    %set_error_flag
    %on_error(ACTION=ABORT)


	/*SASDOC-------------------------------------------------------------------------
	| Update MEMBER_COMMENT_EVENT
	| There is no solution to fix member comment for false positive yet
	------------------------------------------------------------------------SASDOC*/




	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
	%end;
 %END;
%mend edw_claims_reprocess_error;

%edw_claims_reprocess_error;
