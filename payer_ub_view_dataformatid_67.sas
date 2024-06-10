/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  payer_ub_view_dataformatid_67.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE: 	Extract MMO Payer UB from VHSTAGE_PAYER.dbo.V_MMO_MEDICAL_CLAIMS_UB
|           
| INPUT:    VH_STAGE_PAYER MMO_MEDICAL table, UB claims                                 
|
| OUTPUT:        
|                                            
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 13JUN2012 - G Liu - Clinical Integration Release 1.3.01 H01
|			  Original
+-----------------------------------------------------------------------HEADER*/

%macro payer_ub_view_dataformatid_67(m_batch_key,m_datasource_id);
	proc sql;
		connect to oledb(init_string=&sqlci. readbuff=10000);
		create view payer_ub_view as 
		select 	* 
		from 	connection to oledb
				(	select	*
					from	vhstage_payer.dbo.v_mmo_medical_claim_ub
					where	batch_key = &m_batch_key.
				);
	quit;
	
	data payer_ub_data(drop=date_of_birth service_date admission_date discharge_date revcd
					   rename=(revenue_code=revcd discharge_status=dis_cond
							   diagnosis_code_1=diag1 diagnosis_code_2=diag2 diagnosis_code_3=diag3 diagnosis_code_4=diag4 diagnosis_code_5=diag5
							   surgical_code_1=surg1 surgical_code_2=surg2 surgical_code_3=surg3 surgical_code_4=surg4 surgical_code_5=surg5 surgical_code_6=surg6));
		set payer_ub_view(rename=(claimnumber=claimnum line_number=linenum claim_source_unique_id=maxprocessid
								  procedure_code=proccd mod_1=mod1 mod_2=mod2 dob=date_of_birth));
		dob=input(date_of_birth,yymmdd10.);
		if substr(zip,6,5)='-0000' then zip=substr(zip,1,5);
		else if substr(zip,6,1)='-' then zip=substr(zip,1,5)||substr(zip,7);
		else zip=zip;

		memberid=ssn;
		svcdt=input(service_date,yymmdd10.);
		admdt=input(admission_date,yymmdd10.);
		disdt=input(discharge_date,yymmdd10.);
		sbdate=admission_date;
		sedate=discharge_date;
		start_date=.;
		moddt=.;
		filedt=.; filed='';
		practice_id=&m_datasource_id.;
		provname='';
		payorid1=''; payorname1='MMO';
		format admdiag $6.; admdiag='';
		mod1=compress(mod1,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','k');
		mod2=compress(mod2,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789','k');
		submit=.;

		length revcd majcat 8.;
		revcd = REVENUE_CODE * 1;

		if    substr(BILL_TYPE,1,2) in ('11','18','21','28','41','65','66','84','86','89') or
		      POS in ('21','51','61') or
		      revcd in (100:239) then do;
		      if revcd in (115, 118, 125, 128, 135, 138, 145, 148, 155, 158, 190:199, 650, 655, 656, 658, 659) or 
		            drg in ('945','946') then majcat = 4;
		      else if drg in ('876','880','881','882','883','884','885','886','887','894','895','896','897') then majcat = 5;
		      else if drg in ('765','766','767','768','774','775','795') then majcat = 2;
		      else if drg in ('001','002','003','004','005','006','007','008','010','011',
		                              '012','013','014','015','020','021','022','023','024','025',
		                              '026','027','028','029','030','031','032','033','034','035',
		                              '036','037','038','039','040','041','042','113','114','115',
		                              '116','117','129','130','131','132','133','134','135','136',
		                              '137','138','139','163','164','165','166','167','168','215',
		                              '216','217','218','219','220','221','222','223','224','225',
		                              '226','227','228','229','230','231','232','233','234','235',
		                              '236','237','238','239','240','241','242','243','244','245',
		                              '246','247','248','249','250','251','252','253','254','255',
		                              '256','257','258','259','260','261','262','263','264','265',
		                              '326','327','328','329','330','331','332','333','334','335',
		                              '336','337','338','339','340','341','342','343','344','345',
		                              '346','347','348','349','350','351','352','353','354','355',
		                              '356','357','358','405','406','407','408','409','410','411',
		                              '412','413','414','415','416','417','418','419','420','421',
		                              '422','423','424','425','453','454','455','456','457','458',
		                              '459','460','461','462','463','464','465','466','467','468',
		                              '469','470','471','472','473','474','475','476','477','478',
		                              '479','480','481','482','483','484','485','486','487','488',
		                              '489','490','491','492','493','494','495','496','497','498',
		                              '499','500','501','502','503','504','505','506','507','508',
		                              '509','510','511','512','513','514','515','516','517','573',
		                              '574','575','576','577','578','579','580','581','582','583',
		                              '584','585','614','615','616','617','618','619','620','621',
		                              '622','623','624','625','626','627','628','629','630','652',
		                              '653','654','655','656','657','658','659','660','661','662',
		                              '663','664','665','666','667','668','669','670','671','672',
		                              '673','674','675','707','708','709','710','711','712','713',
		                              '714','715','716','717','718','734','735','736','737','738',
		                              '739','740','741','742','743','744','745','746','747','748',
		                              '749','750','769','770','799','800','801','802','803','804',
		                              '820','821','822','823','824','825','826','827','828','829',
		                              '830','853','854','855','856','857','858','901','902','903',
		                              '904','905','906','907','908','909','927','928','929','939',
		                              '940','941','955','956','957','958','959','969','970','981',
		                              '982','983','984','985','986','987','988','989') then majcat = 3;
		      else majcat = 1;
		end;
		else do;
		            if TYPE_OF_SERVICE_DESC in ('EMERGENCY MEDICAL CARE','MEDICAL CARE/EMERGENCY ACCIDENT CARE') or 
		                  revcd in (450) then majcat =6;
		      else if revcd in (360:379, 490:499, 710:719, 975) then majcat = 7;
		      else if revcd in (720:729) then majcat = 8;
		      else if revcd in (300:319, 971) then majcat = 9;
		      else if revcd in (320:329, 340:359, 400:409, 610:619, 972, 974) then majcat = 10;
		      else if revcd in (260:269,330:339, 410:449, 489, 820:835, 839:845, 849:855,859, 940:949, 973, 976:978 ) then majcat = 12;
		      else if revcd in (526:529) then majcat = 19;
		      else if revcd in (550:609, 640:649) then majcat = 29;
		      else if revcd in (540:549) then majcat = 30;
		      else if revcd in (513, 900:919, 961, 1000:1009) or 
		                  proccd in ('90801','90802','90803','90804','90805','90806','90807','90808','90809','90810',
		                                 '90811','90812','90813','90814','90815','90816','90817','90818','90819','90821',
		                                 '90822','90823','90824','90826','90827','90828','90829','90845','90846','90847',
		                                 '90849','90853','90857','90862','90865','90870','90871','90875','90876','90880',
		                                 '90882','90885','90887','90889','90899') then majcat = 51;
		      else majcat = 13;
		end;
	run;
%mend payer_ub_view_dataformatid_67;
