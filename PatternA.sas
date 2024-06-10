%macro patternA (list_condition=,list_provspec=,interval=);
if onset_condition = . then do;
	if care_generic in ("INPATIENT HOSPITAL","ED","HOSPITAL_VISIT") then do;
		onset_condition=svcdt;
		priorseen_condition=svcdt;
		lastseen_condition = svcdt;
	end;

	else if any_dx = 1 or any_proc = 1 then do;
		onset_condition = svcdt;
		priorseen_condition = svcdt;
		lastseen_condition = svcdt;
	end;
	

	else if care_generic in ("OFFICE_VISIT","LAB") then do;
		if priorseen_condition = . then do;
			if condition in (&list_condition) and provspec in (&list_provspec) then do;
				onset_condition = svcdt;
				priorseen_condition = svcdt;
				lastseen_condition= svcdt;
			end;
			else if condition in (&list_condition) and provspec not in (&list_provspec) then do;
				priorseen_condition = svcdt;
				lastseen_condition=svcdt;
			end;
		end;

		else if priorseen_condition ne . then do;
			if condition in (&list_condition) and provspec in (&list_provspec) then do;
				onset_condition = svcdt;
				priorseen_condition = svcdt;
				lastseen_condition= svcdt;
			end;

			else if (condition in (&list_condition) and provspec not in (&list_provspec)) and svcdt > priorseen_condition then do;
				if condition in (&list_condition ) and intck ('month',priorseen_condition,svcdt) <= &interval. then do;
					onset_condition = priorseen_condition;
					lastseen_condition = svcdt;
				end;

				else if condition in (&list_condition) and intck ('month',priorseen_condition,svcdt) > &interval. then do;
					priorseen_condition = lastseen_condition;
					lastseen_condition = svcdt;
				end;
			end;
		end; 
	end;
end;	

else if onset_condition ne . and svcdt ne . then do;
	if svcdt > lastseen_condition then do;
		priorseen_condition = lastseen_condition;
		lastseen_condition = svcdt;
	end;

	else if priorseen_condition < svcdt < lastseen_condition then do;
		priorseen_condition = svcdt;
	end;
end;	
if last.condition then output;

%mend patternA;
