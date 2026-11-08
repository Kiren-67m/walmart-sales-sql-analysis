-- Weekly store performance and a four-observation rolling baseline.
SELECT store_id, week_date, weekly_sales, prior_week_sales,
       ROUND((weekly_sales / NULLIF(prior_week_sales,0) - 1)*100,2) AS wow_change_pct,
       ROUND(rolling_4_week_avg_sales,2) AS rolling_4_week_avg_sales
FROM bi_store_week ORDER BY store_id, week_date;

-- Annual ranks within the same observation period; never label these YoY growth.
WITH annual AS (
    SELECT w.calendar_year, f.store_id, SUM(f.weekly_sales) AS sales,
           COUNT(DISTINCT f.week_date) AS observed_weeks
    FROM bi_store_week f JOIN dim_week w USING (week_date)
    GROUP BY w.calendar_year, f.store_id
)
SELECT a.*, DENSE_RANK() OVER (PARTITION BY calendar_year ORDER BY sales DESC) AS sales_rank,
       ROUND(sales / size_sqft,2) AS period_sales_per_sqft
FROM annual a JOIN dim_store s USING(store_id)
ORDER BY calendar_year, sales_rank;

-- Ranking uses department-week facts without repeating store-wide promotions.
WITH department_sales AS (
    SELECT store_id, department_id, SUM(weekly_sales) AS sales
    FROM bi_department_week GROUP BY store_id, department_id
)
SELECT *, DENSE_RANK() OVER (PARTITION BY store_id ORDER BY sales DESC) AS department_rank,
       ROUND(sales / NULLIF(SUM(sales) OVER (PARTITION BY store_id),0)*100,2) AS sales_share_pct
FROM department_sales ORDER BY store_id, department_rank;

-- Compare mean STORE-week sales, not the mean of department rows.
SELECT f.store_id, w.is_holiday, COUNT(*) AS observed_store_weeks,
       ROUND(AVG(f.weekly_sales),2) AS avg_store_week_sales
FROM bi_store_week f JOIN dim_week w USING(week_date)
GROUP BY f.store_id, w.is_holiday ORDER BY f.store_id, w.is_holiday;

-- Missing markdowns remain a separate group, never relabeled 'No promotion'.
SELECT store_id, markdown_status, COUNT(*) AS observed_store_weeks,
       ROUND(AVG(weekly_sales),2) AS avg_store_week_sales
FROM bi_store_week GROUP BY store_id, markdown_status
ORDER BY store_id, markdown_status;
