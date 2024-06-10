
/*HEADER------------------------------------------------------------------------
|
| program:  create_vmine_libnames.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Create standard libnames based on the vMine database                     
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
| 01APR2010 - Brian Stropich  - Clinical Integration  1.0.01
|             Original
|
| 15FEB2011 - Winnie Lee - Clinical Integration 1.0.04
|			1. Replace VMINE libname to use oledb_init_string macro IDS
|			2. Update all tables and fields from vMine to IDS.
|
| 08APR2011 - Winnie Lee - Clinical Integration 1.0.05
|			1. Included UPCASE function when using TRANWRD to compare and replace strings 
|             
| 11APR2011 - Erin Murphy - Clinical Integration 1.0.05
|			1. No longer mapping libnames to PM system folders that don't contain data 
|
| 02MAY2011 - Winnie Lee - Clinical Integration 1.0.06
|			1. Remapped in vMine_parms to look at TRANSMISSION.versionID instead of DATASOURCE.versionID
|
| 04MAY2011 - Winnie Lee - Clinical Integration 1.0.07
|			1. Fixed comparitive values
|			2. Modified system name to deal with various system names
|			3. Renamed Medisoft16 to Medisoft and Lytec2010 to Lytec
|             
+-----------------------------------------------------------------------HEADER*/

%macro create_vmine_libnames(vmine_client_name=, vmine_client_id=);

	/*15FEB2011 WLEE - modified to call from IDS database*/
	proc sql; 
		create table vmine_parms as
		select distinct
			case when a.processeddate is null then 0
			else -1							end as isprocessed,
			a.processeddate						as dateprocessed,
			a.dataerrors,
			a.receiveddate						as dateentered,
			a.filename							as file_name,
			substr(scan(a.filename,2,'-'),1,8) 	as file_date,
			a.filepath,
			b.datasourceid						as practiceid,
			b.name								as practicename,
			c.clientid,
			c.clientname,
			d.versionid,
			d.directorypath								as systemname, 
			d.systemid
		from IDS.TRANSMISSION 	as a 									inner join
			 IDS.DATASOURCE		as b on a.datasourceid = b.datasourceid inner join
			 IDS.CLIENT			as c on b.clientid = c.clientid 		inner join
			 IDS.VERSION		as d on a.versionid = d.versionid 		inner join
			 IDS.SYSTEM			as e on d.systemid = e.systemid
		where c.clientid = &vmine_client_id.
			  and a.processeddate is not null
		%if &vmine_client_id. ne 4 and &vmine_client_id. ne 5 %then %do; 
			and b.enabled = 1
		%end;
		order by e.name, a.filename
		;
	quit; /*04MAY2011 - WLee modified system name to deal with various system names*/
		  /*04MAY2011 - WLee fixed comparitive values*/
   
	   data vmine_parms;
	      set vmine_parms;
		  if systemname = 'Medisoft16' then systemname = 'Medisoft'; /*04MAY2011 - WLee added to deal with various system names*/
		  if systemname = 'Lytec2010' then systemname = 'Lytec';	 /*04MAY2011 - WLee added to deal with various system names*/
		  if upcase(systemname) = 'ALTAPOINT8' then systemname = 'ALTAPOINT';	 /*04MAY2011 - WLee added to deal with various system names*/
	      old=index(upcase(filepath),'OLD');
		  %if &vmine_client_id. ne 5 AND &vmine_client_id. ne 4 %then %do;
		     if old > 0 then delete;
		  %end; 
	      drop old;
	   run;

   data vmine_libnames badmap;
      length sasdirectory saslibname $100 ;
      set vmine_parms (keep = filepath systemname systemid clientid where=(filepath ne "" and index(upcase(filepath), 'VMINEDEV') in (0, .)));
      
      /**general information --------------------------------------------------------**/
      i=index(filepath,'vMine');
      client=scan(filepath,2,'\');
	  if clientid ne 4 then
        subfolder=scan(filepath,5,'\'); 
	 
	  else
        subfolder=scan(filepath,6,'\'); 
	  
      
      /**sas2 information ----------------------------------------------------------**/
      sasdirectory=substr(filepath,1,i+5);
      sasdirectory=trim(left(sasdirectory))||trim(left(subfolder));
      sasdirectory=tranwrd(sasdirectory, "\\fs\", "M:\");
	  if clientID = 4 then do;
			/*sasdirectory=tranwrd(sasdirectory, "\data\CI\", "\sasdata\CI\CIETL\claims\");*/
	  sasdirectory=tranwrd(upcase(sasdirectory), upcase("\data\CI\"), upcase("\sasdata\CI\CIETL\claims\")); /*08APR2011 - WLee - modified to enable comparisons between different cases in string*/ 
      end; else do;
		    /*sasdirectory=tranwrd(sasdirectory, "\data\", "\sasdata\CIETL\claims\"); */
	  		sasdirectory=tranwrd(upcase(sasdirectory), upcase("\data\"), upcase("\sasdata\CIETL\claims\"));  /*08APR2011 - WLee - modified to enable comparisons between different cases in string*/
      end;

      /** pm system libnames -------------------------------------------------------**/
      saslibname='libname _'||trim(left(systemid))||' "'||trim(left(sasdirectory))||'"; ' ;   
	  if (subfolder ne systemname )and (systemname not in ('Medisoft16', 'Lytec2010', 'ALTAPOINT', 'Altapoint8')) then output badmap;
	  else output vmine_libnames; /*5/10 aisaacs to ensure that bad mappings are not effecting libnames*/
   run;

   proc sort data =  vmine_libnames nodupkey;
      by saslibname ;
   run;
   
   proc sort data =  vmine_libnames nodupkey;
      by systemname ;
   run;


   data _null_;
      set vmine_libnames  end=eof;
      g+1; 
      ii=left(put(g,4.));
      call symput('libname'||ii,trim(saslibname)); 
      if eof then call symput('libname_total',ii);
   run;

   %do lib = 1 %to &libname_total. ; 
     &&libname&lib 
   %end;

%mend create_vmine_libnames;

