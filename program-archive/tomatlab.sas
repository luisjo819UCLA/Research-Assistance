*tomatlab -- code=tomatlab-rev;

*reads stored iabworkfile.sas7bdat (in STORE directory) from newbuild.sas;

*outputs 4 text files defined in filenames tom1-tom4;



***** must define STORE library and locations for tom1-tom4;




options ls=130 nocenter nofmterr;

libname STORE '/tmp/';

filename tom1 '/tmp/interval1e.txt' ;
filename tom2 '/tmp/interval2e.txt' ;
filename tom3 '/tmp/interval3e.txt' ;
filename tom4 '/tmp/interval4e.txt' ;





** macro to select p-y obs in interval;

** min length of interval=4, max length=10;

**********************************************;



%macro select(interval, startyr, endyr);


data work.zero;
set STORE.iabworkfile
   (keep=logwage2 logwage id firmid year trainee  edgroup birthyr
     where=(trainee=0 and (&startyr. <=year<=&endyr.) )    );

length id firmid 8;

matchid=firmid || id ;

if logwage2=. then logwage2=logwage+3.719;


drop trainee logwage ;
run;

proc means data=work.zero;
var logwage2;
run;



*mean firm size;

proc sql;
create table work.one as
  select *,
  count(distinct year) as firm_nyrs,
  count(birthyr)/ calculated firm_nyrs as emp
  from work.zero
  group by firmid;

proc datasets lib=work;
delete zero;
quit;


**count #jobs per person;


proc sql;
create table work.two as
   select *,
   count(distinct firmid) as njobs,
   sum(edgroup=0) as ne0,
   sum(edgroup=1) as ne1,
   sum(edgroup=2) as ne2,
   sum(edgroup=3) as ne3,
   sum(edgroup=4) as ne4
   from work.one
   group by id 
   order by id, year;
quit;

proc datasets lib=work;
delete one;
quit;

proc freq data=work.two;
tables njobs / missing;
run;


data work.two;
set work.two;
if njobs>=2;

if ne0=max(ne0, ne1, ne2, ne3, ne4) then medgroup=0;
else if ne1=max(ne0, ne1, ne2, ne3, ne4) then medgroup=1;
else if ne2=max(ne0, ne1, ne2, ne3, ne4) then medgroup=2;
else if ne3=max(ne0, ne1, ne2, ne3, ne4) then medgroup=3;
else medgroup=4;
run;

proc freq;
where (year=&startyr.);
table edgroup*medgroup / missing;

proc freq;
where (year=&endyr.);
table edgroup*medgroup / missing;



data work.three;
set work.two;
by id year;
lagid=lag(id);
lagfirmid=lag(firmid);
if first.id=1 then firstyr=1;
else firstyr=0;

if firstyr=1 then lagfirmid=-9;
run;

proc datasets lib=work;
delete two;
quit;


data work.three;
set work.three;
file tom&interval. ;
put id 10. +2 year 4. +2 firmid 10. +2 lagfirmid 10. +2 
    logwage2 9.7 +2 birthyr 4. +2 medgroup 2. +2 emp 10.2 ; 
run;

proc means data=work.three;
var id firmid year logwage2 birthyr medgroup emp;
run;


%mend select;

%select(1, 1985, 1991);
%select(2, 1990, 1996);
%select(3, 1996, 2002);
%select(4, 2002, 2009);

