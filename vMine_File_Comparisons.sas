%macro vmine_file_compare (client_id=, table_name=, group=);

	/*List of XML files loaded into CIMaster*/
	proc sql;
		connect to oledb(init_string=&emine. );
		create table filename_sql as select * from connection to oledb
		(	
			select distinct
				a.Filename
			from [dbo].[KTBL_Process] as a inner join
				(
					select distinct 
					kProcessID
					from [dbo].[&table_name.]
					where kPracticeID =&group.
				) as b on a.kProcessID = b.kProcessID
			order by a.Filename
		);
	quit;

	data filename_sql (keep=filename_sql);
	set filename_sql;
	length filename_sql $50.;
	filename_sql = substr(filename,1,index(filename,'.') - 1);
	run;


	/*List of XML files loaded into IDS*/
	proc sql;
		connect to oledb(init_string=&ids.);
		create table filename_ids_dedupped as select * from connection to oledb
		(
			SELECT 
				TransmissionID,
				DataSourceID,
				FileName,
				FullHistory
			FROM
				(
				SELECT 
					TransmissionID,
					DataSourceID,
					FileName,
					FullHistory,
					ROW_NUMBER() OVER (PARTITION BY FileName
									   ORDER BY FileName desc, TransmissionID desc) AS latestfileorder
				FROM [IntegrationDataSource].[dbo].[Transmission]
				WHERE DataSourceID = &group.
				) AS A
			WHERE A.latestfileorder = 1
			ORDER BY FileName desc
		);
	quit;

	proc sql;
		connect to oledb(init_string=&ids.);
		create table latestFHfile as select * from connection to oledb
		(
			SELECT
				TransmissionID
			FROM
				(
				SELECT
					TransmissionID,
					DataSourceID,
					FileName,
					FullHistory,
					ROW_NUMBER() OVER (PARTITION BY FullHistory
									   ORDER BY FullHistory, TransmissionID desc) as latestFHorder
				FROM [IntegrationDataSource].[dbo].[Transmission]
				WHERE DataSourceID = &group. and FullHistory = 1
				) AS B
			WHERE B.latestFHorder = 1
		)
		;
	quit;

	proc sql noprint;
		select * into: latestFHfile
		from latestfhfile
		;
	quit;

	%put NOTE: Latest full history file TransmissionID - &latestFHfile.;

	proc sql;
		create table filename_ids as 
			select 
				substr(FileName,1,index(FileName,'.') - 1) as filename_ids length=50
			from filename_ids_dedupped
			where TransmissionID >= &latestFHfile.
			order by FileName
		;
	quit;

	data filename_&group.;
	merge filename_ids (in=a rename=filename_ids=filename)
		  filename_sql (in=b rename=filename_sql=filename);
	by filename;
	length ids sql difference 3.;
	if a and b then output filename_&group.;
	else if a and not b then do;
		ids = 1;
		difference = 1;
		output filename_&group.;
	end;
	else if b and not a then do;
		ids = 1;
		difference = 1;
		output filename_&group.;
	end;
	run;

	proc print data=filename_&group.;
	title "Comparison - vMine files in IDS and SQLCI.CIMaster";
	run;

%mend vmine_file_compare;
