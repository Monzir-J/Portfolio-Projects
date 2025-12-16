
--  ;

------------------------------------------------------------------
/*Unit the incorrect text values into NULL to simplify cleaning steps
and turning date into date format for better readability*/
-------------------------------------------------------------------
With dcs_Fixed_Nulls AS (
SELECT 
    Transaction_ID
    , CASE 
        WHEN Item IN ('UNKNOWN','ERROR') THEN NULL
        ELSE Item
        END AS Item_name
    ,Quantity
    ,Price_Per_Unit
    ,Total_Spent
    ,CASE 
        WHEN Payment_Method IN ('UNKNOWN','ERROR') THEN NULL
        ELSE Payment_Method
        END AS Payment_Method
    ,CASE 
        WHEN [Location] IN ('UNKNOWN','ERROR') THEN NULL
        ELSE [Location]
        END AS [Location]
    ,CAST( Transaction_Date AS date) AS Transaction_Date
FROM dirty_cafe_sales)
--- Test Code
--SELECT * FROM dcs_Fixed_Nulls


--- This CTE establishes the correct mapping between Price_Per_Unit and Item
, Price_Map AS (
    SELECT
       MAX(Item_name) AS Item_name,-- MAX() to avoid items that share the same price
       Price_Per_Unit AS Item_Price
   FROM dcs_Fixed_Nulls
    WHERE Price_Per_Unit IS NOT NULL
    GROUP BY Price_Per_Unit
)
-- Test Code
--SELECT * FROM Price_Map;

------------------------------------------------------------------
--- Fixing Item column
-------------------------------------------------------------------
,Cleaned_item_tb AS (
SELECT
    dcs.*,
    CASE
        WHEN dcs.Item_name IS NULL
        THEN pm.Item_name -- Use the mapped name for messy entries
        ELSE dcs.Item_name  -- Keep the original, correct name for clean entries
    END AS Cleaned_Item
FROM
    dcs_Fixed_Nulls AS dcs
LEFT JOIN
    Price_Map AS pm ON dcs.Price_Per_Unit = pm.Item_Price
    )
-- Test Code
/*SELECT 
    Cleaned_Item
    ,COUNT(Transaction_ID) AS Tran_Num
FROM Cleaned_item_tb
GROUP BY Cleaned_Item*/


------------------------------------------------------------------
--- Fixing Price_Per_Unit Column
-------------------------------------------------------------------
, Price_Map_v2 AS
(SELECT
    Item_name AS Item_names,
    MAX(Price_Per_Unit) AS Item_Price
FROM Cleaned_item_tb
GROUP BY Item_name)
--Test Code
/*SELECT * 
FROM Price_Map_v2
ORDER BY Item_Price DESC*/

-------- Cleaning Price Per Unit column
,Cleaned_PPU AS 
(SELECT 
    cit.*
    ,CASE 
        WHEN Cit.Price_Per_Unit IS NULL THEN pm.Item_Price
        ELSE Cit.Price_Per_Unit
        END AS Cleaned_Price_Per_Unit
FROM Cleaned_item_tb AS Cit
LEFT JOIN Price_Map_v2 AS pm ON cit.Item_name = pm.Item_names)
-- Test Code
/*SELECT *
FROM Cleaned_PPU
WHERE Cleaned_Price_Per_Unit IS NULL*/
--WHERE Total_Spent IS NOT NULL

------------------------------------------------------------------
--- Fixing Quantity Column
-------------------------------------------------------------------
, Cleaned_Quantity AS 
(SELECT 
    Transaction_ID
    ,Cleaned_Item
    ,CASE 
        WHEN Quantity IS NULL THEN Total_Spent/Cleaned_Price_Per_Unit
        ELSE Quantity
        END AS Cleaned_Quantity
    ,Cleaned_Price_Per_Unit
    ,Total_Spent
    ,Payment_Method
    ,Location
    ,Transaction_Date
FROM Cleaned_PPU
WHERE NOT (Total_Spent IS NULL AND Quantity IS  NULL)
)
--- TEST RESULT
/*SELECT * 
FROM Cleaned_Quantity
WHERE Cleaned_Quantity IS NULL*/

------------------------------------------------------------------
--- Fixing Total Spent Column
-------------------------------------------------------------------
, Cleaned_TotalSpent_tb AS 
(SELECT 
    *
    ,CASE
        WHEN Total_Spent IS NULL THEN Cleaned_Quantity*Cleaned_Price_Per_Unit
        ELSE Total_Spent
        END AS Cleaned_Total_Spent
FROM Cleaned_Quantity)


--- Test Code

/*SELECT 
    * 
FROM Cleaned_TotalSpent_tb
WHERE Cleaned_Total_Spent IS NULL*/


------------------------------------------------------------------
--- Fixing Payment Method 
-------------------------------------------------------------------




------------------------------------------------------------------
--- Filling NULL values in Payment_Method, Location
-------------------------------------------------------------------
--- This approach filling missing values based on the propotional distribution

-- STEP 1: Analyze current distribution of Payment_Method
, payment_method_distribution AS (
    SELECT 
        Payment_Method,
        COUNT(*) as count,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
    FROM Cleaned_TotalSpent_tb
    WHERE Payment_Method IS NOT NULL
    GROUP BY Payment_Method
)

-- Test Code
--SELECT * FROM payment_method_distribution


-- STEP 2: Analyze current distribution of Location
-- ============================================================================
,location_distribution AS (
    SELECT 
        Location,
        COUNT(*) as count,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
    FROM Cleaned_TotalSpent_tb
    WHERE Location IS NOT NULL
    GROUP BY Location
)

