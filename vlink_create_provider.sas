
/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  vlink_create_provider.sas
|
| LOCATION: M:\CI\programs\StandardMacros 
|
| PURPOSE:  To create the provider table
|           
| INPUT:    SQL: NSAPvlink,NSAPPortal,Vmine  
|
| OUTPUT:   Provider dataset
|           UID and PID formats
+--------------------------------------------------------------------------------
| HISTORY:  
|
| 20MAY2010 - Neema Thundathil  - Clinical Integration  1.0.01
|             Created provider macro
|
|             
+-----------------------------------------------------------------------HEADER*/

%macro vlink_create_provider(dataout=, vmine_client_id=);
	
   *SASDOC--------------------------------------------------------------------------
   | Read in vlink tables
   +------------------------------------------------------------------------SASDOC*;   

data prov1 (keep =  P_SocialSecurity P_CIEffDt P_CITermDt P_CIPar P_NPI 
   	   P_MedicareUPIN P_LastName P_FirstName P_Gender providerID P_NetworkStatus pcpname);
 set vlink.tblProvider;
 where ClientID = &vmine_client_id.;
run;

   data groups(keep = groupid groupname groupftin);
     set vlink.tblGroups;
     where ClientID = &vmine_client_id. and G_TermDt = . and G_CIPar = 1;
   run;
   
   data provgroup(keep = providerid groupid);
     set vlink.tblProviderGroups;
   run;
   
   data office(keep = address1 address2 city state zip phone officeid);
     set vlink.tblOffices;
     where ClientID = &vmine_client_id.;
   run;
   
   proc sort data = vlink.tblGroupOffices 
   	         out  = groupoffice(keep = officeid groupid) nodupkey;
     by officeid groupid;
   run;
   
   proc sort data = vlink.tblSpecialty(where = (S_Primary = 1)) 
   	         out  = spec(keep = s_specialtyid providerid rename = (s_specialtyid = specialtyid)) nodupkey;
     by providerid S_SpecialtyID;
   run;
   
   proc sort data = vlink.vAllClientsCIProgressDetailed(where=(ClientID = &vmine_client_id.)) 
   	         out  = pcategory(keep = providerid realcategory) nodupkey;
     by providerid;
   run;
   
   *SASDOC--------------------------------------------------------------------------
   | Get groupid for each provider
   +------------------------------------------------------------------------SASDOC*;   

   proc sort data = prov1 nodupkey; 
     by providerid;
   run;   
   
   proc sort data = provgroup; 
     by providerid;
   run;
   
   data prov2;
     merge prov1     (in=a) 
           provgroup (in=b);
     by providerid;
     if a;
   run;
   
   proc freq data = prov2;
     table providerid*groupid/list missing;
   run;
   
   *SASDOC--------------------------------------------------------------------------
   | Get office ID
   +------------------------------------------------------------------------SASDOC*;   
  
   proc sort data = office nodupkey;
     by officeid;
   run;
   
   data office2;
     merge office      (in=a) 
           groupoffice (in=b);
     by officeid;
     if a;
   run;
   
   *SASDOC--------------------------------------------------------------------------
   | Get group information
   +------------------------------------------------------------------------SASDOC*;   
   proc sort data = prov2;
     by groupid;
   run;
   
   proc sort data = groups nodupkey;
     by groupid;
   run;
   
   proc sort data = office2 ;
     by groupid;
   run;
   
   data prov3;
     merge prov2   (in=a) 
           groups  (in=b) 
           office2 (in=c);
     by groupid;
     if a and b;
   run;

   proc freq data = prov3;
     table providerid*groupid/list missing;
   run;

   
   *SASDOC--------------------------------------------------------------------------
   | Get specialty
   +------------------------------------------------------------------------SASDOC*;   
   proc sort data = prov3;
     by providerid;
   run;
   
   *SASDOC--------------------------------------------------------------------------
   | Get provider category (vmine,manual,pgf)
   +------------------------------------------------------------------------SASDOC*;   
   data prov4;
     merge prov3     (in=a) 
           spec      (in=b) 
           pcategory (in=c);
     by providerid;
     if a;
   run;
   
 
   *SASDOC--------------------------------------------------------------------------
   | Output dataset for CI providers and format provider name
   +------------------------------------------------------------------------SASDOC*;   

   data &dataout. (keep  = _pcpname firstName lastName  PCPName_TItle title sex npi ssn upin tin practice address1 address2 city state zip phone
   	                       cieffdt citermdt cip provspec specdesc groupid provtype P_NetworkStatus providerid
                   rename=( _pcpname = provname));
     length cip 3. npi $10. pcpname $42. ssn tin $9. cieffdt citermdt 8. upin $10. lastname $25. firstname $15. sex provtype $1. 
     practice $50.  provspec $2. specdesc $30.;	
     format cieffdt citermdt mmddyy10.;
     set prov4;
     where p_cipar = 1 and P_NetworkStatus in (5,9) and P_CITermDt = . ;       
     
	 pcpname = trim(left(P_LastName))||' '||trim(left(P_FirstName));
    
	  if index(pcpname,'M.D.') > 0 then do;
           firstName = substr(pcpname,index(pcpName,'M.D.')+4);
           lastName  = substr(pcpname,1,index(pcpName,'M.D.')+3);
           PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
	  end; 
      else if index(pcpname,'DPM') > 0 then do;
		   firstName = substr(pcpname,index(pcpName,'DPM')+3);
		   lastName  = substr(pcpname,1,index(pcpName,'DPM')+2);
		   PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
	  end; 
      else if index(pcpname,'D.P.M.') > 0 then do;
		   firstName = substr(pcpname,index(pcpName,'D.P.M.')+6);
		   lastName  = substr(pcpname,1,index(pcpName,'D.P.M.')+5);
		   PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
	  end; 
      else if index(pcpname,'Ph.D.') > 0 then do;
		   firstName = substr(pcpname,index(pcpName,'Ph.D.')+5);
		   lastName  = substr(pcpname,1,index(pcpName,'Ph.D.')+4);
		   PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
	  end; 
      else if index(pcpname,'D.O.') > 0 then do;
		   firstName = substr(pcpname,index(pcpName,'D.O.')+4);
		   lastName  = substr(pcpname,1,index(pcpName,'D.O.')+3);
		   PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
	  end; 
      else if index(pcpname,'PsyD.') > 0 then do;
		   firstName = substr(pcpname,index(pcpName,'PsyD.')+5);
		   lastName  = substr(pcpname,1,index(pcpName,'PsyD.')+4);
		   PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
	  end; 
      else if index(pcpname,'MD') > 0 then do;
           firstName = substr(pcpname,index(pcpName,'MD')+2);
           lastName  = substr(pcpname,1,index(pcpName,'MD')+1);
           PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
      end; 
      else if index(pcpname,'D.C.') > 0 then do;
           firstName = substr(pcpname,index(pcpName,'D.C.')+4);
           lastName  = substr(pcpname,1,index(pcpName,'D.C.')+3);
           PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
      end; 
      else do;
           firstName = trim(left(P_FirstName));
           lastName = trim(left(P_LastName));
           PCPName_TItle = strip(firstname)||' '||compress(lastname, " '.");
      end;

	  if index(lastname, "-") not in (0,.) then  _pcpname = trim(lastname)||", "||firstname;
	  else _pcpname = scan(lastname,1)||", "||firstname;
	  title = scan(lastname,2,",");

      cieffdt = datepart(P_CIEffDt);
      citermdt = datepart(P_CITermDt); 
      cip = P_CIPar; 
      npi = P_NPI; 
      upin = P_MedicareUPIN; 
      sex = P_Gender;
      practice = groupname;
      provspec = specialtyid;
      specdesc = put(specialtyid,$specd.);
      address1 = Address1;
      address2 = Address2;
      city = city;
      state = state;
      zip = zip;
   
      if realcategory in ('Manual','Targeted') then provtype = 'M'; 
      else if realcategory = 'vMine' then provtype = 'V'; 
      else if realcategory = 'PGF' then provtype = 'P'; else provtype = 'U';
   
      TIN   = substr(compress(groupftin,'(-) '),1,9);
      phone = compress(phone,'-');
      ssn   = compress(p_socialsecurity,'-');
   
      if specialtyid = '' then do;
   	     specdesc = 'Other';
   	     provspec = '99';
      end;

