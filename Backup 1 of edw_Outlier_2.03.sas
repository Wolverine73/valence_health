%macro outlier (client);
	%macro lib;
		%if "&client" = "NSAP" %then %do;
			data _null_;
			*call symput("out_det","M:\NSAP\sasdata\CI\Portal\PortalOut");
			call symput("out_det","M:\ci\programs\EDW\NSAP\guidelines");
			*call symput("prov","M:\NSAP\sasdata\CIETL\provider");
			call symput("current1","M:\NSAP\SASTEMP\CI\Current");
			call symput("current1","M:\ci\programs\EDW\NSAP\guidelines\current");
			*call symput("prior1","M:\NSAP\SASTEMP\CI\Prior");
			call symput("prior1","M:\ci\programs\EDW\NSAP\guidelines\current");
			*call symput("provfmt","M:\NSAP\sasdata\CI\CIETL\provider\Formats");
			call symput("outlier","M:\NSAP\sasdata\CI\Portal\PortalOut\MonthlyComparison");
			call symput("portal","\\sasbi\Projects\NSAP\data");
			call symput("clientid",4);
			run;
		%end; 

		%else %if "&client" = "PHS" %then %do;
			data _null_;
			call symput("out_det","M:\phs\sasdata\Portal\PortalOut");
			call symput("prov","M:\phs\sasdata\CIETL\provider");
			call symput("current1","M:\phs\SASTEMP\Current");
			call symput("prior1","M:\phs\SASTEMP\Prior");
			call symput("provfmt","M:\phs\sasdata\CIETL\provider\Formats");
			call symput("outlier","M:\PHS\sasdata\Portal\PortalOut\MonthlyComparison");
			call symput("portal","\\sasbi\Projects\PHS\data");
			call symput("clientid",5);
			run;
		%end;
		%else %if "&client" = "Adventist" %then %do;
			data _null_;
			call symput("out_det","M:\Adventist\SASTemp\CIProcess\Portal"); *Newly run guidelines: guideline, submeasures_current, guidelineprovider;
			call symput("prov","M:\Adventist\sasdata\CIETL\Provider");		*Provider table;
/*			call symput("current1","M:\phs\SASTEMP\Current");				*Current folder for g6, g9, g10 data sets;*/
/*			call symput("prior1","M:\phs\SASTEMP\Prior");					*Prior data g6, g9, g10 - if data has already been copied into sasbi;*/
			call symput("provfmt","M:\Adventist\sasdata\CIETL\Provider\Formats");	*provider formats;
/*			call symput("outlier","M:\PHS\sasdata\Portal\PortalOut\MonthlyComparison");	*/
			call symput("portal","\\sasbi\Projects\Adventist\data");			*Prior guidelines: guideline, submeasures_current, guidelineprovider;
