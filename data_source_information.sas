
/*HEADER------------------------------------------------------------------------
|
| program:  data_source_information.sas
|
| location: M:\CI\programs\StandardMacros 
|
| purpose:   
|
| logic:     
|           
|
| input:               
|
| output:    
|
+--------------------------------------------------------------------------------
| history:  
|
| 01DEC2011 - Brian Stropich  - Clinical Integration  1.0.01
|  
|
| 21DEC2011 - Brian Stropich  - Clinical Integration  1.1.01
|             Implement into Production
|
| 30MAY2012 - Brian Stropich  - Clinical Integration  1.2.01
|             Added changes for noload hold reprocess.  
|
| 30JUN2012 - Brian Stropich  - Clinical Integration  1.3.01
|             Added additional data format and payer variables.  
|
| 09AUG2012 - G Liu - Clinical Integration 1.5.01
|			  Delete duplicate variables, delete containphonenumber   
|
| 06SEP2012 - B Fletcher - EMR
|			  created an emr flag by left join to ids.version.emr column          
+-----------------------------------------------------------------------HEADER*/

%macro data_source_information;

	%global 
	facility_indicator 
	dataformatid  
	sasfilelayout  
	sassubfilelayout
	destinationdirectory  
	dataformatgroupid  
	dataformatgroupdesc 
	processingdirectory
	deliverytypeid
	deliverytypedescription
	archivepath
	
	sendtoclaimandmember
	payercontainprovider
	payercontainpractice
	payercontainprovpracattr
	payercontainmemberelig
	payercontainmemberattr
	payercontainub
	payercontainhcfa
	payercontainrx
	containmajcat
	runcaselogic
	runstaylogic
	payer_key
	emr
	;
	
	%if %symexist(practice_id) %then %do;
		proc sql noprint;
		select distinct case when e.clientid < 0 then 1
			else 0 
			end as facility_indicator into: facility_indicator separated by ''
		from vlink.tblgroups e,
			 ids.datasource_practice f 
		where f.datasourceid=&practice_id.
		  and e.groupid=f.practiceid;
		quit;
	%end;
	
	proc sql noprint;
	create table client_facility_information as
	select distinct case when e.clientid < 0 then 1
		else 0 
		end as facility_indicator ,
		datasourceid
	from vlink.tblgroups e,
		 ids.datasource_practice f 
	where e.groupid=f.practiceid;
	quit;	
	
	proc sql noprint;
	create table client_data_source_information as
	select distinct
		a.datasourceid,
		a.clientid, 
		a.dataformatid, 
		a.deliverytypeid,
		a.name, 
		a.scheduleid, 
		a.scheduleday, 
		a.schedulehour,
		a.destinationdirectory,
		b.sasfilelayout as sassubfilelayout,
		b.ciofilelayout as sasfilelayout,
		abs(b.sendtoclaimandmember) as sendtoclaimandmember,
		abs(b.payercontainprovider) as payercontainprovider,
		abs(b.payercontainpractice) as payercontainpractice,
		abs(b.payercontainprovpracattr) as payercontainprovpracattr,
		abs(b.payercontainmemberelig) as payercontainmemberelig,
		abs(b.payercontainmemberattr) as payercontainmemberattr,
		abs(b.payercontainub) as payercontainub,
		abs(b.payercontainhcfa) as payercontainhcfa,
		abs(b.payercontainrx) as payercontainrx,
		abs(b.containmajcat) as containmajcat,
		abs(b.runcaselogic) as runcaselogic,
		abs(b.runstaylogic) as runstaylogic,
		c.dataformatgroupid,
		d.dataformatgroupdesc,
		e.ProcessingDirectory, 
		f.deliverytypedescription,
		e.archivepath
	from ids.datasource        	a left outer join
		ids.dataformat       		b on a.DataFormatID=b.DataFormatID left outer join
		ids.dataformattogroup 		c on a.DataFormatID=c.DataFormatID left outer join
		ids.dataformatgroup   		d on c.DataFormatGroupID=d.DataFormatGroupID left outer join
		ids.dataformatgroupsettings e on c.DataFormatGroupID=e.DataFormatGroupID and a.ClientID=e.ClientID left outer join
		ids.deliverytype 		f on a.deliverytypeID=f.deliverytypeID 
	where a.clientid = &client_id. 	;
	quit;
	
	%if %symexist(practice_id) %then %do;
	proc sql noprint;
	create table data_source_information as
	select distinct
		a.datasourceid,
		a.clientid, 
		a.dataformatid, 
		a.deliverytypeid,
		a.name, 
		a.scheduleid, 
		a.scheduleday, 
		a.schedulehour,
		a.destinationdirectory,
		b.sasfilelayout as sassubfilelayout,
		b.ciofilelayout as sasfilelayout,
		abs(b.sendtoclaimandmember) as sendtoclaimandmember,
		abs(b.payercontainprovider) as payercontainprovider,
		abs(b.payercontainpractice) as payercontainpractice,
		abs(b.payercontainprovpracattr) as payercontainprovpracattr,
		abs(b.payercontainmemberelig) as payercontainmemberelig,
		abs(b.payercontainmemberattr) as payercontainmemberattr,
		abs(b.payercontainub) as payercontainub,
		abs(b.payercontainhcfa) as payercontainhcfa,
		abs(b.payercontainrx) as payercontainrx,
		abs(b.containmajcat) as containmajcat,
		abs(b.runcaselogic) as runcaselogic,
		abs(b.runstaylogic) as runstaylogic,
		c.dataformatgroupid,
		d.dataformatgroupdesc,
		e.ProcessingDirectory, 
		f.deliverytypedescription,
		e.archivepath,
		g.payer_key,
		coalesce(h.emr,0) as emr
	from ids.datasource        		a left outer join
		ids.dataformat       		b on a.DataFormatID=b.DataFormatID left outer join
		ids.dataformattogroup 		c on a.DataFormatID=c.DataFormatID left outer join
		ids.dataformatgroup   		d on c.DataFormatGroupID=d.DataFormatGroupID left outer join
		ids.dataformatgroupsettings e on c.DataFormatGroupID=e.DataFormatGroupID and a.ClientID=e.ClientID left outer join
		ids.deliverytype 			f on a.deliverytypeID=f.deliverytypeID left outer join
        ids.datasource_payer 		g on a.datasourceid=g.datasourceid left outer join
		ids.version					h on h.VersionID=a.VersionID 
	where a.datasourceid = &practice_id. 	;
	quit; 

	proc sql noprint; 
	select 
	  	dataformatid, 
	  	sasfilelayout,
	  	sassubfilelayout,
	  	destinationdirectory,
	  	dataformatgroupid,
	  	dataformatgroupdesc,
	  	processingdirectory,
	  	deliverytypeid,
	  	deliverytypedescription,
	  	archivepath,
		sendtoclaimandmember,
		payercontainprovider,
		payercontainpractice,
		payercontainprovpracattr,
		payercontainmemberelig,
		payercontainmemberattr,
		payercontainub,
		payercontainhcfa,
		payercontainrx,
		containmajcat,
		runcaselogic,
		runstaylogic,
		payer_key,
		emr
	  	
	into  :dataformatid separated by '', 
			:sasfilelayout separated by '',
			:sassubfilelayout separated by '',
			:destinationdirectory separated by '',
			:dataformatgroupid separated by '',
			:dataformatgroupdesc separated by '',
			:processingdirectory separated by '',
			:deliverytypeID separated by '',
			:deliverytypedescription separated by '',
			:archivepath separated by '',
		:sendtoclaimandmember separated by '',
		:payercontainprovider separated by '',
		:payercontainpractice separated by '',
		:payercontainprovpracattr separated by '',
		:payercontainmemberelig separated by '',
		:payercontainmemberattr separated by '',
		:payercontainub separated by '',
		:payercontainhcfa separated by '',
		:payercontainrx separated by '',
		:containmajcat separated by '',
		:runcaselogic separated by '',
		:runstaylogic separated by '',
		:payer_key separated by '',
		:emr separated by ''
			
	from data_source_information
	where datasourceid=&practice_id. ;
	quit;

	options nosymbolgen; 
	%put NOTE: facility_indicator       = &facility_indicator. ; 
	%put NOTE: dataformatid             = &dataformatid. ;
	%put NOTE: sasfilelayout            = &sasfilelayout. ; 
	%put NOTE: sassubfilelayout         = &sassubfilelayout. ; 
	%put NOTE: destinationdirectory     = &destinationdirectory. ;
	%put NOTE: dataformatgroupid        = &dataformatgroupid. ;
	%put NOTE: dataformatgroupdesc      = &dataformatgroupdesc. ;
	%put NOTE: processingdirectory      = &processingdirectory. ;
	%put NOTE: deliverytypeID           = &deliverytypeID. ;
	%put NOTE: deliverytypedescription  = &deliverytypedescription. ;
	%put NOTE: archivepath 	   	        = &archivepath. ;
	%put NOTE: sendtoclaimandmember	    = &sendtoclaimandmember. ;
	%put NOTE: payercontainprovider	    = &payercontainprovider. ;
	%put NOTE: payercontainpractice	    = &payercontainpractice. ;
	%put NOTE: payercontainprovpracattr = &payercontainprovpracattr. ;
	%put NOTE: payercontainmemberelig   = &payercontainmemberelig. ;
	%put NOTE: payercontainmemberattr   = &payercontainmemberattr. ;
	%put NOTE: payercontainub	        = &payercontainub. ;
	%put NOTE: payercontainhcfa	        = &payercontainhcfa. ;
	%put NOTE: payercontainrx	        = &payercontainrx. ;
	%put NOTE: containmajcat	        = &containmajcat. ;
	%put NOTE: runcaselogic		        = &runcaselogic. ;
	%put NOTE: runstaylogic		        = &runstaylogic. ;
	%put NOTE: payer_key		        = &payer_key. ;
	%put NOTE: emr						= &emr.;
	
	options symbolgen; 
	
	%end;
			
%mend data_source_information; 
