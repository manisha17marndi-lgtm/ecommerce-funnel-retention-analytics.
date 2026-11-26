-- Reach-based funnel by device category (same cohort and 7-day window as step 20).
WITH cohort AS (
  SELECT user_id, first_visit_ts, device_category
  FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
  WHERE NOT had_earlier_activity
    AND first_visit_date <= DATE '2021-01-24'
),
f AS (
  SELECT
    c.user_id,
    MIN(IF(e.event_name = 'view_item', e.event_timestamp, NULL)) AS vi_ts,
    MIN(IF(e.event_name = 'add_to_cart', e.event_timestamp, NULL)) AS atc_ts,
    MIN(IF(e.event_name = 'begin_checkout', e.event_timestamp, NULL)) AS bc_ts
  FROM cohort c
  JOIN `ga4-funnel-project-515805.ga4_project.events` e
    ON e.user_id = c.user_id
   AND e.event_timestamp >= c.first_visit_ts
   AND e.event_timestamp <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY c.user_id
),
pur AS (
  SELECT c.user_id, MIN(ord.order_ts) AS pu_ts
  FROM cohort c
  JOIN `ga4-funnel-project-515805.ga4_project.orders` ord
    ON ord.user_id = c.user_id
   AND ord.order_ts >= c.first_visit_ts
   AND ord.order_ts <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY c.user_id
)
SELECT
  c.device_category,
  COUNT(*) AS users,
  COUNTIF(f.vi_ts IS NOT NULL) AS viewed_item,
  COUNTIF(f.atc_ts IS NOT NULL) AS added_to_cart,
  COUNTIF(f.bc_ts IS NOT NULL) AS began_checkout,
  COUNTIF(pur.pu_ts IS NOT NULL) AS purchased,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(f.vi_ts IS NOT NULL), COUNT(*)), 2) AS pct_viewed_item,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(f.atc_ts IS NOT NULL), COUNTIF(f.vi_ts IS NOT NULL)), 2) AS pct_view_to_cart,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(pur.pu_ts IS NOT NULL), COUNTIF(f.bc_ts IS NOT NULL)), 2) AS pct_checkout_to_purchase,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(pur.pu_ts IS NOT NULL), COUNT(*)), 2) AS pct_purchased_of_users
FROM cohort c
LEFT JOIN f ON f.user_id = c.user_id
LEFT JOIN pur ON pur.user_id = c.user_id
GROUP BY c.device_category
ORDER BY users DESC
