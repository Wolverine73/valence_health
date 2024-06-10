/*HEADER------------------------------------------------------------------------
|
| program:  Guidelines_Configuration_Shell.sas
|
| location:	M:\CI\programs\StandardMacros
|
| purpose:  
|
| submeasures:   
|
| Production Status: 
|
| Pending Issues: 
|        
+--------------------------------------------------------------------------------
| *HISTORY  
| 05JAN2012 - EM Parentheses placed around submeasure_inclusion macros
| 10JAN2012 - EM If legacy = N, the assignment file and createG0 file will call
|				 a standard program in the m:\CI\programs\ValenceBaseMeasures\Retrospective\V3\PRODUCTION,
|				 otherwise a client-specific assignment file and g0 will be called
| 13JAN2012 - EM Added outlier comments code at the end of the %runall macro
| 16FEB2012 - EM Added option to run Current and/or Prior period
| 09MAR2012 - EM Creates comments table for legacy = 'N' option to be used for breaking attribution for
|				 comments made in the portal
| 22MAR2012 - EM If parameters for the same guideline (but different versions) have been entered into the form generator,
|				 the latest version of the guideline will run
| 27MAR2012 - EM Creates a dummy comments table if no comments are added to the portal
| 21MAY2012 - EM Added fix to capture correct guideline key for comments (if made in with previous guideline versions)
| 30MAR2012 - EM Added creation of lab_submeasures_detail after g0 is called on the non-legacy side
| 02MAY2012 - EM Creates g0 one time (ageR_Prior and ageR_current is created), this now runs outside of the
|				 runall macro (which flips through the current and prior periods). The member table and registry (permanent
|				 copy to g0) also get created at this step (again, only one time). Removed the delete_g0 macro.
| 03MAY2012 - EM All macros entered in the form generator are stored in CHISQL, the libname to fg_guide will never change
| 17MAY2012 - EM Keeping comment_keys of 2,4,5,6 when creating out_det.dmpat_comment table
| 			  EM Hard-coding the latest version of the guideline key to V3 for comments -- need to make this a macro
| 07JUN2012 - EM dmpat_comments table is now created from the V_MEMBER_COMMENT_EVENT view in chisql
|				 event_date is renamed to comment_date (to prevent changing names in all subsequent programs, and comment_date
|				 in the V_MEMBER_COMMENT_EVENT is renamed to comment_date1
| 09AUG2012 - EM added copy_g0 macro (does not recreate the member table, but does create indexes)
| 14AUG2012 - EM in dmpat_comments, use guideline_key from prtl_comments table and not overwrite with guideline_external_id
|				 from v_member_comment_event (because it's not populated)
| 15AUG2012 - EM output dmpat_comments to cistage, and create a copy in work. No longer outputting to out_det
|				 excludes comment_key 7 (registry delete)
|				 outputs provider formats to cistage (provyn, provtype, provname, provspec)
| HISTORY*
+-----------------------------------------------------------------------HEADER*/

/*%let LogFileOut=%str(\\SAS2\Adventist\SASTemp\CIProcess\Portal\Log_File\Guidelines_alltogether.log);*/
/*%start_log_printto(logfile=&LogFileOut.);*/


/***OVERALL PARAMETER CONTROL***/
/***************************************************************************************************************|
|************************************Macro Parameters with Default Values***************************************|
|***************************************************************************************************************|
|																												|
|	Client_Data = Choose the Clients' data source to run off of, and the client macro values:					|
|					ALLIANT																						|
|					ADVENTIST																					|
|					STLUKES																						|
|					NSAP																						|
|					PHS																							|																	|
|					CCCPP																						|
|					OHG																							|
|					EXEMPLA																						|
|					CCPA																						|
|																												|
|																												|
|	Run_Type = Choose one of the following types of 'Guidelines Run' being performed:							|
|					Production																					|
|					Development																					|
|					Testing																						|
|					Prior																						|
|																												|
|																												|
|	Program_Type = Choose the type of Guidelines to run:														|
|					Retrospective																				|
|					Prospective																					|
|																												|
|																												|
|	Client_Parameters = Choose the Clients' Parameters to run (defines which guideline keys to run and guideline|
|						parameters																				|
|							VALENCE																				|
|							ALLIANT																				|
|							ADVENTIST																			|
|							STLUKES																				|
|							NSAP																				|
|							PHS																					|																	|
|							CCCPP																				|
|							OHG																					|
|							EXEMPLA																				|
|							DEMO																				|
|							CCPA																				|
|							DEVELOPMENT																			|
|							TESTING																				|
|							PRIOR																				|
|																												|
|																												|
|	Populate only one of the following three macros:															|
|		Run_all = Run all Guidelines chosen for the Client: (If not Y, then leave blank)						|
|					Y																							|
|		Run_these = Only run the specified guildelines. List out the guideline keys. NOTE: the guideline		|
|					parameters for ALL specified guideline keys need to be defined before running.				|
|		Run_except = Run all guidelines defined by the 'Client_Parameters' macro EXCEPT for the specified 		|
|					 guidelines. List out the guideline keys. NOTE: the guideline parameters for the 			|
|					 guidelines that will be run need to be defined before running.								|
|																												|
|																												|
|	gl_enddt = 	Enter in the guidelines start date in the format: 'DDMONYYYY'd. This creates the current period |
|				end	date, along with the prior period start and end date.										|
|																												|
|	run_g0 = Choose to recreate the g0 or not																	|
|					Y																							|
|					N																							|
|																												|
|	copy_g0 = Choose to copy over the g0 from cistage into work													|
|					Y																							|
|					N																							|
|																												|
|	runPrior = Choose to run through the Prior Year's Guidelines												|
|					Y																							|
|					N																							|
|																												|
|	runCurrent = Choose to run through the Current Year's Guidelines											|
|					Y																							|
|					N																							|
|																												|
|	legacy = Choose to run with work flow (not legacy) or individually (this is legacy)							|
|					Y																							|
|					N																							|
|																												|
|***************************************************************************************************************/

%macro Guidelines_Configuration_Shell(	Client_Data = &CLIENT_NAME.,
										Run_Type = Production,
										Program_Type = Retrospective,
										Client_Parameters = &CLIENT_NAME.,
										gl_enddt = ,
										run_g0 = Y,
										copy_g0 = N,
										runPrior = Y,
										runCurrent = Y,
										Run_all = Y,
										Run_these =,
										Run_except = ,
										legacy = N
									  );



/*	options LS=100;										*/
/*	options sasautos = ("\\Sas2\CI\programs\StandardMacros" sasautos);			*/
/*	options mprint mlogic symbolgen source noquotelenmax msglevel=n error=2 ls=120 ps=60;   */


	/**************************************************************************/
	/*******Program_Type: Choose which types of guidelines are to be run*****/
	/**************************************************************************/
	/*If retrospective, run this shell. If prospective, run Karen/Lori's shell*/
	/**************************************************************************/
	%if &legacy = N %then %do;
		%global ClientID ClientParm;

		%let ClientID = &client_id.;
		%let ClientParm = &client_id.;
	%end;
	%else %do;

		/*If Run_Type is PRODUCTION, then assign chisql libname to point to production, else point to DEVSERV1*/
/*		%if &Run_Type = Production %then %do;*/
			libname fg_guide clear;
			libname fg_guide oledb init_string = "Provider=SQLOLEDB.1;
												Integrated Security = SSPI;
												Data Source = CHISQL;
												Initial Catalog = fg_Guidelines;"
												preserve_tab_names=yes;	
