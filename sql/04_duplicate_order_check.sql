-- For order IDs that appear more than once: are they the same user, revenue and date?
WITH p AS (
  SELECT
    ecommerce.transaction_id AS order_id,
    user_pseudo_id,
    event_date,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id != '(not set)'
),
d AS (
  SELECT
    order_id,
    COUNT(*) AS n_events,
    COUNT(DISTINCT user_pseudo_id) AS n_users,
    COUNT(DISTINCT revenue) AS n_revenues,
    COUNT(DISTINCT event_date) AS n_dates
  FROM p
  GROUP BY order_id
  HAVING COUNT(*) > 1
)
SELECT
  COUNT(*) AS duplicated_order_ids,
  SUM(n_events - 1) AS extra_events,
  COUNTIF(n_users > 1) AS ids_with_multiple_users,
  COUNTIF(n_revenues > 1) AS ids_with_different_revenue,
  COUNTIF(n_dates > 1) AS ids_across_multiple_dates
FROM d
