
-- Quick visual inspection to verify schema, data types, and obvious anomalies.

SELECT TOP 20 * 
FROM marketing_AB
ORDER BY UserID


-- Confirm total row count using the row_index column.
SELECT COUNT(row_index) AS Row_index_num
FROM marketing_AB



-- Verify row_index uniqueness 
SELECT 
	row_index
	,COUNT(row_index)
FROM marketing_AB
GROUP BY row_index
HAVING COUNT(row_index) != 1;


-- Ensure each user appears only once in the dataset.

SELECT
	UserID
	,COUNT(UserID) 
FROM marketing_AB
GROUP BY UserID
HAVING COUNT(UserID) != 1 


-- Compare key statistics between test and control groups for major imbalances.

SELECT 
	test_group
	,COUNT(UserID) UsersNumber
	,SUM(CAST (converted AS int)) Converted_Users
	,AVG(Total_ads) AS Avg_Ads_PerUser
	,MAX(CAST(converted AS int)) AS Max_Converted
	,AVG(CAST(converted AS DECIMAL)) AS Avg_converted
	,MIN(CAST(converted AS int)) AS MIN_Converted
	,MAX(Total_ads) AS Max_User_Ads
	,MIN(Total_ads) AS Min_user_ads
	,MAX(most_ads_hour) AS Max_mah
	,Min(Most_ads_hour) AS Min_mah
FROM marketing_AB
GROUP BY test_group


-- Confirm conversion flag contains only valid binary values.

SELECT 
	DISTINCT(converted)
FROM marketing_AB;

-----------------------------------------------------------------------
------ Checking Sample distribution fairness between the two groups
------------------------------------------------------------------------

-- Verify weekday distribution is balanced between test and control groups.
SELECT 
    ad_results.Most_ads_day,
    ad_results.pct AS test_pct,
    psa_results.pct AS control_pct,
    ABS(ad_results.pct - psa_results.pct) AS pct_diff
FROM (
    -- Subquery for the 'ad' group
    SELECT 
        Most_ads_day,
        (COUNT(*) * 100.0) / (SELECT COUNT(*) FROM Marketing_AB WHERE test_group = 'ad') AS pct
    FROM Marketing_AB
    WHERE test_group = 'ad'
    GROUP BY Most_ads_day
) ad_results
INNER JOIN (
    -- Subquery for the 'psa' group
    SELECT 
        Most_ads_day,
        (COUNT(*) * 100.0) / (SELECT COUNT(*) FROM Marketing_AB WHERE test_group = 'psa') AS pct
    FROM Marketing_AB
    WHERE test_group = 'psa'
    GROUP BY Most_ads_day
) psa_results 
ON ad_results.Most_ads_day = psa_results.Most_ads_day
ORDER BY pct_diff DESC;


-- Verify Most_ads_hour distribution is balanced between test and control groups.
WITH GroupTotals AS (
    SELECT test_group, COUNT(*) AS total_count
    FROM Marketing_AB
    GROUP BY test_group
),
HourDistribution AS (
    SELECT 
        test_group,
        most_ads_hour,
        COUNT(*) AS sample_count
    FROM Marketing_AB
    GROUP BY test_group, most_ads_hour
)
SELECT 
    h.most_ads_hour,
    MAX(CASE WHEN h.test_group = 'ad' THEN CAST(h.sample_count AS FLOAT) / gt.total_count END) * 100 AS test_pct,
    MAX(CASE WHEN h.test_group = 'psa' THEN CAST(h.sample_count AS FLOAT) / gt.total_count END) * 100 AS control_pct,
    ABS(
        MAX(CASE WHEN h.test_group = 'ad' THEN CAST(h.sample_count AS FLOAT) / gt.total_count END) - 
        MAX(CASE WHEN h.test_group = 'psa' THEN CAST(h.sample_count AS FLOAT) / gt.total_count END)
    ) * 100 AS pct_diff