/*		%end;*/
/**/
/*		%else %if 	&Run_Type = Development or */
/*					&Run_Type = Testing or */
/*					&Run_Type = Prior %then %do;*/
/**/
/*			libname fg_guide clear;*/
/*			libname fg_guide oledb init_string = "Provider=SQLOLEDB.1;*/
/*												Integrated Security = SSPI;*/
/*												Data Source = DEVSERV1;*/
/*												Initial Catalog = fg_Guidelines;"*/
/*												preserve_tab_names=yes;*/
/*		%end;	*/


		/*Tap into ChiSQL table for all active clients to assign clientID*/
		%global ClientID;

		data _null_;
		set fg_guide.tblGuideline_ClientActivity;
		where 	upcase(strip(ClientShort))=upcase(strip("&Client_Data")) and 
				Client_Activity_Status=1;
		  call symput('ClientID',ClientID);
		run;
		%put &ClientID.;

		/*Convert Client_Parameters value to numeric clientID, resolving ClientParm */
		%global ClientParm;
		data _null_;
		set fg_guide.tblGuideline_ClientActivity;
		where 	trim(upcase(ClientShort))=trim(upcase("&Client_Parameters."));
		  call symput('ClientParm',ClientID);
		run;
		%put &ClientParm.;

	%end;

	/*Create a list of all the guidelines the client is running*/
	data guidelines_&Client_Data.;
	set fg_guide.Active_ClientGuidelines;
	where 	Clientid=&ClientParm.;
	run;

	/*Subset the list of guidelines to run based on which guidelines are listed in the macro variables for Run_these or Run_except */
	%if (&Run_these = and &Run_except = ) or &Run_all = Y %then %do;
		%let slctglnores = 0;
		%let sub_gl = 0;
		/*Take the latest version of the guideline entered*/
		proc sql;
		  create table run_gl1 as
		  select b.guideline_key,
				 a.Guideline_Name_Key from

		  guidelines_&Client_Data. as a
		  
		  left join
		  (  select distinct
		  				guideline_key,
						scan(guideline_key,1,'.')||'.'||scan(guideline_key,2,'.') as guideline_name_key
				from fg_guide.Active_ClientParameters (where=(clientID=&ClientParm.))
		  ) as b

		  	on 	a.Guideline_Name_Key = b.guideline_name_key
			order by guideline_name_key, guideline_key;
		quit;

		data run_gl;
		set run_gl1;
		by guideline_name_key guideline_key;
		if last.guideline_name_key;
		run;

	%end;
	%else %if (&Run_these ^= or &Run_except ^= ) and &Run_all ^= Y %then %do;
		data run_gl (keep = guideline_key guideline_name_key);
		set fg_guide.Guidelines;
		where 
				%if &Run_these ^= %then %do;
					guideline_key in (&Run_these.)
				%end;
				%else %if &Run_except ^= %then %do;
					guideline_key not in (&Run_except.)
				%end;
					;
			guideline_name_key = scan(guideline_key,1,'.')||'.'||scan(guideline_key,2,'.');
		run;

		proc sql noprint;
		  select count(*) into :sub_gl
		  	from run_gl;
		quit;
		%put &sub_gl.;

		/*Check if the requested guidelines to run are in the Active_ClientGuidelines table*/
		proc sql;
		  create table gl_chk as
		    select 	a.guideline_key,
					b.guideline_name_key
			from
				run_gl as a

			left join
				guidelines_&Client_Data. as b
					on a.guideline_name_key = b.guideline_name_key
					order by guideline_key;
		quit;

		data gl_chk1 (drop = count count_flag);
		set gl_chk;
		  by guideline_key;
		  retain count;

			if _n_=1 then do;
				count = .;
			end;

			if guideline_name_key = '' then do;
				count + 1;
				count_flag = count;
			end;

			if count_flag ne . then output;

		run;

		proc sql noprint;
		  select count(*) into :slctglnores
		  	from gl_chk1;
		quit;
		%put &slctglnores.;

	%end;

	/*****************************************************************************************************|
	|*DQCheck1: If only certain guidelines are going to be run, check to make sure they are checked off  *|
	|*			in the Active_ClientGuidelines form														 *|
	|*****************************************************************************************************/
	%if (&Run_these ^= or &Run_except ^=) and &slctglnores. > 0  %then %do;

		/*Output error message to alert which guidelines to run do not have any parameters defined*/
		data _null_;
		 set gl_chk1;
		 by guideline_key;
		 	if _n_=1 then do;

			 put " " ;	
			 put "ERROR:    	******************************************************************* ";
			 put "ERROR:    	**************************DQCheck1 FAILURE************************* ";
			 put "ERROR:    	******************************************************************* ";
			 put "ERROR:    	*****THE FOLLOWING GUIDELINES HAVE NOT BEEN PREVIOUSLY CHECKED***** ";	
			 put "ERROR:    	******************************************************************* ";
			 put " " ;	
			 put " " ;
			end;

		 put "WARNING: " ;	
		 put "WARNING: " ;	
		 put "WARNING: 					  Guideline Key: " Guideline_Key;	
		 put "WARNING: " ;	
		 put "WARNING: " ;	
		run;

		proc datasets library=work;
		delete gl_chk:;
		run;
		quit;

		%if &legacy = N %then %do;
	        %bpm_additional_validations(validation_rule=55,validation_count=100);

	        %let err_fl=1;
	        %set_error_flag;
	        %on_error(ACTION=ABORT);
		%end;

	%end;
	%else %if 	((&Run_these ^= or &Run_except ^=) and &slctglnores. = 0) or
				((&Run_these = or &Run_except =) and &Run_all = Y) %then %do;

		/*****************************************************************************************************|
		|*DQCheck2: All guidelines in the active_clientguidelines table have corresponding parameters defined*|
		|*			in the active_clientparameters table													 *|
		|*****************************************************************************************************/
		/*Every Guideline_key --> client_guideline_parameters*/
		proc sql;
		  create table gl_parms_resolved as
			  select a.clientid,
					 b.guideline_key,
					 a.Guideline_Name_Key from

			  fg_guide.Active_ClientGuidelines (where=(clientID=&ClientParm.)) 
				as a

		/*	  %if %sysfunc(exist(run_gl)) = 1 %then %do;*/
		/*	  %end;*/
			  %if &sub_gl. > 0 %then %do;
				inner join
					run_gl as a1
						on a.guideline_name_key = a1.guideline_name_key
			  %end;
			  
			  left join
			  (  select distinct
			  				clientid,
							guideline_key,
							scan(guideline_key,1,'.')||'.'||scan(guideline_key,2,'.') as guideline_name_key
					from fg_guide.Active_ClientParameters (where=(clientID=&ClientParm.))
			  ) as b

			  	on 	a.clientid = b.clientid and
					a.Guideline_Name_Key = b.guideline_name_key
				order by guideline_name_key;
		quit;
			 
		data gl_parms_resolved1 (drop = count count_flag guideline_key);
		set gl_parms_resolved;
		  by guideline_name_key;
		  retain count;

			if _n_=1 then do;
				count = .;
			end;

			if guideline_key = '' then do;
				count + 1;
				count_flag = count;
			end;

			if count_flag ne . then output;

		run;

		proc sql noprint;
		  select count(*) into :glnores
		  	from gl_parms_resolved1;
		quit;
		%put &glnores.;

		%if &glnores. ne 0 %then %do;
			/*Grab the name of the guideline and the latest version with parameters not resolved*/
			proc sql;
			create table latest_gl as
				select 	a.g_name length=50 format=$50. informat=$50.,
						b.guideline_name_key length=10 format=$10. informat=$10.,
						b.max_v length=3 format=$3. informat=$3. from
				(  select distinct
							strip(put(g_disease_key,4.))||'.'||strip(put(g_code_key,4.)) as guideline_name_key,
							g_name
						from fg_guide.tblguideline_name			
				) as a 
				
				inner join

				(  select distinct
							scan(guideline_key,1,'.')||'.'||scan(guideline_key,2,'.') as guideline_name_key,
							max(g_version) as max_v,
							g_version,
							g_status
					from fg_guide.guidelines
						group by guideline_name_key
						having 	g_status = 1 and
								g_version = b.max_v
				) as b
			
					on a.guideline_name_key = b.guideline_name_key
			;
			quit;

			proc sql;
			create table Gl_parms_resolved2 as
				select 	a.clientid,
						a.guideline_name_key,
						b.g_name,
						b.max_v from

					gl_parms_resolved1 as a

					inner join
						latest_gl as b
							on a.guideline_name_key=b.guideline_name_key
							order by guideline_name_key;
			quit;

			/*Output error message to alert which guidelines to run do not have any parameters defined*/
			data _null_;
			 set gl_parms_resolved2;
			 by guideline_name_key;
			 	if _n_=1 then do;

				 put " " ;	
				 put "ERROR:    	******************************************************************* ";
				 put "ERROR:    	**************************DQCheck2 FAILURE************************* ";
				 put "ERROR:    	******************************************************************* ";
				 put "ERROR:    	******THE FOLLOWING GUIDELINES DO NOT HAVE PARAMETERS DEFINED****** ";	
				 put "ERROR:    	******************************************************************* ";
				 put " " ;	
				 put " " ;
				end;

			 put "WARNING: " ;	
			 put "WARNING: " ;	
			 put "WARNING: 					  Guideline Name: " G_name;	
			 put "WARNING:  		Latest Guideline Version: " max_V;
			 put "WARNING: " ;	
			 put "WARNING: " ;	
			run;

			proc datasets library=work;
			delete 	gl_chk:					/*DQCheck1*/
					gl_parms_resolved:;		/*DQCheck2*/
			run;
			quit;

			%if &legacy = N %then %do;
		        %bpm_additional_validations(validation_rule=56,validation_count=100);

		        %let err_fl=1;
		        %set_error_flag;
		        %on_error(ACTION=ABORT);
			%end;

			/************************************************************************************************************|
			|*END PROGRAM AND PUT NOTE IF NOT ALL GUIDELINES HAVE THE PARAMETERS RESOLVED -- NOTE THE SPECIFIC GUIDELINE*|
			|************************************************************************************************************/

		%end;
		%else %do;

			/****************************************************************************************************|
			|*DQCheck3: All guidelines in the Active_ClientParameters table have all required parameters defined*|
			|****************************************************************************************************/
			/*client_guideline_parameters --> master_guideline_parameters*/

			/** Grab all parameters defined by guideline owners **/
			/*Guideline Masters Table - who owns what guideline based on the child key of the guideline key*/
			proc sql;
			  create table gl_master as
			    select distinct
						a.G_Child_Key,
						b.Guideline_key,
						a.G_Inventory_Key from
				(  select 	G_Child_Key,
						  	G_Inventory_Key
						from fg_guide.tblGuideline_Inventory
				) as a

				inner join

				(  select 	G_Inventory_Key,
							Guideline_Key
						from fg_guide.Guidelines
				) as b
					on a.G_Inventory_Key = b.G_Inventory_Key;
			quit;

			/*All guidelines (and parameters) being run by client)*/
			proc sql;
			  create table gl_parms_chk as
				select distinct 
						a.guideline_var, 
						a.guideline_key length=15 format=$15. informat=$15.,
						b.guideline_name_key
				  from 
				  (  select clientid,
							paramvalue,
							guideline_key,
							guideline_var,
							strip(strip(scan(guideline_key,1,"."))||"."||strip(scan(guideline_key,2,"."))) as guideline_name_key length=15 format=$15. informat=$15.
						from fg_guide.Active_ClientParameters
				  			where clientID=&ClientParm.
				  ) as a

				  inner join
				  (  select *
						from fg_guide.Active_ClientGuidelines
							where clientID=&ClientParm.
				  ) as b

					on a.guideline_name_key = b.guideline_name_key
					order by guideline_key, guideline_var;
			quit;

			/*Create gl_parms_master based on the guidelines the client is currently interested in running and the parameters that should be resolved
			  for that guideline*/
			proc sql;
			  create table gl_parms_master as
			  	select distinct
						a.guideline_key,
						d.guideline_var label="" as gl_var_m,
						d.single_attrib,
						d.multiple_attrib
	/*						d.guideline_var label="" as gl_var_c  */
							from

				(select guideline_key, guideline_name_key from gl_parms_chk) as a	/*the client's resolved parameters*/

				%if &sub_gl. > 0 %then %do;
					inner join
						run_gl as a1									/*guideline keys to run in this run if specified*/
							on a.guideline_name_key = a1.guideline_name_key
				%end;
				left join
					gl_master as b										/*master table of guidelines owned by the client indicated by the child key*/
						on a.guideline_key = b.guideline_key

				left join
					fg_guide.tblGuideline_Parameter as c					/*all parameters defined/required for that guideline key*/
						on 	b.G_Inventory_key = c.G_Inventory_key

				inner join
					fg_guide.tblGuideline_ParameterList as d
						on c.fieldid = d.fieldid
			;
			quit;

			/*Check if every parameter for the guideline being run, is resolved*/
			proc sql;
			  create table gl_parms_chk1 as
				select 	a.guideline_key,
						a.gl_var_m,
						b.guideline_var label="" as gl_var_c from
					gl_parms_master (where=(gl_var_m not in ("class1" "class1_provspec" "class2" "class2_provspec" "class3" "class3_provspec")))
						as a								/*what should be defined*/

					left join
						gl_parms_chk as b 					/*what is defined*/
							on 	a.guideline_key = b.guideline_key and
								a.gl_var_m = b.Guideline_Var
							order by guideline_key;
			quit;

			data gl_parms_chk2 (drop = count count_flag);
			set gl_parms_chk1;
			  by guideline_key;
			  retain count;

				if _n_=1 then do;
					count = .;
				end;

				if gl_var_c = '' then do;
					count + 1;
					count_flag = count;
				end;

				if count_flag ne . then output;
			run;

			proc sql noprint;
			  select count(*) into :parmnores
			  	from gl_parms_chk2;
			quit;
			%put &parmnores.;

			%if &parmnores. ne 0 %then %do;

				proc sql;
				  create table latest_gl as
					select 	a.g_name length=50 format=$50. informat=$50.,
							b.guideline_name_key length=10 format=$10. informat=$10.,
							b.max_v length=3 format=$3. informat=$3. from
					(  select distinct
								strip(put(g_disease_key,4.))||'.'||strip(put(g_code_key,4.)) as guideline_name_key,
								g_name
							from fg_guide.tblguideline_name			
					) as a 
					
					inner join

					(  select distinct
								scan(guideline_key,1,'.')||'.'||scan(guideline_key,2,'.') as guideline_name_key,
								max(g_version) as max_v,
								g_version,
								g_status
						from fg_guide.guidelines
							group by guideline_name_key
							having 	g_status = 1 and
									g_version = b.max_v
					) as b
				
						on a.guideline_name_key = b.guideline_name_key
				;
				quit;

				proc sql;
				create table gl_parms_chk3 as
					select 	a.guideline_key,
							a.guideline_name_key,
							a.gl_var_m,
							b.g_name,
							b.max_v from

						( select	guideline_key,
									strip(strip(scan(guideline_key,1,"."))||"."||strip(scan(guideline_key,2,"."))) as guideline_name_key length=15 format=$15. informat=$15.,
									gl_var_m,
									gl_var_c
							from gl_parms_chk2
						) as a

						inner join
							latest_gl as b
								on a.guideline_name_key=b.guideline_name_key
								order by guideline_name_key;
				quit;

				/*Output error message to alert which guidelines to run do not have any parameters defined*/
				data _null_;
				 set gl_parms_chk3;
				 by guideline_name_key;
				 	if _n_=1 then do;

					 put " " ;	
					 put "ERROR:    	******************************************************************* ";
					 put "ERROR:    	**************************DQCheck3 FAILURE************************* ";
					 put "ERROR:    	******************************************************************* ";
					 put "ERROR:    	**************THE FOLLOWING PARAMETERS ARE NOT DEFINED************* ";	
					 put "ERROR:    	******************************************************************* ";
					 put " " ;	
					 put " " ;
					end;

				 put "WARNING: " ;	
				 put "WARNING: 					  Guideline Name: " G_name;	
				 put "WARNING:  				   Guideline Key: " Guideline_Key;
				 put "WARNING:  			  Parameter Variable: " gl_var_m;
				 put "WARNING: " ;	
				run;

				proc datasets library=work;
				delete 	gl_chk:					/*DQCheck1*/
						gl_parms_resolved:		/*DQCheck2*/
						latest_gl				/*DQCheck3*/
				;
				run;
				quit;

				%if &legacy = N %then %do;
			        %bpm_additional_validations(validation_rule=57,validation_count=100);

			        %let err_fl=1;
			        %set_error_flag;
			        %on_error(ACTION=ABORT);				
				%end;
				/***********************************************************************************************************************|
				|*END PROGRAM AND PUT NOTE IF NOT ALL GUIDELINE PARAMETERS ARE RESOLVED -- NOTE THE SPECIFIC GUIDELINE and PARAMETER(S)*|
				|***********************************************************************************************************************/
			%end;

			%else %do;	

				%put DQCheck1, DQCheck2 and DQCheck3 have passed. Begin guidelines run;

				/*Create Client Macros*/
				proc sql;
				  create table macro_vars as
					select distinct Client_Var, ParamValue
					  from fg_guide.Active_ClientMacroParameters
					  	where clientID=&clientid.;
				/*		where guideline_key = "120.1.1.0.2" and clientID=&clientid.;*/
				quit;

				proc sql;
				  create table macro_vars_chk as
				    select 	b.cl_var_m label="", 
