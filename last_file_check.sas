
/*HEADER------------------------------------------------------------------------
|
| program:  last_file_check.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Checks for the latest files in the vmine folders
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
| 01APR2010 - Brian Stropich  - Clinical Integration  1.0.02
|             Removed the macro from all the vmine programs and relocated it within
|             the Standard Macro folder.
| 07APR2010 - Erin Murphy - Clinical Integration  1.0.03
|			  Changed "System" length from $30. to $75. in lastfilecheck6 data step.
|
| 15FEB2011 - Winnie Lee - Clinical Integration 1.0.04
|			1. Replace SQLin1 libname to use oledb_init_string macro IDS
|			2. Update all tables and fields from vMine to IDS.
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|             
+-----------------------------------------------------------------------HEADER*/

%macro last_file_check(client,system);

	%put &dataerrors;
	%let client_id = 1; /** default to create EMINE connection **/

	%oledb_init_string;

	libname ids  	oledb init_string=&ids. 	preserve_tab_names=yes;
	libname vlink  	oledb init_string=&vlink. 	preserve_tab_names=yes;
	libname emine 	oledb init_string=&emine. 	preserve_tab_names=yes;
	


	/** CREATE LATEST VMINE EXTRACTION RECORD FROM IDS **/

	proc sql;
		create table sourcestatus as 
		select distinct 
			v.InstallStat		as Install_Status length=25 format=$25. informat=$25., 
			d.datasourceid
		from VLINK.VALLCLIENTSCIPROGRESSDETAILED as v	left join
			 IDS.DATASOURCE_PRACTICE as d on v.groupid=d.practiceid
		where datasourceid ne .
		order by datasourceid;
	quit;
		
	proc sql;
		create table lastfilecheck1 as
		select
			a.datasourceid				as practiceid,
			put(a.filename,$25.)		as filename,
			put(b.name,$50.)			as practice_name,
			put(c.clientname,$25.)		as client,
			put(d.directorypath,$75.)	as system,
			f.Install_Status,
			a.filepath	
		from IDS.TRANSMISSION	as a 									left outer join
			 IDS.DATASOURCE		as b on a.datasourceid=b.datasourceid 	left outer join
			 IDS.CLIENT			as c on b.clientid=c.clientid 			left outer join
			 IDS.VERSION		as d on a.versionid=d.versionid			left outer join
			 IDS.SYSTEM			as e on d.systemid=e.systemid			left join
			 sourcestatus		as f on f.datasourceid=a.datasourceid
		where c.clientid ne 0
		;
	quit;

	data lastfilecheck2 (drop=filename);
	set lastfilecheck1;
	file_month = cats(substr(filename,index(filename,'-') + 1,6)) * 1;
	file_name  = trim(substr(filename,1,index(filename,'.') - 1));
	run;

	proc sort data=lastfilecheck2;
	by client system practiceid practice_name file_name file_month;
	run;

	data lastfilecheck3;
	set lastfilecheck2;
	by client system practiceid practice_name file_name file_month;
	if last.practice_name then output;
	run;


	/** CREATE LATEST TEXT FILE RECORD FROM IDS **/
	data lasttxtfile;
	set lastfilecheck1;
	where filepath ne '';
	file_month = cats(substr(filename,index(filename,'-') + 1,6)) * 1;
	file_name  = trim(substr(filename,1,index(filename,'.') - 1));
	run;

	proc sort data=lasttxtfile;
	by client system practiceid practice_name file_name file_month;
	run;

	data lasttxtfile2 (drop=filepath Install_Status);
	set lasttxtfile;
	by client system practiceid practice_name file_name file_month;
	if last.practice_name then output;
	run;


	/** CREATE LATEST CIMASTER LOADED RECORD FROM KTBL_PROCESS **/
	proc sql;
		create table ktbl_process as
		select
			b.clientname as client,
			filename,
			put(datepart(processdatetime),mmddyy10.) as processdt,
			success,
			kprocessid
		from EMINE.KTBL_PROCESS as a left outer join
			 IDS.CLIENT as b on a.clientid=b.clientid
		where processdatetime >= '27jul2011'd and a.clientid not in (.,0)
		;
	quit;

	data ktbl_process2;
	set ktbl_process;
	length practiceid file_month 8. file_name $25.;
	practiceid = substr(filename,1,index(filename,'-') - 1) * 1;
	file_month = cats(substr(filename,index(filename,'-') + 1,6)) * 1;
	file_name  = trim(substr(filename,1,index(filename,'.') - 1));
	run;

	proc sort data=ktbl_process2;
	by client practiceid file_name file_month kprocessid;
	run;

	data ktbl_process3 (drop=filename);
	set ktbl_process2;
	by client practiceid file_name file_month;
	if last.practiceid then output;
	run;

	data ktbl_process4;
	set ktbl_process3;
	where success not in (.,0);
	run;

	/** CHECK FOR ALL UNIQUE KPROCESSIDS IN ALL OF SPECIFIED PM SYSTEM TABLES TO SEE IF FILE LOADED AT ALL OR IF ANY NEW RECORDS**/

	%vmine_PM_tbl_kProcessIDs (like_statement=&system.);

	data sql_kprocessids;
	set sql_kprocessids;
	length Exists_In_CIMaster $1.;
	Exists_In_CIMaster = 'Y';
	run;
	
	proc sql noprint;
		create table cimaster as
		select
			a.*,
			b.Exists_In_CIMaster
		from ktbl_process4 	 as a left outer join
			 sql_kprocessids as b on a.kprocessid=b.kprocessid
		;
	quit;

	/** COMBINE ALL PIECES OF INFO **/
	proc sql noprint;
		create table latestfile as
		select
			a.client,
			a.system,
			a.practiceid,
			a.practice_name,
			a.file_name,
			a.file_month,
			a.Install_Status,
			case when b.filename is not null then 'Y'
				else 'N'						end as TXT_File_Created length=1,
			case when (c.processdt is not null or c.processdt ne '') and c.success = -1 then 'Y'
				else 'N'						end as Latest_KTBL_ProcessID_Success length=1,
			case when d.Exists_In_CIMaster = 'Y' then d.Exists_In_CIMaster
				else 'N'						end as Latest_ProcessID_In_CIMaster
		from lastfilecheck3 as a left outer join
			 lasttxtfile2	as b on a.client=b.client and a.system=b.system and a.practiceid=b.practiceid and 
									a.practice_name=b.practice_name and a.file_name=b.file_name and
									a.file_month=b.file_month left outer join
			 ktbl_process3	as c on a.client=c.client and a.practiceid=c.practiceid and a.file_name=c.file_name and
			 						a.file_month=c.file_month left outer join
			 cimaster		as d on a.client=d.client and a.practiceid=d.practiceid and a.file_name=d.file_name and
			 						a.file_month=d.file_month
		order by client, system, practiceid, practice_name, file_name, file_month
		;
	quit;

	ods results;
	ods listing;

	proc print data=latestfile;
	where client = "&client" and system="&system";
	*var client system practiceid practice_name file_name file_month installstat Text_File_Exists;
	title "MOST CURRENT &system. FILES FROM VMINE";
	title2 "Make Sure Current Month File Is There";
	title3 "Check For Any New Practices";
	run;

	libname ids clear;

	proc datasets library=work;
	delete 
		cimaster
		ktbl_process
		ktbl_process2
		ktbl_process3
		ktbl_process4
		lastfilecheck1
		lastfilecheck2
		lastfilecheck3
		lasttxtfile
		lasttxtfile2
		null_
		sourcestatus
		sql_kprocessids
		tables_cimaster
		z
	;
	run;
	quit;

	%let client_id = ; /** uninitialize after creating EMINE connection **/
%mend last_file_check;
