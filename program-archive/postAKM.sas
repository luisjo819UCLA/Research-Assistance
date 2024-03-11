*postAKM -- based on postAKM2r;

 
*inputs 4 text files created by matlab in from1-from4;
*       4 coefficient files created by matlab in bhat1-bhat4 ;
*       iabworkfile (created by newbuild) in STORE directory;


*creates SAS format file  to SAVE library;





***  SAS LIBRARIES;
***  set STORE to location of iabworkfile;
***  set SAVE  to location of saved postakm (sas format) file;


libname STORE '/tmp/';
libname SAVE  '/tmp/effects';



*** TEXT FILES in and out;
*** from1-from4   ==  text files from matlab (read in);
*** bhat1-bhat4   ==  coefficient text files from matlab (read in);
*** liab          ==  saved text file to match to LIAB (for Joerg);


filename from1 '~/matlab/AKMeffs1e.txt' ;
filename from2 '~/matlab/AKMeffs2e.txt' ;
filename from3 '~/matlab/AKMeffs3e.txt' ;
filename from4 '~/matlab/AKMeffs4e.txt' ;

filename bhat1 '~/matlab/bhat1e.txt' ;
filename bhat2 '~/matlab/bhat2e.txt' ;
filename bhat3 '~/matlab/bhat3e.txt' ;
filename bhat4 '~/matlab/bhat4e.txt' ;



options ls=130 nocenter nofmterr;


title1 'post-AKM p-y data with person and firm effects' ;


************************************************************;
** macro to read output files from matlab
   only worker-year obs at jobs in connected set for movers;
************************************************************;


%macro input1(interval);

data work.i&interval. ;

length id 8 firmid 8;
infile from&interval. dlm='09'x lrecl=200;
input  id firmid year peff&interval. feff&interval. xb&interval. 
       r&interval.  ;
run;

proc freq data=work.i&interval.;
title2 'person and firm effects returned from matlab in this interval';
tables year;

proc corr data=work.i&interval.;
var peff&interval. feff&interval. xb&interval. r&interval. ;
run;



*extract firm effects;
proc sql;
create table work.f&interval. as
 select firmid,
 min(feff&interval.) as feff&interval.
 from work.i&interval.
 group by firmid
 order by firmid;
quit;

*extract peffs;

proc sql;
create table work.p&interval. as
 select id,
 min(peff&interval.) as peff&interval.
 from work.i&interval.
 group by id
 order by id;
quit;



*get xb;

proc sql;
create table work.xb&interval. as
 select id, year, xb&interval.
 from work.i&interval.
 order by id, year;
quit;

proc datasets lib=work;
delete i&interval. ;


*finally read in bhat from coefficient files ;

data work.bhat&interval. ;
infile bhat&interval. dlm='09'x lrecl=100;
input edgroup age year bhat&interval. ;
run;

proc freq data=work.bhat&interval. ; 
title2 'input of b-hats'; 
tables age edgroup year; 
run; 

proc means data=work.bhat&interval. ; 
run;



%mend input1;
**************************************************************;


%input1(1);
%input1(2);
%input1(3);
%input1(4);


*combine firm effects;

data work.allf;
merge work.f1 work.f2 work.f3 work.f4;
by firmid;
run;

proc datasets lib=work;
delete f1 f2 f3 f4;
quit;

proc corr data=work.allf;
title2 'merged firm effects - one per firm' ;
var feff1-feff4;
run;




*combine worker effects;

data work.allp;
merge work.p1 work.p2 work.p3 work.p4;
by id;
run;

proc datasets lib=work;
delete p1 p2 p3 p4;
run;


proc corr data=work.allp;
title2 'merged person effects - one per person';
var peff1-peff4;
run;



*combine xb;

data work.allxb;
merge work.xb1 work.xb2 work.xb3 work.xb4;
by id year;
run;

proc datasets lib=work;
delete xb1 xb2 xb3 xb4;
run;


proc corr data=work.allxb;
title2 'merged xb - one per person/year';
var xb1-xb4;
run;





*backbone file;

data work.zero;
set STORE.iabworkfile
   (keep=logwage2 logwage id firmid year trainee exp schooling age birthyr
         edgroup beruf ao_bula w73 w03 firm_firstyr firm_lastyr firm_meanemp
         where=(trainee=0) ) ;

length id 8 firmid 8;
if logwage2=. then logwage2=logwage+3.719;  

drop trainee logwage ;
run;


proc sort data=work.zero;
by id year;
run;