/*							c.client_var label="" as cl_var_c from*/
							c.pVal label="" from
					
					(  select 	fieldid as fId,
								clientid
						from fg_guide.tblGuideline_ClientMacro (where=(clientid=&clientid.))
					) as a		/*what is required to be defined*/
					
					inner join
					( select 	fieldID as fId,
								strip(Client_Var) as cl_var_m 
						from fg_guide.tblGuideline_ClientMacroList
					) as b	/*client parameter names*/
							on a.fId = b.fId

					left join
					(  select 	strip(ParamValue) as pVal,
								strip(Client_Var) as cl_var_c 
						from macro_vars
					) as c
							on b.cl_var_m = c.cl_var_c
							order by cl_var_m
					;
				quit;

				data macro_vars_chk1 (drop = count count_flag);
				set macro_vars_chk;
				  by cl_var_m;
				  retain count;

					if _n_=1 then do;
						count = .;
					end;

					if pVal = '' then do;
						count + 1;
						count_flag = count;
					end;

					if count_flag ne . then output;
				run;

				proc sql noprint;
				  select count(*) into :clmacnores
				  	from macro_vars_chk1;
				quit;
				%put &clmacnores.;

				%if &clmacnores. ne 0 %then %do;

					/*Output error message to alert which guidelines to run do not have any parameters defined*/
					data _null_;
					set macro_vars_chk1;
					  by cl_var_m; 
					 	if _n_=1 then do;

						 put " " ;	
						 put "ERROR:    	******************************************************************************* ";
						 put "ERROR:    	*********************************DQCheck4 FAILURE****************************** ";
						 put "ERROR:    	******************************************************************************* ";
						 put "ERROR:    	**************THE FOLLOWING CLIENT MACRO VARIABLES ARE NOT DEFINED************* ";	
						 put "ERROR:    	******************************************************************************* ";
						 put " " ;	
						 put " " ;
						end;

					 put "WARNING: " ;	
					 put "WARNING:  			 Client Macro Variable: " cl_var_m;
					 put "WARNING: " ;	
					run;

					proc datasets library=work;
					delete 	gl_chk:					/*DQCheck1*/
							gl_parms_resolved:		/*DQCheck2*/
							latest_gl				/*DQCheck3*/
					;
					run;
					quit;

					%if &legacy = N %then %do;
				        %bpm_additional_validations(validation_rule=58,validation_count=100);

				        %let err_fl=1;
				        %set_error_flag;
				        %on_error(ACTION=ABORT);				
					%end;
					/***********************************************************************************************************************|
					|*END PROGRAM AND PUT NOTE IF NOT ALL GUIDELINE PARAMETERS ARE RESOLVED -- NOTE THE SPECIFIC GUIDELINE and PARAMETER(S)*|
					|***********************************************************************************************************************/
				%end;

				%else %do;	

					data _null_;
					date_run = today();
					call symput('date_run',date_run);
					run;
					%put &date_run;

					/*Determine the total number of parameters to be resolved*/
					data macro_cnt;
					set macro_vars end=eof;
					    g+1; 
					    ii=left(put(g,4.));
						DelimCnt=countc(ParamValue,',');
						m=DelimCnt+1;
						call symput('m'||ii,trim(m));
						call symput('Client_Var'||ii,trim(left(Client_Var)));
				    if eof then call symput('totalm',ii);
					run;
					%put &totalm.;

					/*Format of all parameter datatypes*/
					data CParamFmt (keep=fmtname type start label);
					set fg_guide.tblGuideline_ClientMacroList (keep=Client_Var Client_Var_Type Client_Macro_Status);
					length fmtname $9. type $1. start $25. label $2.;
					where Client_Macro_Status = 1;
					start = Client_Var;
					label = Client_Var_Type;
					retain fmtname 'CParamFmt' type 'C';
					output;
					if _n_ = 1 then do;
						start = 'OTHER';
						label = '';
						output;
					end;
					run;
					proc sort data=CParamFmt nodupkey;
					by start;
					run;
					proc format cntlin=CParamFmt;
					run;

					%do mcnt = 1 %to &totalm.;

						/*Insert quotes in parameter character strings if necessary*/
						%macro doit_client (par=,cnt=);			
							data macro_vars&mcnt.;
							set macro_vars;
							where Client_Var = "&par.";
								if put(Client_Var,$CParamFmt.) in ("QC","Q") then do; 
									%do a = 1 %to &cnt;
									      x&a=scan(ParamValue,&a.,','); 
									%end;
									%do i = 1 %to &cnt;
									      %if &i = 1 %then %do;
									        Client_var_value='"'||trim(x&i.) 
									      %end; 
									      %else %if (&i ne 1 or &i ne &cnt) %then %do;
									              ||'","'||trim(x&i.)
									      %end;
									      %if &i = &cnt %then %do;
									        ||'"'; 
									      %end;
									%end;
								end;
								else if put(Client_Var,$CParamFmt.) in ("ST") then do;
									Client_var_value = left(strip(ParamValue));
								end;
								else do;
									Client_var_value = ParamValue;
								end;
				/*						keep Guideline_Var Guideline_Var_Value;*/
								val_len = length(Client_var_value);
								var_len = length(Client_Var);
							run;
						%mend;
						%doit_client(par=&&Client_Var&mcnt,cnt=&&m&mcnt);

					%end;

					data val_length;
					set %do mcnt = 1 %to &totalm.;
						 Macro_vars&mcnt. (keep = val_len)
						 %end;
						 ;
					run;

					/*Find the longest length of the Parameter variable name*/
					data var_length;
					set %do mcnt = 1 %to &totalm.;
						 Macro_vars&mcnt. (keep = var_len)
						 %end;
						 ;
					run;

					proc sql noprint;
						select MAX(val_len) into :mval_length
							from val_length;

						select MAX(var_len) into :mvar_length
							from var_length;
					quit;
					%put &mval_length.;
					%put &mvar_length.;

					/*Table of all macro parameters created for the currently processed guideline key*/
					data mvariables;
						length Client_Var $&mvar_length. Client_Var_value $&mval_length.;
					set %do mcnt = 1 %to &totalm.;
						 Macro_vars&mcnt. (keep = Client_Var Client_Var_value paramvalue)
						 %end;
						 ;
					run;

					/*Determine the total number of parameters to be resolved*/
					data _null_;
					set mvariables end=eof;
				     g+1; 
				     ii=left(put(g,4.));
					 mvar=compbl(Client_Var);
				      call symput('mvar'||ii,trim(left(mvar)));  
				    if eof then call symput('totalmv',ii);
					run;
					%put &totalmv.;

					/*Create and resolve client macro parameters dynamically*/
					%macro em;
						%do mv = 1 %to &totalmv.;
						%global &&mvar&mv.;

							proc sql noprint ;
						       select strip(Client_Var_value)
						           into :&&mvar&mv. from mvariables 
				/*						   where guideline_key = "&&glkey&glloop." and clientid = "&clientid." and status = 1 and guideline_var = "&&glvar&gl";*/
								   where Client_Var = "&&mvar&mv";
							quit;
							%put &&mvar&mv.;

						%end;

					%mend;
					%em;

					/*AssignLibnames and CallFormats standard macro*/
					%if &legacy. = N %then %do;
						%include "m:\CI\programs\ValenceBaseMeasures\Retrospective\V3\PRODUCTION\AssignmentFile_3.0.sas";
					%end;
					%else %if &legacy. = Y %then %do;
						%include "&AssignmentFile.";
					%end;

					/**********************************************************************************************/
					/*Read in and create provider comments here - used during attribution macros in the guidelines*/
					/**********************************************************************************************/
					%if &legacy. = N %then %do;

