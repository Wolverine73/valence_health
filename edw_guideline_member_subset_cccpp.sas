/*HEADER-----------------------------------------------------------------------------------------------------------------------------
|
| program:  edw_guideline_member_subset.sas
|
| location: 
+-------------------------------------------------------------------------------------------------------------------------------------
| history:  
| 06JUN2012 - RS Modify to use member view (instead of member table) being deployed in Release 1.3
| 24JUL2012 - RS Modify further for member view usage
| 09AUG2012 - EM No longer outputting a permanent SAS dataset because the member table in SQL only gets modified when a g0 gets created
+-------------------------------------------------------------------------------------------------------------------------------HEADER*/

%macro edw_guideline_member_subset_cccpp;


%let apst = %str(%');
data _null_;
      format curr_dt prior_dt $12.;
	  k = intnx('month',today(),-&lag_number.,'same');
	  mon1 = month(k);
	  year1 = year(k);
	  gl_enddt = "&apst."||put(mdy(cats(mon1),'01',cats(year1)),date9.)||"&apst."||"d";
	  cdate = put(mdy(cats(mon1),'01',cats(year1)),date9.);
	  pdate = put(mdy(cats(mon1),'01',cats(year1 - 1)),date9.);	  
	  curr_dt = "&apst."||(cats(year1))||'-'||(cats(mon1))||'-'||'01'||"&apst.";
	  prior_dt = "&apst."||(cats(year1 - 1))||'-'||(cats(mon1))||'-'||'01'||"&apst.";
	  call symput('gl_enddt',gl_enddt);   /** current end date **/
	  call symput ('current_date',curr_dt);
	  call symput ('prior_date',prior_dt);
	  call symput ('c_date',cdate);
	  call symput ('p_date',pdate);	  
	run;

%put &gl_enddt.;
%put &current_date.;
%put &prior_date.;
%put &c_date.;
%put &p_date.;


		%if %sysfunc(exist(cihold.gline_member_&client_id._20120526)) %then %do;
		    proc sql;
		      connect to oledb(init_string=&cihold.);
		      execute ( 
		                drop table [cihold].[dbo].[gline_member_&client_id._20120526]  
		              ) 
		      by oledb; 
		    quit;
		%end;



proc sql;
	      connect to oledb(init_string=&sqlci.);
	      execute (
		  declare @cdate datetime = &current_date.
		  declare @pdate datetime = &prior_date.

				 select distinct e.member_key
                  ,a.client_key
                  ,dob
				  ,sex
				  ,date_of_death
				  ,FLOOR((DATEDIFF(mm,dob,@cdate) - (case when DAY(@cdate) < DAY(dob) then 1 else 0 end))/12) as ager_current
				  ,FLOOR((DATEDIFF(mm,dob,@pdate) - (case when DAY(@pdate) < DAY(dob) then 1 else 0 end))/12) as ager_prior
				  

				  ,case when (c.PROCEDURE_CODE in('99377','99378','1150F','1152F','G0182','Q5001','Q5002','Q5003','Q5004','Q5005','Q5006','Q5007','Q5008',
                              'Q5009','S9126','T2042','T2043','T2044','T2045','T2046') 
					or DIAGNOSIS_CD2='V66.7'
					or DIAGNOSIS_CD3='V66.7'
					or DIAGNOSIS_CD4='V66.7'
					or DIAGNOSIS_CD5='V66.7'
					or DIAGNOSIS_CD6='V66.7'
					or DIAGNOSIS_CD7='V66.7'
					or DIAGNOSIS_CD8='V66.7'
					or DIAGNOSIS_CD9='V66.7') then service_date                          
				 else NULL end as hspc_adm_dt
				 ,GETDATE() as created_on

				,CASE when (c.PROCEDURE_CODE IN('99304','99305','99306','99307','99308','99309','99310','99318','99324','99325','99326',
                               '99327','99328','99334','99335','99336','99337','99339','99340')
            			OR (POS IN('32','33') and c.PROCEDURE_CODE not in ('99325','99316'))) then 1
            	else 0 end as nh_flag

				into #gline_member_temp

				from [ciedw].[dbo].[ENCOUNTER_HEADER] a inner join [ciedw].[dbo].[ENCOUNTER_DETAIL] b
				on a.ENCOUNTER_KEY=b.ENCOUNTER_KEY left outer join [ciedw].[dbo].[PERSON_MEMBER_MAP] e
				on a.client_key=e.client_key and a.PERSON_KEY=e.PERSON_KEY left outer join [ciedw].[dbo].[V_ACTIVE_MEMBER] f	
				on e.MEMBER_KEY=f.MEMBER_KEY left outer join [ciedw].[dbo].[PROCEDURE_CD] c
				on b.PROCEDURE_CODE_KEY=c.PROCEDURE_CODE_KEY
				where a.CLIENT_KEY=&client_id.				       

		select member_key, dob, sex, date_of_death, ager_current, ager_prior, created_on, max(nh_flag) as nh_fl,
             min(hspc_adm_dt) as hospice_dt

			  into [cihold].[dbo].[gline_member_&client_id._20120526]

			from #gline_member_temp
		group by member_key,dob,sex,date_of_death,ager_current,ager_prior,created_on

				 create index IX_ager_current on [cihold].[dbo].[gline_member_&client_id._20120526] (ager_current)
				 create index IX_ager_prior on [cihold].[dbo].[gline_member_&client_id._20120526] (ager_prior)
				 create index IX_dob on [cihold].[dbo].[gline_member_&client_id._20120526] (dob)
				 create index IX_sex on [cihold].[dbo].[gline_member_&client_id._20120526] (sex)
				 create index IX_key on [cihold].[dbo].[gline_member_&client_id._20120526] (member_key)
				 
			      
	             ) 
	      by oledb; 
	    quit;
   

%mend;

%edw_guideline_member_subset_cccpp;
