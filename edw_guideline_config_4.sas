
/*HEADER------------------------------------------------------------------------
|
| program:  edw_guideline_config_4.sas
|
| location: M:\ci\programs\Development\StandardMacros
+--------------------------------------------------------------------------------
| history:  
| 
| 18AUG2011 - Mark Logsdon / Original
| 25AUG2011 - Changed quotes on guideline keys. ML
|
+-----------------------------------------------------------------------HEADER*/




*SASDOC----------------------------------------------------------------------
|	Config File.                                           
+----------------------------------------------------------------------SASDOC*;
/** original file - M:\ci\programs\StandardMacros\edw_guideline_config_4.sas **/




*----------------------------------*;
* Baretts Esophagus ;
%let guideline_key = 180.1.1.0.2;
/**%let guideline_key = 50;*/
%let rank1 = "22";
%let rank2 = "XXXXXX" "XXXXXX";
%let rank3 = "XXXXXX";
%let leeway = 365; *number of extra days after 365 days for generating compliance - Valence recommends 30;
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Endoscopy, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%Let prefix = Barretts ; 
%let include=&guidelibname.\BaseMeasure_Barretts_Esophagus_Surveillance.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;


*------------------------------*;
* Cataract PreOp*;
%let guideline_key = 230.1.1.0.2; 
/**%let guideline_key = 80; */
%let cpt2include= Y;  *Y if Client wants to include CPT2 codes/ N if Client does not want to include CPT2 codes;
*%let Kera_compflag=1; *Set to 1 if want to include in overall compliance, else set it to 0;
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Fundus, 2= Axial, 4=Power Calc, 
	Optional to include: 3= Keratometry,99= Overall.;
