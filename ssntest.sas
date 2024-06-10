%macro ssntest;
ssnlength = length(cats(ssn));
ssn = upcase(ssn);
if ssn in ('000000000','111111111','222222222','333333333','444444444','555555555','666666666',
			'777777777','888888888','999999999','123456789','missing','MISSING','Missing','','0')
			or index(ssn,"00000") ge 1 or index(ssn,"11111") ge 1 or index(ssn,"22222") ge 1 or 
			index(ssn,"33333") ge 1 or index(ssn,"44444") ge 1 or index(ssn,"55555") ge 1 or 
			index(ssn,"66666") ge 1 or index(ssn,"77777") ge 1 or index(ssn,"88888") ge 1 or 
			index(ssn,"99999") ge 1 or ssnlength ne 9 or 
			indexc(ssn,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;QWERTYUIOPLKJHGFDSAZXCVBNM") ge 1 or
			substr(ssn,1,1) in ('8','9') or
			substr(ssn,1,3) in ('000','666') or
			substr(ssn,4,2)='00' or
			substr(ssn,6,4)='0000'
			then ssnTYPE = 'INVALID'; 
			else ssnTYPE = 'VALID'; 
drop ssnlength;
%mend ssntest;