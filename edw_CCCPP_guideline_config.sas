/*HEADER------------------------------------------------------------------------
| 
| program:  edw_CCCPP_guideline_config.sas
|
| location: M:\ci\programs\Development\StandardMacros
+--------------------------------------------------------------------------------
| history:  
| 09AUG2011 - Brandon Barber / Original
| 28SEP2011 - Brandon Barber / Modified Asthma module and keys to 2.1b programs
+-----------------------------------------------------------------------HEADER*/

*--------------------------------------------*;
* Asthma Management Adult;
%let guideline_key = 150.4.1.0.2;
%let rank1 = "02" "76" "56";  /*specialists- also used in compliance measure; */
%let rank2 = "21" "35" "62"; /*PCPs- also used in compliance measure.  Remove if client wants compliance visits with specialist only; */
%let rank3 = "XXXXXX";
%let var = Asthma_flag;
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Optional to include all:  1= 2 OV per year, 3= Flu Vaccine 2= Spirometry, 99= Overall.*/
/*	But MUST have at least one submeasure*/
%let submeasure_inclusion = ('1','2','3','99'); 
%let minage = 12;
%let maxage = 51;
%let eligvisits = 2; *number of outpatient visits required for eligibility;
%Let prefix = Asthma_adult;
%let include = &guidelibname.\BaseMeasure_Asthma_Management_Adult_v2.1b.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*------------------------------------------*;
* Asthma Management Pediatric;
%let guideline_key = 150.5.1.0.2;
%let rank1 = "02" "76" "56";
%let rank2 = "21" "35" "62";
%let rank3 = "XXXXXX";
%let var = Asthma_flag;
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Optional to include all:  1= 2 OV per year, 3= Flu Vaccine 2= Spirometry, 99= Overall.*/
/*	But MUST have at least one submeasure*/
%let submeasure_inclusion = ('1','2','3','99'); 
%let minage = 5;
%let maxage = 12;
%let eligvisits = 2; /*number of outpatient visits required for eligibility*/
%Let prefix = Asthma_pediatric;
%let include = &guidelibname.\BaseMeasure_Asthma_Management_Pediatric_v2.1b.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------------------*;
* Back Pain Lower Acute;
%let guideline_key = 170.2.1.0.2;
%let minage = 18;  /* upper age cut-off; */
%let maxage = 120;  /* upper age cut-off; */
%Let stoffset = 28; /* number of days offset from start date.  Use 0 for calendar year; */
%let n=1;         /*Number of dx fields to search to IESD.  Use 1 for primary dx and 3 for any dx; */
%let rank1 = "21" "35" "52"; 
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX"; 
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= No Imaging before 28 days, */
/*	Optional to include: 98= Informational in g9 only: Onset of Pain, 99= Overall.*/
%let submeasure_inclusion = ('1','98','99'); 
%Let var= BackPainAc_flag;
%Let prefix = Backpain; 
%let include = &guidelibname.\BaseMeasure_Back_Pain_Lower_Acute_UseofImaging.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*----------------------------*;
*Breast Cancer Screening;
%let guideline_key = 190.2.1.0.2; 
%let rank1 =  "45"; 
%let rank2 = "21";
%let rank3 = "35"; 
%Let min_age = 40;
%Let max_age = 70;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
/*Client decides which submeasures want displayed/ included in the g6/G9.*/
/*	Must include: 1= Timely Mammo,  */
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','99'); 

/* Comment out one or the other below depending on what year range the client wants for compliance; */
%Let start_dt= &stdt - 366; /*Start date range looking for mammo in every other year; */
							/*%Let start_dt= &stdt;*/ /*Start date looking for mammo in every year; */
%Let var= breast_flag;  
%Let prefix = BCScreen;
%let include = &guidelibname.\BaseMeasure_BreastCancer_Screening_Mammography.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*--------------------------------*;
* Cervical Cancer Screening 21-29;
/*%let guideline_key = 240.1.1.0.2; */
/*%let rank1 = "45" ; */
/*%let rank2 = "21" ;*/
/*%let rank3 = "35";*/
/**Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= Biennial Pap,*/
/*	Optional to include: 99= Overall.;*/
/*%let submeasure_inclusion = ('1','99'); */
/*%let minage= 21;*/
/*%let maxage = 29; *Inclusive!!;*/
/*%let attrib_weight=3; *Give more weight to a preventative visit for attribution;*/
/*%Let var= cerv_flag; */
/*%Let prefix = Cervical_21; */
/*%let include = &guidelibname.\BaseMeasure_CervicalCancerScreen21to29.sas;*/
/*%include "&include.";*/
/*%outlier_comments_setup;*/
/*%cleanup;*/
/*%delvars;*/