/*			call symput("portal","M:\Adventist\SASTemp\erin_temp\portal_june");			*Prior guidelines: guideline, submeasures_current, guidelineprovider;*/
			call symput("clientid",2);
			run;
		%end;

		%else %if "&client" = "StLukes" %then %do;
			data _null_;
			call symput("out_det","M:\StLukes\sasdata\Portal\PortalOut");
			call symput("prov","M:\StLukes\sasdata\CIETL\provider");
			call symput("current1","M:\StLukes\SASTEMP\Current");
			call symput("prior1","M:\StLukes\SASTEMP\Prior");
			call symput("provfmt","M:\StLukes\sasdata\CIETL\provider\Formats");
			call symput("outlier","M:\StLukes\sasdata\Portal\PortalOut\MonthlyComparison");
			call symput("portal","\\sasbi\Projects\StLukes\data");
			call symput("clientid",3);
			run;
		%end;
		*libname provider oledb 
		    init_string="Provider=SQLOLEDB.1;Integrated Security=SSPI;Data Source=CHISQL;Initial Catalog=vLinkNSAP;"
		    preserve_tab_names=yes;
		libname out_det "&out_det";
		*libname prov "&prov";
		libname current1 "&current1";
		libname prior1 "&prior1";
		*libname provfmt "&provfmt";
		*libname formats "//SAS2/DW/Formats";
		libname outlier "&outlier";
		libname portal "&portal";

		*proc format cntlin=formats.specdesc;
	%if "&client." = "Adventist" %then %do;
		proc format cntlin=provfmt.npi2provspec;
		proc format cntlin=provfmt.npi2provname;
	%end;
	%else %do;
		*proc format cntlin=provspec;
		*proc format cntlin=provname;
	%end;
		run;
	%mend lib;
	%lib;

		data _null_;
			CurrentPeriodStart  = put(&stdt.,worddate.);
			CurrentPeriodEnd  = put((&enddt. - 1),worddate.);
			Current_Period = cats(CurrentPeriodStart) || " - " || cats(CurrentPeriodEnd) ;
			month1 = put(intnx('month',today(),-1),yymmn6.);
			month6 = put(intnx('month',today(),-6),yymmn6.);
			call symput('Current_Period',Current_Period);
			call symput ('month1',month1);
			call symput ('month6',month6);
		run;

		%put &Current_Period;
		%put FILE MONTH: &month1.;
		%put FILE MONTH: &month6.;

			*SASDOC--------------------------------------------------------------------------
			| Compare guidelines ran this month from last month
			------------------------------------------------------------------------SASDOC*;
		%if "&client" = "NSAP" %then %do;
				proc sort data = portal.guideline(where=(guidelinetype='V')) out = G_prior (drop = eligible1 compliant1 percentcompliant1 
																				rename = (eligible2 = eligible_prior 
																						  compliant2 = compliant_prior PercentCompliant2 = PercentCompliant_prior
																						/*elig = eligible_prior*/));
				  by guideline;
				  run;

				proc sort data = out_det.guideline (where=(guidelinetype='V')) out = G_current (drop = eligible1 compliant1 percentcompliant1
																	 rename = (eligible2 = eligible_current 
																			   compliant2 = compliant_current PercentCompliant2 = PercentCompliant_current));
				  by guideline;
				  run;
		%end;
		%else %do;
				proc sort data = portal.guideline out = G_prior (drop = eligible1 compliant1 percentcompliant1 
																				rename = (eligible2 = eligible_prior 
																						  compliant2 = compliant_prior PercentCompliant2 = PercentCompliant_prior
																						/*elig = eligible_prior*/));
				  by guideline;
				  run;

				proc sort data = out_det.guideline  out = G_current (drop = eligible1 compliant1 percentcompliant1
																	 rename = (eligible2 = eligible_current 
																			   compliant2 = compliant_current PercentCompliant2 = PercentCompliant_current));
				  by guideline;
				  run;
		%end;

				data guideline_index (keep = guideline status eligible_prior eligible_current PercentCompliant_prior PercentCompliant_current gloutlier);
				  merge G_prior (in = a)
						G_current (in = b);
				  by guideline;

			*SASDOC-------------------------------------------------------------------------------
			| *****THIS PORTION DETERMINES GUIDELINE OUTLIERS*****
			-------------------------------------------------------------------------------SASDOC*;
				  format PercentCompliant_current PercentCompliant_prior elig_diff comprate_diff percent8.1;

					  elig_diff = (eligible_current-eligible_prior)/eligible_prior;
					  comprate_diff = PercentCompliant_current-PercentCompliant_prior;

					  if -.10 <= elig_diff <= .10 then eligflag = 0; 
				  		else eligflag = 1;
				/*	  if -.10 <= comp_diff <= .10 then compflag = 0; 
				  		else compflag = 1;*/
					  if -.10 <= comprate_diff <= .10 then comprateflag = 0; 
						else comprateflag = 1;
					  if eligflag = 1 or comprateflag = 1 then gloutlier = 'X';

					if a and not b then status = "Dropped Guideline";
					if b and not a then status = 'New Guideline';
				run;

			*SASDOC--------------------------------------------------------------------------
			| Compare submeasures ran this month from last month
			------------------------------------------------------------------------SASDOC*;


				proc sort data = portal.Submeasures_current /*prior1.g6*/  out = sub_prior1;
				  by guideline submeasure;
				  run;

				proc sort data = out_det.Submeasures_current out = sub_current1;
				  by guideline submeasure;
				  run;

				proc summary data = sub_prior1 nway missing;
				  where pcpid not in ('9999999999');
				  class guideline submeasure;
				  var elig;
				  output out = sub_prior (drop = _TYPE_ _FREQ_) sum=;
				  run;

				proc summary data = sub_current1 nway missing;
				  where pcpid not in ('9999999999');
				  class guideline submeasure;
				  var elig;
				  output out = sub_current (drop = _TYPE_ _FREQ_) sum=;
				  run;

				proc sort data = sub_prior (rename = (elig = elig_pri)) ;
				  by guideline submeasure;
				  run;

				proc sort data = sub_current (rename = (elig = elig_cur)) ;
				  by guideline submeasure;
				  run;

				data submeasure_index (keep = guideline submeasure status elig_pri elig_cur);
				  merge sub_prior (in = a)
						sub_current (in = b);
				  by guideline submeasure;

					if a and not b then status = "Dropped Submeasure";
					if b and not a then status = 'New Submeasure';
				run;


			*SASDOC--------------------------------------------------------------------------
			| Grab Effective and Term Dates of providers
			------------------------------------------------------------------------SASDOC*;
	%if "&client." = "Adventist" %then %do;

				data prov (keep=provname npi prveffdt prvtermdt);
				set prov.Provider;
				run;
	%end;
	%else %do;
				data prov (keep=provname npi prveffdt prvtermdt);
				set provider.tblProvider (keep=	P_CIEffDt P_CITermDt clientid p_firstname p_lastname p_npi p_cipar);
				where clientid = &clientid.;

					length vlinkprovid 8. provlast $25. provfirst $15. provtitle $10. provname $42. npi $10. upin $6. adventid $4. CIPar $1.;
					format prveffdt prvtermdt mmddyy10.;
					provlast  	= cats(p_lastname);
					provfirst 	= cats(p_firstname);
					provname	= cats(provlast) || ", " || cats(provfirst);
					npi 	  	= upcase(cats(p_npi));
					prveffdt	= datepart(P_CIEffDt);
					prvtermdt	= datepart(P_CITermDt);

					if npi in ('NONE','NA','N/A','') then npi = '';
					if upin in ('NONE','NA','N/A','') then upin = '';

				run;
	%end;

				proc summary data = prov nway missing;
				class provname npi prveffdt;
				output out = provef1;
				run;
				  	
				proc sort data = provef1 out = provef2;
				by npi provname descending prveffdt;
				run;

				data providerEF;
				set provef2;
				length status $32.;
				by npi provname descending prveffdt;
					if first.npi and &month6. <= put(prveffdt,yymmn6.) <= &month1. then do;
						status = "New to IPA/PHO:"||''||put(prveffdt,mmddyy10.);
					end;
				if status ne '';
				run;

				proc summary data = prov nway missing;
				class provname npi prvtermdt;
				output out = provtm1;
				run;
				  	
				proc sort data = provtm1 out = provtm2;
				by npi provname descending prvtermdt;
				run;

				data providerTM;
				set provtm2;
				length status $32.;
				by npi provname descending prvtermdt;
					if first.npi and &month6. <= put(prvtermdt,yymmn6.) <= &month1. then do;
						status = "Termed from IPA/PHO:"||''||put(prvtermdt,mmddyy10.);
					end;
				if status ne '';
				run;

				data providerDTS (drop = prveffdt prvtermdt _TYPE_ _FREQ_ 
								  rename = (npi=pcpid));
				set providerEF
					providerTM;
				run;

				proc sort data = providerDTS;
				by pcpid provname;
				run;

			*SASDOC--------------------------------------------------------------------------
			| Effective/Term Date format
			------------------------------------------------------------------------SASDOC*;
				data ProvEfTrm;
					LENGTH FMTNAME $9. TYPE $1 label $32. start $10.;
				  set providerDTS (keep = pcpid status);
				   KEEP START LABEL TYPE FMTNAME ;
				  RETAIN FMTNAME 'ProvEfTrm'  TYPE 'C';
				  if pcpid NE "" then do;
				    start = pcpid;
					label = status;
					output;
				  end;
				  if _n_ = 1 then do;
				   start = "other";
				   label = '';
				   output;
				  end;
				run;

				proc sort data=ProvEfTrm nodupkey;
				by start;
				run;
				proc print data=ProvEfTrm;
				run;
				PROC FORMAT CNTLIN=ProvEfTrm ;
				RUN;
				proc contents data=ProvEfTrm ;
				run;

			*SASDOC--------------------------------------------------------------------------
			| Determine which providers are no longer being measured for some guidelines, 
			| but are now being measured for others
			------------------------------------------------------------------------SASDOC*;

			%if "&client" = "NSAP" %then %do;
				proc sort data = /*prior1.g9*/ portal.guidelineprovider(where=(guidelinetype='V')) out = Gprov_prior;
				  by pcpid guideline;
				  run;

				proc sort data = out_det.guidelineprovider (where=(guidelinetype='V')) out = Gprov_current;
				  by pcpid guideline;
				  run;
			%end;
			%else %do;
				proc sort data = /*prior1.g9*/ portal.guidelineprovider out = Gprov_prior;
				  by pcpid guideline;
				  run;

				proc sort data = out_det.guidelineprovider out = Gprov_current;
				  by pcpid guideline;
				  run;
			%end;

				data prov_movement (drop =  provspec guideline pcpname guidelinetype 
											percentcompliant1 compliant1 eligible1 
											percentcompliant2 compliant2 eligible2 quartile 
											/*comprate comp elig*/);
				  merge Gprov_prior (in = a)
						Gprov_current (in = b);
				  where pcpid not in ('9999999999');
				  by pcpid guideline;

					if a and not b then dropped_meas = guideline;
					if b and not a then newly_meas = guideline;
					if dropped_meas = '' and newly_meas = '' then delete;

					%macro fmt;
						length reason $100.;
					  	%if "&client." = "Adventist" %then %do;
							provname = put(pcpid,$npi2provname.);
							provspec = put(pcpid,$npi2provspec.);
						%end;
						%else %do;
							provname = put(pcpid,$provname.);
							provspec = put(pcpid,$provspec.);
						%end;
					%mend fmt;
					%fmt;
					provspecdesc = put(provspec,$specd.);
					reason = put(pcpid,$ProvEfTrm.);
				run;

				proc sort data = prov_movement;
				by provname pcpid provspecdesc newly_meas dropped_meas;
				run;

				data prov_move;
				  retain provname pcpid provspecdesc newly_meas dropped_meas reason;
				  set prov_movement;
				  run;

			*SASDOC--------------------------------------------------------------------------
			| Determine new, active and termed providers during the reporting period
			------------------------------------------------------------------------SASDOC*;

				  proc summary data = Gprov_current nway missing;
				  where pcpid not in ('9999999999');
				  class pcpid;
				  output out = prov_current (drop = _TYPE_ _FREQ_);
				  run;

				  proc sort data = prov_current;
				  by pcpid;
				  run;

				  proc summary data = Gprov_prior nway missing;
				  where pcpid not in ('9999999999');
				  class pcpid;
				  output out = prov_prior;
				  run;

				  proc sort data = prov_prior;
				  by pcpid;
				  run;

				  data providers2 (drop = _TYPE_ _FREQ_ provspec);
				  merge prov_current (in = a) 
						prov_prior (in = b);
				  by pcpid;
				  where pcpid not = '9999999999';
				  if a and b then delete;
				  if a and not b then new2guide = "X"; else new2guide = "";
				  if b and not a then leftguide = "X"; else leftguide = "";
				
					%macro fmt;
						length reason $100.;
					  	%if "&client." = "Adventist" %then %do;
							provname = put(pcpid,$npi2provname.);
							provspec = put(pcpid,$npi2provspec.);
						%end;
						%else %do;
							provname = put(pcpid,$provname.);
							provspec = put(pcpid,$provspec.);
						%end;
					%mend fmt;
					%fmt;
					provspecdesc = put(provspec,$specd.);
				  run;

				  proc sort data = providers2;
				  by pcpid provname;
				  run;

				  data 	providers3;
				  merge providers2 (in = a)
				  		providerDTS (in = b);
					by pcpid provname;
					if a;
					if status = '' then status = 'No Change';
				  run;

				  proc sort data = providers3 out = providers;
				  by provspecdesc provname;
				  run;

			*SASDOC--------------------------------------------------------------------------
			| Determine outliers with a lot of variability in eligible patients
			------------------------------------------------------------------------SASDOC*;
				proc sort data=Gprov_current;
				by guideline pcpid;
				run;
				proc sort data=Gprov_prior;
				by guideline pcpid;
				run;

				Data GLProvider;
				merge Gprov_current (rename = (Eligible2=eligible_cur Compliant2=compliant_cur percentcompliant2=percom_cur) 
									 drop = quartile Eligible1 Compliant1 guidelinetype)
					  Gprov_prior (rename = (Eligible2=eligible_pri Compliant2=compliant_pri percentcompliant2=percom_pri) 
								   drop = quartile Eligible1 Compliant1 
										  guidelinetype
									/*rename = (Elig = eligible_pri Comp = compliant_pri comprate=percom_pri)*/)
									;
				by guideline pcpid;
				where pcpid not in ('9999999999');
				if eligible_cur ge 1; *Mod 6/2/09 by KG;
				%macro fmt;
					length reason $100.;
				  	%if "&client." = "Adventist" %then %do;
						provname = put(pcpid,$npi2provname.);
					%end;
					%else %do;
						provname = put(pcpid,$provname.);
					%end;
				%mend fmt;
				%fmt;
				run;

					data ProviderOutliers (drop = provspec /*sd zscore outlier_elig outlier_comp outlier_both*/);
					  retain guideline provspecdesc pcpname pcpid eligible_cur eligible_pri compliant_cur compliant_pri percom_cur percom_pri /*outlier eligoutlier*/;
					  set GLProvider;
					  where pcpid ne '9999999999';
					  format percom_cur percom_pri elig_diff comprate_diff percent8.1;

					  elig_diff = (eligible_cur-eligible_pri)/eligible_pri;
					  comprate_diff = percom_cur-percom_pri;

					  if -.10 <= elig_diff <= .10 then eligflag = 0; else eligflag = 1;
				/*	  if -.10 <= comp_diff <= .10 then compflag = 0; else compflag = 1;*/
					  if -.10 <= comprate_diff <= .10 then comprateflag = 0; else comprateflag = 1;
					  if (eligflag = 1 or comprateflag = 1) and (eligible_pri > 30 or eligible_cur > 30) then output;

					%macro fmt;
					  	%if "&client." = "Adventist" %then %do;
							provspec = put(pcpid,$npi2provspec.);
						%end;
						%else %do;
							provspec = put(pcpid,$provspec.);
						%end;
					%mend fmt;
					%fmt;
							provspecdesc = put(provspec,$specd.);

					run;

					proc sort data = provideroutliers out = prov_outliers (drop = compliant_cur compliant_pri percom_cur percom_pri eligflag comprateflag);
					  by guideline pcpname pcpid provspecdesc eligible_cur eligible_pri elig_diff comprate_diff;
					  run;

	*SASDOC--------------------------------------------------------------------------
	| Create numbers for Outliers Report Summary Page
	------------------------------------------------------------------------SASDOC*;
		data totalgl;
		set guideline_index;
		where status not in ('Dropped Guideline');
			total_gl = _n_;
			call symput ('total_gl',total_gl);
		run;
		%put &total_gl.;

		%let new_gl=0;
		data _null_;
		set guideline_index;
		where status in ('New Guideline');
			new_gl = _n_;
			call symput ('new_gl',new_gl);
		run;
		%put &new_gl.;

		%let old_gl=0;
		data _null_;
		set guideline_index;
		where status in ('Dropped Guideline');
			old_gl = _n_;
			call symput ('old_gl',old_gl);
		run;
		%put &old_gl.;

		proc summary data = glprovider nway missing;
		class pcpid;
		output out = all_provs (drop = _TYPE_ _FREQ_);
		run;

		%let all_dr=0;
		data _null_;
		set all_provs;
			all_dr = _n_;
			call symput ('all_dr',all_dr);
		run;
		%put &all_dr.;

		%let new_dr=0;
		data _null_;
		set providers;
		where new2guide = 'X';
			new_dr = _n_;
			call symput ('new_dr',new_dr);
		run;
		%put &new_dr.;

		%let left_dr=0;
		data _null_;
		set providers;
		where leftguide = 'X';
			left_dr = _n_;
			call symput ('left_dr',left_dr);
		run;
		%put &left_dr.;

		proc summary data = prov_outliers nway missing;
		class pcpid;
		output out = outlier_provs (drop = _TYPE_ _FREQ_);
		run;

		%let out_dr=0;
		data _null_;
		set outlier_provs;
			out_dr = _n_;
			call symput ('out_dr',out_dr);
		run;
		%put &out_dr.;


	*SASDOC--------------------------------------------------------------------------
	| Outliers Report Summary Page
	------------------------------------------------------------------------SASDOC*;
		data outliers_summary1 noprint;
		length measure $100. total added dropped flagged 8.;
		measure = 'Guideline Status';
		run;
		data outliers_summary2;
		length measure $100. total added dropped flagged 8.;
		measure = 'Guideline Provider Status';
		run;

		proc sort data = glprovider out = variable_loop (keep = guideline) nodupkey;
		 by guideline;
		run;

	*SASDOC--------------------------------------------------------------------------
	| Individual Modules
	------------------------------------------------------------------------SASDOC*;
	%macro gline;		

		data _null_;
		 set variable_loop end=eof; 
	         i+1;
	         ii=left(put(i,4.));
			 x='gl'||ii;
 
	         call symput('gl'||ii,trim(guideline));
	         if eof then call symput('total_guideline',ii);	 
		run;


		%do j = 1 %to &total_guideline.;

		*SASDOC---------------------total provs per guideline ----------------------------SASDOC*;
			%let tot_drgl=0;
			proc summary data = glprovider nway missing;
			where guideline = "&&gl&j.";
			class pcpid;
			output out = gl_provs (drop = _TYPE_ _FREQ_);
			run;
			data _null_;
			set gl_provs;
				tot_drgl = _n_;
				call symput ('tot_drgl',tot_drgl);
			run;
			%put &tot_drgl.;
		*SASDOC---------------------new provs to guideline ------------------------------SASDOC*;
			%let new_drgl=0;
			data _null_;
			set prov_movement;
				where newly_meas = "&&gl&j.";
				new_drgl = _n_;
				call symput ('new_drgl',new_drgl);
			run;
			%put &new_drgl.;

		*SASDOC---------------------dropped provs from guideline ------------------------SASDOC*;
			%let left_drgl=0;
			data _null_;
			set prov_movement;
				where dropped_meas = "&&gl&j.";
				left_drgl = _n_;
				call symput ('left_drgl',left_drgl);
			run;
			%put &left_drgl.;
		*SASDOC---------------------outliers provs for guideline ------------------------SASDOC*;
			%let out_drgl=0;
			data _null_;
			set prov_outliers;
				where guideline = "&&gl&j.";
				out_drgl = _n_;
				call symput ('out_drgl',out_drgl);
			run;
			%put &out_drgl.;

		*SASDOC---------------------output to summary report ----------------------------SASDOC*;
			data gl&j.;
				measure = "&&gl&j.";
				total=&tot_drgl.;
				added=&new_drgl.;
				dropped=&left_drgl.;
				flagged=&out_drgl.;		
			run;

			%if &j. = &total_guideline. %then %do;
			  data outliers_summary3;
			   length measure $100 ;
			   set %do jj = 1 %to &total_guideline.;
			          gl&jj. 
				   %end;;
			  run;
			%end;

		%end;
	%mend gline;
	%gline;

		data outliers_summary;
		set outliers_summary1 outliers_summary2;
			if measure = 'Guideline Status' then do;
				total=&total_gl.;
				added=&new_gl.;
				dropped=&old_gl.;
				flagged='N/A';
			end;
			if measure = 'Guideline Provider Status' then do;
				total=&all_dr.;
				added=&new_dr.;
				dropped=&left_dr.;
				flagged=&out_dr.;
			end;	
		run;

	*SASDOC--------------------------------------------------------------------------
	| Create PDF Document
	------------------------------------------------------------------------SASDOC*;

		%if "&client." = "NSAP" %then %do;
			ods pdf file="\\fs\NSAP\Reports\Data_Quality_Reports\Outlier_Reports\NSAP_Outliers_&sysdate..pdf" notoc;
			%let emailfile=%str(\\fs\NSAP\Reports\Data_Quality_Reports\Outlier_Reports\NSAP_Outliers_&sysdate..txt);
			%let filename =%str(\\fs\NSAP\Reports\Data_Quality_Reports\Outlier_Reports\NSAP_Outliers_&sysdate..pdf);
		%end;

		%else %if "&client." = "PHS" %then %do;
			ods pdf file="\\fs\PHS\Reports\Data_Quality_Reports\Outlier_Reports\PHS_Outliers_&sysdate..pdf" notoc;
			%let emailfile=%str(\\fs\PHS\Reports\Data_Quality_Reports\Outlier_Reports\PHS_Outliers_&sysdate..txt);
			%let filename =%str(\\fs\PHS\Reports\Data_Quality_Reports\Outlier_Reports\PHS_Outliers_&sysdate..pdf);
		%end;
		%else %if "&client." = "Adventist" %then %do;
			ods pdf file="\\fs\Adventist\reports\Data_Quality_Reports\Outlier_Reports\AHN_Outliers_&sysdate..pdf" notoc;
			%let emailfile=%str(\\fs\Adventist\reports\Data_Quality_Reports\Outlier_Reports\AHN_Outliers_&sysdate..txt);
			%let filename =%str(\\fs\Adventist\reports\Data_Quality_Reports\Outlier_Reports\AHN_Outliers_&sysdate..pdf);
		%end;
		%else %if "&client." = "StLukes" %then %do;
			ods pdf file="\\fs\StLukes\Reports\Monthly_Reports\Data_Load\Outliers\StLukes_Outliers_&sysdate..pdf" notoc;
			%let emailfile=%str(\\fs\StLukes\Reports\Monthly_Reports\Data_Load\Outliers\StLukes_Outliers_&sysdate..txt);
			%let filename =%str(\\fs\StLukes\Reports\Monthly_Reports\Data_Load\Outliers\StLukes_Outliers_&sysdate..pdf);
		%end;
		
		ods listing;
		%macro scale(size); 
		%if %symexist(factor) ne 1 %then %let factor = 1; 
		%let scaled=%sysevalf(&size * &factor); 
		&scaled. 
		%mend;

		ods escapechar='~'; *use with certain style attributes;

	*SASDOC--------------------------------------------------------------------------
	| Outliers Summary Report Page
	------------------------------------------------------------------------SASDOC*;
		PROC REPORT data=outliers_summary nowindows split='/'
		style(header)=[font_face="Arial" font_size=%scale(8)pt just=center background=H14E8679] 
		style(column)=[font_face="Arial" font_size=0.5]; 

			title1 justify=center f="Arial" h=12pt "&client Outliers Summary Report";
			title2 justify=center f="Arial" h=8pt "&Current_Period";
			options pageno=1;

			footnote1 justify=right f="Arial" h=10pt "&client"; 
			footnote2 justify=right f="Arial" h=10pt "Section I, Page ~{thispage}"; 

			options orientation=portrait nodate nonumber leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;			

			column  measure total added dropped flagged;
					define measure / 'Overall';
					define total / 'Total';
					define added / 'Added';
					define dropped / 'Dropped';
					define flagged / 'Total in Outliers/(Section VI)' style=[cellwidth=1.5cm];
		run;

		ods pdf startpage=no;

		PROC REPORT data=outliers_summary3 nowindows split='/'
		style(header)=[font_face="Arial" font_size=%scale(8)pt just=center background=H14E8679] 
		style(column)=[font_face="Arial" font_size=0.5]; 

			options pageno=1;

			footnote1 justify=right f="Arial" h=10pt "&client"; 
			footnote2 justify=right f="Arial" h=10pt "Section I, Page ~{thispage}"; 

			options orientation=portrait nodate nonumber leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;			

			column  measure total added dropped flagged;
					define measure / 'Provider Movement in Guidelines';
					define total / 'Total Providers in Measure';
					define added / 'Providers Added to Measure';
					define dropped / 'Providers Dropped from Measure';
					define flagged / 'Total Providers in Outliers/(Section VI)' style=[cellwidth=3cm];

		run;
		ods pdf startpage=now;

	*SASDOC--------------------------------------------------------------------------
	| List of Measures in Current Reporting period - new and dropped measures flagged
	------------------------------------------------------------------------SASDOC*;
		title1 justify=center f="Arial" h=12pt "Guideline Measures";
		title2 justify=center f="Arial" h=10pt "&Current_Period";
		options pageno=1;
			footnote1 justify=right f="Arial" h=10pt "&client"; 
			footnote2 justify=right f="Arial" h=10pt "Section II, Page ~{thispage}"; 
		options orientation=PORTRAIT nodate nonumber leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;

		PROC REPORT nowd data=guideline_index split='/'
			style(header)=[font_face="Arial" font_size=%scale(8)pt just=center background=H14E8679 bordercolor=black]
			style(column)=[font_face="Arial" font_size=0.5]; 

				column guideline status eligible_current eligible_prior PercentCompliant_current PercentCompliant_prior gloutlier;
				define guideline / 'Guideline';
				define status / 'Status';
				define eligible_current / 'Number of Eligible Members/Current';
				define eligible_prior / 'Number of Eligible Members/Prior';
				define PercentCompliant_current / 'Percent Compliant/Current';
				define PercentCompliant_prior / 'Percent Compliant/Prior';
				define gloutlier / 'Outlier/(Guideline)';
		run;

		ods pdf startpage=now;

	*SASDOC--------------------------------------------------------------------------
	| List of submeasures in Current Reporting period - new and dropped measures flagged
	------------------------------------------------------------------------SASDOC*;

		title1 justify=center f="Arial" h=12pt "Guideline Submeasures";
		title2 justify=center f="Arial" h=10pt "&Current_Period";
		options pageno=1;
			footnote1 justify=right f="Arial" h=10pt "&client"; 
			footnote2 justify=right f="Arial" h=10pt "Section III, Page ~{thispage}"; 
		options orientation=PORTRAIT nodate nonumber leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;

		PROC REPORT nowd data=submeasure_index split='/'
			style(header)=[font_face="Arial" font_size=%scale(8)pt just=center background=H14E8679] 
			style(column)=[font_face="Arial" font_size=0.5]; 

		column guideline submeasure status elig_cur elig_pri;
		define guideline / 'Guideline';
		define submeasure / 'Submeasure' style=[cellwidth=6cm];
		define status / 'Status';
		define elig_cur / 'Number of Eligible Members/Current';
		define elig_pri / 'Number of Eligible Members/Prior';
		run;

		ods pdf startpage=now;

	*SASDOC--------------------------------------------------------------------------
	| Determine new, active and termed providers during the reporting period
	------------------------------------------------------------------------SASDOC*;
		title1 justify=center f="Arial" h=12pt "New and Dropped Providers to the Guidelines";
		options pageno=1;

			footnote1 justify=right f="Arial" h=10pt "&client"; 
			footnote2 justify=right f="Arial" h=10pt "Section IV, Page ~{thispage}"; 
		options orientation=portrait nodate nonumber leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;

		PROC REPORT nowd data=providers split='/'
			style(header)=[font_face="Arial" font_size=%scale(8)pt just=center background=H14E8679] 
			style(column)=[font_face="Arial" font_size=0.5]; 

		column provspecdesc provname pcpid new2guide leftguide status reason;
		define provspecdesc / 'Specialty' ;
		define provname / 'Provider Name' ;
		define pcpid / 'NPI' ;
		define new2guide / 'Provider Added/to Guidelines' center ;
		define leftguide / 'Provider No Longer/in Guidelines' center ;
		define status / 'CI Status' center;
		define reason / 'Explanation' style=[cellwidth=6cm];
