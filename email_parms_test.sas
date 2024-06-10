
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  email_parms.sas
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  
|                        
|
| INPUT:    
|
| OUTPUT:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 01JAN2010 - John Doe  - Clinical Integration  1.0.01
|             
|
|             
+-----------------------------------------------------------------------HEADER*/


%macro email_parms_test(em_to=,
                    em_cc=,
                    em_subject=,
                    em_msg=,
                    em_msg_file=,
                    em_type=,
                    em_attach=,
                    em_from=);


  %*===========================================================================;
  %* Scope the macro variables.
  %*====================================================================SASDOC*;

  %global err_cd message;
  
  %if &em_from eq %then %do;
    %let em_from=&sysuserid.@valencehealth.com;
  %end;
  
  %local  unk_attach_type_flg;
  %let    unk_attach_type_flg=0;

  %*===========================================================================;
  %* Proceed only if the "to" and "from" IDs/addresses have been provided.
  %*====================================================================SASDOC*;
  %put email address are: &em_to. ;

  %isnull(em_to, em_from);
  %if ^&isnull %then %do;

    %*=========================================================================;
    %* Use the %get_email_address macro to retrieve email addresses for any
    %* QCP IDs in EM_TO and EM_CC.
    %*==================================================================SASDOC*;

    %let em_to=%sysfunc(dequote(&em_to));  
    %put email address are: &em_to. ;

    %let em_from=%sysfunc(dequote(&em_from));  

    %isnull(em_cc, em_from, em_subject, em_msg, em_type, em_attach);

    %if ^&em_cc_isnull %then %do;
      %let em_cc=%upcase(%sysfunc(dequote(&em_cc))); 
    %end;
    %else %let em_cc=;

    %if ^&em_subject_isnull %then %let em_subject=%sysfunc(dequote(&em_subject));
    %if ^&em_msg_isnull     %then %let em_msg=%sysfunc(dequote(&em_msg));
    %if ^&em_type_isnull    %then %let em_type=%sysfunc(dequote(&em_type));


    %*=========================================================================;
    %* If an EM_ATTACH parameter has been specified, then determine the
    %* the attachment types based on the filename extensions. Each filename is
    %* processed or rather identified and assigned a CT= value (i.e., content
    %* type) which is added immediately following the filename in a new
    %* _ATTACHMENTS macro variable/string to be used during the email process.
    %*==================================================================SASDOC*;

    %if ^&em_attach_isnull  %then %do;

      %let i=1;

      %let em_attach=%sysfunc(compress(&em_attach,%str(%')%str(%")));
/*      %let em_attach=%sysfunc(compress(%bquote(&em_attach),%str(%')%str(%")' ,')); */
		%PUT &EM_ATTACH;

      %let _attachments=;
		
      %do %while(%qscan(%qcmpres(%bquote(&em_attach)),&i,%str( ))^=);

        %let _attach=%sysfunc(dequote(%qscan(%qcmpres(%bquote(&em_attach)),&i,%str( ))));
		%put &_attach;

        %if "%substr(%left(&_attach),1,3))"="%str(ct=)" %then %let ct=%substr(%left(&_attach,4));
        %else %do;
          %if       %index(%upcase(&_attach),.PDF) %then %let ct=application/pdf;
          %else %if %index(%upcase(&_attach),.RTF) %then %let ct=application/rtf;
          %else %if %index(%upcase(&_attach),.XLS) or
                    %index(%upcase(&_attach),.DOC) or
                    %index(%upcase(&_attach),.SSD) or
                    %index(%upcase(&_attach),.SAS7BDAT) or
                    %index(%upcase(&_attach),.MDE) or
                    %index(%upcase(&_attach),.MDB) or
                    %index(%upcase(&_attach),.SAS7BCAT) or
                    %index(%upcase(&_attach),.SD2) or
                    %index(%upcase(&_attach),.SD7) %then %let ct=application/octet-stream;
          %else %let ct=;
        %end;

        %let _attachments=%left(%str(&_attachments %'%cmpres(&_attach)%'));
        %if "&ct"^="" %then %let _attachments=%left(%str(&_attachments ct=%'%cmpres(&ct)%'));

        %let i=%eval(&i+1);
      %end;
    %end;


    %*=========================================================================;
    %* The email process begins with defining a filename with an EMAIL engine.
    %*==================================================================SASDOC*;
    %*=========================================================================;
    %* NOTE: The email options can be specified directly in the datastep rather
    %*       than in the filename statement, but there were problems experienced
    %*       when attempting to specify multiple attachments in the datastep.
    %*==================================================================SASDOC*;
/*    to=("joe@smplc.org" "jane@diffplc.org")*/
    options emailid="&em_from.";
    filename mail_out email %str(to=("&em_to"))    
                            %if ^&em_cc_isnull %then %str(cc="&em_cc");
                            %if ^&em_type_isnull %then %str(type="&em_type");
                            %if ^&em_subject_isnull %then %str(subject="&em_subject");
                            %if ^&em_attach_isnull  %then %str(attach=%(&_attachments%)) ;
    ;


    %if &em_msg_file =  %then %do;
	data _null_;
	file mail_out lrecl=32767;
	put  "&em_msg";
	if _error_ then do;
	call symput('err_cd', put(1,1.));
	call symput('message', sysmsg());
	end;
	else call symput('err_cd', put(0,1.));
	run;    
    %end;
    %else %do;    
	data message01;
	  infile "&em_msg_file." missover length=lg;
	  input @;
	  input @ 1 fullline $varying2000. lg;
	run;
 		
	data _null_;
	file mail_out lrecl=32767;
	set message01;
	put fullline;
	if _error_ then do;
	call symput('err_cd', put(1,1.));
	call symput('message', sysmsg());
	end;
	else call symput('err_cd', put(0,1.));    
	run;
    %end;

    %****** Clear the fileref *****;
    filename mail_out clear;

  %end;
  %else %do;
    %if &em_from_isnull %then %put ERROR: (&sysmacroname): The EM_FROM parameter has not been specified.;
    %if &em_to_isnull   %then %put ERROR: (&sysmacroname): The EM_TO   parameter has not been specified.;
  %end;
%mend email_parms_test;