*assign rid to each person for sampling;

data work.two;
set work.zero (keep=id year);
by id year;
if first.id;
rid = ranuni(3711);
drop year;
run;


proc means data=work.two;
title2 'check of assignment of rid to backbone file - one obs per person';
var id rid ;
run;







**********************************************;

** macro to combine peff, feff etc for obs in each interval;
** INTERVALS HAVE TO MATCH THOSE SPECIFIED IN tomatlab.sas;

**********************************************;

%macro select(interval, startyr, endyr);

data work.one;
set work.zero (keep=id firmid year schooling logwage2 age edgroup beruf w73 w03 ao_bula
         where=( &startyr. <= year <= &endyr. ) );
       

*define industry ;

interv=%eval(&interval.);


*code assigns sic = w73 for intervals 1-2-3, w03/100 in interval 4;
*note that in 2002, w03 is missing - so sic is missing for all 2002 obs in interval 4;

 
if interv in (1,2,3) then sic=w73; 
else sic = floor(w03/100);

*assign all missing to 0;
if sic<=0 then sic=0;
drop w73 w03;

if beruf in (., .n, .z) then beruf=0;

run;





*get modal education group, min/max occupation code,  and #jobs;

proc sql;
create table work.three as
  select id, firmid, year, schooling, logwage2, age,
  count(distinct firmid) as njobs&interval. ,
  mean(logwage2) as meanlogwage&interval. ,
  mean(schooling) as mschooling&interval. ,
  min(beruf) as minberuf,
  max(beruf) as maxberuf,
  sum(edgroup=0) as ne0_&interval. ,
  sum(edgroup=1) as ne1_&interval. ,
  sum(edgroup=2) as ne2_&interval. ,
  sum(edgroup=3) as ne3_&interval. ,
  sum(edgroup=4) as ne4_&interval. 
  from work.one
  group by id
  order by id, year;
quit;



*get min/max sic codes and mean total employment at firm in interval using emp variable;

proc sql;
create table work.emp as
  select firmid,
  min(sic) as minsic,
  max(sic) as maxsic,
  min(ao_bula) as region&interval. ,
  count(age)/count(distinct year) as meanemp&interval. 
  from work.one
  group by firmid;
quit;



proc datasets lib=work;
delete one;
quit;



*fill in modal education group etc;

data work.three;
set work.three ;

*assign modal schooling class;
*ties assigned down as in tomatlab;

if ne0_&interval. =max(ne0_&interval. , ne1_&interval. , ne2_&interval. , ne3_&interval. , ne4_&interval. ) then medgroup&interval.=0;
else if ne1_&interval. =max(ne0_&interval. , ne1_&interval. , ne2_&interval. , ne3_&interval. , ne4_&interval. ) then medgroup&interval.=1;
else if ne2_&interval. =max(ne0_&interval. , ne1_&interval. , ne2_&interval. , ne3_&interval. , ne4_&interval. ) then medgroup&interval.=2;
else if ne3_&interval. =max(ne0_&interval. , ne1_&interval. , ne2_&interval. , ne3_&interval. , ne4_&interval. ) then medgroup&interval.=3;
else medgroup&interval.=4;


change_occ=(minberuf ne maxberuf);
occ&interval. =maxberuf;

drop ne0_&interval. ne1_&interval. ne2_&interval. ne3_&interval. ne4_&interval. minberuf maxberuf;

run;




proc means data=work.three;
title2 'check of incidence of change in occupation (=beruf) in interval';
var change_occ ;
run;


data work.emp;
set work.emp;
change_sic=(minsic ne maxsic);
cchange_sic=change_sic;
if minsic=0 then cchange_sic=. ;

sic&interval. = maxsic;

keep firmid change_sic cchange_sic sic&interval. meanemp&interval. region&interval. ;



proc means data=work.emp;
title2 'check of incidence of change in sic in interval';
var change_sic cchange_sic;
run;




*create merged p-y data set;
*note that occ/mschooling/medgroup/njobs/peff cannot change in interval for given person;
*          feff/meanemp/sic/region  are all assigned to current firm and can change;