/*				break after pcpid / skip;*/
/*				rbreak after / skip;*/
		run;
		ods pdf startpage=now;
	
	*SASDOC--------------------------------------------------------------------------
	| Providers no longer being measured for some guidelines, but measured for others
	------------------------------------------------------------------------SASDOC*;
		title1 justify=center f="Arial" h=12pt "Provider Changes in Measures";
/*		title2 justify=center f="Arial" h=10pt "#byval(provname) #byval(pcpid) #byval(provspecdesc)";*/
		options pageno=1;
			footnote1 justify=right f="Arial" h=10pt "&client"; 
			footnote2 justify=right f="Arial" h=10pt "Section V, Page ~{thispage}"; 
		options orientation=portrait nodate nonumber leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;

		PROC REPORT nowd nowindows data=prov_move split='@'
			style(header)=[font_face="Arial" font_size=%scale(8)pt just=center background=H14E8679]
			style(column)=[font_face="Arial" font_size=0.5]; 

			column provname pcpid provspecdesc newly_meas dropped_meas reason;
				define provname / group 'Provider';
				define pcpid / 'NPI';
				define provspecdesc / group 'Specialty';
				define newly_meas / 'New Measure for Provider';
				define dropped_meas / 'Provider No Longer@Eligible';
				define reason / 'Explanation' style=[cellwidth=6cm];
				break after provspecdesc / dul ;
