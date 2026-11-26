-- ORDERS table. Grain: one row per valid order for users in the users table.
-- Valid order rules (steps 5-7):
--   real transaction_id (not NULL, not '(not set)'), revenue above 0,
--   one row per transaction_id + user_id (earliest event kept).
CREATE OR REPLACE TABLE `ga4-funnel-project-515805.ga4_project.orders` AS
WITH p AS (
  SELECT
    e.ecommerce.transaction_id AS order_id,
    e.user_pseudo_id AS user_id,
    TIMESTAMP_MICROS(e.event_timestamp) AS order_ts,
    PARSE_DATE('%Y%m%d', e.event_date) AS order_date,
    e.ecommerce.purchase_revenue_in_usd AS order_value
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
  JOIN `ga4-funnel-project-515805.ga4_project.users` u
    ON e.user_pseudo_id = u.user_id
  WHERE e._TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND e.event_name = 'purchase'
    AND e.ecommerce.transaction_id IS NOT NULL
    AND e.ecommerce.transaction_id != '(not set)'
    AND e.ecommerce.purchase_revenue_in_usd > 0
)
SELECT
  CONCAT(order_id, '|', user_id) AS order_key,
  order_id,
  user_id,
  order_ts,
  order_date,
  order_value
FROM p
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id, user_id ORDER BY order_ts) = 1;
