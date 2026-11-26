-- Check the orders table
SELECT
  (SELECT COUNT(*) FROM `ga4-funnel-project-515805.ga4_project.orders`) AS orders_rows,
  (SELECT COUNT(DISTINCT order_key) FROM `ga4-funnel-project-515805.ga4_project.orders`) AS distinct_order_keys,
  (SELECT COUNT(DISTINCT user_id) FROM `ga4-funnel-project-515805.ga4_project.orders`) AS purchasing_users,
  (SELECT ROUND(SUM(order_value), 2) FROM `ga4-funnel-project-515805.ga4_project.orders`) AS total_revenue,
  (SELECT COUNT(*) FROM `ga4-funnel-project-515805.ga4_project.events` WHERE event_name = 'purchase') AS purchase_events_in_events_table
