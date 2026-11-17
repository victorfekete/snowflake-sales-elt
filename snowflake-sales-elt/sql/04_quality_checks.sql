-- =====================================================================
-- 04_quality_checks.sql
-- Every check should return 0 issues / matching numbers.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE ELT_WH;
USE DATABASE SALES_ANALYTICS;

-- 1) Row counts RAW vs STAGING (differences = rows filtered out)
SELECT 'customer' AS entity, (SELECT COUNT(*) FROM RAW.CUSTOMER) AS raw_rows, (SELECT COUNT(*) FROM STAGING.STG_CUSTOMER) AS staging_rows
UNION ALL
SELECT 'orders',   (SELECT COUNT(*) FROM RAW.ORDERS),   (SELECT COUNT(*) FROM STAGING.STG_ORDERS)
UNION ALL
SELECT 'lineitem', (SELECT COUNT(*) FROM RAW.LINEITEM), (SELECT COUNT(*) FROM STAGING.STG_ORDER_LINES);

-- 2) Duplicate primary keys (expect 0)
SELECT 'dup_customer' AS check_name, COUNT(*) AS issues
FROM (SELECT customer_id FROM STAGING.STG_CUSTOMER GROUP BY customer_id HAVING COUNT(*) > 1)
UNION ALL
SELECT 'dup_order', COUNT(*)
FROM (SELECT order_id FROM STAGING.STG_ORDERS GROUP BY order_id HAVING COUNT(*) > 1)
UNION ALL
SELECT 'dup_order_line', COUNT(*)
FROM (SELECT order_id, line_number FROM STAGING.STG_ORDER_LINES GROUP BY 1, 2 HAVING COUNT(*) > 1);

-- 3) Orphan records: orders without a customer (expect 0)
SELECT COUNT(*) AS orders_without_customer
FROM STAGING.STG_ORDERS o
LEFT JOIN STAGING.STG_CUSTOMER c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 4) Revenue reconciliation: staging total = mart total
SELECT
    (SELECT ROUND(SUM(net_revenue), 2) FROM STAGING.STG_ORDER_LINES) AS staging_revenue,
    (SELECT ROUND(SUM(net_revenue), 2) FROM MART.FCT_SALES)          AS mart_revenue;
