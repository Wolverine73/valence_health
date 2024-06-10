
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  guideline_datasets_cleanup.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Delete temp datasets used for guidelines  
|
| LOGIC:    Delete temp datasets used for guidelines 
|           
| INPUT:    d1-d5,g1-g8,elig1-elig5,elig_dt1-elig_dt3, g6_a-g6_i          
|
| OUTPUT:   none - delete datasets
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 26MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created guideline datasets cleanup macro
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro cleanup;

proc datasets library=work;
	delete d1 d2 d3 d4 d5 g1 g1a g1_a g1b g2 g3 g4 g4a g5 g5a g6 g7 g8
		elig1 elig2 elig3 elig4 elig4a elig5 Elig_dt1 Elig_dt2 Elig_dt3
		g6_A g6_B g6_C g6_D g6_E g6_F g6_G g6_H g6_I g6_J g6_k
		g9a g9b g9c g9d g9e g9f g9g g9h g9i g9j g9k temp
		g1_diabetic g1_laser g1_med g1_nopriormem g1_priormem g1_surgery surgery_allclaims
		g4b g6_m g9m laser_allclaims action1 action2 med_allclaims nopriormem_allclaims priormem_allclaims
		g1_md g1_inject g1_photo inject_allclaims md_allclaims photo_allclaims
		&prefix._g0;
run;
quit;
%mend cleanup;