FROM HourDistribution h
JOIN GroupTotals gt ON h.test_group = gt.test_group
GROUP BY h.most_ads_hour
ORDER BY h.most_ads_hour ASC; -- Ordered by time to see the daily trend



-- Confirm average ad exposure is comparable between groups.
 WITH Stats AS (
    SELECT 
        test_group,
        AVG(total_ads) AS avg_ads,
        MAX(total_ads) AS max_ads,
        COUNT(*) AS user_count
    FROM Marketing_AB
    GROUP BY test_group
)
SELECT 
    MAX(CASE WHEN test_group = 'ad' THEN avg_ads END) AS test_avg_ads,
    MAX(CASE WHEN test_group = 'psa' THEN avg_ads END) AS control_avg_ads,
    -- Calculate the percentage difference in exposure
    (MAX(CASE WHEN test_group = 'ad' THEN avg_ads END) - 
     MAX(CASE WHEN test_group = 'psa' THEN avg_ads END)) / 
     NULLIF(MAX(CASE WHEN test_group = 'psa' THEN avg_ads END), 0) * 100 AS pct_avg_diff,
    -- Check for outliers
    MAX(CASE WHEN test_group = 'ad' THEN max_ads END) AS test_max_seen,
    MAX(CASE WHEN test_group = 'psa' THEN max_ads END) AS control_max_seen
FROM Stats;




-- Compare exposure percentiles to detect skew or extreme outliers.
SELECT 
    percentile,
    MAX(CASE WHEN test_group = 'ad' THEN total_ads END) AS ad_max_at_percentile,
    MAX(CASE WHEN test_group = 'psa' THEN total_ads END) AS psa_max_at_percentile
FROM (
    SELECT 
        test_group,
        total_ads,
        NTILE(100) OVER (PARTITION BY test_group ORDER BY total_ads) AS percentile
    FROM Marketing_AB
) AS subquery
WHERE percentile IN (25, 50, 75, 95, 99)
GROUP BY percentile
ORDER BY percentile;



---------------------------------------------------------------------
----------- Evaluate Test Result 
-------------------------------------------------------------------------------------
---------- Converstion rate between the two ads version
/* The new ad have %70 more converstion rate */
WITH conv_rate AS (
    SELECT
        test_group,
        AVG(CAST(converted AS FLOAT)) AS conv_rate
    FROM marketing_AB
    GROUP BY test_group
)
SELECT
    ROUND(ad.conv_rate * 100,4)AS new_ad_conv,
    ROUND(psa.conv_rate * 100,4) AS old_ad_conv,
    ROUND((ad.conv_rate - psa.conv_rate) * 100,4) AS absolute_lift_pct,
    ROUND(((ad.conv_rate - psa.conv_rate) / psa.conv_rate),4) * 100 AS relative_lift_pct
FROM conv_rate ad
JOIN conv_rate psa
    ON ad.test_group = 'ad'
   AND psa.test_group = 'psa';



--- Check 'Most ads day' Column
/* We can a that monday and Tuesday have a slightly advantage on the convertsion rate compare to other week days

*/
SELECT 
	most_ads_day
	,COUNT(UserID) AS NumberOfUser
	,SUM(CAST(Converted AS INT)) AS ConvertedUsers
	,ROUND(SUM(CAST(Converted AS decimal))/COUNT(UserID),3) AS ConvertedPercentate
FROM marketing_AB
GROUP BY most_ads_day;


-- Now let's check if time of day affects how well our ads convert compared to the control group