*-----------------------------------*;
* Cervical Cancer Screening Routine; *CC wants compliance every 3 years for 21-65 year olds;
%let guideline_key = 240.2.1.0.2;
%let rank1 = "45"; 
%let rank2 = "21";
%let rank3 = "35";
%let minage = 21;
%let maxage = 65; *Inclusive!!;
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= Triennial Pap,*/
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','99'); 
%let attrib_weight=3; *Give more weight to a preventative visit for attribution;
%let preg_elig = 0; /* Option to include pregnancy into eligibility.  Choose 1 to include, 0 to not include.*/
%Let var= cerv_flag;
%Let prefix = Cervical_30; 
%let include = &guidelibname.\BaseMeasure_CervicalCancerScreen30to64.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Colorectal Cancer Screening;
%let guideline_key = 280.2.1.0.2; 
%let rank1 = "22";
%let rank2 = "35" "21";
%let rank3 = "45";
%let var = colorectal_flag;
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= FIT or FOBT, 2= Sigmoidoscopy, 3= Colonoscopy, */
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','2','3','99'); 
%let minage = 50;
%let maxage = 120;
%let prefix = colorectal;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include = &guidelibname.\BaseMeasure_ColorectalCancer_Screening_NormalRisk.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Diabetes Management;
%let guideline_key = 310.1.1.0.2; 
%let rank1 = "20" "40";
%let rank2 = "35" "21";
%let rank3 = "XXXXXX";
%let minage = 18;
%let maxage = 120; 				/* Note: to mimic HEDIS logic use 75; */
%Let var= diabetes_prior_flag; 	* Choose between diabetes_prior_flag, diabetes_both_flag, diabetes_current_flag;  
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*  Must Include: 1= Hba1c, 2= 2 OV, 3= LDL, 5=Nephropathy Attn */
/*  Optional to Include: 4=Eye Exam, 99= Overall.*/
%let submeasure_inclusion = ('1','2','3','4','5','99'); 
%Let prefix = Diabetes; 
%let include = &guidelibname.\BaseMeasure_DiabetesManagement.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Diabetes Podiatric Foot Care;
%let guideline_key = 310.5.1.0.2; 
%let rank1 = "72"; 
%let rank2 = "XXXXXX"; 
%let rank3 = "XXXXXX";
%let n=1; 
%Let var = visit_flag; 
/*Client decides which submeasures want displayed/ included in the g6/G9.*/
/*	Must include: 1= Timely Follow-up,*/
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','99');  
%Let prefix = Podiatry;
%let include = &guidelibname.\BaseMeasure_DiabetesPodiatric.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Heart Failure Management;
%let guideline_key = 250.1.1.0.2;
%let rank1 = "08";
%let rank2 = "21" "35";
%let rank3 = "XXXXXX";
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= 2 OV per year, 2= Potassium, 3= Creatinine/BUN, 	*/
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','2','3','99'); 
%let var = chf_d1;
%Let prefix = CHF ; 
%let include = &guidelibname.\BaseMeasure_CHF_Management.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Hypertension Management;
%let guideline_key = 380.1.1.0.2; 
%let rank1 = "08" "40" "20";
%let rank2 = "35" "21";
%let rank3 = "XXXXXXX";
%let minage= 18;
%let ESRD_exclude = 0;
%let pregnancy_exclude = 0;
%let NonAcute_exclude = 0;
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= 2 OV per year, 2= Creatinine/Bun, 3= Potassium, */
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','2','3','99'); 
%let var= hypertension_flag;
%let prefix = hypertension;
%let elig_startdt = (&stdt. - 366); /*First date for counting eligibility. Use 0 to include any history of hypertension.  Use &stdt for new cases. Use (&stdt. - 366) for prior and currentyr ; */
%let elig_enddt = &stdt.; /*End date for counting eligibility.;*/
%let include = &guidelibname.\BaseMeasure_Hypertension_Management.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Immunizations Age 13;
%let guideline_key = 400.1.1.0.2; 
%let rank1 = "62" "21"; 
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX"; 
%let age= 13; 		/*Choose between 13 or 18; */
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*  Must include: 1= MCV4, 3= Tdap*/
/*  Optional to include: 2= HPV (females),4=Seasonal Flu, 99= Overall.*/
%let submeasure_inclusion = ('1','2','3','4','99');
%let comprunout = 30;
%Let var= ImmunizAdol_flag ;
%Let prefix = ImmunizAdol; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include = &guidelibname.\BaseMeasure_Immunization Adolescent.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Immunizations Age 6;
%let guideline_key = 400.3.1.0.2; 
%let rank1 = "62" "21"; 
%let rank2 =  "XXXXXX";
%let rank3 = "XXXXXX"; 
/* Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include:  2= Varicella, 3= IPV, 4=Dtap, 5=MMR */
/*	Optional to include: 1= Flu,99= Overall.*/
%let submeasure_inclusion = ('1','2','3','4','5','99');
%let comprunout = 30;   *leeway for providing shots after 6th birthday in days;
%Let var= Immuniz6_flag;
%Let prefix = Immuniz6; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include = &guidelibname.\BaseMeasure_Immunization_Age6.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Immunizations Age 2;
%let guideline_key = 400.4.1.0.2; 
%let rank1 = "62" "21"; 
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX"; 
%let comprunout= 36.5;
/*Client decides which submeasures want displayed/ included in the g6/G9.*/
/*	Must include: 1= MMR, 2= HepB, 3= HepA, 5=Dtap, 6=Pneumoccoccal, 7=IPV, 8=HiB*/
/*	Optional to include: 4=Rotavirus, 9=Flu, 10=Varicella, 99= Overall.*/
%let submeasure_inclusion = ('1','2','3','4','5','6','7','8','9','10','99');
%let hepb_comp = 3;
%Let var= Immuniz2_mem_flag;
%Let prefix = Immuniz2; 
%let attrib_weight=3; /*Weight a preventative visit more for attribution;*/
%let include = &guidelibname.\BaseMeasure_Immunization_Pediatric.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Lipid Screening;
%let guideline_key = 450.2.1.0.2; 
%let rank1 = "21" "35"; 
%let rank2 = "45";
%let rank3 = "XXXXXX"; 
%let minage = 35;
%let maxage = 66;
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= Lipid Profile, */
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','99');  
%Let var= lipid_flag;
%Let prefix = Dyslipidemia; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include = &guidelibname.\BaseMeasure_Lipid_screening.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Melanoma Continuity of Care;
%let guideline_key = 470.1.1.0.2; 
%let rank1 = "17";
%let rank2 = "71";
%let rank3 = "XXXXXX";
%let age = 0;
%let attrib_start = (&stdt. - 366); /*First date for counting attribution visits.  Use 0 to look for all past visits. (&stdt.-366) for prev year ; */
%let elig_startdt = 0; /*First date for counting eligibility. Use 0 to include any history of melanoma.  Use &stdt for new cases; */
%let elig_enddt = &enddt.;  /*End date for counting eligibility. Use &stdt to look at previous years. Use &enddt to look for current; */
/*Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= Annual OV, */
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','99'); 
%let var = melanoma_flag;
%Let prefix = Melanoma ; 
%let include = &guidelibname.\BaseMeasure_Melanoma.sas;
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Osteoporosis, Women: High Risk - Medical;
/*%let guideline_key = 510.4.1.0.2; */
/*%let rank1 = "20" "40" "22" "80"; */
/*%let rank2 = "21" "35" "25"  ; */
/*%let rank3 = "45"; */
/**Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= 1st DEXA, */
/*	Optional to include: 99= Overall.;*/
/*%let submeasure_inclusion = ('1','99'); */
/*%Let var= osteo_flag; */
/*%Let prefix = osteowomen_HRmed; */
/*%let include = %str(&guidelibname.\BaseMeasure_Osteoporosis Women HighRiskMedical.sas);*/
/*%include "&include.";*/
/*%outlier_comments_setup;*/
/*%cleanup;*/
/*%delvars;*/

