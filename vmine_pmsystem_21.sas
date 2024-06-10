
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_21
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Perform cleansing rules on the NEXTECH pm system practice data   
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
| 03SEP2010 - Valence Health  - Clinical Integration  1.0.01
|             Original
|
| 29JUL2011 - Valence Health - Clinical Integration 2.0.00
|			1. Migrating from text files to SQL
|      
| 20JUN2012 - Winnie Lee - Release 1.3 H02 & L02
|			1. Commented out converting claimnum and linenum into character since
|				it's done in the sql store proc now
|			2. Removed dropping of casenum and visitnum since it's not passed from
|				sql store proc now because they're both null values 
+-----------------------------------------------------------------------HEADER*/

%macro vmine_pmsystem_21;


	%*SASDOC--------------------------------------------------------------------------
	| Perform cleaning and edits to the practice data
	------------------------------------------------------------------------SASDOC*;
	data practice_&do_practice_id. (rename=(/*claimnum2=claimnum linenum2=linenum*/ mname2=mname));
	  length mname2 $1.;
	  format svcdt createdt moddt dob mmddyy10. submit dollar13.2 system $30. filename $50.;
	  set practice_&do_practice_id. ;		  	

		%*SASDOC--------------------------------------------------------------------------
		| Reformat dates and dollars and other                        
		------------------------------------------------------------------------SASDOC*;
		svcdt=datepart(svcdt2);
		createdt=datepart(createdt2);
		moddt=datepart(moddt2);
		dob=datepart(dob2);
		submit=submit2;
		system="&system.";
		if mname='.' then mname="";
		mname2=mname;
		if pos='.' then pos="";
		filename=put(MaxProcessID, kprocessid.);		

		%*SASDOC--------------------------------------------------------------------------
		| Mod                                    
		------------------------------------------------------------------------SASDOC*;
		mod1 = compress(cats(mod1),"'""+""`""[""]");
		mod2 = compress(cats(mod2),"'""+""`""[""]");

		%*SASDOC--------------------------------------------------------------------------
		| Gender                                    
		------------------------------------------------------------------------SASDOC*;

		if sex = '1' then sex = 'M';
		else if sex = '2' then sex = 'F';
		else sex = 'U';
		if sex not in ('F','M') then sex = 'U';

		%*SASDOC--------------------------------------------------------------------------
		| Member ID                                 
		------------------------------------------------------------------------SASDOC*;
		if memberid in ('','0','00','000','0000','00000','000000','0000000','00000000','000000000') then memberid='';
		
		%*SASDOC--------------------------------------------------------------------------
		| Client                          
		------------------------------------------------------------------------SASDOC*;
/*		claim_number=claimnum;*/
/*        line_number=linenum;*/
/*		claimnum2=left(put(claimnum,36.));*/
/*        linenum2=left(put(linenum,36.));*/

		client_key=&client_id. ;
		practice_id=&practice_id.; 
		source='P';


		drop /*casenum visitnum*/ svcdt2 createdt2 moddt2 dob2 submit2 /*claimnum linenum*/ mname; 
	run;

    
%mend vmine_pmsystem_21;