proc sql;
create table work.group&interval as
  select a.id,
         a.year,
         a.occ&interval. ,
         a.mschooling&interval. ,
         a.njobs&interval. ,
         a.meanlogwage&interval. ,
         a.medgroup&interval.,
         b.peff&interval. ,
         c.feff&interval. ,
         d.meanemp&interval. ,
         d.sic&interval. ,
         d.region&interval. ,
         e.xb&interval. ,
         f.bhat&interval.,
         g.rid

  from work.three as a 

         left join work.allp as b on (a.id=b.id)
         left join work.allf as c on (a.firmid=c.firmid)
         left join work.emp  as d on (a.firmid=d.firmid)
         left join work.allxb as e on (a.id=e.id and a.year=e.year)
         left join work.bhat&interval. as f on (a.age=f.age and a.medgroup&interval.=f.edgroup and a.year=f.year) 
         left join work.two as g on (a.id=g.id) ;

quit;

proc datasets lib=work;
delete three emp;
quit;


proc means data=work.group&interval. ;
where (xb&interval. ne .);
title2 'redundancy check of direct merge of xb versus assignment via bhat ';
var  xb&interval. bhat&interval. ;
run;

proc means data=work.group&interval. ;
title2 'check of creation of mschooling and peff/feff/xb for current interval';
var meanlogwage&interval. njobs&interval.  mschooling&interval. 
    peff&interval.  feff&interval.  bhat&interval. ;
run;



**finally assign mean of bhat(i) for all p-y obs in the interval;

proc sql;
create table work.xgroup&interval. as
   select *,
   mean(bhat&interval.) as meanbhat&interval. 
   from work.group&interval. 
   group by id 
   order by id, year;
quit;

proc datasets lib=work;
delete group&interval. ;
quit;

  
proc print data=work.xgroup&interval. (obs=25);
title2 'test of rid assignment';
var id year rid ;
run;



%mend select;


%select(1, 1985, 1991);
%select(2, 1990, 1996);
%select(3, 1996, 2002);
%select(4, 2002, 2009);




*reassemble all-year p-y data;





data work.four;
merge work.zero work.xgroup1 work.xgroup2 work.xgroup3 work.xgroup4;
by id year;

drop xb1-xb4;

matchid=firmid||id ;


length insamp1 insamp2 interval1-interval4 have_feff1-have_feff4 
        cstayer1-cstayer4 have_peff1-have_peff4  3;

interval1=(1985<=year<=1991);
interval2=(1990<=year<=1996);
interval3=(1996<=year<=2002);
interval4=(2002<=year<=2009);


age2=age*age/100;
age3=age*age*age/1000;


have_feff1=(feff1 ne .);
have_feff2=(feff2 ne .);
have_feff3=(feff3 ne .);
have_feff4=(feff4 ne .);

*define cstayer(i) = 1 if connected stayer
                   = 0 if in AKM est sample (mover)
                   = . if outside largest connected set;



if have_feff1=1 then do;
 if peff1=. then cstayer1=1;
 else cstayer1=0;
end;

if have_feff2=1 then do;
 if peff2=. then cstayer2=1;
 else cstayer2=0;
end;

if have_feff3=1 then do;
 if peff3=. then cstayer3=1;
 else cstayer3=0;
end;

if have_feff4=1 then do;
 if peff4=. then cstayer4=1;
 else cstayer4=0;
end;

if cstayer1=1 then peff1=meanlogwage1-meanbhat1-feff1;
r1=logwage2-bhat1-feff1-peff1;


if cstayer2=1 then peff2=meanlogwage2-meanbhat2-feff2;
r2=logwage2-bhat2-feff2-peff2;


if cstayer3=1 then peff3=meanlogwage3-meanbhat3-feff3;
r3=logwage2-bhat3-feff3-peff3;


if cstayer4=1 then peff4=meanlogwage4-meanbhat4-feff4;
r4=logwage2-bhat4-feff4-peff4;

have_peff1=(peff1 ne .);
have_peff2=(peff2 ne .);
have_peff3=(peff3 ne .);
have_peff4=(peff4 ne .);




run;





proc datasets lib=work;
delete zero xgroup1 xgroup2 xgroup3 xgroup4 allp allf allxb two;
quit;


*initial sum stats;

*first check for people who are not assigned peff - these are
 age 20 in first year of interval and age 60 in last year
 since they are not in mover sample;


proc freq data=work.four;
title2 ' feff1 but no peff1';
where (have_feff1=1 and have_peff1=0);
tables year*age / missing;
run;

proc freq data=work.four;
title2 ' feff2 but no peff2';
where (have_feff2=1 and have_peff2=0);
tables year*age / missing;
run;

proc freq data=work.four;
title2 ' feff3 but no peff3';
where (have_feff3=1 and have_peff3=0);
tables year*age / missing;
run;

