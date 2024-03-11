
*build.sas -- designed to read IAB data base (code=newbuild.sas);

*NOTE: libname STORE has to be assigned to hold output data set ;
*      libname cd = input data;


  
*libname STORE '.';





options ls=120 nocenter nofmterr;

* input vars needed (from libname= cd, file = f061_p01

	ieb_prs_id	=	id
	betnr		=	firmid
	gebjahr		=	birthyr
	bild		=	education
	tentgelt	=	dailywage
	beruf		=	occupation 
	jahr		=	year
	
	frau		=	female
	ao_bula		= 	federal state
	stib		=	occupation status/hrs	
	erwstat		=	emp status

	begorig		=	begin date
	endorig		=	end date
	w73, w93, w03	=	5 digit sic codes
	


************************************************;





title1 'IAB data - men age 20-60 - full time, excl marginals';

*set following parameter for obs option ;
%LET	anz02	=	MAX;

data WORK.one;
	set cd.f061_p01
		(
		rename=	(
				ieb_prs_id	=	id
				betnr		=	firmid
				gebjahr		=	birthyr
				bild		=	education
				tentgelt	=	dailywage
				jahr		=	year
				)
		OBS=	&anz02.
		);



*** impose restrictions - must be an employment spell, valid firmid, 
                          full time/non-marginal job, 1985+, W Germ only ;

if firmid not in (.z, .n, .);
if frau	= '0';

/*eliminate jobs in the east and missing location*/
if (1<=ao_bula <=11); 


/* date limit added by Charly in iab1 */
if	begorig	<	'01Jan2010'd;



/* drop daily wage (in current euro) of less than 1 -- siab standard */
if dailywage>=1;



*drop marginal jobs for comparability over time;
*fixed as per Charlys additions to iab1 ;
if erwstat not in (109, 110, 202, 209, 210);

*drop part-time jobs;
if (0<=stib<=4);



/* define trainees - using Charlys modifications */
trainee=(year < 1999 and stib = 0) or (year >= 1999 and erwstat in
 (102,105,106,141));



/* redefine education - missing (=7 in IAB) set to 0  */
/* small number of 9s in file set to 0 also */
if education in (.z, .n, ., 7, 8, 9) then education=0;


length trainee age duration ssmax censor 3;

*define age and trim on age;
age=year-birthyr;
if age>=20 and age<=60; 



/* define spell duration using begorig and endorig */

duration= endorig - begorig + 1;




label     id = "ieb_prs_id = identifier"
      firmid = "betnr = establishment-ID "

   education = "bild=combo educ/training,0=miss"
       beruf = "occupation"
     birthyr = "bebjahr=year of birth"

        stib = "occ stat and ft/pt status"
    erwstat  = "emp status, 101=base" 
   dailywage = "daily wage=tentgelt"

      begorig = "spell start date"
     endorig  = "spell end date"

   ao_bula   = "place of work, state 1-16" 
       
    trainee  = "trainee based on stib/erwstat"
    
   ;


/*code censoring - use ssmax from SIAB*/
/*from now on dailywage is strictly capped*/
if year = 1985 then ssmax=90 ;
else if year = 1986 then ssmax=94 ;
else if year = 1987 then ssmax=95 ;
else if year = 1988 then ssmax=100 ;
else if year = 1989 then ssmax=102 ;
else if year = 1990 then ssmax=105 ;
else if year = 1991 then ssmax=109 ;
else if year = 1992 then ssmax=113 ;
else if year = 1993 then ssmax=121 ;
else if year = 1994 then ssmax=127 ;
else if year = 1995 then ssmax=131 ;
else if year = 1996 then ssmax=134 ;
else if year = 1997 then ssmax=137 ;
else if year = 1998 then ssmax=141 ;
else if year = 1999 then ssmax=142 ;
else if year = 2000 then ssmax=144 ;
else if year = 2001 then ssmax=146 ;
else if year = 2002 then ssmax=147 ; 
else if year = 2003 then ssmax=167 ;
else if year = 2004 then ssmax=168 ;
else if year = 2005 then ssmax=170 ;
else if year = 2006 then ssmax=172 ;
else if year = 2007 then ssmax=172 ;
else if year = 2008 then ssmax=173 ;
else if year = 2009 then ssmax=177 ;
else if year = 2010 then ssmax=180 ;


censor=0;

if dailywage>=ssmax then do;
 censor=1;
 dailywage=ssmax;
 end; 

*CONVERT TO REAL EUROS 1995=100;
*FROM NOW ON WAGES and EARNINGS ARE REAL;

if year = 1985 then cpi=80.2 ;
else if year = 1986 then cpi=80.1 ;
else if year = 1987 then cpi=80.3 ;
else if year = 1988 then cpi=81.3 ;
else if year = 1989 then cpi=83.6 ;
else if year = 1990 then cpi=85.8 ;
else if year = 1991 then cpi=89.0 ;
else if year = 1992 then cpi=92.5 ;
else if year = 1993 then cpi=95.8 ;
else if year = 1994 then cpi=98.4 ;
else if year = 1995 then cpi=100.0;
else if year = 1996 then cpi=101.3;
else if year = 1997 then cpi=103.2;
else if year = 1998 then cpi=104.1;
else if year = 1999 then cpi=104.8;
else if year = 2000 then cpi=106.3;
else if year = 2001 then cpi=108.4;
else if year = 2002 then cpi=110.0;
else if year = 2003 then cpi=111.1;
else if year = 2004 then cpi=112.9;
else if year = 2005 then cpi=114.7;
else if year = 2006 then cpi=116.5;
else if year = 2007 then cpi=119.1;
else if year = 2008 then cpi=122.2;
else if year = 2009 then cpi=122.7;


dailywage=dailywage*100/cpi;
spellearn=duration*dailywage;


rsample=ranuni(9211093);

drop begorig endorig cpi ssmax erwstat stib frau;

run;



proc means nolabels data=WORK.one;
class year;
title2 'FT non-marginal jobs,MEN 1985+, wage>=1, west germany only';
run;


***check distributions of beruf and sic codes by year;
proc freq data=WORK.one;
where (rsample>.95 and (1985<=year<=1991) );
title2 '5 percent sample, 1985-91 only';
tables beruf w73*year / missing;
run;

proc freq data=WORK.one;
where (rsample>.95 and (1992<=year<=1998) );
title2 '5 percent sample, 1992-98 only';
tables beruf w73*year / missing;
run;

proc freq data=WORK.one;
where (rsample>.95 and (1997<=year<=2003) );
title2 '5 percent sample, 1997-2003 only';
tables beruf w73*year 
       w93*year   / missing;
run;

proc freq data=WORK.one;
where (rsample>.95 and (2003<=year<=2009) );
title2 '5 percent sample, 2003-2009 only';
tables beruf w73*year  
       w93*year 
       w03*year / missing;
run;




*collapse to person-firm-year = pfy using sql;
*NOTE THAT THERE APPEAR TO BE DUP RECORDS -- collapsing averages these;
*in case of missing vals or changes, define age,education etc as highest in pfy spell;
*censor =1 if any episode has censored wage;


proc sql;
create table WORK.pfy as
 select id, firmid, year,
 sum(duration) as totduration,
 sum(spellearn) as totearn,
 calculated totearn / calculated totduration as dailywage,
 log(calculated dailywage) as logwage,
 max(trainee) as trainee ,
 max(age) as age,
 max(birthyr) as birthyr,
 max(beruf) as beruf,
 max(w73) as w73,
 max(w93) as w93,
 max(w03) as w03,
 max(ao_bula) as ao_bula,
 max(education) as education,
 max(censor) as censor
 from WORK.one
 group by id, firmid, year ;
quit;


proc datasets lib=WORK;
delete one;
quit;

proc means n mean std min max nolabels data=WORK.pfy;
title2 'collapse spells to pfy data set';
class year;
run;



*now select highest earning pfy as py observation;

proc sort data=WORK.pfy;
by id year descending totearn;
run;


data WORK.py;
set WORK.pfy;

by id year descending totearn;

if first.year=1;    /*select employer with highest earnings in year */

***** NOTE RESTRICTION ON REAL WAGE ;
*     drop person-year obs if daily wage < 10 euros/day, 2001 real;

if dailywage>=10;


length schooling dropout apprentice somecoll university missed
       trainee ao_bula censor age birthyr 3;


if education in (0, .) then edgroup=0;
else if education =1 then edgroup=1;
else if education =2 then edgroup=2;
else if education in (3,4) then edgroup=3;
else if education in (5,6) then edgroup=4;
else edgroup=9;

drop education;

dropout=(edgroup=1);
apprentice=(edgroup=2);
somecoll=(edgroup=3);
university=(edgroup=4);
missed=(edgroup=0);


*assign best estimate of years of schooling to approximate linear return in GLM;
if edgroup=0 then schooling=10.5;
else if edgroup=1 then schooling=11;
else if edgroup=2 then schooling=13;
else if edgroup=3 then schooling=15;
else if edgroup=4 then schooling=18;
else schooling=.; 

if (20<=age<=29) then agegroup=2;
else if (30<=age<=39) then agegroup=3;
else if (40<=age<=49) then agegroup=4;
else agegroup=5;  /*includes 60 year olds*/

*define experience (rough);
if edgroup in (0,1,2) then exp=age-18;
else if edgroup=3 then exp=age-22;
else exp=age-25;



label totearn='tot earns in p-f-year'
      totduration='total days worked in p-f-year'
      trainee='spell as trainee in p-f-year'
      dailywage='avg daily wage, p-f cell'
      logwage='log daily wage, dropped if under 10 e/day';

run;



proc datasets lib=WORK;
delete pfy;
quit;




proc means nolabels;
title2 'collapsed py data set - means by year';
class year;
run;


**** now create tables of means by firm and worker for use in tobits;
**** this time through calculate only firm stats needed for tobits;

proc sql;
create table WORK.fy as
 select firmid, year,
 count(logwage) as emp,
 mean(logwage) as fmeanlogwage, 
 mean(censor) as fmeancensor, 
 mean(schooling) as fmeanschooling,
 mean(university) as fmeanuniversity,
 mean(somecoll) as fmeansomecoll,
 mean(apprentice) as fmeanapprentice,
 mean(exp) as fmeanexp,
 mean(exp*exp/100) as fmeanexpsq
 from WORK.py
 group by firmid, year;
quit;


proc sql;
create table WORK.pall as
 select id, 
 min(year) as pfirstyear,
 max(year) as plastyear,
 count(year) as pnyears,
 sum(1985<=year<=1989) as pn8589,
 sum(1990<=year<=1994) as pn9094,
 sum(1995<=year<=1999) as pn9599,
 sum(2000<=year<=2004) as pn0004,
 sum(2005<=year<=2009) as pn0509,
 mean(logwage) as pmeanlogwage,
 mean(censor) as pmeancensor
 from WORK.py
 group by id;
quit;


*now merge py, fy, and pall;

proc sql;
create table WORK.pyx as
 
select   	a.*,

 		b.emp,
		b.fmeanlogwage,
		b.fmeancensor,	
		b.fmeanschooling,
		b.fmeanapprentice,
		b.fmeansomecoll,
		b.fmeanexp,
		b.fmeanexpsq,
		b.fmeanuniversity,

		c.pfirstyear,
		c.plastyear,
		c.pnyears,
                c.pn8589,
                c.pn9094,
                c.pn9599,
                c.pn0004,
                c.pn0509,
		c.pmeanlogwage,
		c.pmeancensor
	
from WORK.py as a left join WORK.fy as b on (a.firmid=b.firmid and
    a.year=b.year) left join WORK.pall as c on (a.id=c.id) ;
 
quit;


proc datasets lib=WORK;
delete py fy pall;
quit;


proc means nolabels data=WORK.pyx;
title2 'py-extended data, by year';
class year;
run;



data WORK.pyx;
set WORK.pyx;

length onewkr atbigfirm oneyear insub 3;

onewkr=(emp=1);
atbigfirm=(emp>10);   /*big firm indicator flags emp>10 */

if onewkr=0 then do;
  ofmeancensor=(fmeancensor-censor/emp)*emp/(emp-1);
  ofmeanwage= (fmeanlogwage-logwage/emp)*emp/(emp-1);
end;
else do;
  ofmeancensor=0.1; 
  ofmeanwage=4.8; 
end;

oneyear=(pnyears=1);
if oneyear=0 then do;
  opmeancensor= (pmeancensor-censor/pnyears)*pnyears/(pnyears-1);
  opmeanwage= (pmeanlogwage-logwage/pnyears)*pnyears/(pnyears-1);
end;
else do;
  opmeancensor=0.1; 
  opmeanwage=4.8; 
end;

empsq=emp*emp/100;


*create a 3% sample for tobits;

insub=(.47<=ranuni(921)<.5);

run;





data WORK.sub;
set WORK.pyx (where=( insub=1) ) ;
keep logwage censor age atbigfirm ofmeancensor ofmeanwage emp empsq onewkr 
     fmeanuniversity fmeanschooling opmeancensor opmeanwage oneyear 
     year edgroup agegroup ;




**********code for tobits****;

*dummy data set to intialize loop;

data WORK.tobit;
year=0;
edgroup=0;
agegroup=0;
output;
run;


%macro impute;
%do yr=1985 %to 2009;
%do eg=0 %to 4;
%do ag=2 %to 5;


*get means by group - then run tobit;

proc means data=WORK.sub;
where (year=&yr and edgroup=&eg and agegroup=&ag );
title2 'tobit by year/edgroup/agegroup';
var year edgroup agegroup censor logwage;

proc lifereg outest=WORK.temp data=WORK.sub;
where (year=&yr and edgroup=&eg and agegroup=&ag );

model logwage*censor(1)=age atbigfirm ofmeancensor ofmeanwage emp empsq onewkr 
                        fmeanuniversity fmeanschooling 
                        opmeancensor opmeanwage oneyear / d=normal;
run;


*grab and save coefficients, appending to WORK.tobit;

data WORK.temp;
set WORK.temp;
year=&yr;
edgroup=&eg;
agegroup=&ag;

_intercept=intercept;
_scale=_scale_;
_age=age;
_atbigfirm=atbigfirm;
_ofmeancensor=ofmeancensor;
_ofmeanwage=ofmeanwage;
_emp=emp;
_empsq=empsq;
_onewkr=onewkr;
_fmeanuniversity=fmeanuniversity;
_fmeanschooling=fmeanschooling;
_opmeancensor=opmeancensor;
_opmeanwage=opmeanwage;
_oneyear=oneyear;

keep year edgroup agegroup _intercept _scale
_age _atbigfirm _ofmeancensor _ofmeanwage _emp
_empsq _onewkr _fmeanuniversity _fmeanschooling
_opmeancensor _opmeanwage _oneyear ;

run;

data WORK.tobit;
set WORK.tobit WORK.temp;
run;


%end;
%end;
%end;
%mend;

%impute;




*delete dummy obs;
data WORK.tobit;
set WORK.tobit;
if year>0;
run;

proc means nolabels data=WORK.tobit;
title2 'coefficients of tobit by edgroup x agegroup';
class edgroup agegroup;
run;




*merge pyx and tobit coefficients;
*re-create py data set with extended-characteristics and imputed wage;


proc sort data=WORK.pyx;
by year edgroup agegroup;
run;

proc sort data=WORK.tobit;
by year edgroup agegroup;
run;


data WORK.py;
merge WORK.pyx WORK.tobit;
by year edgroup agegroup;

xb= _intercept + _age*age + _atbigfirm*atbigfirm + _ofmeancensor*ofmeancensor
  + _ofmeanwage*ofmeanwage + _emp*emp + _empsq*empsq + _onewkr*onewkr
  + _fmeanuniversity*fmeanuniversity + _fmeanschooling*fmeanschooling
  +_opmeancensor*opmeancensor + _opmeanwage*opmeanwage + _oneyear*oneyear;


*censoring points = log(ssmax/cpi);
if year=1985 then cut=4.720456341;
else if  year=1986 then cut=4.765189114;
else if  year=1987 then cut=4.773277457;
else if  year=1988 then cut=4.812194355;
else if  year=1989 then cut=4.804099479;
else if  year=1990 then cut=4.80711153;
else if  year=1991 then cut=4.807881698;
else if  year=1992 then cut=4.80534936;
else if  year=1993 then cut=4.838698047;
else if  year=1994 then cut=4.860316468;
else if  year=1995 then cut=4.875197323;
else if  year=1996 then cut=4.884923575;
else if  year=1997 then cut=4.888482259;
else if  year=1998 then cut=4.908578101;
else if  year=1999 then cut=4.908943472;
else if  year=2000 then cut=4.9087182;
else if  year=2001 then cut=4.902948719;
else if  year=2002 then cut=4.895122407;
else if  year=2003 then cut=5.012733302;
else if  year=2004 then cut=5.002631694;
else if  year=2005 then cut=4.998648599;
else if  year=2006 then cut=4.99477339;
else if  year=2007 then cut=4.972701186;
else if  year=2008 then cut=4.952802734;
else if  year=2009 then cut=4.971577567;

*impute an upper tail error if censored;
ord=(cut-xb)/_scale;
cf=probnorm(ord);
u=ranuni(881131);
if cf<.9999 then e=probit( cf+u*(1-cf) );
else e=3.71902;

if censor=0 then logwage2=logwage;
else logwage2=xb+_scale*e;


*drop coefficients and means excluding current year;

drop _intercept 
     _age _atbigfirm _ofmeancensor _ofmeanwage _emp
     _empsq _onewkr _fmeanuniversity _fmeanschooling
     _opmeancensor _opmeanwage _oneyear  cut ord xb cf u e ;



*add experience sq and cube for glms;
exp2=exp*exp/100;
exp3=exp*exp*exp/1000;


*create a 5% sample for regression -- USING allocated wage variable;
if (.45<=ranuni(921)<.5) then logwager=logwage2;
else logwager=.;

run;



**** now 2 regressions to assign worker quality and residual wages;
**** these are fit to subsample with logwager nonmissing then extrapolated;


proc glm data=WORK.py;
class year;
title2 'adjusting models on py data';
model logwager=missed apprentice somecoll university exp exp2 exp3 trainee year / solution;
output out=WORK.py1
predicted=xibar;
run;

proc	datasets
	lib	=	work	nolist;
	delete	py;
quit;



proc glm data=WORK.py1;
class year; 
model logwager=missed*year apprentice*year somecoll*year university*year
               exp*year exp2*year exp3*year trainee*year year / solution;
output out=WORK.py
predicted=xibt;
run;


proc	datasets
	lib	=	work	nolist;
	delete	py1;
quit;


** define reswage and add to py dataset;

data WORK.py;
set WORK.py;
reswage=logwage2-xibt;
drop logwager;


label reswage='logwage2-xibt'
      logwage2='log wage with imputed tail'
      logwage = 'log wage, censored'
      pmeanlogwage='p-mean log wage all yrs, censored'
      fmeanlogwage='f-mean log wage this year, censored' ;


run;


proc means nolabels data=WORK.py;
class year;
title2 'means of py data set by year';
var logwage logwage2 censor age exp reswage xibt xibar 
    totduration trainee missed apprentice somecoll university schooling
    atbigfirm fmeancensor fmeanlogwage emp onewkr fmeanuniversity fmeanschooling
    pmeancensor pmeanlogwage oneyear ;
run;







*** recalculate firm-year average data set fy with logwage2  ;

proc summary data=WORK.py;
class firmid year;
var logwage2 reswage trainee xibar;
output out=WORK.fy

mean(logwage2)=mu
std(logwage2)=sigma
n(logwage2)=emp

mean(reswage)=mu_res
std(reswage)=sigma_res

mean(xibar)=meanxibar
std(xibar)=stdxibar
mean(trainee)=meantrainee;

run;




*construct moments of between-firm components;

proc summary data=WORK.fy ;
where (firmid ne . and year ne .);
class year;
var mu mu_res;
output out=WORK.fybetween
mean=
std(mu)=std_mu
std(mu_res)=std_mu_res;
run;

proc print data=WORK.fybetween;
title2 'between firm variation in wages - raw and adjusted';
var year _freq_  mu std_mu mu_res std_mu_res;
run;



*Create summary information across all years for firms = fall data set;

proc sql;
create table WORK.fall as
 select firmid, 
 min(year) as firm_firstyr,
 max(year) as firm_lastyr,
 mean(emp) as firm_meanemp,
 mean(log(emp)) as firm_meanlogemp, 
 min(emp)>=3  as firm_always3p,
 max(emp)=1 as firm_always1,
 sum(mu*emp)/sum(emp) as firm_meanmu,
 sum(mu_res*emp)/sum(emp) as firm_meanmu_res,
 sum(meanxibar*emp)/sum(emp) as firm_meanxibar,
 (calculated firm_firstyr=calculated firm_lastyr) as firm_oneyear
 from WORK.fy
 where year>0 and firmid>0 
 group by firmid;
quit;



%macro bcohort;
%do yr=1985 %to 2008;

proc means nolabels n mean std min max data=WORK.fall;
where (firm_firstyr=&yr);
title2 'fall data - firm-avgerages - firms by first year in sample';
var firm_firstyr firm_meanemp firm_meanlogemp firm_always1 firm_always3p firm_meanmu firm_meanmu_res firm_meanxibar firm_oneyear;

run;

%end;
%mend;
%bcohort;


*now merge py, fy, and fall;

proc sql;
create table STORE.iabworkfile as
 
select   	a.*,

 		b.mu,
 		b.sigma,
		b.mu_res,
		b.sigma_res,
		b.meanxibar,

 		c.firm_firstyr,
 		c.firm_lastyr,
 		c.firm_meanemp,
 		c.firm_always1, 
 		c.firm_always3p,
 		c.firm_oneyear,
		c.firm_meanmu_res,
		c.firm_meanxibar,

  		a.logwage2-b.mu as dev,
		a.reswage-b.mu_res as dev_res,
		a.xibar-b.meanxibar as dev_xibar

		
 from WORK.py as a left join WORK.fy   as b on (a.firmid=b.firmid and
 a.year=b.year)
                   left join WORK.fall as c on (a.firmid=c.firmid) ;
 
quit;


proc datasets lib=WORK;
delete py fy fall;
quit;


***get summary stats;

proc means nolabels data=STORE.iabworkfile;
class year;