/*				rbreak after / skip;*/
		run;
		ods pdf startpage=now;
	*SASDOC--------------------------------------------------------------------------
	| Providers in Guidelines with eligible member - outliers
	------------------------------------------------------------------------SASDOC*;
		PROC REPORT data=prov_outliers nowindows split='/'
		style(header)=[font_face="Arial" font_size=%scale(8)pt just=center background=H14E8679] 
		style(column)=[font_face="Arial" font_size=0.5]; 

			title1 justify=center f="Arial" h=12pt "Provider Outliers, by Guideline";
/*			title4 justify=center f="Arial" h=10pt "#byval(guideline)";*/
			options pageno=1;

			footnote1 justify=right f="Arial" h=10pt "&client"; 
			footnote2 justify=right f="Arial" h=10pt "Section VI, Page ~{thispage}"; 

			options orientation=portrait nodate nonumber leftmargin=0.5in rightmargin=0.5in topmargin=0.5in bottommargin=0.5in;			

/*			by guideline;*/
			column  guideline pcpname pcpid provspecdesc eligible_cur eligible_pri elig_diff comprate_diff;
					define guideline / group 'Guideline';
					define pcpname / group 'Provider Name';
					define pcpid / group 'NPI';
					define provspecdesc / group 'Specialty';

					define eligible_cur / 'Eligibile Members/Current';
					define eligible_pri / 'Eligibile Members/Prior';
					define elig_diff / 'Change in Eligible Members';
					define comprate_diff / 'Compliance Change';

			break after guideline / skip;
		run;

	ods _all_ close;

	options sasautos = ("M:\CI\programs\StandardMacros" sasautos);

	data _null_;
	  file "&emailfile." lrecl=3000;

		put "The &client. Outliers Report has been created and can now be viewed at the following location:";
		put;
		put "&filename.";
		put;
	run;

	data _null_;
	  emailid="&SYSUSERID.@valencehealth.com";
	  call symputx('emailid',emailid);
	run;
	%put NOTE: emailid = &emailid. ;

	%if "&client." = "NSAP" %then %do;
		%email_parms(	em_to=&emailid.,
						*em_cc=knachman@valencehealth.com,
			            em_subject=&client Outliers Report,
			            em_msg_file=%str(&emailfile.),
			            em_from=&emailid.
						);
	%end;
	%else %if "&client." = "PHS" %then %do;
		%email_parms(	em_to=&emailid.,
						em_cc=bphillips@valencehealth.com,
			            em_subject=&client Outliers Report,
			            em_msg_file=%str(&emailfile.),
			            em_from=&emailid.
						);
	%end;
	%else %if "&client." = "Adventist" %then %do;
		%email_parms(	em_to=&emailid.,
						em_cc=bphillips@valencehealth.com,
			            em_subject=&client Outliers Report,
			            em_msg_file=%str(&emailfile.),
			            em_from=&emailid.
						);
	%end;
	%else %if "&client." = "StLukes" %then %do;
		%email_parms(	em_to=&emailid.,
/*						em_cc=kgregory@valencehealth.com,*/
			            em_subject=&client Outliers Report,
			            em_msg_file=%str(&emailfile.),
			            em_from=&emailid.
						);
	%end;
%mend outlier;
/*%outlier(Adventist);*/
/*%outlier(NSAP);*/
/*%outlier(PHS);*/

