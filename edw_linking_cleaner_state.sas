

%macro edw_linking_cleaner_state(prefix);

if &prefix.state not in 
("AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","GU","HI","ID","IL","IN","IA","KS","KY","LA",
"ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK",
"OR","PA","PR","RI","SC","SD","TN","TX","UT","VT","VA","VI","WA","WV","WI","WY") then &prefix.state = "";

%mend edw_linking_cleaner_state;
