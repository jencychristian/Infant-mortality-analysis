*Project : U.S. Infant Mortality Surveillance Analysis 
Author : Jency Joyashish Christian
Date : 05/18/2026 
Data : CDC WONDER Linked Birth/Infant Deaths 2007-2023;


libname infant "C:\Users\jc1695.UNTHSC\Documents\My SAS Files\Datasets";

*macro variables for file paths;

%let path = C:\Users\jc1695.UNTHSC\Documents\My SAS Files\Datasets; 
%let f_race = &path.\infant_mortality_trend_race_2007_2023.csv; 
%let f_cause = &path.\infant_mortality_causes_2007_2023.csv; 
%let f_state = &path.\infant_mortality_state_2007_2023.csv;



/*output*/
 %let outpath = C:\Users\jc1695.UNTHSC\Documents\My SAS Files\Datasets\Output; 

proc contents data=infant._all_ nods;
run; 

options fmtsearch =(infant work); 
title;
footnote; 

*Because of metadata in notes section and the variables being char datatype, I made a raw file first for the dataset to be cleaned;
data work.race_raw;
    infile "&f_race." 
    dsd
    delimiter = ','
    firstobs  = 2
    missover
    lrecl     = 32767;
 
    length
        notes          $130.
        race_raw       $50.
        race_code      $10.
        year_char      $4.
        year_code      $4.
        deaths_raw     $15.
        births_raw     $15.
        rate_raw       $15.;

    input
        notes      $
        race_raw   $
        race_code  $
        year_char  $
        year_code  $
        deaths_raw $
        births_raw $
        rate_raw   $;

run;

*Check;
proc print data=work.race_raw (obs=10); 
run;


/*Final cleaning of dataset*/

data infant.race_clean; 
set work.race_raw;

if strip(notes) ne "" then delete;
if strip(race_raw) = "" then delete;
if strip(year_char) = "" then delete;

*converting year,deaths and rates to num;

year = input(year_char, 4.);
deaths = input(strip(deaths_raw), 8.);
births = input(strip(births_raw), 8.);
rate = input(strip(rate_raw), 8.);

*Collapsing race/ethnicity to 4 analytic categories;

length race_cat $20;

select;
when (race_raw in("Mexican", "Puerto Rican", "Cuban", "Central or South American", "other and Unknown Hispanic")) race_cat = "Hispanic";
when (race_raw = "Non-Hispanic White") race_cat = "NH White";
when (race_raw = "Non-Hispanic Black") race_cat = "NH Black";
otherwise race_cat = "NH Other";
end;

drop notes race_code year_char year_code deaths_raw births_raw rate_raw;
run;



*confirming the cleaning;

proc contents data = infant.race_clean;
run;

title "Race Category Distribution";
proc freq data=infant.race_clean;
tables race_cat year / missing;

title "Descriptive Statistics: Race Clean file";
proc means data=infant.race_clean n nmiss mean min max ;
var year deaths births rate;
run;

title;



*File 2 - Causes Cleaning;

data work.causes_raw;
infile "&f_cause."
dsd
delimiter = ','
firstobs = 2
missover 
lrecl = 32767;

length 
notes $130. 
cause_raw $100. 
cause_code $10. 
year_char $4. 
year_code $4. 
deaths_raw $15. 
births_raw $15. 
rate_raw $20.; 

input 
notes $ 
cause_raw $ 
cause_code $ 
year_char $ 
year_code $ 
deaths_raw $ 
births_raw $ 
rate_raw $; 

run;

*preview;
proc print data=work.causes_raw(obs=10);
run;

*cleaning dataset cuases;

data infant.causes_clean;
set work.causes_raw;

*removing metadata rows at bottom of dataset;

if strip(notes) ne "" then delete;
if strip(cause_raw) = "" then delete;
if strip(year_char) = "" then delete;

*converting to num;
year = input(year_char, 4.);
births = input(strip(births_raw), 8.);

*removing "suppressed" from deaths_raw and converting it into num;

if strip(deaths_raw) = 'Suppressed' then do;
deaths = .; 
suppressed_flg = 1;
end;