WITH DayTime AS (
SELECT 
        CASE
            WHEN most_ads_hour BETWEEN 0 AND 5 THEN 'Late Night'
            WHEN most_ads_hour BETWEEN 6 AND 11 THEN 'Morning'
            WHEN most_ads_hour BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN most_ads_hour BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'NA'
        END AS Time_of_Day,
        -- AD Group Metrics
        SUM(CASE WHEN test_group = 'ad' THEN 1 ELSE 0 END) AS Ad_Users,
        SUM(CASE WHEN test_group = 'ad' AND converted = 1 THEN 1 ELSE 0 END) AS Ad_Conversions,
        
        -- PSA Group Metrics
        SUM(CASE WHEN test_group = 'psa' THEN 1 ELSE 0 END) AS Psa_Users,
        SUM(CASE WHEN test_group = 'psa' AND converted = 1 THEN 1 ELSE 0 END) AS Psa_Conversions
    FROM marketing_AB
    GROUP BY CASE
            WHEN most_ads_hour BETWEEN 0 AND 5 THEN 'Late Night'
            WHEN most_ads_hour BETWEEN 6 AND 11 THEN 'Morning'
            WHEN most_ads_hour BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN most_ads_hour BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'NA'
        END )
SELECT 
    Time_of_Day
    ,Ad_users 
    ,psa_users
    ,Ad_Conversions
    ,psa_Conversions
    ,ROUND(CAST(psa_Conversions AS float) / psa_Users,4)*100 AS psa_Conv_pct
    ,ROUND(CAST (Ad_Conversions AS float) / Ad_Users,4) * 100  AS Ad_Conv_pct
    ,ROUND(CAST (Ad_Conversions AS float) / Ad_Users,4)   / ROUND(CAST(psa_Conversions AS float) / psa_Users,4) AS lift_index
FROM DayTime
WHERE Time_of_Day != 'Late Night'; ---- due to lake of enogh samples;







--------------------------------------------------------------------------------
-- AD VS. PSA LIFT ANALYSIS: By ** WEEK DAY **
-- Goal: Identify incremental conversion lift by comparing Test (Ad) vs. Control (PSA).
-- Performance_Index > 1.0 indicates the ad group outperformed the baseline.
--------------------------------------------------------------------------------
WITH DayStats AS (
    SELECT 
        most_ads_day,
        -- AD Group Metrics
        SUM(CASE WHEN test_group = 'ad' THEN 1 ELSE 0 END) AS Ad_Users,
        SUM(CASE WHEN test_group = 'ad' AND converted = 1 THEN 1 ELSE 0 END) AS Ad_Conversions,
        
        -- PSA Group Metrics
        SUM(CASE WHEN test_group = 'psa' THEN 1 ELSE 0 END) AS Psa_Users,
        SUM(CASE WHEN test_group = 'psa' AND converted = 1 THEN 1 ELSE 0 END) AS Psa_Conversions
    FROM marketing_AB
    GROUP BY most_ads_day
)
SELECT 
    most_ads_day,
    Ad_Users,
    Psa_Users,
    -- Conversion Rates (using FLOAT to avoid integer division issues)
    ROUND(CAST(Ad_Conversions AS FLOAT) / NULLIF(Ad_Users, 0) * 100, 4) AS Ad_Conv_Pct,
    ROUND(CAST(Psa_Conversions AS FLOAT) / NULLIF(Psa_Users, 0) * 100, 4) AS Psa_Conv_Pct,
    
    -- THE INSIGHT: Conversion Lift
    -- (Ad Rate - PSA Rate)
    ROUND((CAST(Ad_Conversions AS FLOAT) / NULLIF(Ad_Users, 0)) - 
          (CAST(Psa_Conversions AS FLOAT) / NULLIF(Psa_Users, 0)), 4) * 100 AS Absolute_Lift_Pct,
    
    -- THE INSIGHT: Performance Index
    -- (Ad Rate / PSA Rate). 1.0 means no difference, 1.2 means Ad is 20% better.
    ROUND((CAST(Ad_Conversions AS FLOAT) / NULLIF(Ad_Users, 0)) / 
          NULLIF((CAST(Psa_Conversions AS FLOAT) / NULLIF(Psa_Users, 0)), 0), 4) AS Performance_Index
FROM DayStats
ORDER BY Performance_Index DESC;



