-- =====================================================================
-- 00_setup.sql
-- Creates the compute (warehouse), the database and the 3 layers.
-- =====================================================================

USE ROLE SYSADMIN;

-- Smallest warehouse; suspends after 60s idle so trial credits last.
CREATE WAREHOUSE IF NOT EXISTS ELT_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE ELT_WH;

CREATE DATABASE IF NOT EXISTS SALES_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS SALES_ANALYTICS.RAW      COMMENT = 'Source data copied as-is + load timestamp';
CREATE SCHEMA IF NOT EXISTS SALES_ANALYTICS.STAGING  COMMENT = 'Cleaned, renamed, typed, deduplicated';
CREATE SCHEMA IF NOT EXISTS SALES_ANALYTICS.MART     COMMENT = 'Business-ready views for analytics';

-- If SNOWFLAKE_SAMPLE_DATA is missing from your account, run this once:
-- USE ROLE ACCOUNTADMIN;
-- CREATE DATABASE SNOWFLAKE_SAMPLE_DATA FROM SHARE SFC_SAMPLES.SAMPLE_DATA;
-- GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE SYSADMIN;