%let submeasure_inclusion = ('1','2','3','4','99'); 
%let rank1 = "49";
%let rank2 = "XXXXXX"; 
%let rank3 = "XXXXXX"; 
%let var = cataract_mem;
%Let prefix = Cataract ;
%let include=&guidelibname.\BaseMeasure_CataractPreOp.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*--------------------------------*;
* Cervical Cancer Screening 21-29;
%let guideline_key = 240.1.1.0.2; 
/**%let guideline_key = 90; */
%let rank1 = "45" ; 
%let rank2 = "21" ;
%let rank3 = "35";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Biennial Pap,
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let minage= 21;
%let maxage = 30; 
%let attrib_weight=3; *Give more weight to a preventative visit for attribution;
%let preg_elig = 0; /* Option to include pregnancy into eligibility.  Choose 1 to include, 0 to not include.*/
%Let var= cerv_flag; 
%Let prefix = Cervical_21; 
%let include=&guidelibname.\BaseMeasure_CervicalCancerScreen21to29.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Cervical Cancer Screening 30-64;
%let guideline_key = 240.2.1.0.2; 
/**%let guideline_key = 100;*/
%let rank1 = "45" ; 
%let rank2 = "21" ;
%let rank3 = "35";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Triennial Pap,
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let minage= 30;
%let maxage = 65; 
%let attrib_weight=3; *Give more weight to a preventative visit for attribution;
%let preg_elig = 0; /* Option to include pregnancy into eligibility.  Choose 1 to include, 0 to not include.*/
%Let var= cerv_flag;
%Let prefix = Cervical_30; 
%let include=&guidelibname.\BaseMeasure_CervicalCancerScreen30to64.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* CHF Management;
%let guideline_key = 250.1.1.0.2;
/**%let guideline_key = 60; */
%let rank1 = "08";
%let rank2 = "21" "35" ;
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= 2 OV per year, 2= Potassium, 3= Creatinine/BUN, 	
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','2','3','99');
%let var = chf_d1;
%Let prefix = CHF ; 
%let include=&guidelibname.\BaseMeasure_CHF_Management.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Chlamydia; 
%let guideline_key = 260.1.1.0.2;
/**%let guideline_key = 190; */
%let rank1 = "45" "21" ;
%let rank2 = "35" "62" ;
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Annual Screening, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let var=chlamydia_flag;
%let prefix = chlamydia;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let minage = 16;
%let maxage = 25;
%let include=&guidelibname.\BaseMeasure_Chlamydia.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Chronic Lymphocytic Leukemia;
%let guideline_key = 440.2.1.0.2; 
/**%let guideline_key = 330; */
%let rank1 = "29" "30" "48" ; 
%let rank2 = "XXXXXX"; 
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= Flow Cytometry,  
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99');  
%Let var= cll_flag;
%Let prefix = cll; 
%let include=&guidelibname.\BaseMeasure_Chronic_Lymphocytic_Leukemia.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Chronic Rhinosinusitis;
%let guideline_key = 590.1.1.0.2; 
%let rank1 = "53" ; 
%let rank2 = "21" "35" "25" ;
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= Adherence to Guideline, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99');  
%let minage = 5; 
%let maxage = 75;
%let complianceperiod = 60;
%let excludedays = 84;
%Let prefix = Sinusitis; *Negative diagnosis days allowance;
%let CR_endoscopy_codes = ,31231:31235,31237:31294; *Include these codes if Client choses to include Endoscopy in addition to CT for compliance. Note: need to have comma before first code for it to run. If do not want to include into compliance
replace with this      /*,31231:31235,31237:31294*/ ;                
%let include=&guidelibname.\BaseMeasure_Chronic_Rhinosinusitis.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Colorectal Cancer Screening - Normal Risk;
%let guideline_key = 280.2.1.0.2; 
/**%let guideline_key = 220; */
%let rank1 = "22"  ;
%let rank2 = "35" "21" "25";
%let rank3 = "45";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= FIT or FOBT, 2= Sigmoidoscopy, 3= Colonoscopy, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','2','3','99'); 
%let var= colorectal_flag;
%let minage= 50;
%let maxage=75;
%let prefix = colorectal;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_ColorectalCancer_Screening_NormalRisk.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* COPD;
/**%let guideline_key = 70;*/
%let guideline_key = 290.1.1.0.2; 
%let var = copd_mem;
%let rank1 = "76";
%let rank2 = "21" "35" "25";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Annual OV, 2= Spirometry,
	Optional to include: 3= Flu Vaccine, 4=Pneumococcal, 99= Overall.;
%let submeasure_inclusion = ('1','2','3','4','99'); 
%let var = copd_mem;
%let prefix = COPD;
%let COPD_diaginclude = ,491.0,491.8,491.9; *AHN will comment this out as they do not want to include these diags.  All other clients leave this in. Need to have comma before first diag code for it to run.;
%let elig_age = 40; * Valence base recommendation is 40, but some clients may choose 18 for consistency with definition of adult guidelines;
%let include=&guidelibname.\BaseMeasure_COPD.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;


*-----------------------------------*;
* COPD Spirometry;
%let guideline_key =  290.2.1.0.2; 
/**%let guideline_key = 270; */
%let rank1 = "21" "25" "35" ; 
%let rank2 = "76";
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1=  Spirometry,  
	Optional to includE: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%Let var= copd_flag;
%Let prefix = COPD_spiro;
%let include=&guidelibname.\BaseMeasure_COPD_Spirometry.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Diabetic Retinopathy Screening;
%let guideline_key = 310.6.1.0.2;
/**%let guideline_key = 350;*/
%let rank1 = "49";
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX";
%Let var=eye_before;
%Let prefix = Diabetes_eye; 
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Annual Retinal Exam,  
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99');  
%let n= 1; *Set to 1 if want to restrict history with ophthalmologist in prior year.  Set to 2 if want history two years prior to measurement year.;
%let maxage = 120; /* Maximum age range – inclusive. This should match your client’s age range for Diabetes Management */
%let include=&guidelibname.\BaseMeasure_Diabetes_Retinopathy_Screening.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Diabetic Management;
%let guideline_key = 310.1.1.0.2; 
/**%let guideline_key = 110;*/
%let rank1 = "20";
%let rank2 = "35" "62" "21";
%let rank3 = "XXXXXX";
* Client decides which submeasures want displayed/ included in the g6/G9. 
  Must Include: 1= Hba1c, 2= 2 OV, 3= LDL, 5=Nephropathy Attn 
  Optional to Include: 4=Eye Exam, 99= Overall.;
