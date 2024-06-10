/*HEADER------------------------------------------------------------------------
|
| program:  vmine_provider_cleanup
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on NPI and TIN for all PM Systems
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
| 28SEP2011 - Valence Health - Clinical Integration 2.0.00
|             
+-----------------------------------------------------------------------HEADER*/

%macro vmine_provider_cleanup (client_id=, do_practice_id=);

	%*SASDOC--------------------------------------------------------------------------
	| Set up provider libnames and formats
	--------------------------------------------------------------------------SASDOC*;

	/***** ADVENTIST ****************************************************************/
	%if &client_id. = 2 %then %do;

			/* MAKE EDITS HERE 
			   Example:
					libname x "\\sas2\Adventist\sasdata\CIETL\Provider\Formats";
					proc format cntlin = x.provyn;
			*/

	%end;

	/***** CCCPP ********************************************************************/
	%else %if &client_id. = 6 %then %do;

		libname provfmt "M:\CCCPP\sasdata\CIETL\Provider\Formats";
		proc format cntlin = provfmt.provyn;
		
	%end;

	/***** EXEMPLA ******************************************************************/
	%else %if &client_id. = 8 %then %do;

			/* MAKE EDITS HERE 
			   Example:
					libname x "\\sas2\Adventist\sasdata\CIETL\Provider\Formats";
					proc format cntlin = x.provyn;
			*/

	%end;

	/***** NSAP *********************************************************************/
	%else %if &client_id. = 4 %then %do;

		libname provfmt "M:\NSAP\sasdata\CI\CIETL\provider\formats" ;
