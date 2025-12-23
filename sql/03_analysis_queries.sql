/* 03_analysis_queries.sql
   Project: Retail Sales Analysis – Holidays & Promotional Markdowns
   Purpose: Answer business questions using SQL analysis
*/

USE walmart_sales;

/* Analysis 1: Store Overview */
SELECT
    s.store,
    s.type,
    s.size,
    COUNT(DISTINCT sa.dept) AS number_of_departments,
    ROUND(AVG(sa.weekly_sales), 2) AS avg_weekly_sales,
    ROUND(AVG(f.fuel_price), 3) AS avg_fuel_price,
    ROUND(MIN(f.temperature), 2) AS min_temperature,
    ROUND(MAX(f.temperature), 2) AS max_temperature
FROM stores s
JOIN sales sa
  ON s.store = sa.store
JOIN features f
  ON sa.store = f.store
 AND sa.date = f.date
GROUP BY
    s.store,
    s.type,
    s.size
ORDER BY
    s.store;


/* Analysis 2: Yearly Sales and Sales per Square Foot */
SELECT
    s.store,
    YEAR(sa.date) AS sales_year,
    ROUND(SUM(sa.weekly_sales), 2) AS total_yearly_sales,
    ROUND(SUM(sa.weekly_sales) / s.size, 2) AS sales_per_square_feet
FROM sales sa
JOIN stores s
  ON sa.store = s.store
GROUP BY
    s.store,
    YEAR(sa.date),
    s.size
ORDER BY
    s.store,
    sales_year;


/* Analysis 3: Holiday vs Non-Holiday Sales */
SELECT
    store,
    isholiday,
    ROUND(AVG(weekly_sales), 2) AS avg_weekly_sales
FROM sales
GROUP BY
    store,
    isholiday
ORDER BY
    store,
    isholiday;


/* Analysis 4: Promotional Markdowns and Sales */
SELECT
    store,
    ROUND(AVG(weekly_total_sales), 2) AS avg_weekly_sales,
    ROUND(AVG(total_markdown), 2) AS avg_total_markdown
FROM sales_analysis_base
GROUP BY
    store
ORDER BY
    store;
    
SELECT
    store,
    CASE
        WHEN total_markdown > 0 THEN 'With Promotion'
        ELSE 'No Promotion'
    END AS promotion_flag,
    ROUND(AVG(weekly_total_sales), 2) AS avg_weekly_sales
FROM sales_analysis_base
GROUP BY
    store,
    promotion_flag
ORDER BY
    store,
    promotion_flag;


/* Analysis 5: Major Holiday Case Study (Super Bowl) */
SELECT
    dept,
    ROUND(SUM(CASE WHEN date = '2011-02-11' THEN weekly_sales ELSE 0 END), 2) AS superbowl_week_sales,
    ROUND(SUM(CASE WHEN date = '2011-02-04' THEN weekly_sales ELSE 0 END), 2) AS previous_week_sales,
    ROUND(
        SUM(CASE WHEN date = '2011-02-11' THEN weekly_sales ELSE 0 END) /
        NULLIF(SUM(CASE WHEN date = '2011-02-04' THEN weekly_sales ELSE 0 END), 0),
        2
    ) AS sales_ratio
FROM sales
WHERE store = 1
  AND date IN ('2011-02-11', '2011-02-04')
GROUP BY dept
ORDER BY sales_ratio DESC;