%let submeasure_inclusion = ('1','2','3','5','99'); *DO I INCLUDE EYE EXAM?;

%let maxage = 90; 				* Note: to mimic HEDIS logic use 75;
%Let var= diabetes_prior_flag; 	* Choose between diabetes_prior_flag , diabetes_both_flag, diabetes_current_flag;  
*%let eye_flag = 0; 				* Use 1 to include eye in compliance and 0 to show as detail;
*%let elig_hosp = 1; *include patients with 1+ hospital visit in eligibility regardless of number of outpatient visit;
%Let prefix = Diabetes; 
%let include=&guidelibname.\BaseMeasure_DiabetesManagement.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Diabetic Podiatry;
%let guideline_key = 310.5.1.0.2; 
/**%let guideline_key = 360;*/
%let rank1 = "72"; 
%let rank2 = "XXXXXX"; 
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= Timey Follow-up,
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99');
%Let var = visit_flag; 
%Let prefix = Podiatry;
%let n =1; *Set to 1 if want to restrict history with podiatrist in prior year.  Set to 2 if want history two years prior to measurement year.;
%let maxage = 120; /* Maximum age range – inclusive. This should match your client’s age range for Diabetes Management */
%let include=&guidelibname.\BaseMeasure_DiabetesPodiatric.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;

* Glaucoma Screening;
%let guideline_key = 340.4.1.0.2; 
/**%let guideline_key = 290; */
%let rank1 = "49" "50";
%let rank2 = "XXXXXXX";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= Eye Exam, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99');  
%let var= glaucoma_flag;
%let minage = 67; 	*use 67 to ensure that members had an exam after turning 65 and before 1 full compliance cycle passes;
%let prefix = glaucoma;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_Glaucoma_Screening.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;


*-----------------------------------*;
* Hypertension Management;
%let guideline_key = 380.1.1.0.2; 
/**%let guideline_key = 240; */
%let rank1 = "08" ;
%let rank2 = "35" "21" "25";
%let rank3 = "XXXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= 2 OV per year, 2= Creatinine/Bun, 3= Potassium, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','2','3','99');
%let var= hypertension_flag;
%let prefix = hypertension;
%let elig_startdt = (&stdt. - 366); *First date for counting eligibility. Use 0 to include any history of hypertension.  Use &stdt for new cases. Use (&stdt. - 366) for prior and currentyr ;
%let elig_enddt = &stdt.; *End date for counting eligibility.;
%let minage = 18 ;/*Minimum age limit - inclusive */
%let maxage = 120 ;/*Maximum age limit - inclusive */
%let ESRD_exclude = 0; /*Flag to indicate whether or not to exclude ESRD. Choose 1 to exclude, 0 to not exclude */
%let Pregnancy_exclude = 0; /*Flag to indicate whether or not to exclude Pregnancy. Choose 1 to exclude, 0 to not exclude */
%let NonAcute_exclude = 0; /* Flag to indicate whether or not to exclude Non Acute Facility admission in the measurement year.  Choose 1 to exclude, 0 to not exclude */