else do;
deaths = input(strip(deaths_raw), 8.);
suppressed_flg = 0;
end;

*cleaning death rate colum of "unreliable" and "suppressed";

if index(rate_raw, 'Unreliable') > 0 then do; 
death_rate = input(scan(rate_raw, 1, '('), 8.); 
unreliable_flg = 1; 
end; 

else if strip(rate_raw) = 'Suppressed' then do; 
death_rate = .; unreliable_flg = 0; 
end; 

else do; 
death_rate = input(strip(rate_raw), 8.); 
unreliable_flg = 0; 
end;

 *NOTE : I have kept ONLY rankable # causes. These are mutually exclusive, non-overlapping officially published NCHS leading causes;

    if substr(strip(cause_raw), 1, 1) = '#' 
    then rankable = 1;
    else rankable = 0;
    drop notes cause_code year_char year_code
         deaths_raw births_raw rate_raw;
run;

*Analysis of rankable causes;
data infant.causes_analysis;
set infant.causes_clean;
where rankable = 1;

*removing # from cause name;
length cause_clean $100.;
cause_clean = substr(strip(cause_raw), 2);
run;

*Check 1 — How many unique rankable causes? ;
title "All Rankable Causes";
proc freq data=infant.causes_analysis nlevels;
tables cause_raw / nocum nopercent;
run;

*Check 2 — Top 10 by total deaths ; 
proc means data=infant.causes_analysis sum noprint;
where suppressed_flg = 0;
var deaths;
class cause_clean; output out=work.rankable_totals sum=total_deaths;
run;

*Removinf the overall total;
data work.rankable_totals;
set work.rankable_totals;
if cause_clean = "" then delete;
run;

proc sort data=work.rankable_totals;
by descending total_deaths;
run;

title "Top 10 Rankable Causes 2007-2023";
proc print data=work.rankable_totals (obs=10);
var cause_clean total_deaths;
run;

*Important findings;

* 1.Top 2 causes alone account for: 80,643 + 65,846 = 146,489 deaths = roughly 44% of all rankable deaths ;

* 2.Top 3 causes = over half of all infant deaths in the US 2007-2023 ;



*File 3: State file cleaning;

data work.state_raw;
infile "&f_state."
dsd delimiter = ',' 
firstobs = 2
missover lrecl  =32767;

length 
notes $130.
state $50.
state_code $5. 
year_char $4. 
year_code $4. 
deaths_raw $15. 
births_raw $15. 
rate_raw $20.; 

input 
notes $ 
state $ 
state_code $ 
year_char $ 
year_code $ 
deaths_raw $ 
births_raw $ 
rate_raw $; 

run;


proc print data=work.state_raw (obs=10);
title"first 10 rows of state_raw";
run;


/*Removing metadata and further cleaning*/
data infant.state_clean;
set work.state_raw;

if strip(notes) ne "" then delete;
if strip(state) = "" then delete;
if strip(year_char) = "" then delete;

births = input(strip(births_raw), 8.);
year = input(year_char, 4.);

/*Clean deaths column */

if upcase(strip(deaths_raw)) = 'SUPPRESSED' then do;
deaths = .;
suppressed_flg = 1;
end;

else if strip(deaths_raw) = '' then do;
deaths = .;
suppressed_flg = 0;
end;

else do;
deaths = input(strip(deaths_raw), 8.);
suppressed_flg = 0;
end;

/*Clean death rate column*/

if index(upcase(rate_raw), 'UNRELIABLE') > 0 then do;
death_rate = input(scan(rate_raw, 1, '('),8.);
unreliable_flg = 1;
end;

else if strip(rate_raw) = '' then do;
death_rate = .;
unreliable_flg = 0;
end;

else do;
death_rate = input(strip(rate_raw), 8.);
unreliable_flg = 0;
end;


length 
region $20.; 

if state in ( "Connecticut", "Maine", "Massachusetts", "New Hampshire", "Rhode Island", "Vermont", "New Jersey", "New York", "Pennsylvania") 
then region = "Northeast"; 

else if state in ( "Illinois", "Indiana", "Michigan", "Ohio", "Wisconsin", "Iowa", "Kansas", "Minnesota", "Missouri", "Nebraska", "North Dakota", "South Dakota") 
then region = "Midwest"; 