/*						libname cmrdin  oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;*/
/*						              	 Initial Catalog=DM_%sysfunc(strip(&client.));" preserve_tab_names=yes insertbuff=10000 readbuff=10000;*/
						libname cmrdin  oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;
						              	 Initial Catalog=CIEDW;" preserve_tab_names=yes insertbuff=10000 readbuff=10000;
						libname glmap  oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;
						              	 Initial Catalog=SasBiWeb;" preserve_tab_names=yes insertbuff=10000 readbuff=10000;
						libname prvedw  oledb init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=SQL-CI;
						              	 Initial Catalog=CIEDW;" preserve_tab_names=yes insertbuff=10000 readbuff=10000;

						proc sql;
						  create table prtl_gls_&Client_Data. as
							select a.guideline_key length=15 format=$15. informat=$15.,
						  		 b.clientid from
							run_gl as a

							inner join
								guidelines_&Client_Data. as b
									on a.guideline_name_key = b.guideline_name_key;
						quit;

						%let number_comments = 0;
						%let comment_list = %str();
						proc sql;
						create table _DMPAT_COMMENT as
						select distinct
								 a.*
								,case when b.guideline_key = '' and a.comment_key = 4 
											then strip(strip((reverse(substr(left(reverse(GUIDELINE_EXTERNAL_ID)),3)))||strip(".3")))
									  when b.guideline_key ^= '' then b.guideline_key
									  else GUIDELINE_EXTERNAL_ID
								 end as guideline_key length=15 format=$15.
								,b.cmnt_type length=20 format=$20. informat=$20.
								,b.submeasure_key
								,c.npi1 as provid
							from cmrdin.V_MEMBER_COMMENT_EVENT
								(where=(client_id = &clientid. and
										comment_key not in (1,3,6,7))	/*these are pt compliant, pt excluded, pt dead, and are dealt with previous to this step*/
								) as a

							left join
							(
								select 	 b1.guideline_key
										,case 	when b2.comment_type = 'REFUSED' then 'REFUSALS'
												else b2.comment_type
										 end as cmnt_type
										,b2.care_element
										,submeasure_key
									from 
										prtl_gls_&Client_Data. as b1
									inner join
										glmap.Measures_Comments_Base as b2
/*										out_det.Measures_Comments_Base as b2*/
											on b1.guideline_key = b2.guideline_key
							) as b
									on 	a.care_element_code = b.care_element and
										a.COMMENT_DESC = b.cmnt_type

							left join
								prvedw.provider as c
									on a.provider_key = c.provider_key
								;
						quit;

						proc sql noprint ;
							select distinct strip(put(comment_key,2.))
								into :comment_list separated by ","
								from _DMPAT_COMMENT;
						quit;
						%put &comment_list.;

						proc sql noprint;
						select count(*) into :number_comments
							from _DMPAT_COMMENT;
						quit;
						%put &number_comments.;
					
						%macro create_portal_comments;
							/*Create dummy comments for any of the comment types not entered into the portal*/
							%let number_dummies = 0;
							%if &number_comments. ^= 0 %then %do;
								proc sql;
								create table comment_types as
								select distinct  comment_key
												,case 	when b2.comment_desc = "No Longer My Patient" then "NOLONGERPATIENT"
														when b2.comment_desc = "Patient Refused" then "REFUSALS"
														when b2.comment_desc = "Measure Not Applicable" then "NOTAPPLICABLE"
												 end as cmnt_type length=20 format=$20. informat=$20.
									from glmap.CI_CLINICAL_COMMENTS (where=(/*client_key = &client_id. and*/
																	   comment_key not in (1,3,6,7))) as b2;
								quit;

								data DMPAT_COMMENT1;
								set comment_types;
								%if &comment_list.= %then %do;
									provid = "9999999999";
									member_key = -99;
									guideline_key = "XXX.X.X.X.X";
									client_id = &client_id.;
									output;
								%end;
								%else %do;
									if comment_key not in (&comment_list.) then do;
										provid = "9999999999";
										member_key = -99;
										guideline_key = "XXX.X.X.X.X";
										client_id = &client_id.;
										output;
									end;
								%end;
								run;
								proc sql noprint;
								select count(*) into :number_dummies
									from DMPAT_COMMENT1;
								quit;
								%put &number_dummies.;

								/*Append any dummy comments to the list of any comments out there to ensure there is a comment type for every possible comment*/
								%if &number_dummies. ^= 0 %then %do;
									data _DMPAT_COMMENT;
									set _DMPAT_COMMENT (rename = (COMMENT_DESC=c_type))
										DMPAT_COMMENT1;
										length comment_type $20.;
										if c_type ^= "" then comment_type = c_type;
										else comment_type = cmnt_type;
									run;
								%end;
							%end;

							/*Create dummy comments table because there have not been comments added yet*/
							%else %if &number_comments. = 0 %then %do;				
									proc sql;
									create table _DMPAT_COMMENT as
									select distinct
											 &client_id. as client_id
											,"XXX.X.X.X.X" as guideline_key
											,"XX" as submeasure_key length=2 format=$2.
											,case 	when b2.comment_desc = "No Longer My Patient" then "NOLONGERPATIENT"
													when b2.comment_desc = "Patient Refused" then "REFUSALS"
													when b2.comment_desc = "Measure Not Applicable" then "NOTAPPLICABLE"
											 end as cmnt_type length=20 format=$20. informat=$20.
											,comment_key
											,"9999999999" as provid
											,-99 as member_key
											,"" as DIAGNOSIS_CODE_ 
											,"" as PROCEDURE_CODE
											,"" as MODIFIER_
											,"" as DRG
											,"" as REVENUE_CODE
											,"" as PLACE_OF_SERVICE
											,"" as UNITS
										from 
											glmap.CI_CLINICAL_COMMENTS (where=(client_key = &client_id. and
																			   comment_key not in (1,3,6,7))) as b2;
									quit;
							%end;
						%mend; 
						%create_portal_comments;

						data /*out_det.*/dmpat_comment (drop = member_key DIAGNOSIS_CODE_: PROCEDURE_CODE MODIFIER_: DRG REVENUE_CODE PLACE_OF_SERVICE UNITS);
						set _DMPAT_COMMENT;
						format memberid 16.;
						informat memberid 16.;
						memberid = member_key;
						run;

						libname cmrdin	clear;
						libname glmap	clear;
						libname prvedw	clear;

					%end;


					%macro create_g0;
						/*Only create g0 if indicated in macro call*/
						%if &run_g0. = Y %then %do;

							 %if &legacy. = N %then %do;
								%include "M:\CI\programs\ValenceBaseMeasures\Retrospective\V3\PRODUCTION\g0.sas";
								 %g0
								 
								/*Create a count of records in g0*/
								proc sql;
								  select count(*) as src_cnt format 20. into: src_record_cnt
								       from g0
								       where client_key=&client_id.
								       ;
								quit;
								 
								%put &src_record_cnt;

								 data Rm_g0_cnt;
									 FormParmName = "G0_COUNT";
									 FormParmVal = "&src_record_cnt.";
									 ParamValue = "&src_record_cnt.";
									 ResParmName = "G0_COUNT";
									 ResParamVal = "&src_record_cnt.";
									 guideline_key = "XXX.X.X.X.X";
								 run;
								 
								/*Creates the member table in CIHOLD and a SAS dataset in CIstage on the day g0 is created*/

								%edw_guideline_member_subset;

								/*Creates a permanent Registry in CIstage on the day g0 is created*/
