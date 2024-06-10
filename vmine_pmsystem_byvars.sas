
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_byvars
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Define the sorting variables for the edw_claims_extract.sas and
|           edw_claims_transformations.sas
|
| logic:                   
|
| input:         
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 01JAN2000 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 14MAR2011 - Winnie Lee - Clinical Integration 1.0.02
|			1. Modified bysort variables to match production for MISYS (System 10)
|
| 23MAR2011 - Winnie Lee - Clinical Integration 1.0.03
|			1. Modified bysort variables to match production for iMedica (System 19)
| 
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 14APR2012 - Brandon Sahulcik - Clinical Integration
|	      Added new PM System OfficeMate (PM System 155)
|
| 26APR2012 - G Liu - Clinical Integration 1.2.01
|			  Added PATID to byvar for AMS(9), AppMed(7), Centricity(3), eClinicalWorks(13), Greenway(96),
|				iMedica(19), Lytec(2), Medical Manager(5), Medisoft(1), Medware(20), Misys(10,105), NextGen(4)
|			  Added PERSON_KEY to all tranvar
|
| 27APR2012 - Brandon Sahulcik - Clinical Integration
|	      Added new PM System Delphi (PM System 432)
|
| 11MAY2012 - Winnie Lee - Clinical Integration
|			  Added new PM System SOS (PM System 143)
|
| 25MAY2012 - Brian Stropich - Clinical Integration
|			  Added new PM System PPMISAV (PM System 165)
|
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_byvars;


	%*SASDOC--------------------------------------------------------------------------
	| Remove duplicate claims - include maximum process ID to keep the latest  
	| claims for the practice data
	------------------------------------------------------------------------SASDOC*;
	%global byvars1  byvars2  byvars3  byvars4  byvars5  byvars6  byvars7  byvars8  byvars9  byvars10
	        byvars11 byvars12 byvars13 byvars14 byvars15 byvars16 byvars17 byvars18 byvars19 byvars20
			byvars21 byvars25 byvars29 byvars31 byvars43 byvars66 byvars72  byvars96 byvars97 byvars99 
			byvars105 byvars111 byvars143 byvars155 byvars165 byvars416 byvars432 byvars0 byvars00 byvars000;
	        
	%global tranvars1  tranvars2  tranvars3  tranvars4  tranvars5  tranvars6  tranvars7  tranvars8  tranvars9  tranvars10
	        tranvars11 tranvars12 tranvars13 tranvars14 tranvars15 tranvars16 tranvars17 tranvars18 tranvars19 tranvars20
	        tranvars21 tranvars25 tranvars29 tranvars31 tranvars43 tranvars66 tranvars72	 
			tranvars96 tranvars97 tranvars99 tranvars105 tranvars111 tranvars143 tranvars155 tranvars165 tranvars416 tranvars432 
			tranvars0 tranvars00 tranvars000;

	%*SASDOC--------------------------------------------------------------------------
	| PGF Systems - All   
	------------------------------------------------------------------------SASDOC*;		
	%let byvars0 = %str(memberid svcdt lname fname dob proccd npi mod1 mod2);
	%let tranvars0 = %str(client_key person_key member_key provider_key svcdt proccd mod1 mod2);
	
	%*SASDOC--------------------------------------------------------------------------
	| PGF Uploader Systems - All   
	------------------------------------------------------------------------SASDOC*;		
	%let byvars00 = %str(memberid svcdt lname fname dob proccd npi mod1 mod2 descending filename descending units);
	%let tranvars00 = %str(client_key person_key member_key provider_key svcdt proccd mod1 mod2 descending filename descending units);

	%*SASDOC--------------------------------------------------------------------------
	| 837 PROFESSIONAL
	------------------------------------------------------------------------SASDOC*;   
	%let byvars000 = %str(memberid svcdt lname fname dob proccd npi mod1 mod2 descending moddt descending filedt);
	%let tranvars000 = %str(client_key person_key member_key provider_key svcdt proccd mod1 mod2 descending moddt descending filedt); 

	%*SASDOC--------------------------------------------------------------------------
	| PM System 1 - Medisoft
	------------------------------------------------------------------------SASDOC*;
	%let byvars1   = %str(patid memberid svcdt lname fname dob proccd npi mod1 mod2  
					     descending kprocessid_mwtrn descending moddt 
		                 units submit diag1 diag2 diag3   
		                 descending claim_number  descending line_number descending maxprocessid descending kprocessid_mwcas);

	%let tranvars1   = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2  
					     descending kprocessid_mwtrn descending moddt 
		                 units submit diag1 diag2 diag3   
		                 descending claim_number  descending line_number descending maxprocessid descending kprocessid_mwcas);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 2 - Lytec
	------------------------------------------------------------------------SASDOC*;
	%let byvars2 = %str(patid memberid svcdt lname fname dob proccd npi mod1 mod2
	               descending  kprocessid_billingdetail descending moddt descending claim_number
		           descending units submit payorname1 diag1 diag2 diag3 descending maxprocessid);
		               
	%let tranvars2 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2
	                 descending  kprocessid_billingdetail descending moddt descending claim_number
		             descending units submit payorname1 diag1 diag2 diag3 descending maxprocessid);		             

	%*SASDOC--------------------------------------------------------------------------
	| PM System 3 - Centricity
	------------------------------------------------------------------------SASDOC*;
	%let byvars3 = %str(patid memberid lname fname dob svcdt proccd npi mod1 mod2    
		           descending patientmax descending units submit descending maxprocessid );

	%let tranvars3 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2    
		             descending patientmax descending units submit descending maxprocessid );		               
		               
	%*SASDOC--------------------------------------------------------------------------
	| PM System 4 - Next Gen
	------------------------------------------------------------------------SASDOC*;                  
	%let byvars4 = %str(patid memberid lname fname dob descending svcdt descending proccd npi mod1 mod2  
                   descending maxprocessid descending createdt units linenum /*claimnum*/ );
               
	%let tranvars4 = %str(client_key practice_key person_key member_key provider_key descending svcdt descending proccd mod1 mod2
                     descending maxprocessid  descending createdt units linenum /*claimnum*/ );
	/* claimnum commented out as stop gap to match SAS production, but eventually we need to figure out
		how to dedup the claims table due to multiple claim number for each encounter id.
		multiple claim number can be due to correction on original claim, or submission to different payor */

	%*SASDOC--------------------------------------------------------------------------
	| PM System 5 - Medical Manager
	------------------------------------------------------------------------SASDOC*;
	%let byvars5 = %str(patid memberid lname fname dob svcdt proccd npi mod1 mod2  
	               descending units submit payorname1 diag1-diag2 descending maxprocessid);

	%let tranvars5 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2
	                 descending units submit payorname1 diag1-diag2 descending maxprocessid);


	%*SASDOC--------------------------------------------------------------------------
	| PM System 6 -  Practice Point Manager
	------------------------------------------------------------------------SASDOC*;
	%let byvars6 = %str(memberid lname fname dob svcdt npi proccd descending mod1 descending mod2
		           descending maxprocessid descending moddt descending claimnum descending linenum); 

	%let tranvars6 = %str(client_key practice_key person_key member_key provider_key svcdt proccd descending mod1 descending mod2
						  descending maxprocessid descending moddt descending claimnum descending linenum);
 

	%*SASDOC--------------------------------------------------------------------------
	| PM System 7 -  AppMed
	------------------------------------------------------------------------SASDOC*; 
	%let byvars7 = %str(patid memberid svcdt lname fname dob proccd npi mod1 mod2   
	               descending kProcessID_Transactions descending moddt descending moddtclaim 
		             units submit diag1 diag2 diag3 descending maxprocessid);
		             
	%let tranvars7 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2   
	                   descending kProcessID_Transactions descending moddt descending moddtclaim 
		           units submit diag1 diag2 diag3 descending maxprocessid);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 8 -  Mosaiq
	------------------------------------------------------------------------SASDOC*;	
	%let byvars8 = %str(memberid svcdt lname fname dob proccd mod1 mod2 
                   descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars8 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2
						  descending maxprocessid descending moddt descending claimnum descending linenum);


	%*SASDOC--------------------------------------------------------------------------
	| PM System 9 - American Medical Software
	------------------------------------------------------------------------SASDOC*;		   
	%let byvars9 = %str(patid memberid svcdt lname fname dob proccd npi mod1 mod2
		               descending kProcessID_Charges descending moddt descending claim_number
		               descending units descending submit descending line_number descending maxprocessid);

	%let tranvars9 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2
		               descending kProcessID_Charges descending moddt descending claim_number
		               descending units descending submit descending line_number descending maxprocessid);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 10 - Allscripts Misys Tiger 
	------------------------------------------------------------------------SASDOC*;
	%let byvars10 = %str(patid memberid lname fname dob svcdt npi proccd mod1 mod2 
			     descending moddt  descending claimnum2 descending linenum2); /*14MAR2011 - WLee: modified bysort variables to match production*/
			     
	%let tranvars10 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2  
				descending moddt descending claimnum2 descending linenum2); /*14MAR2011 - WLee: modified bysort variables to match production*/

	%*SASDOC--------------------------------------------------------------------------
	| PM System 11 -  Allscripts Professional PM (formerly Healthmatics Ntierprise)
	------------------------------------------------------------------------SASDOC*;	
	%let byvars11 = %str(memberid svcdt lname fname dob npi proccd mod1 mod2 
                   		descending maxprocessid descending units descending submit );
                   		 
	%let tranvars11 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2
                   		descending maxprocessid descending units descending submit );            

	%*SASDOC--------------------------------------------------------------------------
	| PM System 12 -  Practice Partner
	------------------------------------------------------------------------SASDOC*;
	%let byvars12 = %str(memberid lname fname dob svcdt proccd mod1 mod2
						descending maxprocessid descending moddt 
                    	descending claim_number descending line_number);

	%let tranvars12 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2
							descending maxprocessid descending moddt 
                    		descending claim_number descending line_number);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 13 - eClinicalWorks 
	------------------------------------------------------------------------SASDOC*;
	%let byvars13 = %str(patid memberid lname fname dob svcdt npi proccd mod1 mod2
	                   descending claim_number descending line_number descending encounter_id); 

	%let tranvars13 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 
	                   descending claim_number descending line_number descending encounter_id); 
	                   
	%*SASDOC--------------------------------------------------------------------------
	| PM System 16 - MicroMD 
	------------------------------------------------------------------------SASDOC*;
	%let byvars16 = %str(memberid lname fname dob svcdt npi proccd mod1 mod2
	                   descending claim_number descending line_number ); 

	%let tranvars16 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 
	                   descending claim_number descending line_number ); 	                
 
	%*SASDOC--------------------------------------------------------------------------
	| PM System 19 - Aprima (Formerly iMedica)
	------------------------------------------------------------------------SASDOC*;
	%let byvars19 = %str(patid memberid svcdt lname fname dob npi proccd mod1 mod2 descending moddt descending maxprocessid 
					     descending linenum descending claimnum descending units descending submit); /*23MAR2011 - WLee: modified bysort variables to match production*/

	%let tranvars19 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 descending moddt descending maxprocessid 
					       descending linenum descending claimnum descending units descending submit); /*23MAR2011 - WLee: modified bysort variables to match production*/
               
	%*SASDOC--------------------------------------------------------------------------
	| PM System 20 - Medware  
	------------------------------------------------------------------------SASDOC*;		       
	%let byvars20 = %str(patid memberid svcdt lname fname dob proccd npi mod1 mod2
	                descending datemodified descending kprocessid_claim
		            units submit payorname1 diag1-diag3 descending claim_number
		            descending maxprocessid);	

	%let tranvars20 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 
	                  descending datemodified descending kprocessid_claim
		              units submit payorname1 diag1-diag3 descending claim_number
		              descending maxprocessid);	 

	%*SASDOC--------------------------------------------------------------------------
	| PM System 21 -  NexTech
	------------------------------------------------------------------------SASDOC*;
	%let byvars21 = %str(memberid svcdt lname fname dob proccd mod1 descending maxprocessid 
	                     descending claimnum descending linenum	                      
		             	 descending units descending submit mod2 payorname1 diag1 diag2 diag3) ;

	%let tranvars21 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 
							descending maxprocessid descending claimnum descending linenum	                      
		             	 	descending units descending submit mod2 payorname1 diag1 diag2 diag3) ;


	%*SASDOC--------------------------------------------------------------------------
	| PM System 25 -  AdvanceMD
	------------------------------------------------------------------------SASDOC*;
        %let byvars25 = %str(memberid lname fname dob svcdt proccd mod1 
                       descending mod2
                       descending moddt descending filename descending claim_number  
                       descending line_number descending units descending submit);
                       
        %let tranvars25 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1
                       descending mod2
                       descending moddt descending filename descending claim_number  
                       descending line_number descending units descending submit);
                       
                       
	%*SASDOC--------------------------------------------------------------------------
	| PM System 27 - AltaPoint 
	------------------------------------------------------------------------SASDOC*;
	%let byvars27 = %str(memberid svcdt lname fname dob npi proccd mod1 mod2 
						 descending maxprocessid descending units descending submit);

	%let tranvars27 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 
						 descending maxprocessid descending units descending submit);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 29 - AmazingCharts 
	------------------------------------------------------------------------SASDOC*;
	%let byvars29 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
					   	 descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars29 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2 descending maxprocessid
							descending moddt descending claimnum descending linenum);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 31 - ASPC 
	------------------------------------------------------------------------SASDOC*;
	%let byvars31 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
					   	 descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars31 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2 descending maxprocessid
							descending moddt descending claimnum descending linenum);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 43 - eMDs  
	------------------------------------------------------------------------SASDOC*;		       
	%let byvars43 = %str(memberid lname fname dob svcdt proccd npi descending mod1 descending mod2 
						 descending maxprocessid descending casenum descending claimnum descending linenum);	

	%let tranvars43 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 
							descending maxprocessid descending casenum descending claimnum descending linenum);	 

	%*SASDOC--------------------------------------------------------------------------
	| PM System 54 - IDX  
	------------------------------------------------------------------------SASDOC*;
	%let byvars54 = %str(memberid lname fname dob svcdt proccd descending mod1 descending mod2
						descending moddt descending maxprocessid descending claimnum descending linenum
						descending units descending submit);

	%let tranvars54 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2
							descending moddt descending maxprocessid descending claimnum descending linenum
							descending units descending submit);


	%*SASDOC--------------------------------------------------------------------------
	| PM System 66 - MedEvolve
	------------------------------------------------------------------------SASDOC*;
	%let byvars66 = %str(memberid lname fname dob svcdt proccd mod1 mod2 descending filename 
                       descending claimnum descending linenum); 

	%let tranvars66 = %str(client_key practice_key member_key provider_key svcdt proccd mod1 mod2 descending filename 
                       descending claimnum descending linenum); 


	%*SASDOC--------------------------------------------------------------------------
	| PM System 72 - MPMOffice 
	------------------------------------------------------------------------SASDOC*;
	%let byvars72 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
					   	 descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars72 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2 descending maxprocessid
							descending moddt descending claimnum descending linenum);


	%*SASDOC--------------------------------------------------------------------------
	| PM System 96 -  Greenway
	------------------------------------------------------------------------SASDOC*;
	%let byvars96 = %str(patid memberid svcdt lname fname dob proccd mod1 mod2
						 descending maxprocessid descending claim_number descending line_number );

	%let tranvars96 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 
							descending maxprocessid	descending claim_number descending line_number );

	%*SASDOC--------------------------------------------------------------------------
	| PM System 97 -  MedInformatix
	------------------------------------------------------------------------SASDOC*;
	%let byvars97   = %str(memberid svcdt lname fname dob proccd mod1 descending maxprocessid mod2 
		      descending claim_number descending line_number units submit payorname1 );
		      
	%let tranvars97   = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2  
		      descending claim_number descending line_number units submit payorname1 );		      
		     
	%*SASDOC--------------------------------------------------------------------------
	| PM System 99 -   Office Practicum
	------------------------------------------------------------------------SASDOC*;
	%let byvars99 = %str(memberid svcdt lname fname dob proccd mod1 mod2
	                   descending kProcessID_ArchiveTransactions   
		           units submit payorname1 diag1 diag2 diag3 descending claimnum descending linenum descending maxprocessid) ;

	%let tranvars99 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2 
                           descending kProcessID_ArchiveTransactions   
		           units submit payorname1 diag1 diag2 diag3 descending claimnum descending linenum descending maxprocessid);	 

	%*SASDOC--------------------------------------------------------------------------
	| PM System 105 - Allscripts Misys PM
	------------------------------------------------------------------------SASDOC*;                
 	%let byvars105 = %str(patid memberid svcdt lname fname dob proccd mod1 
						  descending maxprocessid descending moddt descending claim_number 
		 				  descending line_number);

	%let tranvars105 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 
						    descending maxprocessid descending moddt descending claimnum 
		 				    descending linenum);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 111 -  CompulinkOA
	------------------------------------------------------------------------SASDOC*;                
 	%let byvars111 = %str(memberid svcdt lname fname dob npi proccd mod1 mod2
						 descending maxprocessid descending moddt descending moddt_ldgr 
						 descending casenum descending claim_number descending line_number);

	%let tranvars111 = %str(client_key practice_key person_key member_key provider_key svcdt proccd mod1 mod2
						 	descending maxprocessid descending moddt 
						 	descending casenum descending claimnum descending linenum);


	%*SASDOC--------------------------------------------------------------------------
	| PM System 143 -  SOS
	------------------------------------------------------------------------SASDOC*;                
 	%let byvars143 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
					   	 descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars143 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2 descending maxprocessid 
							descending moddt descending claimnum descending linenum);


	%*SASDOC--------------------------------------------------------------------------
	| PM System 155 - OfficeMate 
	------------------------------------------------------------------------SASDOC*;
	%let byvars155 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
					   	 descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars155 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2 descending maxprocessid
							descending moddt descending claimnum descending linenum);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 165 - PPMISAV 
	------------------------------------------------------------------------SASDOC*;
	%let byvars165 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
      			descending maxprocessid descending moddt descending claimnum descending linenum 
      			payorname1 payorname2 payorname3);
	%let tranvars165 = %str(client_key practice_key person_key member_key provider_key svcdt proccd descending mod1 descending mod2
      			descending maxprocessid descending moddt descending claimnum descending linenum 
      			payorname1 payorname2 payorname3);
							

	%*SASDOC--------------------------------------------------------------------------
	| PM System 416 - TRAKnet 
	------------------------------------------------------------------------SASDOC*;
	%let byvars416 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
					   	 descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars416 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2 descending maxprocessid
							descending moddt descending claimnum descending linenum);

	%*SASDOC--------------------------------------------------------------------------
	| PM System 432 - DELPHI 
	------------------------------------------------------------------------SASDOC*;
	%let byvars432 = %str(memberid svcdt lname fname dob proccd descending mod1 descending mod2
					   	 descending maxprocessid descending moddt descending claimnum descending linenum);

	%let tranvars432 = %str(client_key practice_key person_key member_key provider_key 
							svcdt proccd descending mod1 descending mod2 descending maxprocessid
							descending moddt descending claimnum descending linenum);

%mend vmine_pmsystem_byvars;
