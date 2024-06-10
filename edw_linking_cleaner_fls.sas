%macro edw_linking_cleaner_fls(prefix); 

if &prefix.sex not in ("M","F") then &prefix.sex = put(cats(&prefix.fname),$fnameGender.);

&prefix.lname = upcase(compbl(compress(&prefix.lname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890")));
&prefix.lname=tranwrd(&prefix.lname,'DO NOT USE','');
if &prefix.lname ne '' then do;
	if scan(&prefix.lname,1)||scan(&prefix.lname,2) in ('DELA') then &prefix.lname=scan(&prefix.lname,1)||scan(&prefix.lname,2)||scan(&prefix.lname,3);
	else if scan(&prefix.lname,1) in ('VAN','VON','MC','ST','BIN','BINTI','O','AL','BEN','D','DE','DEL','EL','L','LA','LE','DI','ABU','ABDULLAH',
									  'CASTILLO','CASTRO','CHAVEZ','CRUZ','DIAZ','DOMINGUEZ','ENRIQUEZ','ESPINOZA','ESTRADA',
									  'FERNANDEZ','FLORES','GARCIA','GOMEZ','GONZALES','GUTIERREZ','GUZMAN','HERNANDEZ','LOPEZ','MARQUEZ','MARTINEZ','ORTIZ','PEREZ','RAMIREZ','RAMOS',
									  'RIVERA','RODRIGUEZ','ROJAS','ROMERO','RUIZ','SAN','SANCHEZ','TORRES','TRUJILLO','VEGA','VELA','VERA','VIGIL','VILLA') 
		then &prefix.lname=scan(&prefix.lname,1)||scan(&prefix.lname,2);
	else &prefix.lname=scan(&prefix.lname,1);
end;
if cats(&prefix.lname) in ("BOY","GIRL","TEST","PATIENT","REUSE") then &prefix.lname = "";
if length(&prefix.lname) = 1 then &prefix.lname = "";

&prefix.fname = upcase(compbl(compress(&prefix.fname,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890")));
if scan(&prefix.fname,1) in ("BABY","TEST","PATIENT","REUSE") then &prefix.fname = "";
/* If Asian last name (mostly Korean) then retain and compress 2-word first names */
/* !!!! Same list exist below in compare macro. If you update this, update below too !!!! */
if &prefix.lname in ("AHN","BAE","BAEK","BAN","BANG","BEA","BYUN",
					 "CHA","CHAE","CHAN","CHANG","CHEN","CHO","CHOE","CHOI","CHON","CHONG","CHOW","CHUN","CHUNG","DO","EAP","EUM",
					 "HA","HAHN","HAN","HONG","HUH","HWANG","IMM","JANG","JEON","JEONG","JI","JIN","JO","JOO","JU","JUN","JUNG",
					 "KANG","KAO","KHAN","KIM","KO","KOH","KONG","KOO","KU","KUK","KWAK","KWAN","KWON","KYE",
					 "LAM","LEE","LI","LIM","LIU","MA","MIN","MOON","MYONG","OH","PAIK","PAK","PARK","PHAN","RHEE","RYOO","RYU",
					 "SEO","SHIM","SHIN","SIM","SOHN","SON","SONG","SUH","SUK","SUL","TSAO","UM",
					 "WANG","WHANG","WON","WOO","YANG","YI","YIM","YOO","YOON","YU","YUM","YUN")
	then &prefix.fname=compress(&prefix.fname);
else if &prefix.fname ne ''
	then &prefix.fname = scan(&prefix.fname,1);
%mend edw_linking_cleaner_fls;
