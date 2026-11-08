-- One row per store and sales week. Only sales-covered weeks enter the BI fact.
CREATE OR REPLACE VIEW bi_store_week AS
WITH store_sales AS (
    SELECT store_id, week_date,
           SUM(weekly_sales) AS weekly_sales,
           COUNT(*) AS observed_departments,
           SUM(CASE WHEN weekly_sales < 0 THEN 1 ELSE 0 END) AS negative_sales_rows
    FROM fact_department_week
    GROUP BY store_id, week_date
), joined AS (
    SELECT s.*, d.size_sqft,
           s.weekly_sales / d.size_sqft AS sales_per_sqft,
           f.temperature_f, f.fuel_price_usd,
           f.markdown_fields_observed,
           CASE WHEN f.markdown_fields_observed > 0 THEN
               COALESCE(f.markdown1,0) + COALESCE(f.markdown2,0) +
               COALESCE(f.markdown3,0) + COALESCE(f.markdown4,0) +
               COALESCE(f.markdown5,0)
           END AS reported_markdown_total,
           CASE WHEN f.markdown_fields_observed = 0 THEN 'Not reported'
                WHEN COALESCE(f.markdown1,0) + COALESCE(f.markdown2,0) +
                     COALESCE(f.markdown3,0) + COALESCE(f.markdown4,0) +
                     COALESCE(f.markdown5,0) > 0 THEN 'Reported positive'
                ELSE 'Reported zero or non-positive' END AS markdown_status
    FROM store_sales s
    JOIN dim_store d USING (store_id)
    LEFT JOIN fact_store_features f USING (store_id, week_date)
)
SELECT j.*,
       LAG(weekly_sales) OVER (PARTITION BY store_id ORDER BY week_date) AS prior_week_sales,
       CASE WHEN COUNT(*) OVER w4 = 4 THEN AVG(weekly_sales) OVER w4 END
           AS rolling_4_week_avg_sales
FROM joined j
WINDOW w4 AS (PARTITION BY store_id ORDER BY week_date ROWS BETWEEN 3 PRECEDING AND CURRENT ROW);

CREATE OR REPLACE VIEW bi_department_week AS
SELECT f.store_id, f.department_id, f.week_date, f.weekly_sales
FROM fact_department_week f;

-- Context for annual totals: 2010 and 2012 are partial years in this source.
CREATE OR REPLACE VIEW bi_year_coverage AS
SELECT w.calendar_year,
       MIN(s.week_date) AS first_sales_week,
       MAX(s.week_date) AS last_sales_week,
       COUNT(DISTINCT s.week_date) AS observed_weeks,
       COUNT(*) AS store_weeks,
       SUM(s.weekly_sales) AS total_sales
FROM bi_store_week s JOIN dim_week w USING (week_date)
GROUP BY w.calendar_year;
