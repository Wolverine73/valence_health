%macro outlier_comments_setup;

      %if &period. = current %then %do;
            %outlier_comments(client=&client., folder=out_det); /*libname that points to the portal datasets on m:*/
      %end; 

%mend outlier_comments_setup;