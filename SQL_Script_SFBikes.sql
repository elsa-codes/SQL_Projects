{\rtf1\ansi\ansicpg1252\cocoartf2709
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 SELECT * FROM stations\
SELECT * FROM status\
SELECT * FROM trip\
SELECT * FROM weather\
--------------------------------------------------------\
--------------------------------------------------------\
\
--TABLE FORMATTING\
\
ALTER TABLE stations\
RENAME COLUMN id TO station_id\
\
ALTER TABLE trip\
ALTER COLUMN start_date SET DATA TYPE TIMESTAMP USING start_date::timestamp without time zone\
ALTER COLUMN end_date SET DATA TYPE TIMESTAMP USING end_date::timestamp without time zone\
\
ALTER TABLE weather\
DROP COLUMN max_temperature_f,\
DROP COLUMN min_temperature_f,\
DROP COLUMN max_dew_point_f, \
DROP COLUMN mean_dew_point_f, \
DROP COLUMN min_dew_point_f, \
DROP COLUMN max_sea_level_pressure_inches, \
DROP COLUMN mean_sea_level_pressure_inches, \
DROP COLUMN min_sea_level_pressure_inches\
DROP COLUMN max_humidity,\
DROP COLUMN min_humidity,\
DROP COLUMN max_visibility_miles,\
DROP COLUMN mean_visibility_miles,\
DROP COLUMN min_visibility_miles,\
DROP COLUMN max_wind_speed_mph,\
DROP COLUMN max_gust_speed_mph,\
DROP COLUMN wind_dir_degrees,\
DROP COLUMN min_temperature_f,\
--------------------------------------------------------\
--------------------------------------------------------\
\
--1/ STATIONS\
SELECT COUNT(name), city\
FROM stations\
GROUP BY city\
ORDER BY COUNT(name)  DESC\
-- Results: 35 in SF, 16 in San Jose, 7 in Redwood City, Mountain View, 5 Palo Alto\
\
--------------------------------------------------------\
--------------------------------------------------------\
\
--2/ STATUS\
/* Utilisation rate Assumption: docks available demonstrate usage of the bikes placed there, and is used as the basis of \
the calculation (a more detailed calculation will come later with the trips table) */\
SELECT * FROM status\
--cleaning for Power BI export\
WITH changes AS (\
  SELECT\
    station_id,\
    bikes_available,\
    docks_available,\
    time,\
    LAG(bikes_available) OVER (PARTITION BY station_id ORDER BY time) AS prev_bikes_available,\
    LAG(docks_available) OVER (PARTITION BY station_id ORDER BY time) AS prev_docks_available\
  FROM\
    your_table\
)\
SELECT\
  station_id,\
  bikes_available,\
  docks_available,\
  time\
FROM\
  changes\
WHERE\
   bikes_available != prev_bikes_available\
  OR docks_available != prev_docks_available\
  OR prev_bikes_available IS NULL\
ORDER BY\
  station_id, time;\
SELECT * FROM stations\
SELECT station_id, ROUND(AVG(bikes_available),1)AS Average_Av_Bikes, EXTRACT(YEAR from time)\
FROM status\
GROUP BY EXTRACT(YEAR from time), station_id\
ORDER BY EXTRACT(YEAR from time) ASC, ROUND(AVG(bikes_available),1)\
\
--Performance Analysis\
-- Logic: success is defined by a low number of bikes available in the station, as this reflect that the said bikes are being used by users.\
-- Assumption is that the bikes are regularly redistributed between the stations.\
SELECT station_id, (ROUND(100*(ROUND(AVG(bikes_available),1))/stations.dock_count),1) AS Perc_Av_Bikes, \
TO_CHAR(time, 'YYYY/MM') AS Month\
-- EXTRACT (YEAR from time) AS Year \
FROM status\
NATURAL JOIN stations\
GROUP BY TO_CHAR(time, 'YYYY/MM'), station_id\
-- GROUP BY EXTRACT (YEAR from time), station_id\
ORDER BY TO_CHAR(time, 'YYYY/MM'), (ROUND(100*(ROUND(AVG(bikes_available),1))/stations.dock_count),1)\
-- ORDER BY EXTRACT (YEAR from time),(ROUND(100*(ROUND(AVG(bikes_available),1))/stations.dock_count),1)\
\
\
/*Results: User behaviour changed between 2013 and 2014 as most used stations (Adjust the code to replace the TO_CHAR with the EXTRACT lines)\
changed from 6-7-8-9 to 9-7-8-6-5 in DESC order.\
Overall usage also increased by 3.75% in the most used stations */\
\
--2/ Service Utilisation Seasonality Analysis, by station, by city\
SELECT \
	ROUND(100*(AVG(docks_available)/(AVG(docks_available)+AVG(bikes_available))),2) AS Utilisation_Rate,\
	'Q'|| TO_CHAR(time, 'Q') as quarter,\
	EXTRACT (month from time) as month,\
	station_id,\
	stations.city\
FROM status\
NATURAL JOIN stations\
GROUP BY\
ROLLUP('Q'|| TO_CHAR(time, 'Q'),\
EXTRACT (month from time)),\
stations.city, stations.station_id\
ORDER BY 2,3 ASC, 1 DESC\
\
SELECT \
	ROUND(100*(AVG(docks_available)/(AVG(docks_available)+AVG(bikes_available))),2) AS Utilisation_Rate, season,\
	EXTRACT (month from time) as month,\
	station_id,\
	stations.city\
FROM (SELECT *,\
CASE\
	WHEN EXTRACT(month FROM time) IN (12,1,2) THEN 'Winter'\
	WHEN EXTRACT(month FROM time) IN (3,4,5) THEN 'Spring'\
	WHEN EXTRACT(month FROM time) IN (6,7,8) THEN 'Summer'\
	WHEN EXTRACT(month FROM time) IN (9,10,11) THEN 'Autumn'\
	END AS Season\
	FROM status) as season\
NATURAL JOIN stations\
GROUP BY season.season,\
EXTRACT (month from time), stations.city, stations.station_id\
ORDER BY 1 DESC\
\
--Seasonality by station, by city\
SELECT \
	ROUND(100*(AVG(docks_available)/(AVG(docks_available)+AVG(bikes_available))),2) AS Utilisation_Rate,\
	season,\
	stations.city,\
	stations.station_id\
FROM (SELECT *,\
CASE\
	WHEN EXTRACT(month FROM time) IN (12,1,2) THEN 'Winter'\
	WHEN EXTRACT(month FROM time) IN (3,4,5) THEN 'Spring'\
	WHEN EXTRACT(month FROM time) IN (6,7,8) THEN 'Summer'\
	WHEN EXTRACT(month FROM time) IN (9,10,11) THEN 'Autumn'\
	END AS Season\
	FROM status) as season\
NATURAL JOIN stations\
GROUP BY stations.city, season.season, stations.station_id\
ORDER BY 4 ASC, 1 DESC\
/* User behaviour affected by seasonability with a peak in Summer in 56.20% usage overall, and drop in Autumn-Winter 47.13% and 47.44%.\
This user behaviour pattern is found for all stations (drop stations.station_id in SELECT, GROUP BY and ORDER BY clauses for summary) */\
\
-- Seasonality Details: Utilisation by month\
SELECT \
ROUND(100*(AVG(docks_available)/(AVG(docks_available)+AVG(bikes_available))),2) AS Utilisation_Rate,\
EXTRACT (month from time) as month,\
stations.city\
FROM status\
NATURAL JOIN stations\
GROUP BY\
EXTRACT (month from time),\
stations.city\
ORDER BY 1 DESC\
-- Results: User behaviour: peak of usage in August with 56.2%. Lowest service usage in November with 45.77%.\
\
--Service Utilisation Weekday/weekends by city, by station\
SELECT \
	ROUND(100*(AVG(docks_available)/(AVG(docks_available)+AVG(bikes_available))),2) AS Utilisation_Rate,\
	Day_Week,\
	stations.city,\
	stations.station_id\
FROM (SELECT *,\
	CASE\
	WHEN\
	EXTRACT(DOW from time) BETWEEN 1 AND 5 THEN 'Weekday'\
	ELSE 'Weekend'\
	END AS Day_Week\
	FROM status) as Day_Week\
NATURAL JOIN stations\
GROUP BY stations.city, Day_Week, stations.station_id\
ORDER BY 1 DESC, 4 ASC\
\
/*Results: Taking into account weekend vs weekend usage (weekend rate /2days; weekday rate/5days), the daily utilisation rates remain higher during the weekend.*/\
\
--2/ Service Utilisation Summary by year, by city\
\
SELECT EXTRACT (YEAR FROM time) as YEAR, \
	ROUND(100*(AVG(docks_available)/(AVG(docks_available)+AVG(bikes_available))),2) AS Utilisation_Rate, stations.city\
FROM status\
JOIN stations\
	ON stations.id=status.station_id\
GROUP BY stations.city, EXTRACT (YEAR FROM time)\
ORDER BY EXTRACT (YEAR FROM time),  Utilisation_Rate DESC\
\
--------------------------------------------------------\
--------------------------------------------------------\
-- 3/ TRIPS\
-- Trips data overview : trip duration, user types\
SELECT ROUND((AVG(duration)/60),0)\
FROM trip\
-- Result: average duration 18 minutes.\
\
SELECT COUNT(subscription_type)\
FROM trip\
WHERE subscription_type!='Subscriber'\
--WHERE subscription_type='Subscriber'\
\
-- Results: vast majority of Subscribers vs Customers\
\
--Most used start stations across dataset\
SELECT\
	start_station_name, stations.city,\
	COUNT(start_station_id) as count,\
	ROUND(100*COUNT(start_station_id)/SUM(COUNT(start_station_id)) OVER (),2) AS share_all_trips\
FROM trip\
LEFT JOIN stations\
	ON stations.station_id=trip.start_station_id\
GROUP BY start_station_name, stations.city\
ORDER BY share_all_trips DESC\
LIMIT 10\
\
-- Top 10 start_station per city (min/max)\
WITH Top10Start AS\
	(SELECT\
	start_station_name, stations.city,\
	COUNT(start_station_id) as count,\
	ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS Share_all_trips,\
	ROW_NUMBER() OVER (Partition BY stations.city ORDER BY COUNT(*) DESC) AS rn\
	FROM trip\
	LEFT JOIN stations\
	ON stations.station_id=trip.start_station_id\
	GROUP BY start_station_name, stations.city)\
SELECT *\
FROM Top10Start\
WHERE rn <=10 \
	--AND Top10Start.city='San Francisco'\
	AND Top10Start.city='San Jose'\
	--AND Top10Start.city='Mountain View'\
	--AND Top10Start.city='Palo Alto'\
	--AND Top10Start.city='Redwood City'\
ORDER BY share_all_trips DESC\
-- Results: Adjust the filter in the code in the WHERE AND clause\
\
--Most used end stations across dataset\
SELECT\
	end_station_name, stations.city,\
	COUNT(end_station_id) as count,\
	ROUND(100*COUNT(end_station_id)/SUM(COUNT(end_station_id)) OVER (),2) AS share_all_trips\
FROM trip\
LEFT JOIN stations\
	ON stations.station_id=trip.end_station_id\
GROUP BY end_station_name, stations.city\
ORDER BY share_all_trips DESC\
LIMIT 10\
\
WITH Top10End AS\
	(SELECT\
	end_station_name, stations.city,\
	COUNT(end_station_id) as count,\
	ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS Share_all_trips,\
	ROW_NUMBER() OVER (Partition BY stations.city ORDER BY COUNT(*) DESC) AS rn\
	FROM trip\
	LEFT JOIN stations\
	ON stations.station_id=trip.end_station_id\
	GROUP BY end_station_name, stations.city)\
SELECT *\
FROM Top10End\
WHERE rn <=10 \
	--AND Top10End.city='San Francisco'\
	--AND Top10End.city='San Jose'\
	--AND Top10End.city='Mountain View'\
	--AND Top10End.city='Palo Alto'\
	--AND Top10End.city='Redwood City'\
ORDER BY share_all_trips DESC\
\
-------------------------------------------------------\
--Top trips overall, by city, on weekends/weekdays\
\
SELECT t.start_station_name, start.city AS start_city, t.end_station_name, e.city AS end_city, COUNT(*)\
FROM trip t\
LEFT JOIN stations AS start\
	ON  t.start_station_id = start.station_id\
LEFT JOIN stations AS e\
	ON t.end_station_id = e.station_id\
--WHERE start.city = 'San Jose' OR e.city ='San Jose'\
--WHERE start.city = 'Mountain View' OR e.city = 'Mountain View'\
--WHERE start.city = 'Palo Alto' OR e.city = 'Palo Alto'\
--WHERE start.city = 'Redwood City' OR e.city = 'Redwood City'\
GROUP BY t.start_station_name, start.city, t.end_station_name, e.city\
ORDER BY COUNT(*) DESC\
LIMIT 10\
\
/* Results: all favored trips are intra-city rather than inter-city trips. Bikes do not seem to be a \
favored mean of transport for such trips although the cities mentionned touch each other */\
\
-- User behaviour: Most popular trips overall, and on weekends/weekdays\
\
\
/* Results: Top 10 results (without WHERE filtering) show that all most popular trips are conducted during weekdays, demonstrating repetitive patterns \
(ie from/to workplace). This could also explain why all the trop 10 figures are relatively high figures, and some end_station_names are especially \
populars (ie buisness districs). Hence, six of the top 10 stations are along the Townsend (Townsend at 7th, Townsend at 4th, 2nd at Townsend).\
This could explain why none of these trips are conducted on the weekends as the latter tend to be less bound to obligations, and more flexible. \
Weekend trips (with the WHERE filtering) confirm this hypothesis as the most popular trip reaches only 1/5th of the most popular weekday trip.\
Let's test these hypothesis with checking the departure times for the weekdays/weekends trips.*/\
\
SELECT Top_trips.start_station_name, Top_trips.start_city, Top_trips.end_station_name, Top_trips.end_city, \
Top_trips.Day_Week,  Top_trips.trip_count,\
TO_CHAR(TO_TIMESTAMP(AVG(EXTRACT(EPOCH FROM t.start_date)))::time, 'HH') AS avg_departure_time\
FROM(\
SELECT Day_Week.start_station_name, start.city AS start_city,  Day_Week.end_station_name, \
	e.city AS end_city, Day_Week, COUNT(*) AS trip_count\
	--MIN(Day_Week.start_date) OVER (PARTITION BY Day_week.start_station_name, Day_Week.end_station_name, \
	--Day_Week.Day_Week, start.city, e.city) AS departure_time\
\
	FROM (SELECT *,\
		CASE\
		WHEN\
		EXTRACT(DOW from start_date) BETWEEN 1 AND 5 THEN 'Weekday'\
		ELSE 'Weekend'\
		END AS Day_Week\
		FROM trip) as Day_Week\
		\
	LEFT JOIN stations AS start\
		ON  Day_Week.start_station_id = start.station_id\
	LEFT JOIN stations AS e\
		ON Day_Week.end_station_id = e.station_id\
		\
	--WHERE  Day_Week = 'Weekend'\
	GROUP BY Day_Week, Day_Week.start_station_name, start.city, Day_Week.end_station_name, e.city) AS Top_trips\
LEFT JOIN trip t\
ON t.start_station_name=Top_trips.start_station_name\
\
GROUP BY Top_trips.start_station_name, Top_trips.start_city, Top_trips.end_station_name, Top_trips.end_city, \
Top_trips.Day_Week,  Top_trips.trip_count\
ORDER BY trip_count DESC\
LIMIT 10\
\
\
-- Identifying technical issues in the trips:\
SELECT id, duration, start_date, start_station_name, start_station_id,end_date, end_station_name, end_station_id\
FROM trip\
WHERE duration <=(60*3)\
AND start_station_id=end_station_id\
\
-- Identify stations with issues (more than x technical issues in a day/week(month))\
SELECT COUNT(subquery.id), DATE(start_date), start_station_name\
FROM (SELECT id, duration, start_date, start_station_name, start_station_id, end_station_name, end_station_id\
FROM trip\
WHERE duration <=(60*3)\
AND start_station_id=end_station_id) AS subquery\
GROUP BY DATE(start_date), start_station_name\
HAVING COUNT (id) > 2\
\
\
-- Impact weather on trips\
SELECT * FROM weather\
SELECT COUNT(id) AS Number_trips, s.city, DATE(start_date), w.events\
FROM trip t\
JOIN stations s\
ON s.station_id=t.start_station_id\
LEFT JOIN weather w\
ON w.date=t.start_date\
GROUP BY s.city, DATE(start_date), w.events}