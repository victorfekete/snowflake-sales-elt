-- =====================================================================
-- 02_staging.sql  (Transform, step 1: clean)
-- Rename cryptic columns, cast types, decode codes, drop bad rows,
-- deduplicate, and compute net revenue.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE ELT_WH;
USE SCHEMA SALES_ANALYTICS.STAGING;

-- Customers: one row per customer (keep the latest load if duplicated)
CREATE OR REPLACE TABLE STG_CUSTOMER AS
SELECT
    C_CUSTKEY                    AS customer_id,
    TRIM(C_NAME)                 AS customer_name,
    C_NATIONKEY                  AS nation_id,
    UPPER(TRIM(C_MKTSEGMENT))    AS market_segment,
    C_ACCTBAL::NUMBER(12,2)      AS account_balance
FROM RAW.CUSTOMER
WHERE C_CUSTKEY IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY C_CUSTKEY ORDER BY _LOADED_AT DESC) = 1;

-- Geography: flatten nation + region into one lookup table
CREATE OR REPLACE TABLE STG_GEOGRAPHY AS
SELECT
    n.N_NATIONKEY        AS nation_id,
    INITCAP(n.N_NAME)    AS nation_name,
    r.R_NAME             AS region_name
FROM RAW.NATION n
JOIN RAW.REGION r ON n.N_REGIONKEY = r.R_REGIONKEY;

-- Orders: decode status codes into readable values
CREATE OR REPLACE TABLE STG_ORDERS AS
SELECT
    O_ORDERKEY                       AS order_id,
    O_CUSTKEY                        AS customer_id,
    CASE O_ORDERSTATUS
        WHEN 'F' THEN 'FULFILLED'
        WHEN 'O' THEN 'OPEN'
        WHEN 'P' THEN 'PARTIAL'
        ELSE 'UNKNOWN'
    END                              AS order_status,
    O_ORDERDATE::DATE                AS order_date,
    O_ORDERPRIORITY                  AS order_priority,
    O_TOTALPRICE::NUMBER(14,2)       AS order_total_price
FROM RAW.ORDERS
WHERE O_ORDERKEY IS NOT NULL
  AND O_ORDERDATE IS NOT NULL;

-- Order lines: net revenue = price after discount
CREATE OR REPLACE TABLE STG_ORDER_LINES AS
SELECT
    L_ORDERKEY                                         AS order_id,
    L_LINENUMBER                                       AS line_number,
    L_QUANTITY::NUMBER(10,2)                           AS quantity,
    L_EXTENDEDPRICE::NUMBER(14,2)                      AS gross_amount,
    L_DISCOUNT                                         AS discount_rate,
    ROUND(L_EXTENDEDPRICE * (1 - L_DISCOUNT), 2)       AS net_revenue,
    L_SHIPDATE::DATE                                   AS ship_date,
    L_SHIPMODE                                         AS ship_mode,
    (L_RETURNFLAG = 'R')                               AS is_returned
FROM RAW.LINEITEM
WHERE L_ORDERKEY IS NOT NULL
  AND L_QUANTITY > 0;
