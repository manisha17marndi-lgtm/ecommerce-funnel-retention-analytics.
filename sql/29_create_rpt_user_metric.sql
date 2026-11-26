-- RPT_USER_METRICS. Grain: one row per new user (no earlier activity; 257,299 users).
-- Eligibility flags decide which users count for each metric (same rules as steps 18-28).
-- Funnel and revenue windows are 7 days from first_visit; retention uses UTC calendar days.
CREATE OR REPLACE TABLE `ga4-funnel-project-515805.ga4_project.rpt_user_metrics` AS
WITH base AS (
  SELECT user_id, first_visit_ts, first_visit_date, channel_group, device_category
  FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
  WHERE NOT had_earlier_activity
),
act AS (
  SELECT
    user_id,
    DATE(event_timestamp) AS d,
    MAX(event_name = 'session_start') AS had_session,
    MAX(event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')) AS had_shopping
  FROM `ga4-funnel-project-515805.ga4_project.events`
  WHERE event_name IN ('session_start', 'view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  GROUP BY user_id, d
),
ret AS (
  SELECT
    b.user_id,
    COUNTIF(a.d = DATE_ADD(b.first_visit_date, INTERVAL 1 DAY) AND a.had_session) > 0 AS ret_d1_session,
    COUNTIF(a.d = DATE_ADD(b.first_visit_date, INTERVAL 7 DAY) AND a.had_session) > 0 AS ret_d7_session,
    COUNTIF(a.d = DATE_ADD(b.first_visit_date, INTERVAL 30 DAY) AND a.had_session) > 0 AS ret_d30_session,
    COUNTIF(a.d = DATE_ADD(b.first_visit_date, INTERVAL 1 DAY) AND a.had_shopping) > 0 AS ret_d1_shopping,
    COUNTIF(a.d = DATE_ADD(b.first_visit_date, INTERVAL 7 DAY) AND a.had_shopping) > 0 AS ret_d7_shopping
  FROM base b
  LEFT JOIN act a ON a.user_id = b.user_id
  GROUP BY b.user_id
),
fun AS (
  SELECT
    b.user_id,
    COUNTIF(e.event_name = 'view_item') > 0 AS did_view_item_7d,
    COUNTIF(e.event_name = 'add_to_cart') > 0 AS did_add_to_cart_7d,
    COUNTIF(e.event_name = 'begin_checkout') > 0 AS did_begin_checkout_7d
  FROM base b
  JOIN `ga4-funnel-project-515805.ga4_project.events` e
    ON e.user_id = b.user_id
   AND e.event_timestamp >= b.first_visit_ts
   AND e.event_timestamp <= TIMESTAMP_ADD(b.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY b.user_id
),
o7 AS (
  SELECT b.user_id, COUNT(*) AS orders_7d, SUM(o.order_value) AS revenue_7d
  FROM base b
  JOIN `ga4-funnel-project-515805.ga4_project.orders` o
    ON o.user_id = b.user_id
   AND o.order_ts >= b.first_visit_ts
   AND o.order_ts <= TIMESTAMP_ADD(b.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY b.user_id
),
o30 AS (
  SELECT b.user_id, COUNT(*) AS orders_30d
  FROM base b
  JOIN `ga4-funnel-project-515805.ga4_project.orders` o
    ON o.user_id = b.user_id
   AND o.order_ts >= b.first_visit_ts
   AND o.order_ts <= TIMESTAMP_ADD(b.first_visit_ts, INTERVAL 30 DAY)
  GROUP BY b.user_id
)
SELECT
  b.user_id,
  b.first_visit_date,
  DATE_TRUNC(b.first_visit_date, WEEK) AS cohort_week,
  b.channel_group,
  b.device_category,
  b.first_visit_date <= DATE '2021-01-30' AS eligible_d1,
  b.first_visit_date <= DATE '2021-01-24' AS eligible_d7_and_funnel,
  b.first_visit_date <= DATE '2021-01-01' AS eligible_d30_and_repeat,
  IFNULL(f.did_view_item_7d, FALSE) AS did_view_item_7d,
  IFNULL(f.did_add_to_cart_7d, FALSE) AS did_add_to_cart_7d,
  IFNULL(f.did_begin_checkout_7d, FALSE) AS did_begin_checkout_7d,
  IFNULL(o7.orders_7d, 0) AS orders_7d,
  IFNULL(o7.revenue_7d, 0) AS revenue_7d,
  IFNULL(o30.orders_30d, 0) AS orders_30d,
  r.ret_d1_session, r.ret_d7_session, r.ret_d30_session,
  r.ret_d1_shopping, r.ret_d7_shopping
FROM base b
LEFT JOIN ret r ON r.user_id = b.user_id
LEFT JOIN fun f ON f.user_id = b.user_id
LEFT JOIN o7 ON o7.user_id = b.user_id
LEFT JOIN o30 ON o30.user_id = b.user_id;