else if state in ( "Delaware", "Florida", "Georgia", "Maryland", "North Carolina", "South Carolina", "Virginia", "District of Columbia", 
"West Virginia", "Alabama", "Kentucky", "Mississippi", "Tennessee", "Arkansas", "Louisiana", "Oklahoma", "Texas") 
then region = "South"; 

else if state in ( "Arizona", "Colorado", "Idaho", "Montana", "Nevada", "New Mexico", "Utah", "Wyoming", "Alaska", "California", "Hawaii", "Oregon", "Washington") 
then region = "West"; 

else region = "Unknown"; 

drop notes state_code year_char year_code deaths_raw births_raw rate_raw; 
run;




*Checks;

title "Variables in state_clean dataset";
proc contents data=infant.state_clean;
run;

title "State list";
proc freq data=infant.state_clean nlevels;
tables state / nocum nopercent;
run;

title "Year range 2007-2023";
proc freq data=infant.state_clean;
tables year / nocum nopercent missing;
run;

title "Census Region distribution";
proc freq data=infant.state_clean;
tables region / nocum missing;
run;

title "Unreliable flag count";
proc freq data=infant.state_clean;
tables unreliable_flg / missing;
run;

title "Top ten states by Average infant Moratlity Rate 2007-2023";
proc means data=infant.state_clean mean noprint;
where unreliable_flg=0;
var death_rate;
class state;
output out=work.state_rates mean=avg_death_rate;
run;

proc sort data=work.state_rates;
    by descending avg_death_rate;
run;

proc print data=work.state_rates (obs=10);
var state avg_death_rate;
run;
title;

*Check race categories;
proc freq data=infant.race_clean;
    tables race_raw / nocum nopercent;
    title "Race Categories in race_clean dataset";
run;

*Analysis and Charts;

*Create summary datasets and 5 charts;

*National overall trend by year 
Sum deaths and births across all race groups ;


proc means data=infant.race_clean sum noprint; 
var deaths births; 
class year; 
output out=work.national_trend sum(deaths) = total_deaths sum(births) = total_births; 
run; 

*Recalculate rate per 1000 live births ; 
data work.national_trend; 
set work.national_trend; 
where _type_ = 1; 
overall_rate = (total_deaths / total_births) * 1000; 
drop _type_ _freq_; 
run; 

*Trend by collapsed race category Sum deaths and births within race_cat by year 
and recalculate rate per 1000;

proc means data=infant.race_clean sum noprint; 
var deaths births; 
class race_cat year; 
output out=work.race_trend sum(deaths) = total_deaths sum(births) = total_births; 
run; 

data work.race_trend; 
set work.race_trend; 
where _type_ = 3; 
race_rate = (total_deaths / total_births) * 1000; 
drop _type_ _freq_; 
run; 

*Top 10 causes total - top 10 rows;

data work.top10_causes; 
set work.rankable_totals (OBS=10); 
where cause_clean NE ""; 

* Shorten long cause names for chart labels ; 
length cause_short $50.; 
if index(cause_clean, 'Congenital') > 0 then cause_short = "Congenital Malformations"; 
else if index(cause_clean, 'Short gestation') > 0 then cause_short = "Short Gestation/Low Birthweight"; 
else if index(cause_clean, 'Sudden infant') > 0 then cause_short = "SIDS"; 
else if index(cause_clean, 'maternal comp') > 0 then cause_short = "Maternal Complications"; 
else if index(cause_clean, 'Accidents') > 0 then cause_short = "Unintentional Injuries"; 
else if index(cause_clean, 'placenta') > 0 then cause_short = "Placenta/Cord Complications"; 
else if index(cause_clean, 'Bacterial') > 0 then cause_short = "Bacterial Sepsis"; 
else if index(cause_clean, 'Respiratory') > 0 then cause_short = "Respiratory Distress"; 
else if index(cause_clean, 'circulatory') > 0 then cause_short = "Circulatory Disease"; 
else if index(cause_clean, 'hemorrhage') > 0 then cause_short = "Neonatal Hemorrhage"; 
else cause_short = cause_clean; 
run; 

