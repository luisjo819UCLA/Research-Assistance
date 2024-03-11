Readme file for archive of programs in Card, Heining, and Kline (2012)

1) build.sas  (SAS program)
    -extracts spells of full time men age 20-60
    -assigns one daily wage observation per person/year
    -fits Tobit models and allocates upper tail of wages
    -creates workfile

2) tomatlab.sas  (SAS program)
    -reads workfile
    -creates 4 interval-level data set of person/year wage data for movers

3) AKMest.m  (Matlab Program -- use version 2011a or newer)
    -reads output of tomatlab.sas and conducts AKM estimation for mover samples in each interval.
	-conducts variance decomposition for movers and some specification tests
	-outputs person effects, estab-effects, Xb-hat, and residuals for each interval
   
4) postAKM.sas  (SAS program)
    -reads in files of estimated person effects, estab-effects, Xb-hat for 
     movers in largest connected set (in 4 intervals)
    -combines these with workfile, assigns person effects for connected
     stayers (people who work at estabs in largest connected set who
     never changed jobs in the interval), creating "full connected set"
    -computes Match effect models for full connected set
    -computes various summary statistics by interval
    -analyzes data by education and occupation group, by interval