proc format cntlin=provfmt.upin_npi;


	%end;

	/***** OHG **********************************************************************/
	%else %if &client_id. = 7 %then %do;

			/* MAKE EDITS HERE 
			   Example:
					libname x "\\sas2\Adventist\sasdata\CIETL\Provider\Formats";
					proc format cntlin = x.provyn;
			*/

	%end;

	/***** PHS **********************************************************************/
	%else %if &client_id. = 5 %then %do;

			/* MAKE EDITS HERE 
			   Example:
					libname x "\\sas2\Adventist\sasdata\CIETL\Provider\Formats";
					proc format cntlin = x.provyn;
			*/
      libname x "M:\PHS\sasdata\CIETL\provider\formats";
      proc format cntlin = x.provname;
	%end;

	/***** STLUKES ******************************************************************/
	%else %if &client_id. = 3 %then %do;

			libname x "\\sas2\stlukes\sasdata\CIETL\Provider\Formats";
                              proc format cntlin = x.provyn;
							  proc format cntlin = x.upin_npi;
							  proc format cntlin = x.npi2tin;
							  *run;

	%end;



	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	--------------------------------------------------------------------------SASDOC*;

	data practice_&do_practice_id.;
	set practice_&do_practice_id.;


		/***** ADVENTIST ****************************************************************/

		%if &client_id. = 1 %then %do;

			/* MAKE EDITS HERE 
			   Example:
					if &do_practice_id.=123 then do;
						if provname = 'SMITH, JAMES' and npi = '' then npi = '';
						if tin = '' then tin = '987654321';
					end;
			*/

		%end;


		/***** CCCPP ********************************************************************/

		%else %if &client_id. = 6 %then %do;

			*ECLINICAL;
			if cats(provname) 		= "BONNIE WHITE, MD" 	then npi = "1336146653";
			if cats(provname)		= "STEPHANIE L KERESZTES, PA" then npi = "1386833366";

			*MEDISOFT;
			if cats(provname) 		= "CHOHANEY, KATHLEEN"	then npi = "1720169782";

			*MEDISOFT16;
			if cats(provname) 		= "KHAMBATTA, PARVEZ" 	then npi = "1326126368";
			if cats(provname) 		= "LLERENA, LUIS"		then npi = "1639164148";
			if cats(provname) 		= "MOURANY, ADNAN"		then npi = "1952320178";
			if cats(provname) 		= "MOURANY, MOURANY"	then npi = "1952320178";
			if cats(provname) 		= "SEE, LILY" 			then npi = "1376511634";
			if cats(provname) 		= "MOHR, ROSE" 			then npi = "1346222684";

			*MISYS;
			if cats(provname)		= "BROWN MD, BERT"			and npi = "" then npi = "1114928900";
			if cats(provname)		= "DOBROWSKI MD, JOHN"		and npi = "" then npi = "1538160452";
			if cats(provname)		= "FLORES MD, TORIBIO"		and npi = "" then npi = "1407857162";
			if cats(provname)		= "MCDONNELL MD, MATTHEW"	and npi = "" then npi = "1841291507";

			*Centricity;
			else if cats(provname) 	= "KRIWINSKY, JAN" 		then npi = "1982632881";
			else if cats(provname) 	= "REYES, BETTINA" 		then npi = "1710919907";
			else if cats(provname) 	= "ROSENTHAL, ALAN" 	then npi = "1003848284";

			*MedicalManager;
			else if cats(provname) 	=: "SLAWINSKI," 			then npi = "1548285521";
				
		%end;


		/***** EXEMPLA ******************************************************************/

		%else %if &client_id. = 8 %then %do;

			/**CENTRICITY-Exempla**/
				 if compress(provname) = 'ABERNATHY,BRETT' then npi='1437106028';
			else if compress(provname) = 'AUGSPURGER,RICHARD' then npi='1811944663';
			else if compress(provname) = 'CONYERS,DAVID' then npi='1780648378';
			else if compress(provname) = 'FRY,THOMAS' then npi='1558325662';
			else if compress(provname) = 'GROSS,ERIC' then npi=	'1336135516';
		    else if compress(provname) = 'HEPPE,RICHARD' then npi= '1649207077';
		    else if compress(provname) = 'HSU,ELIAS' then npi= '1902077332';
		    else if compress(provname) = 'JONES,MARKLYN' then npi= '1003859075';
			else if compress(provname) = 'KARSH,LAWRENCE' then npi=   '1194766279';
		    else if compress(provname) = 'MAY,DONALD' then npi=   '1689615999';
		    else if compress(provname) = 'MILLS,JESSE' then npi=   '1295881803';
		    else if compress(provname) = 'MONTOYA,JUAN' then npi=   '1588607626';
		    else if compress(provname) = 'MUELLERJR,FERDINAND' then npi=   '1811916794';
		    else if compress(provname) = 'PHILPOTT,ALEXANDER' then npi=   '1598706889';
		    else if compress(provname) = 'RAGAN,DAVID' then npi=   '1568403657';
		    else if compress(provname) = 'RUYLE,STEPHEN' then npi=   '1558300483';
		    else if compress(provname) = 'SMITH,BRIAN' then npi=   '1629011564';
		    else if compress(provname) = 'SORENSEN,CARSTEN' then npi=   '1780625392';
		    else if compress(provname) = 'WESTMACOTT,REGINALD' then npi=   '1194760827';
		    else if compress(provname) = 'WILSON,CHRISTOPHER' then npi=   '1841254943';
		    else if compress(provname) = 'WOLF,TRACY' then npi=   '1285698886';
			else if compress(provname) = 'SAKURADA,CRAIG' then npi = '1376582288';
			else if compress(provname) = 'ASAD,JUHI' then npi ='1821252206';
			else if compress(provname) = 'BAER,BRYAN' then npi = '1912904327';
			else if compress(provname) = 'BREW,ELIZABETH' then npi = '1962519363';
			else if compress(provname) = 'PULIDO,EDWARD' then npi = '1225072010';
			else if compress(provname) = 'WARING,BRUCE' then npi = '1366559742';
			else if compress(provname) = 'BALES,STEPHEN' then npi = '1750383394';
			else if compress(provname) = 'ZWIERS,LISA' then npi = '1396924049';

			/*MEDMAN*/
			if upin = "E90278" or compress(provname) ="DART,M.D.,DOUGLAS" then npi = "1376657411";
			else if compress(provname) = 'REDOSHMD,DOUGLAS' and npi = '' then npi = '1679546758';
			if upcase(compress(provname)) ='PICKETT,HMANNING' then npi = '1902964075';

			/*NTERPRISE*/
		    if upcase(compress(provname)) = "BERGEN,MICHAEL" then npi = "1851385330";
	        if upcase(compress(provname))=  'WRIGHT,ROBERT'  then npi=  '1275544421';
	        if upcase(compress(provname))=  'PACKER,ROBERT'  then npi = '1366453516';
	        if upcase(compress(provname))=  'HELZER,AMITY'   then npi = '1013069566';


			/*MEDISOFT*/
			if compress(provname) = "DESJARDIN,JEFFREY" then npi = "1821191305";
		    if compress(provname) = "CULLINAN,MARYLOU"  then npi=  "1710041942";
		    if compress(provname) = "HAMMERBERG,ERIC"   then npi=  "1427234046";

			/* MEDWARE */
		    if compress(provname) = "DOBBS,AUDREY"   then npi=  "1316007826";
		%end;



		/***** NSAP *********************************************************************/

		%else %if &client_id. = 4 %then %do;

		
			if NPI = "" and upin ne "" then NPI = put(UPIN,$UPIN_NPI.);

			*SASDOC--------------------------------------------------------------------------
			| GE Centricity                            
			|------------------------------------------------------------------------SASDOC*;
			if provname in ('KAHAN, ERIKA') then npi  = '1992756340';
			if provname in ('LEYENSON, VADIM') then npi  = '1427052851';
			if provname in ('RIES, MICHAEL') then npi  = '1366446791';
			if provname in ('ROSENBERG, NEIL') then npi  = '1265436695';
			if provname in ('SANDERS, WILLIAM') then npi  = '1164426599';
			if provname in ('WEINBERGER, JULIA') then npi  = '1063445195';
			if provname in ('GOLDBERG, MARNI') then npi  = '1063459741';
			if provname in ('GRINBLATT, JEFFREY') then npi  = '1679580039';
			if provname in ('MEYERS, STEVEN') then npi  = '1770579716';
			if provname in ('BITRAN, JACOB') then npi = '1407815822';
			if provname in ('FRIED, WALTER') then npi = '1851350284';
			if provname in ('GALVEZ, ANGEL') then npi = '1144280835';
			if provname in ('HALLMEYER, SIGRUN') then npi = '1164481412';
			if provname in ('HOOBERMAN, ARTHUR') then npi = '1124088489';
			if provname in ('KAISER, PAMELA') then npi = '1184684821';
			if provname in ('LESTINGI, TIMOTHY') then npi = '1114986411';
			if provname in ('NABHAN, CHADI') then npi = '1972563682';
			if provname in ('RICHARDS, JON') then npi = '1588624290';


			*SASDOC--------------------------------------------------------------------------
			| imedica - resolution for npi and tin                            
			|------------------------------------------------------------------------SASDOC*;
			if kPracticeID = 346 then do;
			   tin = '061648249';
			   if provname in('','JEFFREY JACOBS') then do;
				provname = ('JEFFREY JACOBS');
				npi = '1174524136';
			   end;
			end;

			if provname in ('NINA MEREL') then do;
				   npi = '1285616300';
				   tin = '362894273';
			end;

			if kPracticeID=256 then do;
				if provname in ('GOLDIN, HARRY') then do;
					npi='1184619785';
					tin='363681398';
				end;
			end;


			if kPracticeID = 347 then do;

				if provname in ('DANIEL GOLDSTEIN') then do;
					npi = '1265401335';
					tin = '362697811';
				end;

				if provname in ('BETTY GOLDSTEIN') then do;
				   npi = '1699743070';
				   tin = '362697811';
				end;
			   
				if provname in ('IRENA CHIZHIK') then do;
					npi = '1275501579';
					tin = '362697811';
				end;

				if provname in ('STEVEN LEVINE') then do;
					npi = '1275502346';
					tin = '362697811';
				end;
				if provname in ('JEFFREY WEINBERG') then do;
					npi = '1447228762';
					tin = '362697811';
				end;

				if provname in ('JEFFREY RAGER') then do;
					npi = '1538137831';
					tin = '362697811';
				end;
				if provname in ('JEFFREY FOREMAN') then do;
					npi = '1881663243';
					tin = '362697811';
				end;
				if provname in ('STEVEN SHOLL') then do;
					npi = '1982672275';
					tin = '362697811';
				end;
				if provname in ('SHARON BERLIANT') then do;
					npi = '1982672549';
					tin = '362697811';
				end;

				if provname in ('DOUGLAS ADLER') then do;
					npi = '1255313367';
					tin = '362894273';
				end;
				if provname in ('RONALD BLOOM') then do;
					npi = '1659353779';
					tin = '362894273';
				end;
				if provname in ('ALAN SHAPIRO')  then do;
					npi = '1881676997';
					tin = '362894273';
				end;
				if provname in ('KEN CHI') then do;
					npi = '1821070939';
					tin = '362894273';
				end;
			end;

			if kPracticeID = 350 then do;
				tin = '364435962';
				if provname = ('') then do;
					provname = 'WOLF, M.D.ROBERT J.';
			 		npi = '1376566034';
				end;
				if provname in ('ROBERT WOLF M D') then npi =  '1376566034';
			end;

			*SASDOC--------------------------------------------------------------------------
			| lytec - resolution for npi and tin                             
			|------------------------------------------------------------------------SASDOC*;
			if provname in ('EDWARDS, ELENA') then  do;
				npi = '1568524098'; 
			    tin = '262643964';
			end;

			*SASDOC--------------------------------------------------------------------------
			| medisoft - resolution for npi and tin                             
			|------------------------------------------------------------------------SASDOC*;
			if provname in ('MORGAN, JACK') then tin = '363509633';
			if provname in ('KIM, DONG') then npi = '1255307104';
			if provname in ('LANSKY, OLGA') then npi = '1326019407';
		     
			if kPracticeID = 430 then tin = '611442061';
			*SASDOC--------------------------------------------------------------------------
			| medman - resolution for npi and tin                             
			|------------------------------------------------------------------------SASDOC*;
			if kPracticeID = 242 then tin = '362697154';
			if kPracticeID = 342 then tin = '362784592';
			if provname in ('SPERO, MD,') then do;
			   tin = '363434158';
			end;

			if provname in ('KURGANOFF, M.D.,') then do;
			   tin = '260480606';
			   npi = '1720270085';
			end;

			if kPracticeID = 368 then do;
			   tin = '320042680';
			   if provname in ('ASHBY, SUZANNE') then npi = '1124100839';
			   if provname in ('SHAW, DAVID') then npi = '1952484644';
			end;

			if kPracticeID  = 244 then do;
			   tin = '362679877';
			end;

			*SASDOC--------------------------------------------------------------------------
			| medware - resolution for npi and tin                             
			|------------------------------------------------------------------------SASDOC*;
			if provname in ('KALE, SCOTT') then npi = '1861416737';
			if kPracticeID = 367 then do;
			   tin = '363530510';
			end;

			*SASDOC--------------------------------------------------------------------------
			| misys - resolution for npi and tin                            
			|------------------------------------------------------------------------SASDOC*;
			if kPracticeID = 280 then tin = '043683352';

			*SASDOC--------------------------------------------------------------------------
			| nextgen - resolution for npi and tin                            
			|------------------------------------------------------------------------SASDOC*;
			if kPracticeID = 365 then tin = '043827137';

			*SASDOC--------------------------------------------------------------------------
			| eclinical - resolution for npi and tin                            
			|------------------------------------------------------------------------SASDOC*;
			if kPracticeID = 358 then do;
			   if npi='1063459741' and tin = "" then tin='364417968';
			   if npi='1952359440' or npi='1760431076' and tin="" then tin = '364094373';
			end;

			if kPracticeID = 371 then do;
			   tin = '362894273';
			end;

			if kPracticeID = 245 then do;
			   tin = '030401297';
			end;

		%end;



		/***** OHG **********************************************************************/

		%else %if &client_id. = 7 %then %do;
	 
			practiceid =  &do_practice_id.;
			FILENAME RECODE "M:\CI\programs\ClientMacros\cio\ohg_npi_&system..txt";
			%IF %SYSFUNC(FEXIST(RECODE)) %THEN %DO;
				%include "M:\CI\programs\ClientMacros\cio\ohg_npi_&system..txt"/source2;
			%END;

		%end; 



		/***** PHS **********************************************************************/

		%else %if &client_id. = 5 %then %do;

			practiceid =  &do_practice_id.;
			FILENAME RCD "M:\CI\programs\ClientMacros\cio\phs_npi_&system..txt";
			%IF %SYSFUNC(FEXIST(RCD)) %THEN %DO;
				%include "M:\CI\programs\ClientMacros\cio\phs_npi_&system..txt"/source2;
			%END;

		%end;



		/***** STLUKES ******************************************************************/

		%else %if &client_id. = 3 %then %do;
			
			FILENAME SLEH "M:\StLukes\programs\CIETL\claims\vMine\vMine_hardcode_cleanups.txt";
			%IF %SYSFUNC(FEXIST(SLEH)) %THEN %DO;
				%include "M:\StLukes\programs\CIETL\claims\vMine\vMine_hardcode_cleanups.txt"/source2;
			%END;
			%end;