*	  if npi in ('1700878857','1720089923','1821066580','1386619518','1619942836') then provtype = 'M';
	  if npi in ('1629045778','1598872160') then provtype  = 'M';


   run;
   

   
   proc sort data = &dataout. ;
     by npi;
   run;
   
   proc freq data = &dataout.;
     table provtype*provname/list missing;
   run;
   
   proc print data =  &dataout.; 
   run;
   
   proc freq data = &dataout.;
     table npi*provname practice*tin cieffdt citermdt /list missing;
   run;
   
   proc print data =  &dataout.; 
     where citermdt ne . ;
   run;
    
   *SASDOC--------------------------------------------------------------------------
   | Manual provider datasets for formats
   +------------------------------------------------------------------------SASDOC*;   
    data Providers;
	  set vLink.tblProvider (keep=providerID p_npi clientID p_lastUpdate);
	  rename p_npi = pcpid providerID = PID;
	  where clientID=&vmine_client_id.;
	run;

	data Logins (drop=providerID);
	  set vportal.Portal_Users (keep=providerID Name lastModifiedDT);
	  rename Name = UID ;
	  PID = providerID*1;
	run;

	proc sort data = Providers nodupkey; 
      by PID; 
    run;

	proc sort data = Logins nodupkey; 
      by PID; 
    run;

	data ProviderLogins;
	  merge Providers (in=ina) 
            Logins (in=inb);
	  by PID;
	  if ina;
	  if ^inb then UID = ' ';
	run;

	proc sort data = ProviderLogins nodupkey; 
      by pcpid;
	  where pcpid ne ' ';
	run;
	
   *SASDOC--------------------------------------------------------------------------
   | Create NPI to UID Format
   +------------------------------------------------------------------------SASDOC*;   
	data provfmt.NPI2UID ;
	  set ProviderLogins (rename= (UID = label))  end = last; 
	  retain fmtname '$NPI2UID' type 'C';
	  start = put(pcpid,10.); 
	  output; 
	  if last then do; 
		Start = ' '; 
		Hlo = 'o'; 
		Label = ' '; 
	    output; 
	  end;
	run;

    
   *SASDOC--------------------------------------------------------------------------
   | Create NPI to PID Format
   +------------------------------------------------------------------------SASDOC*;   
	data provfmt.NPI2PID ;
	  set ProviderLogins (rename= (pid = label))  end = last; 
	  retain fmtname '$NPI2PID' type 'C'; 
	  start = put(pcpid,10.);
	  output; 
	  if last then do; 
		Start = ' '; 
		Hlo = 'o'; 
		Label = ' '; 
	    output; 
	  end;
	run;


%mend vlink_create_provider;
