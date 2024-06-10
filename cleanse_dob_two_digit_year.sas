/*HEADER------------------------------------------------------------------------
|
| program:  cleanse_dob_two_digit_year.sas
|
| location: M:\ci\programs\EDW\
|
| purpose:  determine the proper value for 2 digit years
|           sas option has yearcutoff = 1920
|
| input:    			
|
| output:   
|
+--------------------------------------------------------------------------------
| HISTORY:  
|	
| 01JUN2012 - B Stropich - Clinical Integration 1.0.03 Release 1.3
|             Initiated
|
+-----------------------------------------------------------------------HEADER*/

%macro cleanse_dob_two_digit_year;

	if dob >  today() then do; 
		d_year=day(dob);
		m_year=month(dob);
		y_year=year(dob);
			if y_year >= year(today()) and y_year < 2040 then do;
			  y_year=y_year-100;
			  dob=mdy(m_year,d_year,y_year);
			end;
			else do;
			  dob=.;
			end;
		drop d_year m_year y_year;
	end;

%mend cleanse_dob_two_digit_year;