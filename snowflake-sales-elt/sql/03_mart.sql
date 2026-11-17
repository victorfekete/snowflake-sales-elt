-- =====================================================================
-- 03_mart.sql  (Transform, step 2: business views)
-- One joined fact view + analytical views built on top of it.
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE ELT_WH;
USE SCHEMA SALES_ANALYTICS.MART;

-- Fact: one row per order line, enriched with customer and geography
CREATE OR REPLACE VIEW FCT_SALES AS
SELECT
    l.order_id,
    l.line_number,
    o.order_date,
    DATE_TRUNC('month', o.order_date) AS order_month,
    o.order_status,
    c.customer_id,
    c.customer_name,
    c.market_segment,
    g.nation_name,
    g.region_name,
    l.quantity,
    l.net_revenue,
    l.is_returned
FROM STAGING.STG_ORDER_LINES l
JOIN STAGING.STG_ORDERS    o ON l.order_id   = o.order_id
JOIN STAGING.STG_CUSTOMER  c ON o.customer_id = c.customer_id
JOIN STAGING.STG_GEOGRAPHY g ON c.nation_id  = g.nation_id;

-- 1) Revenue per month and region (GROUP BY)
CREATE OR REPLACE VIEW V_MONTHLY_REVENUE_BY_REGION AS
SELECT
    order_month,
    region_name,
    COUNT(DISTINCT order_id)   AS orders,
    ROUND(SUM(net_revenue), 2) AS revenue
FROM FCT_SALES
GROUP BY order_month, region_name;

-- 2) Top 10 customers per region (CTE + RANK window function)
CREATE OR REPLACE VIEW V_TOP_CUSTOMERS_BY_REGION AS
WITH customer_revenue AS (
    SELECT
        region_name,
        customer_id,
        customer_name,
        ROUND(SUM(net_revenue), 2) AS revenue
    FROM FCT_SALES
    GROUP BY region_name, customer_id, customer_name
)
SELECT
    region_name,
    customer_id,
    customer_name,
    revenue,
    RANK() OVER (PARTITION BY region_name ORDER BY revenue DESC) AS revenue_rank
FROM customer_revenue
QUALIFY revenue_rank <= 10;

-- 3) Year-to-date running total + month-over-month growth (SUM OVER, LAG)
CREATE OR REPLACE VIEW V_REVENUE_TRENDS AS
WITH monthly AS (
    SELECT order_month, SUM(net_revenue) AS revenue
    FROM FCT_SALES
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(SUM(revenue) OVER (
        PARTITION BY YEAR(order_month)
        ORDER BY order_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS ytd_revenue,
    ROUND(LAG(revenue) OVER (ORDER BY order_month), 2) AS prev_month_revenue,
    ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
              / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 2) AS mom_growth_pct
FROM monthly;

-- 4) Segment KPIs: revenue, average order value, return rate
CREATE OR REPLACE VIEW V_SEGMENT_SUMMARY AS
SELECT
    market_segment,
    COUNT(DISTINCT customer_id)                                   AS customers,
    COUNT(DISTINCT order_id)                                      AS orders,
    ROUND(SUM(net_revenue), 2)                                    AS revenue,
    ROUND(SUM(net_revenue) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_order_value,
    ROUND(100 * AVG(IFF(is_returned, 1, 0)), 2)                   AS return_rate_pct
FROM FCT_SALES
GROUP BY market_segment;

-- Try them:
-- SELECT * FROM V_MONTHLY_REVENUE_BY_REGION ORDER BY order_month, region_name LIMIT 20;
-- SELECT * FROM V_TOP_CUSTOMERS_BY_REGION ORDER BY region_name, revenue_rank;
-- SELECT * FROM V_REVENUE_TRENDS ORDER BY order_month;
-- SELECT * FROM V_SEGMENT_SUMMARY ORDER BY revenue DESC;