%let include=&guidelibname.\BaseMeasure_Hypertension_Management.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Hypothyroidism Management;
%let guideline_key = 390.1.1.0.2; 
/**%let guideline_key = 250; */
%let rank1 = "20" ;
%let rank2 = "35" "21" "25";
%let rank3 = "XXXXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= OV, 2= TSH, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','2','99'); 
%let var= hypothyroid_flag;
%let minage = 18;
%let prefix = hypothyroid;
%let elig_startdt = (&stdt. - 366); *First date for counting eligibility. Use 0 to include any history of hypothyroidism.  Use &stdt for new cases. Use (&stdt. - 366) for prior and currentyr ;
%let elig_enddt = &stdt.; *End date for counting eligibility.;
%let include=&guidelibname.\BaseMeasure_Hypothyroidism_Management.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Immunizations Adolescents ;
%let guideline_key = 400.1.1.0.2; 
/**%let guideline_key = 120; */
%let rank1 = "62" "21" "35"; 
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9. 
  Must include: 1= MCV4, 3= Tdap
  Optional to include: 2= HPV (females),4=Seasonal Flu, 99= Overall.;
%let submeasure_inclusion = ('1','3','99');
%let age= 13; 		*Choose between 13 or 18;
*%let incl_flu_flag = 0;	*use 1 for required and 0 for informational only;
*%let incl_hpv_flag = 0; *use 1 for required and 0 for informational only;
%let comprunout = 30;
%Let var= ImmunizAdol_flag ;
%Let prefix = ImmunizAdol; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=%str(&guidelibname.\BaseMeasure_Immunization Adolescent.sas);
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Immunizations Age 6 ;
%let guideline_key = 400.3.1.0.2; 
/**%let guideline_key = 130; */
%let rank1 = "62" "21" ; 
%let rank2 =  "XXXXX";
%let rank3 = "XXXXXX"; 
 *Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include:  2= Varicella, 3= IPV, 4=Dtap, 5=MMR 
	Optional to include: 1= Flu,99= Overall.;
%let submeasure_inclusion = ('2','3','4','5','99');
*%let incl_flu_flag = 0; *1 to require annual flu shot 0 for informational;
%let comprunout = 30;   *leeway for providing shots after 6th birthday in days;
%Let var= Immuniz6_flag;
%Let prefix = Immuniz6; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_Immunization_Age6.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Immunizations Pediatric - Age 2;
%let guideline_key = 400.4.1.0.2; 
/**%let guideline_key = 320;*/
%let rank1 = "62" "21" ; 
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= MMR, 2= HepB, 3= HepA, 5=Dtap, 6=Pneumoccoccal, 7=IPV, 8=HiB
	Optional to include: 4=Rotavirus, 9=Flu, 10=Varicella, 99= Overall.;
%let submeasure_inclusion = ('1','2','3','5','6','7','8','99');
%let comprunout= 0;
/*%let RV_compflag=0;   *Set to 1 if want to include in overall compliance;*/
/*%let Flu_compflag=0;  *Set to 1 if want to include in overall compliance;*/
/*%let VZV_compflag=0;  *Set to 1 if want to include in overall compliance;*/
%let hepb_comp = 3; *This is requirement for HepB compliance.  Set equal to 2 if only require 2 vaccines/ set equal to 3 if only require 3 vaccines;
%Let var= Immuniz2_mem_flag;
%Let prefix = Immuniz2; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_Immunization_Pediatric.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Chronic Kidney Disease - Lab Testing;
%let guideline_key = 420.1.1.0.2; 
/**%let guideline_key = 210;*/
%let var = CKD_flag;
%let rank1 = "40";
%let rank2 = "21" "25" "35" ;
%let rank3 = "XXXXXX";
 *Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Lipid, 2= Paratyhroid, 3=Serum Phosphorus, 4=Calcium,
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','2','3','4','99');
%Let prefix = CKD ; 
%let elig_startdt = 0; *First date for counting eligibility. Strongly recommend 0 because this is a process that, once started, does not reverse unless there is a 
transplant.  Use &stdt for new cases if client wishes previous year diagnoses as eligibility;
%let elig_enddt = &enddt.; *End date for counting eligibility.;
%let include=&guidelibname.\BaseMeasure_Kidney_Disease_Chronic_Labtesting.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;