-- Test Code 
--SELECT * FROM location_distribution


-- STEP 3: Assign row numbers to NULL Payment_Method records
-- ============================================================================
,payment_method_nulls AS (
    SELECT 
        Transaction_ID,
        ROW_NUMBER() OVER (ORDER BY Transaction_ID) as rn,
        COUNT(*) OVER () as total_nulls
    FROM Cleaned_TotalSpent_tb
    WHERE Payment_Method IS NULL
)

-- Test Code
--SELECT * FROM payment_method_nulls


-- STEP 4: Assign row numbers to NULL Location records
-- ============================================================================
, location_nulls AS (
    SELECT 
        Transaction_ID,
        ROW_NUMBER() OVER (ORDER BY Transaction_ID) as rn,
        COUNT(*) OVER () as total_nulls
    FROM Cleaned_item_tb
    WHERE Location IS NULL
)

-- Test Code
--SELECT * FROM location_nulls

-- STEP 5: Fill Payment_Method based on proportional distribution
-- ============================================================================
-- Distribution: Digital Wallet (33.56%), Credit Card (33.31%), Cash (33.12%)
-- Total NULLs: 3170
-- Allocation: Digital Wallet=1063, Credit Card=1056, Cash=1051
, payment_method_filled AS (
    SELECT 
        t.*,
        CASE 
            WHEN t.Payment_Method IS NOT NULL THEN t.Payment_Method
            WHEN pn.rn <= 1063 THEN 'Digital Wallet'  -- First 33.56% (1063 records)
            WHEN pn.rn <= 2119 THEN 'Credit Card'     -- Next 33.31% (1056 records)
            ELSE 'Cash'                                -- Remaining 33.12% (1051 records)
        END as Payment_Method_Filled
    FROM Cleaned_TotalSpent_tb AS t
    LEFT JOIN payment_method_nulls pn ON t.Transaction_ID = pn.Transaction_ID
)
-- Test code
/*SELECT 
    Payment_Method_Filled
    ,COUNT(*) As Total
    ,COUNT(*)*100.0/ SUM(COUNT(*)) over() AS [Percentage] -- The original percentage didn't change 
FROM payment_method_filled
GROUP BY Payment_Method_Filled*/


-- STEP 6: Fill Location based on proportional distribution
-- ============================================================================
-- Distribution: Takeaway (50.08%), In-store (49.92%)
-- Total NULLs: 3953
-- Allocation: Takeaway=1979, In-store=1974
,location_filled AS (
    SELECT 
        pmf.*,
        CASE 
            WHEN pmf.Location IS NOT NULL THEN pmf.Location
            WHEN ln.rn <= 1979 THEN 'Takeaway'  -- First 50.08% (1979 records)
            ELSE 'In-store'                      -- Remaining 49.92% (1974 records)
        END as Location_Filled
    FROM payment_method_filled pmf
    LEFT JOIN location_nulls ln ON pmf.Transaction_ID = ln.Transaction_ID
)
-- Test code
/*SELECT 
    Location_Filled
    ,COUNT(*) As Total
    ,COUNT(*)*100.0/ SUM(COUNT(*)) over() AS [Percentage] -- The original percentage didn't change 
FROM location_filled
GROUP BY Location_Filled*/
--SELECT * FROM location_filled

---------------------------------------------------------
------- Saving results into table for Query optimization
----------------------------------------------------------
SELECT 
    Transaction_ID,
    Cleaned_Item AS Item_name,
    Cleaned_Quantity AS Quantity,
    Cleaned_Price_Per_Unit AS Price_Per_Unit,
    Cleaned_Total_Spent AS Total_Spent,
    Payment_Method_Filled as Payment_Method,
    Location_Filled as Location,
    Transaction_Date
INTO Cleaned_Dirty_Cafe_Sales
FROM location_filled;
/*WHERE 
    Cleaned_Item IS NULL 
    OR Cleaned_Quantity IS NULL
    OR Cleaned_Price_Per_Unit IS NULL
    OR Total_Spent IS NULL
    OR Transaction_Date IS NULL
ORDER BY Cleaned_Quantity, Cleaned_Price_Per_Unit, Total_Spent, Transaction_DAte ASC*/

-- Test Table 
--SELECT * FROM Cleaned_Dirty_Cafe_Sales



/*
This query selects all your data.
It uses a CTE to generate a new column 'filled_transaction_date'
where any NULL date is replaced with a random date from 2023.
*/

WITH FilledDatesCTE AS
(
    SELECT
        Transaction_ID,
        Item_name,
        quantity,
        Price_Per_Unit,
        Total_Spent,
        Payment_Method,
        Location,
        transaction_date,

        -- Use COALESCE to pick the first non-null value.
        -- 1. If transaction_date exists, use it.
        -- 2. If it's NULL, use the randomly generated date.
        COALESCE(
            transaction_date, 
            DATEADD(day, ABS(CHECKSUM(NEWID())) % 365, '2023-01-01')
        ) AS filled_transaction_date
    FROM
        Cleaned_Dirty_Cafe_Sales  -- <-- Replace with your actual table name
    WHERE Item_name IS NOT NULL
)

-- Select from the CTE to see the results

------------------------------------------------------------------
--- Save Final result into a table
-------------------------------------------------------------------
SELECT 
    Transaction_ID,
    item_name,
    quantity,
    Price_Per_Unit,
    Total_spent,
    Payment_Method,
    Location,
        filled_transaction_date AS transaction_date 
        INTO Cleaned_Cafe_Sales-- This column now has no NULLs
    FROM 
        FilledDatesCTE


---------------------------------------------------------------------
----------- Testing the new data:
---------------------------------------------------------------------