/*								data cistage.registry_final_glrun;*/
/*								set release.registry_final;*/
/*								run;	*/

								/*Creates a permanent DMPAT_COMMENTS table in CIstage on the day g0 is created*/
								proc datasets; 
								copy 	in = work 
										out = cistage; 
								select dmpat_comment; 
								quit; 
								run;

								/*Creates a permanent set of provider formats in CIstage on the day g0 is created*/
								proc datasets; 
								copy 	in = work 
										out = cistage; 
								select provyn; 
								quit; 
								run;

								proc datasets; 
								copy 	in = work 
										out = cistage; 
								select provtype; 
								quit; 
								run;

								proc datasets; 
								copy 	in = work 
										out = cistage; 
								select provname; 
								quit; 
								run;

								proc datasets; 
								copy 	in = work 
										out = cistage; 
								select provspec; 
								quit; 
								run;

							 %end;

							 %else %if &legacy. = Y %then %do;
								 %include "&CreateG0File.";
								 %g0
							 %end;
						%end;

						%if &copy_g0. = Y %then %do;
							proc datasets; 
							copy 	in = cistage 
									out = work; 
							select g0; 
							quit; 
							run;

							proc sql;   
							    drop index memberid from g0;
							    drop index care_element from g0;
							    drop index dx_condition from g0;
							    create index memberid on g0 (memberid);
							    create index care_element on g0 (care_element);
							    create index dx_condition on g0 (dx_condition);
						    quit;

						%end;

					%mend create_g0;
					%create_g0;


					/*Guideline and Guideline_Submeasure Reference Tables*/

					/*Begin to run Prior and/or Current reporting year*/
					%macro runall;

						/*Determine Start and End Dates (eventually this can be automated when the lag time/units can be filled in and automated*/
						/*Prior Period*/
						%if &period = prior %then %do;
							libname temp clear;
							libname temp "&prior1.";
							data _null_;
							  s = put(intnx('year',&gl_enddt.,-2,'same'),date9.);
							  e = put(intnx('year',&gl_enddt.,-1,'same'),date9.);
							  call symputx('s',s);
							  call symputx('e',e);
							run;
							%put NOTE:  Start Date: &s.;
							%put NOTE:  End Date: &e.;

							data _null_;
							   call symputx('stdt',%str("'&s.'d"));
							   call symputx('enddt',%str("'&e.'d"));
							run;

							%put NOTE:  Start Date: &stdt.;
							%put NOTE:  End Date: &enddt.;

							data _null_;
								PriorPeriodStart  = put(&stdt.,worddate.);
								PriorPeriodEnd  = put((&enddt. - 1),worddate.);
								Prior_Period = cats(PriorPeriodStart) || " - " || cats(PriorPeriodEnd) ;
								call symput('Prior_Period',Prior_Period);
							run;
							%put &Prior_Period;
							%let client=&Client_Data.;

						%end;

						%else %if &period = current %then %do;
							libname temp clear;
							libname temp "&current1.";
							data _null_;
							  s = put(intnx('year',&gl_enddt.,-1,'same'),date9.);
							  e = put(intnx('year',&gl_enddt.,0,'same'),date9.);
							  rp = put(intnx('year',&gl_enddt.,0,'same'),yymon.) || "-" || put(intnx('month',&gl_enddt.,-13,'same'),yymon.);
							  call symputx('s',s);
							  call symputx('e',e);
							  call symputx('rp',rp);
							run;
							%put NOTE:  Start Date: &s.;
							%put NOTE:  End Date: &e.;
							%put NOTE:  Reporting Period: &rp.;

							data _null_;
							   call symputx('stdt',%str("'&s.'d"));
							   call symputx('enddt',%str("'&e.'d"));
							run;

							%put NOTE:  Start Date: &stdt.;
							%put NOTE:  End Date: &enddt.;

							%let client=&Client_Data.;
						%end;

						/*CREATE LAB_SUBMEASURES_DETAIL -- CURRENT PERIOD ONLY*/
						%if &LAB_SUBMEAS_DETS. = Y and %QUPCASE(&period.) = CURRENT %then %do;

							/** Create table of all lab data for codes approved to be displayed in the portal**/
							data guidelines_lab_codes;
							set control.Labs_approved_for_guidelines (keep = care_granular clientid code indicator use_in_results imputed_range default_value units hierarchy);
							where use_in_results = 1 and care_granular ^= "TEST";
							run;

							data impute_labs;
							set control.Labs_approved_for_guidelines (keep = care_granular clientid code indicator use_in_results imputed_range default_value units hierarchy);
							where use_in_results = 1 and imputed_range ^= '' and care_granular ^= "TEST";
							run;

							/** Assign value ranges for CPT2/loinc test codes **/
							data _null_;
							set impute_labs end=eof;
							 g+1; 
							 ii=left(put(g,4.));
							 cpt2=compbl(code);
							 val=compbl(imputed_range);
							 defval=input(compbl(default_value),8.);
							 units=compbl(units);
							 hier=hierarchy;
							 
							  call symput('cpt2'||ii,trim(left(cpt2)));  
							  call symput('val'||ii,trim(left(val)));  
							  call symput('defval'||ii,trim(left(defval)));  
							  call symput('units'||ii,trim(left(units)));  
							  call symput('hier'||ii,trim(left(hier)));  
							if eof then call symput('num_cpt2',ii);
							run;
							%put &num_cpt2.;

							%macro m;
								data lab_sub_clean_cpt2;
								set cistage.g0_lab;
								length code $7. units $20. value_numeric 8.;

								if loinc ^= '' and databand = 'OBX' then code = loinc;
								else if proccd ^= '' then code = proccd;
								
						/*		if loinc ^= '' and value_numeric = . then delete;*/
								%do i=1 %to &num_cpt2.;
									if proccd ^= '' and proccd = "&&cpt2&i" then do;
										value_character = "&&val&i";
										value_numeric = "&&defval&i";
										units = "&&units&i";
									end;
								%end;
								run;
							%mend;
							%m;	

							data guideline_required_elements;
							set valence.Guidelines_required_elements;
							clientid = %sysfunc(strip("&client."));
							run;

							data careelements;
							set control.Care_elements;
							clientid = %sysfunc(strip("&client."));
							run;

							data &client._gl (drop = maxFDate);
							set fg_guide.Active_ClientGuidelines;
							where clientid = &clientid.;
							run;

							/** Replace '.' in guideline_key with '_' **/
							%macro replace (datain = , dataout = , chkvar = , search = , replace =, newvar =, newvarlen= );
								data &dataout (drop = textpos &chkvar. oldvar) newvars;
								length &newvar $&newvarlen.;
								set &datain;
								textpos = index(upcase(&chkvar.), upcase(&search.));
								oldvar = &chkvar;
								if textpos ne 0 then do;
									if textpos ne 1 then &newvar = substr(&chkvar, 1, (textpos - 1))||&replace||substr(&chkvar, (textpos + length(&search)));
									else &newvar = &replace||substr(&chkvar, (textpos + length(&search)));
								output newvars;
								end;

								else &newvar = &chkvar;
								output &dataout;
								run;
							%mend replace;

							%replace (	datain = &client._gl, 
										dataout = &client._guidelines,
										chkvar = Guideline_Name_Key,
										search = %str("."),
										replace = %str("_"),
										newvar = G_Name_Key,
										newvarlen = 10
									 );
							/*The value_character for CPT2 codes is a reference range; and the numeric value will be the default*/
							proc sql;
							create table lab_details as

							  select distinct	 a.clientid as client_key
												,e.care_granular as care_element
												,e.code
												,case when e.indicator = 'LOINC' then e.code
													  else ''
												 end as loinc length=7 format=$7. informat = $7.
												,case when substr(e.indicator,1,3) = 'CPT' then e.code
													  else ''
												 end as proccd length=5 format=$5. informat = $5.
												,e.hierarchy
												from

									&client._guidelines as a

									inner join
										(select clientid,
												guidekey as g_name_key,
												Element
											from guideline_required_elements
										) as b
											on 	a.g_name_key = b.g_name_key

									inner join
										careelements as c
											on 	b.clientid = c.clientid and
												b.element = c.care_granular

									inner join
										guidelines_lab_codes as e
											on 	c.code = e.code 


								  order by care_element
							;
							quit;

							proc sql;
							create table lab_submeasures_detail_cpt as
							select  d.memberid,
									a.client_key,
									a.care_element,
									d.value_character,
									d.value_numeric,
									d.units length=20 format=$20.,
									d.svcdt format=mmddyy10.,
									a.hierarchy
								from 
									lab_details (where = (proccd ^= '')) as a
								inner join
									lab_sub_clean_cpt2 as d
										on	a.client_key = d.client_key and
											a.code = d.code
								  order by memberid, d.svcdt, a.care_element
							;
							quit;

							proc sql;
							create table lab_submeasures_detail_loinc as
							select  d.memberid,
									a.client_key,
									a.care_element,
									d.value_character,
									d.value_numeric,
									d.units length=20 format=$20.,
									d.svcdt format=mmddyy10.,
									a.hierarchy
								from 
									lab_details (where = (loinc ^= '')) as a
								inner join
									lab_sub_clean_cpt2 as d
										on	a.client_key = d.client_key and
											a.code = d.code
								  order by memberid, d.svcdt, a.care_element
							;
							quit;

							data lab_submeasures_detail2
								 del
								 lab_cleaner;
							set lab_submeasures_detail_loinc
								lab_submeasures_detail_cpt;

								if hierarchy = 2 then rank = 5;
								else if value_numeric ^= . and units ^= '' then rank = 1;
								else if value_numeric ^= . and units = '' then rank = 2;
								else if value_numeric = . and value_character ^= '' and units ^= '' then rank = 3;
								else do;
									if /*substr(value_character,1,1) in (1,2,3,4,5,6,7,8,9,0) or*/ 
										substr(value_character,1,1) in ('<','>') then rank = 4; /*TD 3/28/2012 - as per convo with KN, removed reference below to digits*/
								end;

								if rank = . then output del;
								else if rank in (1,2,5) then output lab_submeasures_detail2;
								else if rank in (3,4) then output lab_cleaner;

							run;

							data lab_cleaner1;
							set lab_cleaner;
								if substr(strip(value_character),1,1) = "<" then do;
									val_check=value_character;
									val_char=substr(strip(value_character),2);
									value_character = scan(value_character,1," ");

									if input(scan(val_char,1," "),8.) ^= . then do;
										value_numeric = input(scan(val_char,1," "),8.);
										value_numeric = value_numeric - .1;
									end;
									else if input(scan(substr(val_char,1),1," "),8.) ^= . then do;
										value_numeric = input(scan(substr(val_char,1),1," "),8.);
										value_numeric = value_numeric - .1;
									end;
									else if input(substr(val_char,1),8.) ^= . then do;
										value_numeric = input(scan(substr(val_char,1),1," "),8.);
										value_numeric = value_numeric - .1;
									end;
								end;
								else if substr(strip(value_character),1,1) = ">" then do;
									val_check=value_character;
									val_char=substr(strip(value_character),2);
									value_character = scan(value_character,1," ");

									if input(scan(val_char,1," "),8.) ^= . then do;
										value_numeric = input(scan(val_char,1," "),8.);
										value_numeric = value_numeric + .1;
									end;
									else if input(scan(substr(val_char,1),1," "),8.) ^= . then do;
										value_numeric = input(scan(substr(val_char,1),1," "),8.);
										value_numeric = value_numeric + .1;
									end;
									else if input(substr(val_char,1),8.) ^= . then do;
										value_numeric = input(scan(substr(val_char,1),1," "),8.);
										value_numeric = value_numeric - .1;
									end;
								end;

								else do;
									if input(scan(value_character,1," "),8.) ^= . then do;
										val_check=value_character;
										value_character = scan(value_character,1," ");
										value_numeric = input(scan(value_character,1," "),8.);
									end;
								end;

								if value_numeric ^= .;
							run;

							data lab_submeasures_detail3;
							set lab_submeasures_detail2
								lab_cleaner1;
							attrib _all_ label = '';
							run;

							proc sort data = lab_submeasures_detail3;
							by memberid svcdt care_element rank;
							run;

							data out_det.lab_submeasures_detail (rename = (value_character=value))
								 dups;
							set lab_submeasures_detail3;
							by memberid svcdt care_element rank;
							if first.care_element then output out_det.lab_submeasures_detail;
							else output dups;
							run;	   
						%end;

						%macro guidelines_config;
						
							/*Assign attrib_val based on client global macros of measure_level and location*/
							%if &measure_level = provider %then %do;
								data _null_;
									call symput("attrib_val","pcpid");
								run;
							%end;
							%else %if &measure_level = location %then %do;
								data _null_;
									call symput("attrib_val","pcpid&location.");
								run;
							%end;

							/*Create a list of all the guidelines the client is running, subset all guideline keys to run for the ClientParm Value
							  based on the values provided in Run_all, Run_these or Run_except*/
							proc sql;
							  create table run_gl_&Client_Data. as
								select a.guideline_key,
							  		 b.clientid from
								run_gl as a

								inner join
									guidelines_&Client_Data. as b
										on a.guideline_name_key = b.guideline_name_key;
							quit;
							
							/*Total Number of Guidelines to Run per Client*/
							data _null_;
							set run_gl_&Client_Data. end=eof;
						     g+1; 
						     ii=left(put(g,4.));
							 glkey=compbl(guideline_key);
						      call symput('glkey'||ii,trim(left(glkey)));  
						    if eof then call symput('totalgl',ii);
							run;
							%put &totalgl.;

							%do glloop = 1 %to &totalgl.;
						/*	%global "&&glkey&glloop.";*/

								/*Format of all parameter datatypes*/
								data ParamFmt (keep=fmtname type start label);
								set fg_guide.tblGuideline_ParameterList (keep=Guideline_Var Guideline_Var_Type Guideline_CParm_Status);
								length fmtname $8. type $1. start $25. label $2.;
								where Guideline_CParm_Status = 1;
								start = Guideline_Var;
								label = Guideline_Var_Type;
								retain fmtname 'ParamFmt' type 'C';
								output;
								if _n_ = 1 then do;
									start = 'OTHER';
									label = '';
									output;
								end;
								run;
								proc sort data=ParamFmt nodupkey;
								by start;
								run;
								proc format cntlin=ParamFmt;
								run;


								/*Find the longest length of the Parameter value*/
								proc sql noprint;
								select MAX(paramVal) into :val_length from
									(select ((countc(ParamValue,',') + 1)*2 + length(ParamValue) + 2) as paramVal
										from fg_guide.Active_ClientParameters);
								quit;
								%put &val_length;

								/*Find the longest length of the Parameter variable name*/
								proc sql noprint;
								select MAX(paramVar) into :var_length from
									(select length(ParamValue) as paramVar
										from fg_guide.Active_ClientParameters);
								quit;
								%put &var_length;

								/*Create Macro Variables for each guideline to be run*/
								proc sql;
								  create table guideline_vars as
									select distinct guideline_var, ParamValue
									  from fg_guide.Active_ClientParameters
									  	where guideline_key = "&&glkey&glloop." and clientID=&ClientParm.;
					/*				  	where guideline_key = "120.1.1.0.2" and clientID=&clientid.;*/
								quit;

								/*Determine the total number of parameters to be resolved*/
								data guideline_cnt;
								set guideline_vars end=eof;
								    g+1; 
								    ii=left(put(g,4.));
									DelimCnt=countc(ParamValue,',');
									c=DelimCnt+1;
									call symput('c'||ii,trim(c));
									call symput('guideline_var'||ii,trim(left(guideline_var)));
							    if eof then call symput('totalc',ii);
								run;
								%put &totalc.;

								%do dcnt = 1 %to &totalc.;

									/*Insert quotes in parameter character strings if necessary*/
									%macro doit (par=,cnt=);			
										data guideline_vars&dcnt.;
										set guideline_vars;
										where guideline_var = "&par.";
											if put(guideline_var,$ParamFmt.) in ("QC","Q") then do; 
												%do a = 1 %to &cnt;
												      x&a=scan(ParamValue,&a.,','); 
												%end;
												%do i = 1 %to &cnt;
												      %if &i = 1 %then %do;
												        guideline_var_valueX='"'||trim(x&i.) 
												      %end; 
												      %else %if (&i ne 1 or &i ne &cnt) %then %do;
												              ||'","'||trim(x&i.)
												      %end;
												      %if &i = &cnt %then %do;
												        ||'"'; 
												      %end;
												%end;
											end;
											else do;
												guideline_var_valueX = ParamValue;
											end;
						/*						keep Guideline_Var Guideline_Var_Value;*/


											/**Insert Parentheses around the submeasure_inclusion macro**/
											if strip(guideline_var) in ('submeasure_inclusion') then do;
												guideline_var_value = catt('(',guideline_var_valueX,')');
											end;
											else guideline_var_value = guideline_var_valueX;

											drop guideline_var_valueX;

											val_len = length(guideline_var_value);
											var_len = length(guideline_var);
										run;
									%mend;
									%doit(par=&&guideline_var&dcnt,cnt=&&c&dcnt);

								%end;

								/*Table of all macro parameters created for the currently processed guideline key*/
								data variables;
									length guideline_var $&var_length. guideline_var_value $&val_length.;
								set %do dcnt = 1 %to &totalc.;
									 guideline_vars&dcnt. (keep = guideline_var guideline_var_value paramvalue)
									 %end;
									 ;
								run;

								/*Determine the total number of parameters to be resolved*/
								data _null_;
								set Variables end=eof;
							     g+1; 
							     ii=left(put(g,4.));
								 gvar=compbl(guideline_var);
							      call symput('glvar'||ii,trim(left(gvar)));  
							    if eof then call symput('total',ii);
								run;
								%put &total.;

								/*Create and resolve macro parameters dynamically*/
								%macro k;
									%do gl = 1 %to &total.;
									%global &&glvar&gl.;
					
										proc sql noprint ;
									       select strip(guideline_var_value)
									           into :&&glvar&gl. from Variables 
					/*						   where guideline_key = "&&glkey&glloop." and clientid = "&clientid." and status = 1 and guideline_var = "&&glvar&gl";*/
											   where guideline_var = "&&glvar&gl";
										quit;
										%put &&glvar&gl.;

									%end;
								%mend;
								%k;

								/*Create include macro that resolves to programs filepath*/
								proc sql noprint;
								 select quote(trim(a.PathName)) as %str(PN) into :include from 

							       (select * from fg_guide.Program_FilePaths) a

									inner join

									(select G_Inventory_Key from fg_guide.Guidelines 
										where guideline_key = "&&glkey&glloop.") as b
										on a.G_Inventory_Key=b.G_Inventory_Key;
								quit;

								/*Create guideline_key macro*/
								data _null_;
									call symput("guideline_key",trim(left("&&glkey&glloop.")));
								run;

								/*RUN GUIDELINE HERE*/
								%include &include.;
								%outlier_comments_setup
