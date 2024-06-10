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
+-----------------------------------------------------------------------HEADER*/



/**/
/*%let client_key =6;*/
/*%let payer_key = 3;*/
/*%let enddt = '31MAY2012';*/


%macro HEDIS_claims_query;

%let ciedw  =%str("Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;Initial Catalog=CIEDW;"); 

libname ciedw   oledb init_string=&ciedw.  	preserve_tab_names=yes insertbuff=10000 readbuff=10000;	


/*Work around for CPT2 implemented until view is corrected.  Currently, CPT2 column in not populated, and CPY2 codes are in HCPCS column.*/

%macro visit_query;
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table visit as  
			 select  client_key format 3.
					,memberid format 16. length 8 as memberid
					,datepart(svcdt2) format mmddyy10. length 4 as svcdt 
					,datepart(admdt2) format mmddyy10. length 4 as admdt
					,datepart(disdt2) format mmddyy10. length 4 as disdt 
					,DaysCov format 3. as DaysCov
					,proccd format $5. as CPT
					,MOD1 format $2. as Mod1
					,MOD2 format $2. as Mod2
					,HCPCS format $5. as HCPCS
					,HCPCS format $5. as CPT2
/*					,CPT2 format $5. as CPT2*/
					,diag1 format $6. length 6 as Diag1
					,diag2 format $6. length 6 as Diag2
					,diag3 format $6. length 6 as Diag3
					,diag4 format $6. length 6 as Diag4
					,diag5 format $6. length 6 as Diag5
					,diag6 format $6. length 6 as Diag6
					,diag7 format $6. length 6 as Diag7
					,diag8 format $6. length 6 as Diag8
					,diag9 format $6. length 6 as Diag9
/*					,diag10 format$6. length 6 as Diag10 */
					,surg1 format $5. length 5 as Surg1
					,surg2 format $5. length 5 as Surg2
					,surg3 format $5. length 5 as Surg3
					,surg4 format $5. length 5 as Surg4 
					,surg5 format $5. length 5 as Surg5
					,surg6 format $5. length 5 as Surg6
					,drg format $5. as DRG
					,dis_cond format $20. as dis_cond
					,revcd format $50. as revcd
					,billtype format $10. as BillType
					,units format 8. as Units
					,pos format $2. as POS
					,claimsstatus format $1. as ClaimStatus
					,provid format $12. as Provid
				
					from 
						(select * from connection to oledb  
							(select client_key, payer_key, memberid ,svcdt as svcdt2,admdt as admdt2, disdt as disdt2, dayscov, proccd,mod1, mod2, 
							HCPCS, CPT2, diag1, diag2, diag3, diag4, diag5, diag6, diag7, diag8,diag9, diag10,
							surg1, surg2, surg3, surg4, surg5, surg6, drg,dis_cond,revcd, billtype,units,pos,claimsstatus,provid
								from dbo.v_HEDIS_visit 
									where 
										(client_key in (&client_key.) and payer_key in (&payer_key.) and memberid not in (-99))
											order by memberid, svcdt))	;
				disconnect from oledb;
			quit;

%mend visit_query;
%visit_query;

%macro provider_query;
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table providera as  
			 select  client_key format 3.
			 		,provider_ID format $12. as Provid
					,PCP_Flag format $1. as PCP
					,OBGYN_flag format $1. as OBGYN
					,Mental_Health_flag format $1. as MHProv
					,EyeCare_flag format $1. as EyeCProv
					,Dentist_flag format $1. as Dentist
					,Nephrologist_flag format $1. as Neph
					,Anesthesiologist_flag format $1. as Anes
					,Nurse_practitioner_flag format $1. as NPR
					,Physician_assistant_flag format $1. as PAS
					,Clinical_pharmacist_flag format $1. as PHAProv
					,Registered_nurse_flag format $1. as RN
					
					from 
						(select * from connection to oledb  
							(select client_key, provider_ID, PCP_Flag, OBGYN_flag, Mental_Health_flag, EyeCare_flag, Dentist_flag, 
							Nephrologist_flag, Anesthesiologist_flag, Nurse_practitioner_flag, Physician_assistant_flag, Clinical_pharmacist_flag, Registered_nurse_flag
								from dbo.v_HEDIS_provider 
									where 
										(client_key in (&client_key.) and payer_key in (&payer_key.))
											order by provider_ID))	;
				disconnect from oledb;
			quit;

%mend provider_query;
%provider_query;



%macro provider_spec_query;
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table provider_spec as  
			 select  *
			 		,case when specialty_code in ('93','94','M1','M2','M3','M5','V1','02','05','08','09','10','11','12','14',
					'15','17','19','20','21','22','23','25','26','27','28','29','30','34','35','39','40','41','42','44','45',
					'46','48','49','51','52','53','54','56','57','58','59','60','61','62','63','64','65','66','67','69','71',
					'72','74','76','80','83','84','85','88','V2','V3','V4','M6') then 'Y'
					 else 'N'
					 end as ProvPres
					
					from 
						(select * from connection to oledb 
							(select * from 
							(select a.provider_key, a.specialty_key, a.isPrimary,b.specialty_code,b.specialty_description
								from dbo.Provider_Specialty_XREF as a inner join dbo.Specialty as b 
									on a.specialty_key = b.specialty_key
									where 
										provider_key > 0 and isprimary = 1) as a inner join dbo.provider_payer as b 
											on a.provider_key = b.provider_key))
												;
				disconnect from oledb;
			quit;

%mend provider_spec_query;
%provider_spec_query;

proc sql noprint;
	create table provider as
		select  b.Provpres, b.specialty_code, b.specialty_description, a.*
			from providera as a inner join provider_spec as b on a.provid = b.npi1
				order by provid;
					quit;


