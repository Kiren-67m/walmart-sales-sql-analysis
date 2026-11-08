-- MySQL 8.0+. Run in a dedicated portfolio database, not the legacy coursework DB.
CREATE TABLE IF NOT EXISTS dim_store (
    store_id INT PRIMARY KEY,
    store_type CHAR(1) NOT NULL,
    size_sqft INT NOT NULL,
    CHECK (size_sqft > 0)
);

CREATE TABLE IF NOT EXISTS dim_department (
    department_id INT PRIMARY KEY,
    department_label VARCHAR(30) NOT NULL
);

-- Weekly dimension: dates are the source's Friday week labels, not daily dates.
CREATE TABLE IF NOT EXISTS dim_week (
    week_date DATE PRIMARY KEY,
    calendar_year SMALLINT NOT NULL,
    calendar_month TINYINT NOT NULL,
    month_label CHAR(7) NOT NULL,
    quarter_label CHAR(7) NOT NULL,
    week_index INT NOT NULL UNIQUE,
    is_holiday TINYINT NOT NULL,
    CHECK (is_holiday IN (0, 1))
);

CREATE TABLE IF NOT EXISTS fact_department_week (
    store_id INT NOT NULL,
    department_id INT NOT NULL,
    week_date DATE NOT NULL,
    weekly_sales DECIMAL(15,2) NOT NULL,
    PRIMARY KEY (store_id, department_id, week_date),
    FOREIGN KEY (store_id) REFERENCES dim_store(store_id),
    FOREIGN KEY (department_id) REFERENCES dim_department(department_id),
    FOREIGN KEY (week_date) REFERENCES dim_week(week_date)
);

-- Separate fact grain prevents store-level markdowns repeating per department.
-- Retain every source store-week feature row, even beyond sales coverage.
CREATE TABLE IF NOT EXISTS fact_store_features (
    store_id INT NOT NULL,
    week_date DATE NOT NULL,
    temperature_f DECIMAL(6,2) NULL,
    fuel_price_usd DECIMAL(6,3) NULL,
    markdown1 DECIMAL(15,2) NULL,
    markdown2 DECIMAL(15,2) NULL,
    markdown3 DECIMAL(15,2) NULL,
    markdown4 DECIMAL(15,2) NULL,
    markdown5 DECIMAL(15,2) NULL,
    markdown_fields_observed TINYINT NOT NULL,
    PRIMARY KEY (store_id, week_date),
    FOREIGN KEY (store_id) REFERENCES dim_store(store_id),
    FOREIGN KEY (week_date) REFERENCES dim_week(week_date),
    CHECK (markdown_fields_observed BETWEEN 0 AND 5)
);
