
%macro fallout_logic;
	%if execute_fallout = 1 and &period = current %then %do;

		proc sql;
		create table temp.%sysfunc(strip(&prefix.))_falloutcount as 

			select "%sysfunc(strip(&prefix.))_falloutcount_g0" as fallout_location,
			count(distinct memberid) as member_count	
			from &prefix._g0

		union

			select "%sysfunc(strip(&prefix.))_falloutcount_g1" as fallout_location,
			count(distinct memberid) as member_count	
			from g1

		union

			select "%sysfunc(strip(&prefix.))_falloutcount_g5a" as fallout_location,
			count(distinct memberid) as member_count	
			from g5a

		union

			select "%sysfunc(strip(&prefix.))_falloutcount_g5" as fallout_location,
			count(distinct memberid) as member_count	
			from g5;
		quit;

		proc sql;
		create table temp.%sysfunc(strip(&prefix.))_falloutmembers as select
			distinct memberid,
			1 as g0_mem,
			case when memberid in (select distinct memberid from g1) 
			then 1 else 0 end as g1_mem,
			case when memberid in (select distinct memberid from g5a)
			then 1 else 0 end as g5a_mem,
			case when memberid in (select distinct memberid from g5)
			then 1 else 0 end as g5_mem
			from &prefix._g0;
		quit;
	%end;
%mend fallout_logic;