%macro pharm_query;
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table pharm as  
			 select  client_key format 3.
			 		,memberid format 16. length 8 as memberid
					,PDaysSup format 4. as PDaysSup
					,input(svcdt2,yymmdd10.) format mmddyy10. length 4 as svcdt
					,compress(NDC,'-') format $13. as NDC
					,Clmstat as Clmstat
					,Mquant format 4. as Mquant
					,provid as provid
					/*,specialty_code as provspec*/
					
			
					from 
						(select * from connection to oledb  
							(select client_key, memberid, PDaysSup, svcdt as svcdt2 , NDC, Clmstat, 
								Mquant, provid /*, specialty_code*/
								from dbo.v_HEDIS_PHARM 
									where 
										(client_key in (&client_key.) and payer_key in (&payer_key.))
											order by memberid, svcdt))	;
				disconnect from oledb;
			quit;
%mend pharm_query;
%pharm_query;

%macro member_en;
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table member_en as  
			 select  client_key format 3.
			 		,memberid format 16. length 8 as memberid
					,input(ENROLL_ST_DT,yymmdd10.) format mmddyy10. as Startdate
					,input(ENROLL_DIS_DT,yymmdd10.) format mmddyy10. as FinishDate
					,Dental format $1. as Dental
					,Drug as Drug
					,MHInpt as MHInpt
					,MHDN as MHDN
					,MHAMB as MHAMB
					,CDInpt as CDInpt
					,CDDN as CDDN
					,CDAMB as CDAMB
					,Payer as Payer
					,case when Payer in ('MDE') then 'MCD'
					 when Payer in ('MD')then 'MCD'
					 when Payer in ('MLI') then 'MCD'
					 when Payer in ('MRB') then 'MCD'
					 when Payer in ('MR') then 'MCR'
					 when Payer in ('MP') then 'MP'
					 when Payer in ('MC') then 'MCR'
					 when Payer in ('PPO') then 'PPO'
					 when Payer in ('POS') then 'COM'
					 when Payer in ('HMO') then 'COM'
					 when Payer in ('SN1') then 'SN1'
					 when Payer in ('SN2') then 'SN2'
					 when Payer in ('SN3') then 'SN3'
					 when Payer in ('CHP') then 'MCD'
					 when Payer in ('COF') then 'COM'
					 when Payer in ('MRF') then	'MCD'
					 when Payer in ('MCF') then 'MCD'
					 end as Payer_group
					,PEFlag as PRFlag
					,Member_Ind as IND	

					from 
						(select * from connection to oledb  
							(select client_key, memberid, Enroll_ST_DT, Enroll_DIS_DT,
								Dental, Drug, MHInpt, MHDN, MHAMB, CDInpt, CDDN, CDAMB, Payer, 
								PEFlag, Member_Ind
								from dbo.v_HEDIS_Member_en
									where 
										(client_key in (&client_key.) and payer_key in (&payer_key.) and memberid not in (-99))
											order by memberid, enroll_ST_DT))	;
				disconnect from oledb;
			quit;
%mend member_en;
%member_en;

			
%macro member_gm;
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table member_gm as  
			 select client_key format 3.
			 		,memberid format 16. length 8 as memberid
					,sex as sex
					,datepart(DOB2) format mmddyy10. length 4 as DOB 
					,LName as patient_lname
					,FName as patient_fname
					," " as patient_MName
					,SubId as SubID
					,Address1 as Address1
					,Address2 as Address2
					,City as City
					,State as State
					,Zip as Zip
					,Phone as Phone
					,PFirstName as subscriber_FName
					," " as subscriber_MName
					,PLastName as subscriber_LName
					,Race as Race
					,Ethnicity as Ethnic
					,RaceDS as RaceDS
					,SpokenLang as SpokenLang
					,SpokenLangSource as SpokenLangSource
					,WrittenLang as WrittenLang
					,WrittenLangSource as WrittenLangSource
					,OtherLang as OtherLang
					,OtherSource as OtherSource
					from
						(select * from connection to oledb 
							(select client_key, memberid, sex, DOB as DOB2, LName, FName, SubId, Address1, Address2,
							City, State, Zip, Phone, PFirstName, PLastName, Race, Ethnicity, RaceDS, SpokenLang, 
							SpokenLangSource, WrittenLang, WrittenLangSource, OtherLang, OtherSource
								from dbo.v_HEDIS_Member_GM
									where (client_key in (&client_key.) and payer_key in (&payer_key.) 
										and memberid not in (-99))
											order by memberid))	;
				disconnect from oledb;
			quit;
%mend member_gm;
%member_gm;




/*  WILL NOT WORK UNTIL IT FIXES THE DATE  */
%macro lab_query;
	proc sql noprint;
		connect to oledb(init_string=&ciedw.);
		create table lab as  
			 select  client_key format 3.
			 		,memberid format 16. length 8 as memberid
					,CPT format $5. as CPT
					,LOINC format $7. as LOINC
					,labobsvalue  format $50. as value
/*					,input(svcdt2,yymmdd8.) format mmddyy10. as svcdt*/
/*					,svcdt2 format mmddyy10. as svcdt*/
					,lab_indicator format $1. as lab_indicator					
					from 
						(select * from connection to oledb  
							(select client_key, memberid, CPT, LOINC, labobsvalue, svcdt as svcdt2, lab_indicator
								from dbo.v_HEDIS_LAB
									where 
										(client_key in (&client_key.) )
											order by memberid, svcdt))	;
				disconnect from oledb;
			quit;

%mend lab_query;
/*%lab_query;*/
		
%mend HEDIS_claims_query;
