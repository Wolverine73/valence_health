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
|	delete_g0 = Choose to delete the g0 or not																	|
|					Y																							|
|					N																							|
|																												|
|	runPrior = Choose to run through the Prior Year's Guidelines												|
|					Y																							|
|					N																							|
|																												|
|	runCurrent = Choose to run through the Current Year's Guidelines												|
|					Y																							|
|					N																							|
|
|	legacy = Choose to run with work flow (not legacy) or individually (this is legacy)							|
|					Y																							|
|					N																							|
|																												|
|***************************************************************************************************************/

%macro Guidelines_Configuration_Shell_test(	Client_Data = &CLIENT_NAME.,
										Run_Type = Production,
										Program_Type = Retrospective,
										Client_Parameters = &CLIENT_NAME.,
										gl_enddt = ,
										run_g0 = Y,
										delete_g0 = Y,
										runPrior = Y,
										runCurrent = Y,
										Run_all = Y,
										Run_these = ,
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
		%if &Run_Type = Production %then %do;
			libname fg_guide clear;
			libname fg_guide oledb init_string = "Provider=SQLOLEDB.1;
												Integrated Security = SSPI;
												Data Source = CHISQL;
												Initial Catalog = fg_Guidelines;"
												preserve_tab_names=yes;	
		%end;

		%else %if 	&Run_Type = Development or 
					&Run_Type = Testing or 
					&Run_Type = Prior %then %do;

			libname fg_guide clear;
			libname fg_guide oledb init_string = "Provider=SQLOLEDB.1;
												Integrated Security = SSPI;
												Data Source = DEVSERV1;
												Initial Catalog = fg_Guidelines;"
												preserve_tab_names=yes;
		%end;	


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
		proc sql;
		  create table run_gl as
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
			order by guideline_name_key;
		quit;
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
						%include "m:\CI\programs\ValenceBaseMeasures\Retrospective\V3\TESTING\AssignmentFile_3.0.sas";
					%end;
					%else %if &legacy. = Y %then %do;
/*						%let AssignmentFile = %str(M:\CI\programs\ValenceBaseMeasures\Guidelines Configuration\AssignmentFile_3.0.sas);*/
						%include "&AssignmentFile.";
					%end;

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
					/*		proc sql;*/
					/*		      update out1.portal_dates*/
					/*		            set value="&Prior_Period."*/
					/*		            where Parameter = "priorperiod"*/
					/*					;*/
					/*		quit;*/
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

						%macro create_g0;
							/*Only create g0 if indicated in macro call*/
							%if &run_g0 = Y %then %do;
								/*********************************************************************
								 *********************************************************************
								 *CREATE G0 HERE BASED OFF THE CLIENTID ASSIGNED*/
								 %if &legacy. = N %then %do;
									%include "M:\CI\programs\ValenceBaseMeasures\Retrospective\V3\TESTING\g0.sas";
									 %g0
								 %end;
								 %else %if &legacy. = Y %then %do;
/*								 	%let CreateG0File = %str(M:\CI\programs\ValenceBaseMeasures\Guidelines Configuration\g0.sas);*/
									 %include "&CreateG0File.";
									 %g0
								 %end;

								 /*Create a count of records in g0*/
								 %if &period = current %then %do;
									/* proc sql noprint;
									   select count(*) into: src_record_cnt
										from g0 
									   where client_key=&client_id.
									   ;
									 quit; */
									 
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
								 %end;
								 /********************************************************************
								 *********************************************************************/
							%end;

						%mend create_g0;
						%create_g0

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

								/*Compile the appropriate attribution macro*/
				/*				options sasautos = ("\\Sas2\CI\programs\StandardMacros" sasautos);                         */
				/*				%include "";*/
				/*				%include "M:\CI\programs\ValenceBaseMeasures\Guidelines Release 1.0\provider_comments.sas";*/
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
						delete 	Rm_:
							%if &delete_g0 = Y %then %do;
								g0
							%end;
							;
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
