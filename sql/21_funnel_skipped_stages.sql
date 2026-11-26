-- Stage coverage and skipped stages, same cohort and 7-day window as the funnel.
-- "any order" = the user did the event at some point in the window, regardless of sequence.
WITH cohort AS (
  SELECT user_id, first_visit_ts
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
  COUNT(*) AS cohort_users,
  COUNTIF(f.vi_ts IS NOT NULL) AS any_order_view_item,
  COUNTIF(f.atc_ts IS NOT NULL) AS any_order_add_to_cart,
  COUNTIF(f.bc_ts IS NOT NULL) AS any_order_begin_checkout,
  COUNTIF(pur.pu_ts IS NOT NULL) AS any_order_purchase,
  COUNTIF(f.atc_ts IS NOT NULL AND f.vi_ts IS NULL) AS cart_without_view,
  COUNTIF(f.bc_ts IS NOT NULL AND f.atc_ts IS NULL) AS checkout_without_cart,
  COUNTIF(pur.pu_ts IS NOT NULL AND f.bc_ts IS NULL) AS purchase_without_checkout,
  COUNTIF(pur.pu_ts IS NOT NULL AND f.atc_ts IS NULL) AS purchase_without_cart
FROM cohort c
LEFT JOIN f ON f.user_id = c.user_id
LEFT JOIN pur ON pur.user_id = c.user_id
