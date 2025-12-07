create or replace TABLE MOTORS.DATASET05.SALE04_SALE04_CLEANED (
YEAR NUMBER(38,0),
MODEL VARCHAR(16777216),
TRIM VARCHAR(16777216),
BODY VARCHAR(16777216),
TRANSMISSION VARCHAR(16777216),
VIN VARCHAR(16777216),
STATE VARCHAR(16777216),
CONDITION NUMBER(38,0),
ODOMETER NUMBER(38,0),
COLOR VARCHAR(16777216),
INTERIOR VARCHAR(16777216),
SELLER VARCHAR(16777216),
MMR FLOAT,
SELLING_PRICE FLOAT,
SALE_DATE DATE,
UNITS_SOLD NUMBER(1,0),
EST_COST FLOAT,
TOTAL_REVENUE FLOAT,
PROFIT_MARGIN FLOAT,
RN NUMBER(18,0)
);
-------------------------------------------

---inserting rows--------------------------

INSERT INTO MOTORS.DATASET05.SALE04_SALE04_CLEANED(
YEAR, MODEL, TRIM, BODY, TRANSMISSION, VIN, STATE, CONDITION,
ODOMETER, COLOR, INTERIOR, SELLER, MMR, SELLING_PRICE, SALE_DATE,
UNITS_SOLD, EST_COST, TOTAL_REVENUE, PROFIT_MARGIN, RN
)
SELECT
TRY_CAST(REGEXP_REPLACE("YEAR", '[^0-9]', '') AS NUMBER) AS YEAR,
MODEL,
TRIM,
BODY,
TRANSMISSION,
VIN,
STATE,
TRY_CAST(REGEXP_REPLACE(CONDITION, '[^0-9]', '') AS NUMBER) AS CONDITION,
TRY_CAST(REGEXP_REPLACE(ODOMETER, '[^0-9]', '') AS NUMBER) AS ODOMETER,
COLOR,
INTERIOR,
SELLER,
TRY_CAST(REGEXP_REPLACE(MMR, '[^0-9.]', '') AS FLOAT) AS MMR,
TRY_CAST(REGEXP_REPLACE(SELLINGPRICE, '[^0-9.]', '') AS FLOAT) AS SELLING_PRICE,
COALESCE(
TRY_TO_DATE(SALEDATE, 'YYYY-MM-DD'),
TRY_TO_DATE(SALEDATE, 'MM/DD/YYYY'),
TRY_TO_DATE(SALEDATE, 'DD-MM-YYYY')
) AS SALE_DATE,
1 AS UNITS_SOLD,
----- Estimate cost-----------------------
CASE
WHEN TRY_CAST(REGEXP_REPLACE(MMR, '[^0-9.]', '') AS FLOAT) IS NOT NULL THEN TRY_CAST(REGEXP_REPLACE(MMR, '[^0-9.]', '') AS FLOAT) * 0.85
ELSE TRY_CAST(REGEXP_REPLACE(SELLINGPRICE, '[^0-9.]', '') AS FLOAT) * 0.7
END AS EST_COST,
------Total revenue(1 car per sale)-------
TRY_CAST(REGEXP_REPLACE(SELLINGPRICE, '[^0-9.]', '') AS FLOAT) AS TOTAL_REVENUE,
------Profit margin-----------------------
CASE
WHEN TRY_CAST(REGEXP_REPLACE(SELLINGPRICE, '[^0-9.]', '') AS FLOAT) > 0 THEN
(TRY_CAST(REGEXP_REPLACE(SELLINGPRICE, '[^0-9.]', '') AS FLOAT) -
CASE
WHEN TRY_CAST(REGEXP_REPLACE(MMR, '[^0-9.]', '') AS FLOAT) IS NOT NULL THEN TRY_CAST(REGEXP_REPLACE(MMR, '[^0-9.]', '') AS FLOAT) * 0.85 ELSE TRY_CAST(REGEXP_REPLACE(SELLINGPRICE, '[^0-9.]', '') AS FLOAT) * 0.7
END ) / TRY_CAST(REGEXP_REPLACE(SELLINGPRICE, '[^0-9.]', '') AS FLOAT) * 100
ELSE NULL
END AS PROFIT_MARGIN,
ROW_NUMBER() OVER (PARTITION BY VIN ORDER BY SALEDATE DESC NULLS LAST) AS RN
FROM MOTORS.DATASET05.SALE04
WHERE SELLINGPRICE IS NOT NULL;
-------------------------------------------

--Keep only uniqui VINs--------------------
CREATE OR REPLACE TABLE MOTORS.DATASET05.SALE04_SALE04_CLEANED AS
SELECT *
FROM MOTORS.DATASET05.SALE04_SALE04_CLEANED
WHERE RN = 1;
-------------------------------------------

