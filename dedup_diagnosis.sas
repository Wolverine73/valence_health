/* Dedup Diagnosis Code (and POA if exists), but maintain original order.
	If same diagnosis, but different poa, take first pair.
   Macro will determine how many diagnosis codes or poa codes there are in the input dataset.

   Required macro parameter:
	m_input 		= input dataset
	m_diag_prefix 	= prefix for diagnosis variable
	m_poa_prefix	= prefix for poa variable, if poa does not exist, set parameter as null
	
   Optional macro parameter:
	m_diag_suffix 	= suffix for diagnosis variable
	m_poa_suffix	= suffix for poa variable

   To call macro:
	%dedup_diagnosis(test,diag,)
		- no poa variables
		- diag variables are diag1-diagx

	%dedup_diagnosis(incoming,diag,poa)
		- diag variables are diag1-diagx
		- poa variables are poa1-poax

	%dedup_diagnosis(dataset,dx,poa,m_diag_suffix=cd,m_poa_suffix=_pfkey)
		- diag variables are dx1cd-dx?cd
		- poa variables are poa1_pfkey-poa?_pfkey

   Example:
	Input: Diag1=123, Diag2=456, Diag3=123, Diag4=987, Diag5=456
	Output:Diag1=123, Diag2=456, Diag3=987, Diag4=   , Diag5=

	Input: Diag1=123 POA1=Y, Diag2=123 POA2=U, Diag3=456 POA3=, Diag4=456 POA4=Y
	Output:Diag1=123 POA1=Y, Diag2=456 POA2= , Diag3=    POA3=, Diag4=    POA4=
	Take first occurrence of diag and poa, hence second occurrence of same diag, poa loses even when poa
		has different value
*/
%macro dedup_diagnosis(m_input,m_diag_prefix,m_poa_prefix,m_diag_suffix=,m_poa_suffix=);
	%let m_diag_prefix=%upcase(&m_diag_prefix.);
	%let m_diag_suffix=%upcase(&m_diag_suffix.);
	%let m_poa_prefix=%upcase(&m_poa_prefix.);
	%let m_poa_suffix=%upcase(&m_poa_suffix.);
	proc contents data=&m_input. out=m_input_contents noprint;
	data _null_;
		set m_input_contents;
		name=upcase(name);
		namelength=length(name);
		diagprefixlength=length("&m_diag_prefix.");
		if "&m_diag_suffix."="" then diagsuffixlength=0; else diagsuffixlength=length("&m_diag_suffix.");
		retain numofdiag 0;
		if name=: "&m_diag_prefix." and compress(substr(name,diagprefixlength+1),'0123456789')="&m_diag_suffix."
			 then numofdiag=max(numofdiag,substr(name,diagprefixlength+1,namelength-diagprefixlength-diagsuffixlength));
		call symput('m_numofdiag',cats(numofdiag));
	run;
	proc sql; drop table m_input_contents; quit;
	%put NOTE: # of ICD-9 Diagnosis Codes = &m_numofdiag.;

	%IF &m_numofdiag. ge 2 %THEN %DO;
		data &m_input.;
			modify &m_input.;
			array x_d(&m_numofdiag.) %do dd=1 %to &m_numofdiag.; &m_diag_prefix.&dd.&m_diag_suffix. %end; ;
		  %if &m_poa_prefix. ne %then %do;
			array x_p(&m_numofdiag.) %do dd=1 %to &m_numofdiag.; &m_poa_prefix.&dd.&m_poa_suffix. %end; ;
		  %end;
			do x_i=2 to &m_numofdiag.;
				do x_j=x_i-1 to 1 by -1;
					if x_d(x_i)=x_d(x_j) then call missing(x_d(x_i) %if &m_poa_prefix. ne %then %do;,x_p(x_i) %end;);
				end;
			end;
			do x_i=&m_numofdiag. to 2 by -1;
				if x_d(x_i) ne '' and x_d(x_i-1)='' then do x_j=x_i to &m_numofdiag.;
					x_d(x_j-1)=x_d(x_j);
				  %if &m_poa_prefix. ne %then %do;
					x_p(x_j-1)=x_p(x_j);
				  %end;
					call missing(x_d(&m_numofdiag.) %if &m_poa_prefix. ne %then %do;,x_p(&m_numofdiag.) %end;);
				end;
			end;
			drop x_i x_j;
		run;
	%END;
%mend dedup_diagnosis;
/*
data test(bufsize=128k compress=yes);
	diag1='123.2'; poa1='U';
	diag2='126.2'; poa2='Y';
	diag3='123.2'; poa3='Y';
	diag4='126.2'; poa4='N'; output;
	diag1='123.2'; poa1='N';
	diag2='123.2'; poa2='Y';
	diag3='123.2'; poa3='';
	diag4='126.2'; poa4='U'; output;
	diag1='123.2'; poa1='N';
	diag2='123.2'; poa2='Y';
	diag3='126.2'; poa3='';
	diag4='126.2'; poa4='U'; output;
	diag1='123.2'; poa1='N';
	diag2='124.2'; poa2='Y';
	diag3='125.2'; poa3='';
	diag4='126.2'; poa4='U'; output;
	diag1='123.2'; poa1='N';
	diag2='124.2'; poa2='Y';
	diag3='123.2'; poa3='';
	diag4='125.2'; poa4='';
	diag5='123.2'; poa5='';
	diag6='126.2'; poa6='U'; output;
	diag1='126.2'; poa1='N';
	diag2='126.2'; poa2='Y';
	diag3='126.2'; poa3='';
	diag4='126.2'; poa4='U';
	diag5=''; poa5='U'; output;
	rename poa1=poa1_pfkey poa2=poa2_pfkey poa3=poa3_pfkey poa4=poa4_pfkey poa5=poa5_pfkey poa6=poa6_pfkey;
*	rename diag1=diag1cd diag2=diag2cd diag3=diag3cd diag4=diag4cd diag5=diag5cd diag6=diag6cd;
run;
%dedup_diagnosis(test,diag,poa,m_poa_suffix=_pfkey)
*/
