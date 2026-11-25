SELECT
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT ecommerce.transaction_id) AS distinct_transaction_ids,
  COUNTIF(ecommerce.transaction_id IS NULL) AS null_transaction_id,
  COUNTIF(ecommerce.transaction_id = '(not set)') AS notset_transaction_id,
  COUNTIF(ecommerce.purchase_revenue_in_usd IS NULL) AS null_revenue,
  COUNTIF(ecommerce.purchase_revenue_in_usd <= 0) AS zero_or_negative_revenue,
  COUNT(DISTINCT user_pseudo_id) AS purchasing_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name = 'purchase'
