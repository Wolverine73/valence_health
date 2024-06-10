
if onset = . then do;
	onset_condition=svcdt;
	priorseen_condition=svcdt;
	lastseen_condition = svcdt;
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
