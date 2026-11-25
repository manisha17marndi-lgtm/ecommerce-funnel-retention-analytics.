-- Rows for order IDs where user, revenue or date differ across repeats
WITH p AS (
  SELECT
    ecommerce.transaction_id AS order_id,
    user_pseudo_id,
    event_date,
    TIMESTAMP_MICROS(event_timestamp) AS event_ts,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id != '(not set)'
),
odd AS (
  SELECT order_id
  FROM p
  GROUP BY order_id
  HAVING COUNT(DISTINCT user_pseudo_id) > 1
      OR COUNT(DISTINCT revenue) > 1
      OR COUNT(DISTINCT event_date) > 1
)
SELECT p.order_id, p.user_pseudo_id, p.event_date, p.event_ts, p.revenue
FROM p
JOIN odd USING (order_id)
ORDER BY p.order_id, p.event_ts
LIMIT 100
