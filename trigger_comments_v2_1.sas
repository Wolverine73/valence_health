/*HEADER------------------------------------------------------------------------
|
| program:  trigger_comments_v2_1.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose: Trigger Attribution logic for guidelines                     
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
| 16JAN2012 - EM Exempla calls the trigger_comments_v3 macro - converting to EDW
+-----------------------------------------------------------------------HEADER*/

%macro trigger_comments_v2_1;
	%if &trigger_comments = 1 %then %do;

/*		%if &client = Exempla %then %do;*/
/*			%trigger_comments_v3;*/
/*		%end;*/

/*		%else %do;*/
			data g5;
			set g5;

			where 	  		%if &client=Adventist 	   		   %then %do; put(pcpid,$ReportingType.) in ("V")			and	%end;
					  %else %if %QUPCASE("&client.")="EXEMPLA" %then %do; put(pcpid,$RptCode.) 							in ("P", "V") 		and	%end;
					  %else %if &client=NSAP 				   %then %do; put(pcpid,$provtype.) 						in ("P", "V") 		and	%end;
					  %else %if &client=OHG 		           %then %do; put(pcpid,$ProvType.) 						in ("P", "V") 		and	%end;
					  %else %if &client=PHS 		           %then %do; put(pcpid,$rptcode.) 							in ("V") 			and	%end;
					  %else %if &client=StLukes 	           %then %do; put(pcpid,$rptcode.) 							in ("NotManual")	and	%end;

			  substr(pcpid,1,1) not in ("8","9") and
			  put(pcpid,$provyn.) = "Y";

			%if &period = current %then %do;
				length mem_guide $32. mem_pcp $27. guideline_key $15.;
				guideline_key = "&guideline_key.";
				mem_guide = cats(memberid)||"||"||cats(guideline_key);
				mem_pcp = cats(memberid)||"||"||cats(pcpid);
			    	
				if put(memberid,$expired.) = 'Y' then delete;
				if put(mem_guide,$refused.) = 'Y' then delete;
				if put(mem_pcp,$nopat.) = 'Y' then delete;
				run;
			%end;
/*		%end;*/

	%end;
%mend trigger_comments_v2_1;


%trigger_comments_v2_1;
