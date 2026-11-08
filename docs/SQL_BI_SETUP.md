# SQL and Power BI setup

This guide reproduces the [Walmart Retail report](../powerbi/Walmart%20Retail.pbip) from the original five CSVs. The MySQL model is in [`sql/bi/`](../sql/bi/), and the Power BI project contains the semantic model and both report pages.

## Rebuild the MySQL data layer

Requires Python 3 and MySQL 8.0+ with a `mysql` client. No Python packages are needed.
Use a dedicated database and a user with permissions to create its tables/views.
The loader accepts only database names matching `walmart_<name>bi` to avoid touching
the coursework database accidentally. Never point it at unrelated business data.

The source directory must contain the original files with these names:

- `stores.csv`
- `store_features.csv`
- `store 1.csv`
- `store 12.csv`
- `Store 45.csv`

```bash
python3 scripts/build_bi.py --data-dir /absolute/path/to/original/csvs
```

Connection options: `--host`, `--port`, `--user`, `--socket`, `--mysql`.
For authenticated connections, use `--defaults-file /local/path/mysql-client.cnf`;
keep that file outside version control. The script never prints its contents.
Use `--replace` only when intentionally refreshing this project's dedicated BI
database. Existing non-empty databases are refused without it.

Run ingestion boundary tests:

```bash
python3 -m unittest discover -s tests -v
```

The pipeline validates source keys and holiday labels before loading; runs SQL
integrity checks; reconciles the raw Decimal sales total to MySQL and to the
persisted CSV handoff. Outputs are written only after SQL checks pass.

## Power BI handoff

`data/exports/` contains six UTF-8 CSVs, generated from actual MySQL queries:

| File | Grain / purpose |
| --- | --- |
| `dim_store.csv` | Three selected stores and their floor areas |
| `dim_department.csv` | Observed department IDs; no invented category names |
| `dim_week.csv` | Friday week labels, including feature-only weeks |
| `fact_store_week.csv` | One row per store and sales-covered week |
| `fact_department_week.csv` | One row per store, department and observed week |
| `year_coverage.csv` | Actual sales-period boundaries and week counts |

The exports are a reproducible snapshot, not a configured live database connection.
Regenerate them before refreshing Power BI. Raw files, exports, credentials and
Power BI caches are ignored by Git. Use a copy of the original five CSVs to regenerate the exports.

## Open and refresh Power BI Desktop

1. On Windows, open [`Walmart Retail.pbip`](../powerbi/Walmart%20Retail.pbip) with the adjacent `Walmart Retail.Report` and `Walmart Retail.SemanticModel` folders in place.
2. Open **Transform data**. In Power Query Editor, choose **Home → Manage Parameters** and update `ExportFolder` to the absolute path of the generated exports as seen by Windows. If MySQL and the loader run on another machine, copy the exported folder to Windows or use a Windows-accessible share. Use the location given to `--output-dir` if you overrode the default.
3. Select **Close & Apply**, then **Refresh**. Save the project if you want Power BI Desktop to remember your path.

The report imports five files. The sixth, `year_coverage.csv`, is available for checking the coverage reported in the visuals. See [Microsoft's guide to Power Query parameters](https://learn.microsoft.com/en-us/power-query/power-query-query-parameters) for the parameter editor.

## Model and metric decisions

- Keep store-week markdowns separate from department-week sales. Do not flatten
  them into a department fact and then sum repeated markdown values.
- Use one-way dimension-to-fact relationships for Store, Week and Department.
  Department should filter only the department fact; do not silently apply a
  department slicer to store-wide promotion metrics.
- Sales are summed as supplied, retaining negative observations. Their underlying
  reason is not established, so they are not labeled as returns or errors.
- Holiday comparisons in the new model use average **store-week** sales; the
  coursework query's department-week average is a different measure.
- A missing markdown field remains NULL. `reported_markdown_total` sums the
  observed fields only and is NULL when all five are missing. Show reporting
  coverage with the amount; never rename missing reporting as 'No promotion'.
- Annual periods have unequal coverage (48 / 52 / 43 weeks in 2010 / 2011 / 2012).
  Annual totals are period totals, not comparable full-year growth. Do not add a
  headline YoY card until matching-period logic has been implemented and tested.
- The SQL four-week moving average includes the current and three previous
  observations; only complete four-observation windows are returned. Source
  weeks are checked for gaps before running it.
- Feature data extends beyond sales history. Feature-only weeks must not be
  presented as zero-sales observations.

## Verification records

`artifacts/validation.json` records input SHA-256 hashes, coverage, retained negative
sales, quality-check outcomes and raw/SQL/export reconciliation. Query results are
saved in `artifacts/business_query_results.tsv`. These are local working records.
In the recorded run, all six SQL checks reported zero issues and the source, MySQL and exported store-week sales totals agreed at **$479,085,380.42**. The all-store report shows 143 observed weeks and three stores. For a filter check, select Store 12 and 2011 on **Store overview**. The report should show about **$52.58M** and **52** weeks.