*-----------------------------------*;
* Osteoporosis, Women: High Risk - Ortho;
/*%let guideline_key = 510.5.1.0.2; */
/*%let rank1 = "52" "20" "80" "27"; */
/*%let rank2 =  "21" "35" "45" "25";*/
/*%let rank3 = "19"; */
/**Client decides which submeasures want displayed/ included in the g6/G9. */
/*	Must include: 1= Bone Density,*/
/*	Optional to include: 99= Overall.;*/
/*%let submeasure_inclusion = ('1','99'); */
/*%let compmonth= 180; *180 for 6 months/ 90 for 3 months;*/
/*%Let var= osteo_flag; */
/*%Let prefix = osteowomen_HRortho; */
/*%let include = %str(&guidelibname.\BaseMeasure_Osteoporosis Women HighRiskOrtho.sas);*/
/*%include "&include.";*/
/*%outlier_comments_setup;*/
/*%cleanup;*/
/*%delvars;*/

*-----------------------------------*;
* Osteoporosis Women Routine;
%let guideline_key = 510.6.1.0.2; 
%let rank1 = "35" "21" "45"; 
%let rank2 = "20" "40" "52" "80"; 
%let rank3 = "XXXXXX"; 
%Let var = osteo_flag;
%let trigger_age = 65;
/*Client decides which submeasures want displayed/ included in the g6/G9.*/
/*	Must include: 1= 1st DEXA, */
/*	Optional to include: 99= Overall.*/
%let submeasure_inclusion = ('1','99'); 
%Let prefix = osteo_women;
%let attrib_weight = 3; *Weight a preventative visit more for attribution;
%let include = %str(&guidelibname.\BaseMeasure_Osteoporosis Women ScreeningRoutine.sas);
%include "&include.";
%outlier_comments_setup;
%cleanup;
%delvars;