--Verify if data loaded correct------------
SELECT *
FROM MOTORS.DATASET05.SALE04_SALE04_CLEANED
LIMIT 10;
-------------------------------------------

--total rows-------------------------------
SELECT COUNT(*) AS total_rows
FROM MOTORS.DATASET05.SALE04_SALE04_CLEANED;
-------------------------------------------

---Top 10 models by total revenue----------
SELECT model, COUNT(*) AS units_sold, SUM(total_revenue) AS total_revenue, AVG(selling_price) AS avg_price
FROM motors.dataset05.sale04_sale04_cleaned
GROUP BY model
ORDER BY total_revenue DESC
LIMIT 10;
-------------------------------------------

---example: extract first word as make-----
SELECT
SPLIT_PART(model, ' ', 1) AS make,
COUNT(*) AS units_sold,
SUM(total_revenue) AS total_revenue,
AVG(selling_price) AS avg_price
FROM motors.dataset05.sale04_sale04_cleaned
GROUP BY make
ORDER BY total_revenue DESC
LIMIT 10;
-------------------------------------------

--Price vs Mileage vs Year
SELECT
CORR(selling_price, odometer) AS corr_price_odometer,
CORR(selling_price, year) AS corr_price_year,
CORR(odometer, year) AS corr_odometer_year
FROM motors.dataset05.sale04_sale04_cleaned
WHERE selling_price IS NOT NULL AND odometer IS NOT NULL AND year IS NOT NULL;
-------------------------------------------

--Sells volome
SELECT state, COUNT(*) AS transactions, SUM(total_revenue) AS total_revenue
FROM motors.dataset05.sale04_sale04_cleaned
GROUP BY state
ORDER BY transactions DESC;
-------------------------------------------

--Monthly revenue trand--------------------
SELECT DATE_TRUNC('month', sale_date) AS month, COUNT(*) AS units_sold, SUM(total_revenue) AS revenue
FROM motors.dataset05.sale04_sale04_cleaned
GROUP BY month
ORDER BY month;
-------------------------------------------

--Emerging trends, fuel, type, body,------ --transamission preferences----------------
SELECT body, COUNT(*) AS units_sold, SUM(total_revenue) AS revenue, AVG(selling_price) avg_price
FROM motors.dataset05.sale04_sale04_cleaned
GROUP BY body
ORDER BY units_sold DESC;
-------------------------------------------

--Top low-odometer high-margin --------------inventory{good for allocation}-----------
SELECT model, year, odometer, selling_price, profit_margin
FROM motors.dataset05.sale04_sale04_cleaned
WHERE profit_margin >= 20
ORDER BY odometer ASC
LIMIT 20;
------------------------------------------

ALTER TABLE MOTORS.DATASET05.SALE04_SALE04_CLEANED
ADD COLUMN MARGIN_TIER VARCHAR(20);

UPDATE MOTORS.DATASET05.SALE04_SALE04CLEANED;
SET MARGIN_TIER =
CASE
WHEN PROFIT_MARGIN >= 20 THEN 'High Margin'
WHEN PROFIT_MARGIN BETWEEN 10 AND 19.99 THEN 'Medium Margin'
ELSE 'Low Margin'
-------------------------------------------

---Model performance-----------------------
CREATE OR REPLACE VIEW MOTORS.DATASET05.V_MODEL_REVENUE AS
SELECT MODEL, SUM(TOTAL_REVENUE) AS TOTAL_REVENUE, AVG(PROFIT_MARGIN) AS AVG_MARGIN
FROM MOTORS.DATASET05.SALE04_SALE04_CLEANED
GROUP BY MODEL;

-- State performance-----------------------
CREATE OR REPLACE VIEW MOTORS.DATASET05.V_STATE_REVENUE AS
SELECT STATE, SUM(TOTAL_REVENUE) AS TOTAL_REVENUE, COUNT(*) AS TRANSACTIONS
FROM MOTORS.DATASET05.SALE04_SALE04_CLEANED
GROUP BY STATE;
-------------------------------------------

UPDATE MOTORS.DATASET05.SALE04_SALE04_CLEANED
SET MARGIN_TIER =
CASE
WHEN PROFIT_MARGIN >= 20 THEN 'High Margin'
WHEN PROFIT_MARGIN BETWEEN 10 AND 19.99 THEN 'Medium Margin'
ELSE 'Low Margin'
END;

-------------------------------------------

SELECT *
FROM MOTORS.DATASET05.SALE04_SALE04_CLEANED;