*-----------------------------------*;
* Lipid Screening;
%let guideline_key = 450.2.1.0.2; 
/**%let guideline_key = 230; */
%let rank1 =  "08"; 
%let rank2 = "21" "35" "25" "62";
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Lipid Profile, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let minage = 20;
%let maxage = 90;
%Let var= lipid_flag;
%Let prefix = Dyslipidemia; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_Lipid_screening.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Melanoma;
%let guideline_key = 470.1.1.0.2; 
/**%let guideline_key = 280; */
%let rank1 = "17" ;
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Annual OV, 
	Optional to include: 99= Overall.;
%let age = 0;
%let attrib_start = 0; *First date for counting attribution visits.  Use 0 to look for all past visits. (&stdt.-366) for prev year ;
%let elig_startdt = (&stdt. - 366); *First date for counting eligibility. Use 0 to include any history of melanoma.  Use &stdt for new cases;
%let elig_enddt = &stdt.;  *End date for counting eligibility. Use &stdt to look at previous years. Use &enddt to look for current;
%let var = melanoma_flag;
%Let prefix = Melanoma ; 
%let include=&guidelibname.\BaseMeasure_Melanoma.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* New Onset Seizure;
%let guideline_key = 600.1.1.0.2; 
/**%let guideline_key = 370;*/
%let rank1 = "42" ; 
%let rank2 = "XXXXXX" ;
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= Timely Imaging w/ CT/MRI, 2= Timely EEG (Neuro Only), 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','2','99'); 
%let minage = 18; 
%let maxage = 99;
%let complianceperiod = 30;
%let excludedays = 761;
%Let var= seiz_mem;
%Let prefix = Seizure; 
%let include=&guidelibname.\BaseMeasure_NewOnset_Seizure.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;
*/


*-----------------------------------*;
* Osteoporosis, Women: High Risk - Ortho;
%let guideline_key = 510.5.1.0.2; 
/**%let guideline_key = 140; */
%let rank1 = "52" "20" "80" "27"; 
%let rank2 =  "21" "35" "45" "25";
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Bone Density,
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let compmonth= 180; *180 for 6 months/ 90 for 3 months;
%Let var= osteo_flag; 
%Let prefix = osteowomen_HRortho; 
%let include=%str(&guidelibname.\BaseMeasure_Osteoporosis Women HighRiskOrtho.sas);
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Osteoporosis Women Routine Screening;
%let guideline_key = 510.6.1.0.2; 
/**%let guideline_key = 150;*/
%let rank1 = "45" "21"; 
%let rank2 = "35" "20" "25" "80"; 
%let rank3 = "52"; 
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= 1st DEXA, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','2','99');
%Let var= osteo_flag;
%let trigger_age = 65;
%Let prefix = osteo_women;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=%str(&guidelibname.\BaseMeasure_Osteoporosis Women ScreeningRoutine.sas);
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Acute Pharyngitis - Pediatric;
%let guideline_key = 610.2.1.0.2; 
/**%let guideline_key = 40;*/
%let rank1 = "21" "62" "35"  ;
%let rank2 = "44";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Strep Test, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let var = AP_mem;
%let negdays = 30;
%let prefix = AP_ped ; 
%let minage= 2;
%let maxage = 18;
%let clientcomp = "86317" "86318" "86403" "87449";
/*%let excldays = 3;*/ 
/*%let excldiag = "058" "074" "487" "488";*/
%let include=&guidelibname.\BaseMeasure_Pharyngitis_AcutePediatric_Approp_testing.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Prenatal Routine Screening;
%let guideline_key = 550.2.1.0.2; 
/**%let guideline_key = 160;*/
%let rank1 = "45"; 
%let rank2 = "21" ;
%let rank3 = "XXXXXX"; 
*Client decides which submeasures want displayed/ included 	in the g6/G9. 
	Must include: 1= HepB, 2= RPR, 3= Rubella, 4= Blood Typing &Antibody,
	5= Urinanalysis and Culture, 6= CBC, 7= Chlamydia, 8= Gonorrhea, 
	Optional to include: 9= HIV, 10= Random Blood Sugar, 99= Overall.;
