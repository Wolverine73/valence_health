

%macro edw_linking_cleaner_cityzip(prefix);

&prefix.zip = compbl(compress(&prefix.zip,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;QWERTYUIOPLKJHGFDSAZXCVBNM"));
&prefix.zip = substr(&prefix.zip,1,5);
if put(&prefix.zip,$LatXwalk.) = "" and put(&prefix.zip,$ciozip.)='N' then &prefix.zip = "";

&prefix.city = upcase(&prefix.city);
&prefix.city = compbl(compress(&prefix.city,"`~!@#$%^&*()-_+=\|][{}',.<>?/:;1234567890"));

if put(substr(&prefix.zip,1,5)||substr(&prefix.city,1,25),$cityalias.) ne 'N' then &prefix.city=substr(put(substr(&prefix.zip,1,5)||substr(&prefix.city,1,25),$cityalias.),6);

%mend edw_linking_cleaner_cityzip;
