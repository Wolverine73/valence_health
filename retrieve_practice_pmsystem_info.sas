%macro retrieve_practice_pmsystem_information;

	proc sql;
	create table vmine_pmsystem_information as
	select 
		a.FilePath as FilePath,
		a.dateentered,
		b.practiceid,  
		b.name as practicename, 
		c.clientid, 
		c.clientname,   
		d.versionid as versionid,
		e.name as systemname, 
		e.systemid
	from vmine.ExtractedFileList a
		left join vmine.practice  b on a.practiceid=b.practiceid
		left join vmine.client    c on b.clientid=c.clientid 
		left join vmine.version   d on a.versionid=d.versionid
		left join vmine.system    e on d.systemid=e.systemid
	where b.Termed = 0 and e.systemid = 13
	and index(lowcase(a.filepath), 'old') = 0 
	order by b.practiceid;
	quit;

	proc sort data = vmine_pmsystem_information;
	by practiceid descending dateentered;
	run;

	proc sort data = vmine_pmsystem_information
	out = vmine_practice_information nodupkey;
	by practiceid ;
	run;

	quit;
%mend;
