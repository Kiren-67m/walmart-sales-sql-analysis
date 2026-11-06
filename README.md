# Retail Sales Analysis: Holidays and Promotional Markdowns

## Project Summary
This project uses SQL to compare historical weekly sales across three stores and their departments, examining store sales efficiency, holiday patterns and associations with promotional markdowns.

## Dataset
- Weekly sales data from three retail stores (2010–2012)
- Store attributes including size and type
- Promotional markdown activity and holiday indicators
- External factors such as temperature and fuel prices

## Key Questions
- How do store size and type relate to average weekly sales?
- Which stores generate the highest yearly sales and sales per square foot?
- Do holiday weeks outperform non-holiday weeks in sales?
- How are promotional markdowns associated with weekly sales?
- How do department sales differ between the selected Super Bowl week and the preceding week?

## Findings in the three-store sample
- Store 1 has the highest annual sales and sales per square foot in all three recorded years. In 2011, its sales were $80.92 million and $534.79 per square foot.
- Holiday weeks have higher average department-week sales in all three stores; for Store 1, the recorded averages are $23,039.39 versus $21,609.63.
- Weeks with promotional markdowns have higher average store-week sales in all three stores. This is an association, not an estimate of promotion effectiveness.
- The Store 1 Super Bowl comparison shows department-level differences between two selected weeks; it does not establish a holiday effect.

## Tools & Skills
- SQL (joins, aggregations, subqueries, views)
- Data cleaning and transformation
- Business-oriented analytical reasoning
- Retail and promotional performance analysis

## Project Context
This project originated as a group coursework assignment for ITC 295 at Missouri State University.

The version presented here reflects my individual contributions and post-course refinements, including query restructuring, data cleaning, and analytical interpretation.


## Repository and execution guide

The SQL uses MySQL syntax. Run it only in a dedicated project database: the setup and cleaning scripts recreate or truncate project tables.

1. Run `sql/01_create_tables.sql` to create the database and final tables.
2. Run section A of `sql/02_load_and_clean.sql` to create the staging tables.
3. Import the original CSVs into `stores_raw`, `store_features_raw`, `store1_raw`, `store12_raw` and `store45_raw` using matching column order.
4. Run sections B and C of that file to clean the staging data, populate final tables and build views.
5. Run `sql/03_analysis_queries.sql` to reproduce the analyses.

The source CSVs are not included. Screenshots below preserve the recorded query results; a fresh data run requires the original files.

## Interpretation limits

The sample covers three stores, so results should not be generalized to the full retailer. Holiday and promotion comparisons are descriptive associations, without causal controls. Queries 1 and 3 average store-department-week rows; queries using `weekly_store_sales` aggregate departments to store-week totals. These grains should not be treated as interchangeable.

## Analysis Results

### Analysis 1: Store Overview
![Analysis 1](assets/screenshots/analysis1_store_overview.png)

### Analysis 2: Yearly Sales and Sales per Square Foot
![Analysis 2](assets/screenshots/analysis2_yearly_sales_efficiency.png)

### Analysis 3: Holiday vs Non-Holiday Sales
![Analysis 3](assets/screenshots/analysis3_holiday_vs_nonholiday.png)

### Analysis 4: Promotional Markdowns and Sales
![Analysis 4a](assets/screenshots/analysis4_avg_markdown_vs_sales.png)
![Analysis 4b](assets/screenshots/analysis4_promotion_vs_no_promotion.png)

### Analysis 5: Major Holiday Case Study – Super Bowl
![Analysis 5](assets/screenshots/analysis5_superbowl_department_comparison.png)



