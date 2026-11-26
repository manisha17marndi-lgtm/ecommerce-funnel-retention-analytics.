-- Reconciliation: where did each purchase event for new users go?
WITH p AS (
  SELECT
    e.ecommerce.transaction_id AS order_id,
    e.user_pseudo_id AS user_id,
    TIMESTAMP_MICROS(e.event_timestamp) AS ts,
    e.ecommerce.purchase_revenue_in_usd AS rev,
    (e.ecommerce.transaction_id IS NOT NULL
     AND e.ecommerce.transaction_id != '(not set)'
     AND e.ecommerce.purchase_revenue_in_usd > 0) AS is_valid
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
  JOIN `ga4-funnel-project-515805.ga4_project.users` u
    ON e.user_pseudo_id = u.user_id
  WHERE e._TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND e.event_name = 'purchase'
),
c AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY order_id, user_id, is_valid ORDER BY ts) AS rn
  FROM p
)
SELECT
  CASE
    WHEN order_id IS NULL THEN '1_no_transaction_id'
    WHEN order_id = '(not set)' AND rev <= 0 THEN '2_not_set_id_zero_revenue'
    WHEN order_id = '(not set)' THEN '3_not_set_id_positive_revenue'
    WHEN rev <= 0 THEN '4_real_id_zero_revenue'
    WHEN rn > 1 THEN '5_repeat_of_valid_order'
    ELSE '6_kept_as_order'
  END AS status,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS users,
  ROUND(SUM(rev), 2) AS revenue
FROM c
GROUP BY status
ORDER BY status
