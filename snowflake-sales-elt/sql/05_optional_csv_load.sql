-- =====================================================================
-- 05_optional_csv_load.sql
-- Load an external CSV (regional revenue targets) through a stage
-- with COPY INTO, then compare targets with actual revenue.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE ELT_WH;
USE SCHEMA SALES_ANALYTICS.RAW;

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE;

CREATE OR REPLACE STAGE CSV_STAGE
  FILE_FORMAT = CSV_FORMAT;

-- Upload data/regional_targets.csv into CSV_STAGE from Snowsight
-- (open the stage in the database explorer and use its file upload),
-- or with SnowSQL:  PUT file://data/regional_targets.csv @CSV_STAGE AUTO_COMPRESS=FALSE;

LIST @CSV_STAGE;

CREATE OR REPLACE TABLE REGIONAL_TARGETS (
    region_name     STRING,
    target_year     INT,
    target_revenue  NUMBER(18,2)
);

COPY INTO REGIONAL_TARGETS
FROM @CSV_STAGE/regional_targets.csv
ON_ERROR = 'ABORT_STATEMENT';

-- Target vs actual per region and year
CREATE OR REPLACE VIEW SALES_ANALYTICS.MART.V_TARGET_VS_ACTUAL AS
WITH actual AS (
    SELECT region_name, YEAR(order_date) AS sales_year, SUM(net_revenue) AS actual_revenue
    FROM SALES_ANALYTICS.MART.FCT_SALES
    GROUP BY region_name, YEAR(order_date)
)
SELECT
    t.region_name,
    t.target_year,
    t.target_revenue,
    ROUND(a.actual_revenue, 2)                               AS actual_revenue,
    ROUND(100 * a.actual_revenue / t.target_revenue, 2)      AS pct_of_target
FROM SALES_ANALYTICS.RAW.REGIONAL_TARGETS t
LEFT JOIN actual a
  ON a.region_name = t.region_name
 AND a.sales_year  = t.target_year;

-- SELECT * FROM SALES_ANALYTICS.MART.V_TARGET_VS_ACTUAL ORDER BY target_year, region_name;
