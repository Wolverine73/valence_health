
%macro luhn_npi_check(npival);

length provid_luhn $15. luhnsum_mod10 $6;
provid_luhn = "80840" || &npival.;

luhn_num1 = substr(provid_luhn,1,1)*1;
luhn_num2 = substr(provid_luhn,2,1)*1*2;
luhn_num3 = substr(provid_luhn,3,1)*1;
luhn_num4 = substr(provid_luhn,4,1)*1*2;
luhn_num5 = substr(provid_luhn,5,1)*1;
luhn_num6 = substr(provid_luhn,6,1)*1*2;
luhn_num7 = substr(provid_luhn,7,1)*1;
luhn_num8 = substr(provid_luhn,8,1)*1*2;
luhn_num9 = substr(provid_luhn,9,1)*1;
luhn_num10 = substr(provid_luhn,10,1)*1*2;
luhn_num11 = substr(provid_luhn,11,1)*1;
luhn_num12 = substr(provid_luhn,12,1)*1*2;
luhn_num13 = substr(provid_luhn,13,1)*1;
luhn_num14 = substr(provid_luhn,14,1)*1*2;
luhn_num15 = substr(provid_luhn,15,1)*1;

luhn_char2 = put(luhn_num2,z2.);
luhn_char4 = put(luhn_num4,z2.);
luhn_char6 = put(luhn_num6,z2.);
luhn_char8 = put(luhn_num8,z2.);
luhn_char10 = put(luhn_num10,z2.);
luhn_char12 = put(luhn_num12,z2.);
luhn_char14 = put(luhn_num14,z2.);

luhn_num2_1 = substr(luhn_char2,1,1)*1;
luhn_num2_2 = substr(luhn_char2,2,1)*1;
luhn_num4_1 = substr(luhn_char4,1,1)*1;
luhn_num4_2 = substr(luhn_char4,2,1)*1;
luhn_num6_1 = substr(luhn_char6,1,1)*1;
luhn_num6_2 = substr(luhn_char6,2,1)*1;
luhn_num8_1 = substr(luhn_char8,1,1)*1;
luhn_num8_2 = substr(luhn_char8,2,1)*1;
luhn_num10_1 = substr(luhn_char10,1,1)*1;
luhn_num10_2 = substr(luhn_char10,2,1)*1;
luhn_num12_1 = substr(luhn_char12,1,1)*1;
luhn_num12_2 = substr(luhn_char12,2,1)*1;
luhn_num14_1 = substr(luhn_char14,1,1)*1;
luhn_num14_2 = substr(luhn_char14,2,1)*1;

luhnsum_mod10 = sum(luhn_num1,luhn_num3,luhn_num5,luhn_num7,luhn_num9,luhn_num11,luhn_num13,luhn_num15,
				luhn_num2_1,luhn_num2_2,luhn_num4_1,luhn_num4_2,luhn_num6_1,luhn_num6_2,luhn_num8_1,
				luhn_num8_2,luhn_num10_1,luhn_num10_2,luhn_num12_1,luhn_num12_2,luhn_num14_1,luhn_num14_2) / 10;

if index(luhnsum_mod10,".") lt 1 and length(cats(provid_luhn)) = 15 and
indexc(provid_luhn,"QWERTYUIOPASDFGHJKLZXCVBNM") lt 1 then npi_valid = 1;
else npi_valid = 0;

drop 	provid_luhn luhnsum_mod10 luhn_num1-luhn_num15 luhn_char2 luhn_char4 luhn_char6 luhn_char8 luhn_char10 luhn_char12 luhn_char14
		luhn_num2_1 luhn_num2_2 luhn_num4_1 luhn_num4_2 luhn_num6_1 luhn_num6_2 luhn_num8_1 luhn_num8_2 luhn_num10_1 luhn_num10_2
		luhn_num12_1 luhn_num12_2 luhn_num14_1 luhn_num14_2;

%mend;