proc freq data=work.four;
title2 ' feff4 but no peff4';
where (have_feff4=1 and have_peff4=0);
tables year*age / missing;
run;




proc means data=work.four;
title2 'final p-y data set -- means of key vars in interval 1';
where (interval1=1);
var year logwage2 meanlogwage1 feff1 peff1 r1 have_feff1 have_peff1
  meanemp1 cstayer1 r1 rid insamp1 insamp2;
run;

proc freq data=work.four;
where (interval1=1);
tables njobs1*cstayer1;
run;


proc means data=work.four;
title2 'final p-y data set -- means of key vars in interval 2';
where (interval2=1);
var year logwage2 meanlogwage2 feff2 peff2 r2 have_feff2 have_peff2
 meanemp2 cstayer2 r2 rid insamp1 insamp2;
run;

proc freq data=work.four;
where (interval2=1);
tables njobs2*cstayer2;
run;



proc means data=work.four;
title2 'final p-y data set -- means of key vars in interval 3';
where (interval3=1);
var year logwage2 meanlogwage3 feff3 peff3 r3 have_feff3 have_peff3
 meanemp3 cstayer3 r3 rid insamp1 insamp2;
run;


proc freq data=work.four;
where (interval3=1);
tables njobs3*cstayer3;
run;


proc means data=work.four;
title2 'final p-y data set -- means of key vars in interval 4';
where (interval4=1);
var year logwage2 meanlogwage4 feff4 peff4 r4 have_feff4 have_peff4
  meanemp4 cstayer4 r4 rid insamp1 insamp2;
run;

proc freq data=work.four;
where (interval4=1);
tables njobs4*cstayer4;
run;




*** checks by interval  -- first for est sample;

proc corr data=work.four;
where (cstayer1=0);
title2 'check of assignment of peff/feff -- akm estimation sample';
var logwage2 peff1 feff1 bhat1 r1;
run;

proc corr data=work.four;
where (cstayer2=0);
var logwage2 peff2 feff2 bhat2 r2;
run;

proc corr data=work.four;
where (cstayer3=0);
var logwage2 peff3 feff3 bhat3 r3;
run;

proc corr data=work.four;
where (cstayer4=0);
var logwage2 peff4 feff4 bhat4 r4;
run;



proc reg data=work.four;
where (cstayer1=0);
model logwage2=peff1 feff1 bhat1;
run;

proc reg data=work.four;
where (cstayer2=0);
model logwage2=peff2 feff2 bhat2;
run;

proc reg data=work.four;
where (cstayer3=0);
model logwage2=peff3 feff3 bhat3;
run;

proc reg data=work.four;
where (cstayer4=0);
model logwage2=peff4 feff4 bhat4;
run;



*** checks by interval  -- now for connected stayers with peff;

proc corr data=work.four;
where (cstayer1=1 and have_peff1=1);
title2 'check of assignment of peff and feff for  connected stayers with peff';
var logwage2 peff1 feff1 bhat1 r1;
run;

proc corr data=work.four;
where (cstayer2=1 and have_peff2=1);
var logwage2 peff2 feff2 bhat2 r2;
run;

proc corr data=work.four;
where (cstayer3=1 and have_peff3=1);
var logwage2 peff3 feff3 bhat3 r3;
run;

proc corr data=work.four;
where (cstayer4=1 and have_peff4=1);
var logwage2 peff4 feff4 bhat4 r4;
run;



proc reg data=work.four;
where (cstayer1=1 and have_peff1=1);
model logwage2=peff1 feff1 bhat1;
run;

proc reg data=work.four;
where (cstayer2=1 and have_peff2=1);
model logwage2=peff2 feff2 bhat2;
run;

proc reg data=work.four;
where (cstayer3=1 and have_peff3=1);
model logwage2=peff3 feff3 bhat3;
run;

proc reg data=work.four;
where (cstayer4=1 and have_peff4=1);
model logwage2=peff4 feff4 bhat4;
run;





*** checks by interval  -- now for est sample + connected stayers;

proc corr data=work.four;
where (have_peff1=1);
title2 'check for pooled akm estimation sample + connected stayers';
var logwage2 peff1 feff1 bhat1 r1 cstayer1;
run;

proc corr data=work.four;
where (have_peff2=1 );
var logwage2 peff2 feff2 bhat2 r2 cstayer2;
run;

proc corr data=work.four;
where (have_peff3=1 );
var logwage2 peff3 feff3 bhat3 r3 cstayer3;
run;

