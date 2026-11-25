-- Overlap between order ID problems and revenue problems
SELECT
  CASE
    WHEN ecommerce.transaction_id IS NULL THEN 'null_id'
    WHEN ecommerce.transaction_id = '(not set)' THEN 'not_set_id'
    ELSE 'has_id'
  END AS id_status,
  CASE
    WHEN ecommerce.purchase_revenue_in_usd > 0 THEN 'revenue_positive'
    ELSE 'revenue_zero_or_negative'
  END AS revenue_status,
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT ecommerce.transaction_id) AS distinct_ids,
  ROUND(SUM(ecommerce.purchase_revenue_in_usd), 2) AS total_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
GROUP BY id_status, revenue_status
ORDER BY id_status, revenue_status
