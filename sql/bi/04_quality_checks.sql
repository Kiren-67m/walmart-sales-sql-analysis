-- Stable integrity checks. issue_count must be zero for each row.
SELECT 'unmatched_sales_features' AS check_name, COUNT(*) AS issue_count
FROM fact_department_week s LEFT JOIN fact_store_features f USING(store_id,week_date)
WHERE f.store_id IS NULL
UNION ALL
SELECT 'non_friday_weeks', COUNT(*) FROM dim_week WHERE DAYOFWEEK(week_date) <> 6
UNION ALL
SELECT 'store_week_join_multiplication',
       ABS((SELECT COUNT(*) FROM bi_store_week) -
           (SELECT COUNT(*) FROM (SELECT store_id,week_date FROM fact_department_week GROUP BY store_id,week_date) x))
UNION ALL
SELECT 'sales_total_reconciliation',
       CASE WHEN (SELECT SUM(weekly_sales) FROM fact_department_week) =
                      (SELECT SUM(weekly_sales) FROM bi_store_week) THEN 0 ELSE 1 END
UNION ALL
SELECT 'sales_per_sqft_reconciliation', COUNT(*) FROM bi_store_week
WHERE ABS(sales_per_sqft - weekly_sales / size_sqft) > 0.0001
UNION ALL
SELECT 'calendar_gaps', COUNT(*) FROM (
    SELECT week_date, DATEDIFF(week_date,LAG(week_date) OVER (ORDER BY week_date)) AS gap_days
    FROM dim_week
) gaps WHERE gap_days <> 7;