*Top 10 and Bottom 10 states; 

data work.state_rates_clean; 
set work.state_rates; 
where state NE ""; 
drop _type_ _freq_; 
RUN; 

proc sort data=work.state_rates_clean; 
by descending avg_death_rate; 
run; 

data work.top10_states; 
set work.state_rates_clean (obs=10); 
run;

*CHART 1 : Overall U.S. Infant Mortality Trend 2007-2023;

Title "U.S. Infant Mortality Rate, 2007-2023"; 
Title2 "Source: CDC WONDER Linked Birth/Infant Deaths"; 
proc sgplot data=work.national_trend; 
series X=year Y=overall_rate / lineattrs = (thickness=2.5 color=CX2166AC) markers markerattrs = (symbol=CircleFilled size=8 color=CX2166AC); 
Xaxis label = "Year" values = (2007 to 2023 by 1) valueattrs = (size=9); 
Yaxis label = "Infant Mortality Rate (per 1,000 Live Births)" min = 0; 
footnote "Rate calculated as deaths per 1,000 live births"; 
run;

*CHART 2 — Infant Mortality Trend by Race/Ethnicity; 

title "U.S. Infant Mortality Rate by Race/Ethnicity, 2007-2023"; 
title2 "Source: CDC WONDER Linked Birth/Infant Deaths"; 
proc sgplot data=work.race_trend; series X=year Y=race_rate / group = race_cat lineattrs = (thickness=2) markers markerattrs = (size=7);
Xaxis label = "Year" values = (2007 to 2023 by 1) valueattrs = (size=9); 
Yaxis label = "Infant Mortality Rate (per 1,000 Live Births)" min = 0; 
keylegend/title = "Race/Ethnicity" location = inside position = topright; 

footnote "Race/ethnicity based on Mother's Bridged Race/Hispanic Origin"; 
run;

*CHART 3 — Top 10 Causes of Infant Death 2007-2023;

title "Top 10 Leading Causes of Infant Death, United States 2007-2023"; 
title2 "Source: CDC WONDER Linked Birth/Infant Deaths"; 
proc sgplot data=work.top10_causes; 
Hbar cause_short / response = total_deaths fillattrs = (color=CX4393C3) datalabel datalabelattrs = (size=8) categoryorder = respdesc; 
Xaxis label = "Total Deaths 2007-2023" grid; 
Yaxis label = "Cause of Death" valueattrs = (size=9); 

footnote "Based on NCHS rankable causes of infant death (ICD-10)"; 
run;

*CHART 4 — Top 10 States by Average Infant Mortality Rate; 

title "Top 10 States by Average Infant Mortality Rate, 2007-2023"; 
title2 "Source: CDC WONDER Linked Birth/Infant Deaths"; 
proc sgplot data=work.top10_states; 
Hbar state / response = avg_death_rate fillattrs = (color=CX8B0000) datalabel datalabelattrs = (size=8) categoryorder = respdesc; 
Xaxis label = "Average Infant Mortality Rate (per 1,000 Live Births)" grid; 
Yaxis label = "State" valueattrs = (size=9); 

footnote "Unreliable rates (fewer than 20 deaths) excluded from average"; 
run;

/* Round avg_death_rate */
data work.top10_states;
    set work.top10_states;
    avg_death_rate = round(avg_death_rate, 0.1);
run;

/*CHART 5 — Infant Mortality Trend by Census Region */ 

/* First create regional summary dataset */ 
proc means data=infant.state_clean sum noprint; 
where unreliable_flg = 0; 
var deaths births; 
class region year; 
output out=work.region_trend sum(deaths) = total_deaths sum(births) = total_births; 
run; 

data work.region_trend; 
set work.region_trend; 
where _TYPE_ = 3 AND region ne ""; region_rate = (total_deaths / total_births) * 1000; 
drop _TYPE_ _FREQ_; 
run; 