/*			if tin = '' then do;*/
/*			tin=put(npi, $npi2tin.);*/
/*			end;*/
/*			if npi = '1811974090' then tin = '760531506';*/
/**/
/*			if npi = '1346230976' then tin = '275461233';*/
/*			IF UPCASE(COMPRESS(PROVNAME))  IN ('ALAMMD,TAWFIQ') THEN NPI = '1629092689';*/
/*			if upcase(compress(provname))  in ('MEYER,B.CHRISTOPH') then npi = '1225036429';*/
/*			if upcase(compress(provname))  in ('SPARKSJR,JOHN') then npi = '1558353177';*/
/*			/**GE Centricity--THIS SYSTEM DOESN'T PULL NPI**/*/
/*			if upcase(compress(provname))  in ('BENZ,MATTHEW') then npi = '1689771545';*/
/*			if upcase(compress(provname))  in ('BROWN,DAVID') then npi = '1548368509';*/
/*			if upcase(compress(provname))  in ('FISH,RICHARD') then npi = '1881792844';*/
/*			if upcase(compress(provname))  in ('OMALLEY,RONAN') then npi = '1194719765';*/
/*			if upcase(compress(provname))  in ('MORAN,KEVIN') then npi  = '1376535922';*/
/*			if upcase(compress(provname))  in ('ANKOMA-SEY,VICTOR') then npi  = '1144226515';*/
/*			if upcase(compress(provname))  in ('GOTTESMAN,MARK') then npi  = '1770684375';*/
/*			if upcase(compress(provname))  in ('MORGAN,MEREDITH') then npi  = '1326193574';*/
/*			if upcase(compress(provname))  in ('CHERCHES,IGOR') then npi  = '1942295522';*/
/*			if upcase(compress(provname))  in ('JONES,JULIA') then npi  = '1225024854';*/
/*			if upcase(compress(provname))  in ('LOVITT,STEVEN') then npi  = '1114912748';*/
/*			if upcase(compress(provname))  in ('MCLAUCHLIN,GREG') then npi  = '1023004694';*/
/*			if upcase(compress(provname))  in ('CHOKSI,ASIT') then npi  = '1295798874';*/
/*			if upcase(compress(provname))  in ('KHOURY,PIERRE') then npi  = '1548223878';*/
/*		*/
/*			if upcase(compress(provname))  in ('SETHI,GURDEEP') then npi  = '1801859491';*/
/*			if upcase(compress(provname))  in ('SEYMOUR,GREGORY') then npi  = '1720041056';*/
/*			if upcase(compress(provname))  in ('SUKI,SAMER') then npi  = '1639132962';*/
/*	*/
/*			if upcase(compress(provname))  in ('CHUKWUMA,EGWIM') then npi  = '1265607725';*/
/*			if upcase(compress(provname))  in ('BETHEA,LOUISE') then npi  = '1841258217';*/
/**/
/*			if upcase(compress(provname))  in ('BOBO,KIMBERLY') then npi  = '1194710616';*/
/*			if upcase(compress(provname))  in ('BOSWELL,HILLARY') then npi  = '1083827281';*/
/*			if upcase(compress(provname))  in ('DEFRANCESCO,THEODORAH') then npi  = '1437144581';*/
/*			if upcase(compress(provname))  in ('DRYDEN,DAMLA') then npi  = '1699760116';*/
/*			if upcase(compress(provname))  in ('HEARD,MICHAEL') then npi  = '1851353031';*/
/*			if upcase(compress(provname))  in ('MOTT,WANDA') then npi  = '1235124546';*/
/*			if upcase(compress(provname))  in ('OTUNLA,MERCY') then npi  = '1992790042';*/
/*			if upcase(compress(provname))  in ('YOSOWITZ,EDWARD') then npi  = '1851386288';*/
/*			if upcase(compress(provname))  in ('ZEPEDA,DAVID') then npi  = '1033104351';*/
/**/
/*			/**renal specialist of houson added 11-2010**/*/
/*			if upcase(compress(provname))  in ('MUNIZ,HENRY') then npi  = '1023034014';*/
/*			if upcase(compress(provname))  in ('SHEARER,SARAH') then npi  = '1083630065';*/
/*			if upcase(compress(provname))  in ('FAUST,ERIC') then npi  = '1306862396';*/
/*			if upcase(compress(provname))  in ('BARCENAS,CAMILO') then npi  = '1932125929';*/
/*			if upcase(compress(provname))  in ('ETHERIDGE,WHITSON') then npi  = '1710906680';*/
/**/
/**/
/*			if upcase(compress(provname))  in ('BERKMAN,ERIC') then npi  = '1932201241';  /**Added 11-9-10**/*/
/*			if upcase(compress(provname))  in ('GHOSH,SUBRATA') then npi  = '1477554913';  /**Added 8-12-09**/*/
/*			if upcase(compress(provname))  in ('BERRY,JOHN') then npi  = '1184602948';  /**Added 8-12-09**/*/
/*			if upcase(compress(provname))  in ('WONG,TIEN') then npi = '1003914151';*/
/*			if upcase(compress(provname))  in ('JANSSEN,NAMIETA') then npi = '1609979947';*/
/*			if upcase(compress(provname))  in ('JANSSEN,NAMIETA') then npi = '1609979947';*/
/*	*/
/*			if upcase(compress(provname))  in ('SHEARER,SARAH') then npi = '1083630065';*/
/*	*/
/*			/**Lytec**/*/
/*			if upcase(compress(provname))  in ('LI,KWOK') then npi = '1487641353';*/
/**/
/*			/**Medisoft**/*/
/*			if upcase(compress(provname))  in ('KOVACS,JULIA') then npi  = '1366527798';*/
/*			if upcase(compress(provname))  in ('SIFF,SHERWIN') then npi  = '1497793392';*/
/*			if upcase(compress(provname))  in ('BARROWS,LINDA') then npi  = '1467555813';*/
/*			if upcase(compress(provname))  in ('ELZUFARI,MOHAMMAD') then npi  = '1689669525';*/
/*			if upcase(compress(provname))  in ('CHENG,YAIYUNJUDY') then npi  = '1194759258';*/
/*			if upcase(compress(provname))  in ('VELAZQUEZ,FRANCISCO') then npi = '1922096197';*/
/*			if upcase(compress(provname))  in ('SCHULZE,KEITH') then npi = '1174612162';*/
/*			if upcase(compress(provname))  in ('SPARKSJR,JOHN') then npi = '1558353177';*/
/*			if upcase(compress(provname))  in ('FACKLER,JOHN') then npi = '1447242128';*/
/*			if upcase(compress(provname))  in ('CARNEY,RICHARD') then npi = '1124018544';*/
/*			if upcase(compress(provname))  in ('LAM,MICHAEL') then npi = '1548200835';*/
/*			if upcase(compress(provname))  in ('MAHESRI,MURTAZA') then npi = '1437253739';*/
/*			if upcase(compress(provname))  in ('RAMOS,ANTONIO') then npi = '1063424992';*/
/*			if upcase(compress(provname))  in ('AL-KHADOUR,HUSSAMADDIN') then npi = '1396730230';*/
/*			if upcase(compress(provname))  IN ('BERBERIAN,ESTEBAN') then NPI = '1962490052';*/
/**/
/**/
/*			/**AllScripts**/*/
/*			if upcase(compress(provname))  in ('RAIJMAN,ISAAC') then npi = '1689679557';*/
/**/
/*			/**Medical Manager**/*/
/*			/**Practice 205 does not have NPI's**/*/
/*			if upcase(compress(provname))  in ('AHUJA,ANOOP', 'AHUJAMD,ANOOP') then npi  = '1619960994';*/
/*			/**if upcase(compress(provname))  in ('HERNDON, JOHN') then npi  = 'XXXXXXXXXXXXXXXXXXX'**/*/
/*			if upcase(compress(provname))  in ('HORWITZ,MELTON', 'HORWITZMD,MELTON') then npi  = '1487647798';*/
/*			if upcase(compress(provname))  in ('KAPLAN,MICHAEL', 'KAPLANMD,MICHAEL') then npi  = '1750443289';*/
/*			if upcase(compress(provname))  in ('KATZ,CHARLES') then npi  = '1922091230';*/
/*			if upcase(compress(provname))  in ('FEIGON,JUDITH') then npi  = '1871592063';*/
/*			if upcase(compress(provname))  in ('HAREMD(CC-DCH),JOANIE','HAREMD(CNRO),JOANIE','HAREMD(KTY),JOANIE',*/
/*				'HAREMD(KWD),JOANIE','HAREMD(LUF),JOANIE','HAREMD(SL),JOANIE','HAREMD(WH),JOANIE','HARE,MD(GR),JOANIE',*/
/*				'HARE,MD(WB),JOANIE','HARE,MD,JOANIE') then npi = '1184625667';*/
/*			if upcase(compress(provname))  in ('KIRSHONMD(CNRO), BRIAN','KIRSHONMD(KTY), BRIAN','KIRSHONMD(KWD), BRIAN',*/
/*				'KIRSHONMD(LUF),BRIAN','KIRSHONMD(SL),BRIAN','KIRSHONMD(WH),BRIAN','KIRSHON,MD(GR),BRIAN',*/
/*				'KIRSHON,MD(WB),BRIAN','KIRSHON,MD,BRIAN') then npi = '1679574115';*/
/*			if upcase(compress(provname))  in('MACCATOMD(CNRO),MAURIZIO','MACCATOMD(KTY), MAURIZIO','MACCATOMD(KWD),MAURIZIO',*/
/*				'MACCATOMD(WH),MAURIZIO','MACCATO, MD(GR),MAURIZIO','MACCATO,MD,MAURIZIO') then npi = '1396746830';*/
/*			if upcase(compress(provname))  in ('PINELLMD(CNRO),PHILLIP','PINELLMD(KTY),PHILLIP','PINELLMD(KWD),PHILLIP',*/
/*				'PINELLMD(WH),PHILLIP','PINELL,MD(GR),PHILLIP','PINELL,MD,PHILLIP') then npi  = '1922009463';*/
/*			if upcase(compress(provname))  in ('REITERMD(CC),ALEXANDER','REITERMD(CNRO),ALEXANDER','REITERMD(KS),ALEXANDER','REITERMD(KTY),ALEXANDER',*/
/*				'REITERMD(KWD),ALEXANDER','REITERMD(LUF),ALEXANDER','REITERMD(SL),ALEXANDER','REITERMD(WH),ALEXANDER',*/
/*				'REITERMD,ALEXANDER','REITER,MD(GR),ALEXANDER','REITER,MD(WB),ALEXANDER','REITER,MD,ALEXANDER')*/
/*			then npi = '1790786119';*/
/*			if upcase(compress(provname))  in ('ROONGTA,SURESH') then npi  = '1366555039';*/
/*			if upcase(compress(provname))  in ('SANDRAE.LEMMING,MD') then npi  = '1508861600';*/
/*			if upcase(compress(provname))  in ('SCHRADER,SHANNON') then npi  = '1629056304';*/
/*			if upcase(compress(provname))  in ('CHANG,MDPA,CLAIRE') then npi = '1568423200';*/
/**/
/*			/**MYSIS**/*/
/*			if npi = "" then do;*/
/*				if upin = "G03639" then NPI = "1659346799";*/
/*				if upin = "H36711" then NPI = "1417991910";*/
/*			end;*/
/*			if upcase(compress(provname))  in ('JARQUIN,ARMANDO') then npi  = '1326043860'; *practice interchanges NPI and NPI2 ;*/
/*			if upcase(compress(provname))  in ('DIAZMD,LUIS') then npi  = '1659346799'; */
/**/
/*			/**NEXTGEN**/*/
/*			if upcase(compress(provname))  in ('KHOURY,PIERRE') then npi  = '1548223878';*/
/*			if upcase(compress(provname))  in ('SUKI,SAMER') then npi  = '1639132962';*/
/*			if upcase(compress(provname))  in ('SETHI,GURDEEP') then npi  = '1801859491';*/
/*			if upcase(compress(provname))  in ('SEYMOUR,GREGORY') then npi  = '1720041056'; */
/**/
/*			/**NExtech**/*/
/*			if upcase(compress(provname))  in ('EUBANKS,LEIGH') then npi  = '1780681171';  	*/
/*		*/
/*			/**Medisoft**/*/
/*			if upcase(compress(provname))  in ('JARQUIN,ARMANDO') then npi  = '1326043860'; /**practice interchanges NPI and NPI2**/*/
/*			if upcase(compress(provname))  in ('STOERR,KOMAL') then npi  = '1063443216'; /**practice interchanges NPI and NPI2**/*/
/*			if upcase(compress(provname))  in ('ABDELGHANI,WAEL') then npi  = '1508837915';  	*/
/*			if upcase(compress(provname))  in ('ADAMMD(CC-DCH),KAROLINA','ADAMMD(CNRO),KAROLINA','ADAMMD(KTY),KAROLINA',*/
/*				'ADAMMD(KWD),KAROLINA','ADAMMD(LUF),KAROLINA','ADAMMD(SL),KAROLINA','ADAMMD(WH),KAROLINA',*/
/*				'ADAMMD(GR),KAROLINA','ADAMMD(WB),KAROLINA','ADAMMD,KAROLINA') then npi ='1326049891';*/
/*			if upcase(compress(provname))  in ('ALAPPATT,JOHN') then npi  = '1568409688'; */
/*			if upcase(compress(provname))  in ('EVANS,RANDOLPH') then npi  = '1780684076'; */
/*			if upcase(compress(provname))  in ('GUY,ESTHER') then npi  = '1740399484';*/
/*			if upcase(compress(provname))  in ('BERBERIAN,ESTEBAN') then npi = '1962490052';*/
/*			if upcase(compress(provname))  in ('SPARKSJR,JOHN') then npi = '1558353177';*/
/**/
/* 			/**Nterprise**/*/
/*			if upcase(compress(provname))  in ('ESCALANTEGLORSKY,SUSANA') then npi  = '1043214760'; */
/**/
/*			/**eClinical**/*/
/*			if upcase(compress(provname))  in ('ALEXM.SU,MD') then npi  = '1609871706'; 		*/
/*			if upcase(compress(provname))  in ('ASIFCOCHINWALA, MD') then npi  = '1245212521'; */
/*			if upcase(compress(provname))  in ('BRIANHOWARDKAPLAN,M.D.') then npi  = '1205015765'; */
/*			if upcase(compress(provname))  in ('CLIVEK.FIELDS,MD.') then npi  = '1366447583';*/
/*			if upcase(compress(provname))  in ('DWANEG.BROUSSARD,MD') then npi  = '1902801004';*/
/*			if upcase(compress(provname))  in ('ERICS.POWITZKY,MD') then npi  = '1952383200';*/
/*			if upcase(compress(provname))  in ('GEOFFREYA.GROFF,MD') then npi  = '1730184995';*/
/*			if upcase(compress(provname))  in ('GOTTESMAN,MARK') then npi  = '1770684375';*/
/*			if upcase(compress(provname))  in ('HOPED.SHIPMAN,MD') then npi  = '1932170719';*/
/*			if upcase(compress(provname))  in ('JOSEPHSEDRAK,MD') then npi  = '1316966575';*/
/*			if upcase(compress(provname))  in ('MARCH.FELDMAN,MD') then npi  = '1205831310';*/
/*			if upcase(compress(provname))  in ('MICHAELL.NOEL,MD') then npi  = '1366447526';*/
/*			if upcase(compress(provname))  in ('NORACATHERINEHART,MD') then npi  = '1003853276';*/
/*			if upcase(compress(provname))  in ('SUSANT.ERIE,MD') then npi  = '1609871862';*/
/*			if upcase(compress(provname))  in ('SANDRAE.LEMMING,MD') then npi  = '1508861600';*/
/*			if upcase(compress(provname))  in('MADELINEDOMASK,MD') then npi = '1790780955';*/
/**/
/*			if upcase(compress(provname))  in ('WAQARAKHAN(3)','WAQARA.KHAN(10)','WAQARKHAN,MD,F.A.C.C.','WAQARKHAN,MD.F.A.C.C.')*/
/*			then npi = '1811971914';*/
/**/
/*			/**medinformatix**/*/
/*			if upcase(compress(provname))  in ('ENGLER,DAVIDB.') then npi  = '1669477568';*/
/**/
/*			/**AMS**/*/
/*			if upcase(compress(provname))  in ('ELAHEE,TRECIA') then npi  = '1306922182'; */
/*			if upcase(compress(provname))  in ('FERSHTMAN,MURRAY') then npi  = '1013093897'; */
/**/
/*			/**Cleanup based on Heather's Review.  Remove Physicians in old practices 6-26-09 KG.**/*/
/*			if kpracticeID = 127 and npi = "1922096197" then npi = "";  /**Velazquez, Francisco**/*/
/*			if kpracticeID = 220 and npi = "1174612162" then npi = "";  /**Schulze, Keith**/*/
/*			if kpracticeID = 125 and npi = "1497793392" then npi = "";  /**Siff, Sherwin**/*/
/**/
/*			/**Practice Partner**/*/
/*			/**spelling error in Pract #338 upin**/*/
/*			if upin = 'I45313' then do;	/**Boccalandro, Cristina**/*/
/*				upin = 'I15313'; */
/*				npi = '1508890427';*/
/*				provname  = 'BOCCALANDRO, CRISTINA';*/
/*			end;*/
/*			if upcase(compress(provname))  in ('BOCCALANDRO,CRISTINA') then npi  = '1508890427'; */
/*			*/
/*			*added 11/7/2011  ;*/
/*			if tin = '' then do;*/
/*				tin=put(npi, $npi2tin.);*/
/*			end;*/
/*			if npi = '1811974090' then tin = '760531506';*/
/*			if npi = '1346230976' then tin = '275461233';*/
/**/
/**/
/*		%end;*/
;
run;

%mend vmine_provider_cleanup;
