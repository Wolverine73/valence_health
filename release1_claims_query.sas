/*HEADER------------------------------------------------------------------------
|
| program:  release1_claims_query.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Macro to pull down EDW vlabclme for each client. For Release 1.0 
| (v3.0 of Guidelines), this only needs to be done once before registry,
| care elements, and guidelines are run. 
|
+--------------------------------------------------------------------------------
| history:  
| 21DEC2011 - LS original
| 22DEC2011 - LS per dw KN, BS, RB: use max_proc_date not svcdt
| 15JAN2012 - LS modify query to grab lab values 
| 22FEB2012 - LS incorporate NULL date_of_death into query.
| 05MAR2012 - EM now keeping units (LabObsUnitOfMeasure) from vGuidelineInput
| 08MAR2012 - LS keep abnormal_values, normal_range per EM/lab results needs.
| 03MAY2012 - LS per dw KN/TB no longer save out to cistage but keep in work
| 10MAY2012 - LS implement length statements
| 07JUN2012 - LS modify logic to pull 9 diags for PHS in addition to CCCPP. 
| 13JUN2012 - LS modify logic to determine how many diags to pull down based on what PM
|			  enters for number_diags in the FG.
| 06JUL2012 - EM Added OBX_F2 field to the query
+-----------------------------------------------------------------------HEADER*/


%macro release1_claims_query;
	%if &number_diags. = 9 %then %do;
/*	%if (%QUPCASE("&client.") = "CCCPP"  or %QUPCASE("&client.") = "PHS")  %then %do;*/
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table edw_labclme as  
			 select  member_key format 16. length 8
					,sex
					,datepart(svcdt2) format mmddyy10. length 4 as svcdt 
					,client_key format 4. length 4
					,diag1 format $6. length 6
					,diag2 format $6. length 6
					,diag3 format $6. length 6
					,diag4 format $6. length 6
					,diag5 format $6. length 6
					,diag6 format $6. length 6
					,diag7 format $6. length 6
					,diag8 format $6. length 6
					,diag9 format $6. length 6
					,loinc format $7. length 7
					,strip(proccd) format $5.length 5 as proccd
					,strip(revcd) format $4. length 4 as revcd 
					,strip(upcase(mod1)) format $3. length 3 as mod1 
					,strip(mod2) format $3. length 3 as mod2
					,surg1 format $5. length 5
					,datepart(admdt) format mmddyy10. length 4 as admdt2
					,datepart(disdt) format mmddyy10. length 4 as disdt2 
					,majcat format 3. length 3
					,provspec format $2. length 2
					,encounter_key 
					,dis_cond format $3. length 3
					,pos format $2. length 2
					,provid
					,source format $2. length 2
					,tin	
					,datepart(dob) format mmddyy10. length 4 as dob1
					,datepart(max_proc_date) format mmddyy10. length 4 as max_proc_date
					,labobsvalue format $50. length 50 as value_character 
					,input(labobsvalue,best16.) as value_numeric 
					,LabObsUnitOfMeasure format $14. length 14 as units 
					,databand
					,LabObsNormalRange format $60. length 60 as normal_range 
					,LabObsAbnormal format $5. length 5 as abnormal_values
					,OBX_F2 format $3. length 3 as OBX_F2
				
					from 
						(select * from connection to oledb  
							(select member_key, sex,svcdt2 ,client_key ,diag1,diag2 ,diag3, diag4, diag5, diag6, diag7, diag8,diag9,loinc,
							proccd ,revcd,mod1,mod2,surg1 ,admdt ,disdt,majcat,provspec,dob,dis_cond, pos, provid,source,tin,encounter_key,
							labobsvalue, LabObsUnitOfMeasure, databand, max_proc_date, date_of_death, LabObsNormalRange, LabObsAbnormal, OBX_F2
								from dbo.vGuidelineInput 
									where 
										(client_key = &client_key. 
										and max_proc_date >= &p_stdt. 
										and member_key not in (-99) 
										and date_of_death is NULL)

											order by member_key, svcdt2	))	;
				disconnect from oledb;
			quit;
	%end;

	%else %if &number_diags. = 3 %then %do;
/*	%else %if (%QUPCASE("&client.") ne "CCCPP"  and %QUPCASE("&client.") ne "PHS") %then %do;*/
		proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table edw_labclme as  
			 select  member_key format 16. length 8
					,sex
					,datepart(svcdt2) format mmddyy10. length 4 as svcdt 
					,client_key format 4. length 4
					,diag1 format $6. length 6
					,diag2 format $6. length 6
					,diag3 format $6. length 6
					,loinc format $7. length 7
					,strip(proccd) format $5.length 5 as proccd
					,strip(revcd) format $4. length 4 as revcd 
					,strip(upcase(mod1)) format $3. length  3 as mod1 
					,strip(mod2) format $3. length 3 as mod2
					,surg1 format $5. length 5
					,datepart(admdt) format mmddyy10. length 4 as admdt2
					,datepart(disdt) format mmddyy10. length 4 as disdt2 
					,majcat format 3. length 3
					,provspec format $2. length 2
					,encounter_key 
					,dis_cond format $3. length 3
					,pos format $2. length 2
					,provid
					,source format $2. length 2
					,tin	
					,datepart(dob) format mmddyy10. length 4 as dob1
					,datepart(max_proc_date) format mmddyy10. length 4 as max_proc_date
					,labobsvalue format $50. length 50 as value_character 
					,input(labobsvalue,best16.) as value_numeric 
					,LabObsUnitOfMeasure format $14. length 14 as units 
					,databand
					,LabObsNormalRange format $60. length 60 as normal_range 
					,LabObsAbnormal format $5. length 5 as abnormal_values 
					,OBX_F2 format $3. length 3 as OBX_F2

					from 
						(select * from connection to oledb  
							(select member_key, sex,svcdt2 ,client_key ,diag1,diag2 ,diag3,loinc,max_proc_date,
							proccd ,revcd,mod1,mod2,surg1 ,admdt ,disdt,majcat,provspec,dob,dis_cond, pos, provid,
							source,tin,encounter_key,labobsvalue,LabObsUnitOfMeasure, databand, date_of_death, 
							LabObsNormalRange, LabObsAbnormal, OBX_F2
								from dbo.vGuidelineInput 
									where 
										(client_key = &client_key. 
										and max_proc_date >= &p_stdt. 
										and member_key not in (-99)
										and date_of_death is NULL)

											order by member_key, svcdt2 ))
							 			;
				disconnect from oledb;
			quit;
	%end;  
	

%mend release1_claims_query;
