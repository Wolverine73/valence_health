
%macro G1_to_G4;

    %macro qrystr;
       %local i;
       %global sumselect_str case_str;

        %let i=1;
        %let sumselect_str=%str();
        %let case_str=%str();
        %isnull(flagvars);

        %do %while (%qscan(&flagvars, &i, %str( )) ne %str() and ^&flagvars_isnull);
            %let word=%str(,)sum(%qscan(&flagvars, &i, %str( ))) as %qscan(&flagvars, &i, %str( ));
            %let caseword=%str(,case when ) %qscan(&flagvars, &i, %str( )) %str(ge 1 THEN 1 ELSE 0 END AS ) %qscan(&flagvars, &i, %str( ));
            %put wordname: &word ;
            %put caseword: &caseword ;

            %isnull(sumselect_str);
            %isnull(word);

            %if ^&word_isnull and &sumselect_str_isnull %then %let sumselect_str = &word;
            %else %if ^&word_isnull %then %let sumselect_str = &sumselect_str &word;

            %put sumselect_str: &sumselect_str;

            %isnull(case_str);
            %isnull(caseword);

            %if ^&caseword_isnull and &case_str_isnull %then %let case_str = &caseword;
            %else %if ^&caseword_isnull %then %let case_str = &case_str &caseword;

            %put case_str: &case_str;

            %let i=%eval(&i+1);

        %end;
    %mend qrystr;
    %qrystr;

    proc sql;
      create table g4 as
      ( select memberid &sumselect_str.
        from
      (
        select x.memberid
               &case_str.
        from
      (
        select memberid, svcdt &sumselect_str.
        from g1 (keep= memberid svcdt &flagvars.)
        group by memberid, svcdt
      ) x

      ) y
      group by y.memberid
      ) ;
    quit;


%mend G1_to_G4;
