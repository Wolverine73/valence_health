/*HEADER------------------------------------------------------------------------
|
| PROGRAM:  G1_to_G4
|
| LOCATION: M:\CI\programs\StandardMacros
|
| PURPOSE:  Sums g1 through g4 datasets to create records at a memberid level
|
| INPUT:    G1 dataset
| OUTPUT:   G4 dataset
+--------------------------------------------------------------------------------
| HISTORY:  
| 10JAN2012 - EM Resaved to original code
|
+------------------------------------------------------------------------HEADER*/
%macro G1_to_G4;

	proc sort data = g1;
	by memberid svcdt;
	run;

	proc summary data=g1 nway missing;
	by memberid svcdt ;
	var &flagvars. ;
	output out=g2 (drop=_type_ _freq_)   sum=;
	run;

	data g3;
	set g2;
	array outvars{*} &flagvars.;
		do loop = 1 to dim(outvars);
		if outvars{loop} ge 1 then  outvars{loop} = 1;
		end;
		drop loop;
	run;

	proc summary data=g3 nway missing;
	by memberid ;
	var &flagvars. ;
	output out=g4 (drop = _type_ _freq_)   sum=;
	run;

%mend G1_to_G4;
