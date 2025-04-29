
-- data_analysis_sera_payments.sql

-- 1. How many transactions occurred?
-- sera_payments_data_analysis_1
SELECT 
    COUNT(*) AS total_transactions
FROM sales_txn;

-- 2. What is the period covered in the analysis?
-- sera_payments_data_analysis_2
SELECT 
    MIN(
      to_timestamp(
        regexp_replace(transaction_date, '(\\d+)(st|nd|rd|th)', '\\1', 'g'),
        'Mon DD, YYYY HH12:MI:SS AM'
      )
    )::date AS start_date,
    MAX(
      to_timestamp(
        regexp_replace(transaction_date, '(\\d+)(st|nd|rd|th)', '\\1', 'g'),
        'Mon DD, YYYY HH12:MI:SS AM'
      )
    )::date AS end_date
FROM sales_txn;

-- 3. Show the transaction count by status along with percentage of total
--    Using a WINDOW FUNCTION
-- sera_payments_data_analysis_3
SELECT 
    status,
    COUNT(*) AS transaction_count,
    ROUND(
      COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
      2
    ) AS pct_of_total
FROM sales_txn
GROUP BY status
ORDER BY transaction_count DESC;

-- 4. Show the monthly subscription revenue split by channel.
--    Assume NGN/USD = 950. Round up USD values for neatness.
-- sera_payments_data_analysis_4
SELECT
    DATE_TRUNC('month',
      to_timestamp(
        regexp_replace(transaction_date, '(\\d+)(st|nd|rd|th)', '\\1', 'g'),
        'Mon DD, YYYY HH12:MI:SS AM'
      )
    ) AS month,
    channel,
    ROUND(
      SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END),
      2
    ) AS revenue_ngn,
    CEIL(
      SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END) / 950.0
    ) AS revenue_usd
FROM sales_txn
GROUP BY 1, 2
ORDER BY 1, 2;

-- 4a. Which month-year had the highest revenue?
-- sera_payments_data_analysis_4a
SELECT
    DATE_TRUNC('month',
      to_timestamp(
        regexp_replace(transaction_date, '(\\d+)(st|nd|rd|th)', '\\1', 'g'),
        'Mon DD, YYYY HH12:MI:SS AM'
      )
    ) AS month,
    SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END) AS total_revenue_ngn
FROM sales_txn
GROUP BY 1
ORDER BY total_revenue_ngn DESC
LIMIT 1;

-- 5. Total transactions by channel split by transaction status.
-- sera_payments_data_analysis_5
SELECT
    channel,
    status,
    COUNT(*) AS txn_count
FROM sales_txn
GROUP BY channel, status
ORDER BY channel, txn_count DESC;

-- 6. How many subscribers are there in total?
--    A subscriber is a user with at least one successful payment.
-- sera_payments_data_analysis_6
SELECT
    COUNT(DISTINCT user_id) AS total_subscribers
FROM sales_txn
WHERE status = 'success';

-- 7. User activity: number of active months and transaction counts by status.
-- sera_payments_data_analysis_7
WITH monthly_txn AS (
    SELECT
        user_id,
        DATE_TRUNC('month',
          to_timestamp(
            regexp_replace(transaction_date, '(\\d+)(st|nd|rd|th)', '\\1', 'g'),
            'Mon DD, YYYY HH12:MI:SS AM'
          )
        ) AS month,
        status
    FROM sales_txn
)
SELECT
    user_id,
    COUNT(DISTINCT month) AS active_months,
    SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END)    AS success_count,
    SUM(CASE WHEN status = 'abandoned' THEN 1 ELSE 0 END)  AS abandoned_count,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END)     AS failed_count
FROM monthly_txn
GROUP BY user_id
ORDER BY active_months DESC, success_count DESC;

-- 8. Identify users with >1 active months and no successful transactions.
-- sera_payments_data_analysis_8
WITH monthly_summary AS (
    SELECT
        user_id,
        DATE_TRUNC('month',
          to_timestamp(
            regexp_replace(transaction_date, '(\\d+)(st|nd|rd|th)', '\\1', 'g'),
            'Mon DD, YYYY HH12:MI:SS AM'
          )
        ) AS month,
        MAX(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS had_success
    FROM sales_txn
    GROUP BY user_id, month
),
user_summary AS (
    SELECT
        user_id,
        COUNT(*) AS active_months,
        SUM(had_success) AS success_months
    FROM monthly_summary
    GROUP BY user_id
)
SELECT
    user_id,
    active_months
FROM user_summary
WHERE active_months > 1
  AND success_months = 0
ORDER BY active_months DESC;