proc corr data=work.four;
where (have_peff4=1 );
var logwage2 peff4 feff4 bhat4 r4 cstayer4;
run;



proc reg data=work.four;
where (have_peff1=1 );
model logwage2=peff1 feff1 bhat1;
run;

proc reg data=work.four;
where (have_peff2=1 );
model logwage2=peff2 feff2 bhat2;
run;

proc reg data=work.four;
where (have_peff3=1 );
model logwage2=peff3 feff3 bhat3;
run;

proc reg data=work.four;
where (have_peff4=1 );
model logwage2=peff4 feff4 bhat4;
run;




** additional checks on full connected set;


%macro match(int);

data work.check;
set work.four (keep=id firmid matchid year logwage2 interval&int. peff&int.
                    feff&int. bhat&int. r&int. cstayer&int. age2 age3 medgroup&int.
                    where=(peff&int. ne .) );
run;

proc means data=work.check;
title2 'recheck for pooled akm est sample';
run;

proc freq data=work.check;
tables medgroup&int. / missing;
run;


proc sql;
create table work.checkp as
 select id,
 count (distinct year) as nyrs
 from work.check
 group by id;
quit;

proc freq data=work.checkp;
title2 'persons in pooled sample';
tables nyrs / missing;
run;

proc datasets lib=work;
delete checkp;
quit;


proc sql;
create table work.checkf as
 select firmid,
 min(year) as minyr,
 max(year) as maxyr
 from work.check
 group by firmid;
quit;

proc freq data=work.checkf;
title2 'firms (estabs) in pooled sample';
tables minyr*maxyr / missing;
run;

proc datasets lib=work;
delete checkf;
quit;


proc sql;
create table work.checkm as
 select matchid,
 min(medgroup&int) as edgroup,
 min(cstayer&int.) as min_stayer,
 max(cstayer&int.) as max_stayer
 from work.check
 group by matchid;
quit;

proc freq data=work.checkm;
title2 'matches in pooled sample';
tables edgroup min_stayer*max_stayer / missing;
run;

proc datasets lib=work;
delete checkm;
quit;



proc sort data=work.check;
by matchid;
run;


*estimate match effect model on full sample;

proc glm data=work.check;
title2 'match effect model';
absorb matchid;
class year medgroup&int. ;
model logwage2=year*medgroup&int. medgroup&int. * age2 
               medgroup&int. * age3  / solution;
run;


proc datasets lib=work;
delete check;
quit;



%mend match;
%match(1);
%match(2);
%match(3);
%match(4);




************************ further analysis ******************;


****** step 1 - education ****************;

%macro ed(int);

proc summary data=work.four;
where (peff&int. ne . );
class medgroup&int.;
var logwage2 peff&int. feff&int. bhat&int. mschooling&int. r&int. ;
output out=work.ed&int.
n(logwage2)=n&int.
mean(logwage2)=meanwage&int.
mean(peff&int.)=meanpeff&int.
mean(feff&int.)=meanfeff&int.
mean(bhat&int.)=meanbhat&int.
mean(mschooling&int.)=meanschooling&int. 
mean(r&int.)=meanres&int. ;
run;

proc print data=work.ed&int.;
var medgroup&int. 
    n&int. 
    meanwage&int.
    meanpeff&int.
    meanfeff&int.
    meanbhat&int.
    meanschooling&int. 
    meanres&int. ;

run;

data work.ed&int. ;
set work.ed&int.;
medgroup=medgroup&int.;
run;

proc sort data=work.ed&int;
by medgroup;
run;

%mend ed;

%ed(1);
%ed(2);
%ed(3);
%ed(4);

data work.alled;
merge work.ed1 work.ed2 work.ed3 work.ed4;
by medgroup;
run;

proc print data=work.alled;
title2 'summarized data by medgroup';
var medgroup n1-n4;
run;


proc print data=work.alled;
var medgroup meanwage1-meanwage4 meanpeff1-meanpeff4 meanfeff1-meanfeff4;
format meanwage1-meanwage4 meanpeff1-meanpeff4 meanfeff1-meanfeff4 6.3;
run;

proc print data=work.alled;
var medgroup meanbhat1-meanbhat4 meanres1-meanres4;
format meanbhat1-meanbhat4 meanres1-meanres4 6.3;
run;


****** step 3 - occupation ****************;

%macro occ(int);

