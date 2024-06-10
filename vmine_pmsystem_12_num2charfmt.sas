
/*HEADER------------------------------------------------------------------------
|
| program:  vmine_pmsystem_12_num2charfmt
|
| location: M:\CI\programs\StandardMacros
|
| purpose:  Creates format to convert numbers to characters for gender codes and middle initial codes within PracticePartner   
|
| logic:                   
|
| input:         
|                        
| output:    
|
| usage:    
|
|
+--------------------------------------------------------------------------------
| history:  
|
| 14SEP2010 - Winnie Lee  - Clinical Integration  1.0.01
|             Original
|             
+-----------------------------------------------------------------------HEADER*/

data num2charfmt;
length fmtname $8. type $1. start $2. label $1.;
input fmtname $ type $ start $ label $;
datalines;
num2char C 32 *
num2char C 65 A
num2char C 66 B
num2char C 67 C
num2char C 68 D
num2char C 69 E
num2char C 70 F
num2char C 71 G
num2char C 72 H
num2char C 73 I
num2char C 74 J
num2char C 75 K
num2char C 76 L
num2char C 77 M
num2char C 78 N
num2char C 79 O
num2char C 80 P
num2char C 81 Q
num2char C 82 R
num2char C 83 S
num2char C 84 T
num2char C 85 U
num2char C 86 V
num2char C 87 W
num2char C 88 X
num2char C 89 Y
num2char C 90 Z
;
run;

data num2charfmt;
set num2charfmt;
if start = '32' then label = '';
run;

proc sort data=num2charfmt nodupkey;
by start;
run;

proc format cntlin=num2charfmt; run;

proc print data=num2charfmt; 
title "PracticePartner";
title2 "Number to Character Format";
title3 "Applied to gender and middle initials";
run;