title "U.S. Infant Mortality Rate by Census Region, 2007-2023"; 
title2 "Source: CDC WONDER Linked Birth/Infant Deaths"; 
proc sgplot data=work.region_trend; series X=year Y=region_rate / group = region lineattrs = (thickness=2) markers markerattrs = (SIZE=7); 
Xaxis label = "Year" values = (2007 to 2023 by 1) valueattrs = (size=9); 
Yaxis label = "Infant Mortality Rate (per 1,000 Live Births)" min = 0; 
Keylegend / title = "Census Region" location = inside position = topright; 

footnote "Regions defined by U.S. Census Bureau classification"; 
run;
 
title; 
footnote;



*Report figures;

options nodate nonumber;
ods noproctitle;
ods graphics / width=7in height=5in;

* Figure 1: National Trend;
title    "Figure 1. U.S. Infant Mortality Rate, 2007-2023";
title2   "Source: CDC WONDER Linked Birth/Infant Deaths";
footnote "Rate calculated as deaths per 1,000 live births";

proc sgplot data=work.national_trend;
    series x=year y=overall_rate / lineattrs = (thickness=2.5 color=cx2166ac) markers markerattrs = (symbol=circlefilled size=8 color=cx2166ac);
    xaxis label  = "Year" values = (2007 to 2023 by 1);
    yaxis label  = "Rate per 1,000 Live Births" min = 0;
run;

* Figure 2: Race Trend;
title    "Figure 2. Infant Mortality by Race/Ethnicity, 2007-2023";
title2   "Source: CDC WONDER Linked Birth/Infant Deaths";
footnote "Race/ethnicity based on Mother's Bridged Race/Hispanic Origin";

proc sgplot data=work.race_trend;
    series x=year y=race_rate /group = race_cat lineattrs = (thickness=2) markers markerattrs = (size=7);
    xaxis label  = "Year" values = (2007 to 2023 by 1);
    yaxis label  = "Rate per 1,000 Live Births" min = 0;
    keylegend / title    = "Race/Ethnicity" location = inside position = bottomright;
run;

*Figure 3: Top 10 Causes;
title    "Figure 3. Top 10 Leading Causes of Infant Death, 2007-2023";
title2   "Source: CDC WONDER Linked Birth/Infant Deaths";
footnote "Based on NCHS rankable causes — ICD-10 130 Cause List";

proc sgplot data=work.top10_causes;
    hbar cause_short /response = total_deaths fillattrs = (color=cx4393c3)
        datalabel datalabelattrs = (size=8)
        categoryorder  = respdesc;
    xaxis label = "Total Deaths 2007-2023" grid;
    yaxis label = "Cause of Death";
run;

*Figure 4: Top 10 States;
title    "Figure 4. Top 10 States by Average Infant Mortality Rate, 2007-2023";
title2   "Source: CDC WONDER Linked Birth/Infant Deaths";
footnote "Unreliable rates excluded from average calculation";

proc sgplot data=work.top10_states;
    hbar state / response = avg_death_rate fillattrs = (color=cx8b0000)
    datalabel datalabelattrs = (size=8)
    categoryorder  = respdesc;
    xaxis label = "Average Rate per 1,000 Live Births" grid;
    yaxis label = "State";
run;

*Figure 5: Regional Trend;
title    "Figure 5. Infant Mortality by Census Region, 2007-2023";
title2   "Source: CDC WONDER Linked Birth/Infant Deaths";
footnote "Regions defined by U.S. Census Bureau classification";

proc sgplot data=work.region_trend;
    series x=year y=region_rate /group = region lineattrs   = (thickness=2) markers markerattrs = (size=7);
    xaxis label  = "Year" values = (2007 to 2023 by 1);
    yaxis label  = "Rate per 1,000 Live Births" min=0;
    keylegend / title    = "Census Region" location = inside position = topright;
run;

title;
footnote;

* Export all 3 clean datasets for Tableau ;

proc export
    data    = infant.race_clean
    outfile = "&outpath.\tableau_race.csv"
    dbms    = csv replace;
run;

proc export
    data    = infant.causes_analysis
    outfile = "&outpath.\tableau_causes.csv"
    dbms    = csv replace;
run;

proc export
    data    = infant.state_clean
    outfile = "&outpath.\tableau_state.csv"
    dbms    = csv replace;
run;