proc summary data=work.four;
where (peff&int. ne .);
class occ&int.;
var logwage2 peff&int. feff&int. bhat&int. mschooling&int. r&int. ;
output out=work.occ&int.
n(logwage2)=n&int.
mean(logwage2)=meanwage&int.
mean(peff&int.)=meanpeff&int.
mean(feff&int.)=meanfeff&int.
mean(bhat&int.)=meanbhat&int.
mean(mschooling&int.)=meanschooling&int. 
mean(r&int.)=meanres&int. ;
run;

data work.occ&int. ;
set work.occ&int.;
occ=occ&int.;
run;

proc sort data=work.occ&int;
by occ;
run;


%mend occ;

%occ(1);
%occ(2);
%occ(3);
%occ(4);


data work.alloccs;
merge work.occ1 work.occ2 work.occ3 work.occ4;
by occ;
if occ ne .;
run;


proc means data=work.alloccs;
run;


proc print data=work.alloccs;
title2 'summarized data by occupation';
var occ n1-n4;
run;


proc print data=work.alloccs;
var occ meanwage1-meanwage4 meanpeff1-meanpeff4 meanfeff1-meanfeff4;
format meanwage1-meanwage4 meanpeff1-meanpeff4 meanfeff1-meanfeff4 6.3;
run;

proc print data=work.alloccs;
var occ meanbhat1-meanbhat4 meanres1-meanres4 meanschooling1-meanschooling4;
format meanbhat1-meanbhat4 meanres1-meanres4 meanschooling1-meanschooling4 6.3;
run;



proc plot data=work.alloccs;
plot meanwage2*meanwage1;
plot meanwage3*meanwage2;
plot meanwage4*meanwage3;
plot meanwage4*meanwage1;
plot meanwage4*meanwage2;
run;

proc corr data=work.alloccs;
var n1 - n4;
run;


proc corr data=work.alloccs;
var meanwage1 - meanwage4;
run;

proc corr data=work.alloccs;
var meanpeff1 - meanpeff4 meanfeff1-meanfeff4 ;
run;

proc corr data=work.alloccs;
var meanwage1 meanpeff1 meanfeff1 meanbhat1;
run;

proc corr data=work.alloccs;
var meanwage2 meanpeff2 meanfeff2 meanbhat2;
run;

proc corr data=work.alloccs;
var meanwage3 meanpeff3 meanfeff3 meanbhat3;
run;

proc corr data=work.alloccs;
var meanwage4 meanpeff4 meanfeff4 meanbhat4;
run;



proc reg data=work.alloccs;
model meanwage2=meanwage1;
model meanwage3=meanwage2;
model meanwage4=meanwage3;
model meanwage4=meanwage1;


model meanwage1 = meanpeff1 meanfeff1 meanbhat1 meanres1;
model meanwage1 = meanpeff1 meanfeff1 meanbhat1 ;
model meanpeff1=meanwage1;
model meanfeff1=meanwage1;
model meanbhat1=meanwage1;

model meanwage2 = meanpeff2 meanfeff2 meanbhat2 meanres2;
model meanwage2 = meanpeff2 meanfeff2 meanbhat2;
model meanpeff2=meanwage2;
model meanfeff2=meanwage2;
model meanbhat2=meanwage2;


model meanwage3 = meanpeff3 meanfeff3 meanbhat3 meanres3;
model meanwage3 = meanpeff3 meanfeff3 meanbhat3;
model meanpeff3=meanwage3;
model meanfeff3=meanwage3;
model meanbhat3=meanwage3;

model meanwage4 = meanpeff4 meanfeff4 meanbhat4 meanres4;
model meanwage4 = meanpeff4 meanfeff4 meanbhat4;
model meanpeff4=meanwage4;
model meanfeff4=meanwage4;
model meanbhat4=meanwage4;


model meanfeff1=meanpeff1;
model meanfeff2=meanpeff2;
model meanfeff3=meanpeff3;
model meanfeff4=meanpeff4;


model meanpeff2=meanpeff1;
model meanpeff3=meanpeff2;
model meanpeff4=meanpeff3;
model meanpeff4=meanpeff1;

model meanfeff2=meanfeff1;
model meanfeff3=meanfeff2;
model meanfeff4=meanfeff3;
model meanfeff4=meanfeff1;
run;






*postAKM file - stored in SAVE directory;

data SAVE.postakm;
set work.four (keep=id year firmid peff1-peff4 feff1-feff4 cstayer1-cstayer4 r1-r4 
                    medgroup1-medgroup4 );
run;

proc means data=save.postakm;
title2 'means of archived file postakm';
run;

