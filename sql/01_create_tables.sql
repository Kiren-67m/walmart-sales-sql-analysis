/* 01_create_tables.sql
   Project: Retail Sales Analysis – Holidays & Promotional Markdowns
   Purpose: Create database schema and core tables with primary keys
*/

CREATE DATABASE IF NOT EXISTS walmart_sales;
USE walmart_sales;

-- Clean start (safe for re-run)
DROP TABLE IF EXISTS features;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS stores;

-- 1) Stores table
CREATE TABLE stores 
(
  store INT NOT NULL,
  type CHAR(1) NOT NULL,
  size INT NOT NULL,
  PRIMARY KEY (store)
);

-- 2) Sales table (combined from store1/store12/store45 later)
CREATE TABLE sales 
(
  store INT NOT NULL,
  dept INT NOT NULL,
  date DATE NOT NULL,
  weekly_sales DECIMAL(11,2) NOT NULL,
  isholiday VARCHAR(5) NOT NULL,
  PRIMARY KEY (store, dept, date)
);

-- 3) Features table
CREATE TABLE features 
(
  store INT NOT NULL,
  date DATE NOT NULL,
  temperature DECIMAL(5,2) NOT NULL,
  fuel_price DECIMAL(4,3) NOT NULL,
  markdown1 DECIMAL(9,2) NULL,
  markdown2 DECIMAL(9,2) NULL,
  markdown3 DECIMAL(9,2) NULL,
  markdown4 DECIMAL(9,2) NULL,
  markdown5 DECIMAL(9,2) NULL,
  isholiday VARCHAR(5) NOT NULL,
  PRIMARY KEY (store, date)
);