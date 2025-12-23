/* 02_load_and_clean.sql
   Project: Retail Sales Analysis – Holidays & Promotional Markdowns
   Purpose: Load raw CSVs into staging tables, clean data, and build final analysis tables
*/

USE walmart_sales;

DROP TABLE IF EXISTS stores_raw;
DROP TABLE IF EXISTS store_features_raw;
DROP TABLE IF EXISTS store1_raw;
DROP TABLE IF EXISTS store12_raw;
DROP TABLE IF EXISTS store45_raw;

CREATE TABLE stores_raw 
(
  store INT,
  type CHAR(1),
  size INT
);

CREATE TABLE store_features_raw 
(
  store INT,
  date VARCHAR(20),
  temperature VARCHAR(20),
  fuel_price VARCHAR(20),
  markdown1 VARCHAR(20),
  markdown2 VARCHAR(20),
  markdown3 VARCHAR(20),
  markdown4 VARCHAR(20),
  markdown5 VARCHAR(20),
  isholiday VARCHAR(10)
);

CREATE TABLE store1_raw 
(
  store INT,
  dept INT,
  date VARCHAR(20),
  weekly_sales VARCHAR(30),
  isholiday VARCHAR(10)
);

CREATE TABLE store12_raw LIKE store1_raw;
CREATE TABLE store45_raw LIKE store1_raw;


/* B) Clean and load final tables: stores / features / sales */
USE walmart_sales;

-- 1) Load stores (overwrite existing data)
TRUNCATE TABLE stores;

INSERT INTO stores (store, type, size)
SELECT store, type, size
FROM stores_raw;

-- 2) Clean and load features
TRUNCATE TABLE features;

INSERT INTO features 
(
  store, date, temperature, fuel_price,
  markdown1, markdown2, markdown3, markdown4, markdown5,
  isholiday
)
SELECT
  store,
  STR_TO_DATE(date, '%m/%d/%Y') AS date,
  CAST(temperature AS DECIMAL(5,2)) AS temperature,
  CAST(fuel_price AS DECIMAL(4,3)) AS fuel_price,
  NULLIF(markdown1, 'NA') AS markdown1,
  NULLIF(markdown2, 'NA') AS markdown2,
  NULLIF(markdown3, 'NA') AS markdown3,
  NULLIF(markdown4, 'NA') AS markdown4,
  NULLIF(markdown5, 'NA') AS markdown5,
  isholiday
FROM store_features_raw;

-- Convert markdown columns to DECIMAL after NA -> NULL
ALTER TABLE features
  MODIFY markdown1 DECIMAL(9,2) NULL,
  MODIFY markdown2 DECIMAL(9,2) NULL,
  MODIFY markdown3 DECIMAL(9,2) NULL,
  MODIFY markdown4 DECIMAL(9,2) NULL,
  MODIFY markdown5 DECIMAL(9,2) NULL;

-- 3) Load sales (combine store1/store12/store45)
TRUNCATE TABLE sales;

INSERT INTO sales (store, dept, date, weekly_sales, isholiday)
SELECT
  store,
  dept,
  STR_TO_DATE(date, '%m/%d/%Y') AS date,
  CAST(weekly_sales AS DECIMAL(11,2)) AS weekly_sales,
  isholiday
FROM store1_raw
UNION ALL
SELECT
  store,
  dept,
  STR_TO_DATE(date, '%m/%d/%Y') AS date,
  CAST(weekly_sales AS DECIMAL(11,2)) AS weekly_sales,
  isholiday
FROM store12_raw
UNION ALL
SELECT
  store,
  dept,
  STR_TO_DATE(date, '%m/%d/%Y') AS date,
  CAST(weekly_sales AS DECIMAL(11,2)) AS weekly_sales,
  isholiday
FROM store45_raw;


/* C) Build analysis-ready views */
CREATE OR REPLACE VIEW store_features_clean AS
SELECT
  store,
  date,
  temperature,
  fuel_price,
  COALESCE(markdown1, 0)
+ COALESCE(markdown2, 0)
+ COALESCE(markdown3, 0)
+ COALESCE(markdown4, 0)
+ COALESCE(markdown5, 0) AS total_markdown,
  isholiday
FROM features;

CREATE OR REPLACE VIEW weekly_store_sales AS
SELECT
  store,
  date,
  SUM(weekly_sales) AS weekly_total_sales
FROM sales
GROUP BY store, date;

CREATE OR REPLACE VIEW sales_analysis_base AS
SELECT
  s.store,
  s.date,
  s.weekly_total_sales,
  f.total_markdown,
  f.temperature,
  f.fuel_price,
  f.isholiday
FROM weekly_store_sales s
LEFT JOIN store_features_clean f
  ON s.store = f.store
 AND s.date = f.date;
