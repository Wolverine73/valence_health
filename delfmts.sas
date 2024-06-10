/*HEADER------------------------------------------------------------------------
|
| program:  delfmts.sas
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Macro to delete Condition and Care Elements Formats Datasets
			in v3.0 Rollout.                     
|
+--------------------------------------------------------------------------------
| history:  
| 21DEC2011 - LS original
+-----------------------------------------------------------------------HEADER*/
%macro delfmts;
	proc sql noprint;
	select distinct memname into: _deltblst separated by " " from dictionary.members
	where index(memname,"_")=1 and libname="WORK";
	quit;

	proc datasets library = work nolist;
	delete &_deltblst;
	quit;
%mend delfmts;
