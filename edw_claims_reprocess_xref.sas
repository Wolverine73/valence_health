
/*HEADER------------------------------------------------------------------------
|
| program:  edw_claims_reprocess_xref.sas
|
| location: M:\CI\programs\EDW
|
| purpose:  Map member keys in XREF table
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
| 23JAN2012 - G Liu - Clinical Integration 1.1.02
|			  Added logic to handle member keys in LAB_CLINICAL_PANEL table
|			  Added member key from and member key to for tables without client
|				key to ensure this program only handles for the specified clientid
|			  Delete member keys from member table last due to FK constraints
| 08JUN2012 - G Liu - Clinical Integration 1.3.01            
| 			  Remove any update to CIEDW transaction tables. Now, all member keys
|				will be dependent on the join to ciedw.person_member_map
| 13JUN2012 - G Liu - Clinical Integration 1.3.02
|			  Removed comment_event paragraph
| 07AUG2012 - G Liu - Clinical Integration 1.5.01 
|			  Temporary stop gap fix to make sure we carry over is_payer_data=1 
|				and is_ci_data=1 when collapsing. This is NOT the best way to do
|				it. Ideally VH_EMPI database should have a is_payer_data and 
|				is_ci_data attribute in the person table, then when constructing
|				the member record, we take those attributes into account.
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


%macro edw_claims_reprocess_xref;
	%bpm_process_control(timevar=START)

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
	/*SASDOC-------------------------------------------------------------------------
	| Update old mapping and insert new mapping of person_key to patient_key in VH_EMPI
	------------------------------------------------------------------------SASDOC*/
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
						(	client_key, person_key, patient_key, delete_flag, created_wflow_exec_id, created_by)
					select	distinct a.client_key, a.person_key, b.patient_key_xref, 0, &wflow_exec_id., &sasprogramby.
					from	vh_empi.dbo.person_patient_map a inner join
							vh_empi.dbo.patient_false_negative(nolock) b on a.client_key=b.client_key and a.patient_key=b.patient_key and a.delete_flag=1
					where	a.updated_wflow_exec_id=&wflow_exec_id.
				)
		by oledb;
	quit;

	/*SASDOC-------------------------------------------------------------------------
	| Sync EDW to VH_EMPI
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	update	ciedw.dbo.person_member_map
					set		member_key=b.patient_key, update_date=b.created_on, updated_by=&sasprogramby.
					from	ciedw.dbo.person_member_map a inner join
							vh_empi.dbo.person_patient_map(nolock) b on a.client_key=b.client_key and a.person_key=b.person_key
					where	b.created_wflow_exec_id=&wflow_exec_id.
				)
		by oledb;
	quit;

	/*SASDOC-------------------------------------------------------------------------
	| Update FN table with updated to mark fix completion
	------------------------------------------------------------------------SASDOC*/
	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
	%end;
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute	(	select	distinct client_key, patient_key
					into	cihold.dbo.saswrk_bulkload_&wflow_exec_id.
					from	vh_empi.dbo.person_patient_map(nolock)
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

	/*SASDOC-------------------------------------------------------------------------
	| Construct patient record
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create table construct_want_patient as
		select	&client_id. as client_key, patient_key
		from	connection to oledb
				(	select	distinct patient_key_xref as patient_key
					from	vh_empi.dbo.patient_false_negative(nolock)
					where	client_key=&client_id.
					and		updated_wflow_exec_id=&wflow_exec_id.
				);
	quit;
	%edw_construct_member_record(construct_want_patient,&client_id.,&wflow_exec_id.,&sasprogramby.)

	/*SASDOC-------------------------------------------------------------------------
	| Temporary stop gap fix to make sure we carry over is_payer_data=1 
	|	and is_ci_data=1 when collapsing. This is NOT the best way to do
	|	it. Ideally VH_EMPI database should have a is_payer_data and 
	|	is_ci_data attribute in the person table, then when constructing
	|	the member record, we take those attributes into account.
	------------------------------------------------------------------------SASDOC*/
	/* NOTE!!! Delete this section when we have is_payer_data and is_ci_data in VH_EMPI database. */
	proc sql;
		connect to oledb(init_string=&sqlci.);
		execute (	update	newmem
					set		is_payer_data = case when oldmem.is_payer_data = 1 then oldmem.is_payer_data else newmem.is_payer_data end,
     						is_ci_data    = case when oldmem.is_ci_data = 1 then oldmem.is_ci_data else newmem.is_ci_data end,
							updated_on	  = getdate(),
							updated_by	  = convert(varchar(50),ltrim(rtrim(fn.updated_wflow_exec_id)))
					from	vh_empi.dbo.patient_false_negative(nolock) fn inner join
				            ciedw.dbo.member(nolock) oldmem on fn.client_key=oldmem.client_key and fn.patient_key=oldmem.member_key inner join
				            ciedw.dbo.member(nolock) newmem on fn.client_key=newmem.client_key and fn.patient_key_xref=newmem.member_key
					where	fn.client_key=&client_id.
					and		fn.updated_wflow_exec_id=&wflow_exec_id.
					and (	oldmem.is_payer_data=1 and newmem.is_payer_data=0
	 					 or oldmem.is_ci_data=1 and newmem.is_ci_data=0			)
				)
		by oledb;
	quit;

	/*SASDOC-------------------------------------------------------------------------
	| Logically delete patient_key from VH_EMPI database
	------------------------------------------------------------------------SASDOC*/
	proc sql;
		create table eel_patient_key_fixed as
		select	patient_key
		from	vh_empi.patient_false_negative
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

	/* There should be a step to reconstruct the patient record based on the collapsed demographics, but since
		we have never done that in the past, and we will be coming up with new and better logic for that,
		by incorporating svcdt appropriately when necessary, we will defer this to R1.3 */
	proc sql noprint;
		select	count(*)
		into	:tgt_record_cnt separated by ','
		from	eel_patient_key_fixed;
	quit;

	%if %sysfunc(exist(cihold.saswrk_bulkload_&wflow_exec_id.)) %then %do;
		proc sql; drop table cihold.saswrk_bulkload_&wflow_exec_id.; quit;
	%end;
 %END;

	%bpm_process_control(timevar=COMPLETE)
%mend edw_claims_reprocess_xref;

%edw_claims_reprocess_xref