/*								%fallout_logic*/
								%cleanup
/*								%delvars*/

								/*Replace periods with dashes in the guideline key*/
								data _null_;
								  gl_dash=translate("&&glkey&glloop.",'_','.');
								  call symput('gl_dash',gl_dash);
								run;

								/*Create table of all resolved macro variables identified by their guideline key*/
								proc sql;
								create table RM_&gl_dash. as
								  select a.FormParmName
										,a.FormParmVal
										,a.paramvalue
										,b.ResParamName
										,b.ResParamVal
										,"&&glkey&glloop." as guideline_key
									from
									(select upcase(Guideline_Var) as FormParmName,guideline_var_value as FormParmVal,paramvalue from variables) a
									left join
									(select name as ResParamName, value as ResParamVal from sashelp.vmacro) b
									on a.FormParmName=b.ResParamName;
								quit;

								/*Delete all dynamically created guideline macros*/
								data temp;
								set sashelp.vmacro;
								  if ^	(	scope in ('AUTOMATIC') or 
											name in (&del_vars.) or 
											index(name,'GLKEY')
										);
								run;
								data _null_;
								set temp;
								  call symdel(name);
								run;

								proc datasets library=work;
								delete 	Guideline_cnt
										Guideline_vars:
										macro_cnt
										macro_vars:
										Variables	
										Val_length
										Var_length
										Temp
										gl_chk:
										gl_parms:;
								run;
								quit;

							%end;

						%mend guidelines_config;
						%guidelines_config;

						/*Set all Resolved Macro (RM) Tables*/
						data out_det.resolved_macros_&period.;
						set Rm_:;
						run;

						/* create comments table for the outlier report*/
						%if &period.=current %then %do;

						    data _comments_all;
						        length date cur_date_run 8. text $1000. guideline_key $15.;
						        format date cur_date_run mmddyy10.;

						        label     date              = "Comment Date"
						                  text              = "Comment"
						                  guideline_key     = "Guideline Key"
						                  cur_date_run      = "Current Run Date";
						    run;
							
							data comments_all;
							set _comments_all (obs = 0);
							run;

							proc datasets library=work;
							delete _comments_all ;
							run;
							quit;

					        data list (keep=libname memname);
					        set sashelp.vtable;
					          if upcase(libname) in ("WORK") and (substr(upcase(memname),1,9) = "COMMENTS_") and 
								 (upcase(memname) not in ("COMMENTS_DATE","COMMENTS_ALL"));
					          call execute("proc append base=comments_all force data="||libname||"."||memname||";run;");
					        run;
							
						    /* create latest run date table*/
					        proc sort data = out_det.dates out = dates;
					        by guideline_key;
					        run;

					        proc sort data = comments_all;
					        by guideline_key;
					        run;
	
					        data out_det.comments_all;
					        merge comments_all (in = a)
					              dates (in = b
										 keep = guideline_key daterun);
					            by guideline_key;

					            label daterun = "Prior Run Date";
					        run;

					        data _dates_cur;
					          length cur_date_run 8. guideline_key $15.;
					          format cur_date_run mmddyy10.;
					        run;

							data out_det.dates_cur;
							set _dates_cur (obs = 0);
							run;

							data list (keep=libname memname);
						    set sashelp.vtable;
						      if upcase(libname) in ("WORK") and (substr(upcase(memname),1,6) = "DATES_") and (upcase(memname) not in ("DATES_ALL"));
						      call execute("proc append base=out_det.dates_cur force data="||libname||"."||memname||";run;");
						    run;

							proc datasets library=work;
							delete 	comments_:
									dates_:
								;
							run;
							quit;

						%end;

						proc datasets library=work;
						delete 	Rm_:;
						run;
						quit;

					%mend runall;	/*run through each period - prior and/or current*/

					%if &runPrior = Y %then %do;
						%let period=prior;
						%runall

						data temp;
						set sashelp.vmacro;
						  if name in ('STDT','ENDDT','PRIOR_PERIOD');
						run;
						data _null_;
						set temp;
						  call symdel(name);
						run;
					%end;

					%if &runCurrent = Y %then %do;
						%let period=current;
						%runall
					%end;

					/*Create table of all resolved client macro variables identified by their clientid*/
					proc sql;
					create table out_det.CM_&Client_Data. as
					  select a.FormParmName
							,a.FormParmVal
							,a.paramvalue
							,b.ResParamName
							,b.ResParamVal
						from
						(select upcase(Client_Var) as FormParmName,Client_var_value as FormParmVal,paramvalue from mvariables) a
						left join
						(select name as ResParamName, value as ResParamVal from sashelp.vmacro) b
						on a.FormParmName=b.ResParamName;
					quit;

					/*Create a list of all the guideline keys that were run*/
					data out_det.run_gl_&Client_Data.;
					set run_gl_&Client_Data.;
					run;

				%end;	/*this %end belongs to DQCheck4*/

			%end;	/*this %end belongs to DQCheck3*/

		%end;	/*this %end belongs to DQCheck2*/

	%end;	/*this %end belongs to DQCheck1*/
%mend;