--------------------------------------------------------------------------------
-- AD VS. PSA LIFT ANALYSIS: By ** TOTAL ADS **
-- Goal: Identify incremental conversion lift by comparing Test (Ad) vs. Control (PSA).
-- Performance_Index > 1.0 indicates the ad group outperformed the baseline.
--------------------------------------------------------------------------------
WITH ExposureBuckets AS (
    SELECT
        CASE
            WHEN total_ads BETWEEN 1 AND 5 THEN '01–05'
            WHEN total_ads BETWEEN 6 AND 10 THEN '06–10'
            WHEN total_ads BETWEEN 11 AND 20 THEN '11–20'
            WHEN total_ads BETWEEN 21 AND 50 THEN '21–50'
            WHEN total_ads BETWEEN 51 AND 100 THEN '51–100'
            WHEN total_ads BETWEEN 101 AND 200 THEN '101–200'
            WHEN total_ads BETWEEN 201 AND 500 THEN '201–500'
            ELSE '501+'
        END AS Ads_Exposure_Bucket,

        CASE
            WHEN total_ads BETWEEN 1 AND 5 THEN 1
            WHEN total_ads BETWEEN 6 AND 10 THEN 2
            WHEN total_ads BETWEEN 11 AND 20 THEN 3
            WHEN total_ads BETWEEN 21 AND 50 THEN 4
            WHEN total_ads BETWEEN 51 AND 100 THEN 5
            WHEN total_ads BETWEEN 101 AND 200 THEN 6
            WHEN total_ads BETWEEN 201 AND 500 THEN 7
            ELSE 8
        END AS Bucket_Order,

        test_group,
        converted
    FROM marketing_AB
),

BucketStats AS (
    SELECT
        Ads_Exposure_Bucket,
        Bucket_Order,

        COUNT(CASE WHEN test_group = 'ad' THEN 1 END) AS Ad_Users,
        SUM(CASE WHEN test_group = 'ad' AND converted = 1 THEN 1 ELSE 0 END) AS Ad_Conversions,

        COUNT(CASE WHEN test_group = 'psa' THEN 1 END) AS Psa_Users,
        SUM(CASE WHEN test_group = 'psa' AND converted = 1 THEN 1 ELSE 0 END) AS Psa_Conversions
    FROM ExposureBuckets
    GROUP BY Ads_Exposure_Bucket, Bucket_Order
)

SELECT
    Ads_Exposure_Bucket,
    Ad_Users,
    Psa_Users,

    ROUND(100.0 * Ad_Conversions / NULLIF(Ad_Users, 0), 3) AS Ad_Conv_Pct,
    ROUND(100.0 * Psa_Conversions / NULLIF(Psa_Users, 0), 3) AS Psa_Conv_Pct,

    ABS(ROUND(
        100.0 * (
            (CAST(Ad_Conversions AS FLOAT) / NULLIF(Ad_Users, 0)) -
            (CAST(Psa_Conversions AS FLOAT) / NULLIF(Psa_Users, 0))
        ),
        3
    ) )AS Absolute_Lift_Pct,

    ROUND(
        (CAST(Ad_Conversions AS FLOAT) / NULLIF(Ad_Users, 0)) /
        NULLIF((CAST(Psa_Conversions AS FLOAT) / NULLIF(Psa_Users, 0)), 0),
        3
    ) AS Performance_Index
FROM BucketStats
WHERE Ad_Users >= 100
  AND Psa_Users >= 20
ORDER BY Bucket_Order;

/*Ad effectiveness dependson total exposure. At low exposure (1–10 ads), the Ad underperforms the PSA,
likely due to insufficient repetition to influence behavior. Performance converges at 11–20 ads as users 
become familiar with the message. The Ad strongly outperforms the PSA between 21–100 ads, driven by reinforcement 
and message recall, with peak effectiveness at 51–100 ads. Beyond 100 ads, performance plateaus and declines at extreme exposure levels, 
suggesting ad fatigue, saturation, or selection bias.*/