%let submeasure_inclusion = ('1','2','3','4','5','6','7','8','99'); 
%let HIV_compflag=0;   *Set to 1 if want to include in overall compliance;
%let gluc_compflag=0;  *Set to 1 if want to include in overall compliance;
%Let var= preg_mem;
%Let prefix = Prenatal; 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_Prenatal_RoutineScreening.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;


*-----------------------------------*;
* Well Child Visits 3-6 ;
%let guideline_key = 560.3.1.0.2; 
/**%let guideline_key = 200; */
%let rank1 = "21" "62" "44";
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= Well Visit, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99');
%let var= WV_3to6_flag;
%let prefix = WV_3to6;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let priorflag = .; *Use 0 to require at least one service date in prior year PLUS prior year or missing (.) for service date 
					 in current year only;
%let include=&guidelibname.\BaseMeasure_WellChildVisits_3to6.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Well Child Visits 15 Months;
%let guideline_key = 560.2.1.0.2; 
/**%let guideline_key = 340; */
%let rank1 = "21" "62" "44";
%let rank2 = "XXXXXX";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Well Visit, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let var= WV_15_flag;
%let prefix = WV_15;
%let leeway = 0; *Macro variable to allow for 0- 31 extra days leeway for compliance;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_WellChildVisits_15mos.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

*-----------------------------------*;
* Well Child Visits Adolescents;
%let guideline_key = 560.1.1.0.2; 
%let rank1 = "21" "62" "44";
%let rank2 = "45";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9.
	Must include: 1= Timely Well Visit, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let start_dt = &stdt.; *If want annual visit choose this;
/*%let start_dt = (&stdt. - 366); *If want visit every other year choose this*/
%let var= WV_adol_flag;
%let prefix = WV_Adolescent;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%let include=&guidelibname.\BaseMeasure_WellChildVisits_Adolescents.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;


*-----------------------------------*;
* Prostate Cancer Screening;
%let guideline_key = 555.1.1.0.2; *update client specific guideline key;
%let rank1 = "84";
%let rank2 = "21" "35" "25";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Biennial PSA, 
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99'); 
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%Let var=Prostate_flag;
%Let prefix = ProstateARnew; 
%let include=&guidelibname.\BaseMeasure_Prostate_screenAR.sas;
%include "&include";
%outlier_comments_setup;
%cleanup
%delvars

*-----------------------------------*;
* PSA After Prostate Cancer (High Risk Screening);
%let guideline_key = 555.2.1.0.2; *update client specific guideline key;
%let rank1 = "84" "30" "48";
%let rank2 = "25" "21" "35";
%let rank3 = "XXXXXX";
*Client decides which submeasures want displayed/ included in the g6/G9. 
	Must include: 1= Annual PSA,
	Optional to include: 99= Overall.;
%let submeasure_inclusion = ('1','99');
%let maxage = 120;
%let attrib_weight=3; *Weight a preventative visit more for attribution;
%Let var=Prostate_flag;
%Let prefix = ProstateHRnew; 
%let include=&guidelibname.\BaseMeasure_Prostate_screenHR.sas;
%include "&include";
%outlier_comments_setup;
%cleanup
%delvars
*----------------;




%let include=m:\NSAP\Programs\CIOPS\Modules\Base_Measures\V1.1\V1.1\BaseMeasure_Prostate_screenAR.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;

%let include=m:\NSAP\Programs\CIOPS\Modules\Base_Measures\V1.1\V1.1\BaseMeasure_Prostate_screenHR.sas;
%include "&include";
%outlier_comments_setup;
%cleanup;
%delvars;


