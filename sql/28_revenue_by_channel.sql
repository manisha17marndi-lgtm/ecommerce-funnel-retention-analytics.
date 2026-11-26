-- REVENUE AND REPEAT PURCHASE BY CHANNEL.
-- 7-day metrics: new users with first_visit on or before 2021-01-24 (full 7 days of follow-up).
-- 30-day repeat rate: new users with first_visit on or before 2021-01-01 (full 30 days).
-- Revenue = valid orders only (orders table). Observed revenue, not lifetime value.
WITH base AS (
  SELECT user_id, first_visit_ts, first_visit_date, channel_group
  FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
  WHERE NOT had_earlier_activity
),
c7 AS (
  SELECT * FROM base WHERE first_visit_date <= DATE '2021-01-24'
),
o7 AS (
  SELECT c.channel_group, o.user_id, o.order_id, o.order_value
  FROM c7 c
  JOIN `ga4-funnel-project-515805.ga4_project.orders` o
    ON o.user_id = c.user_id
   AND o.order_ts >= c.first_visit_ts
   AND o.order_ts <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
),
size7 AS (
  SELECT channel_group, COUNT(*) AS users_7d FROM c7 GROUP BY channel_group
),
rev7 AS (
  SELECT
    channel_group,
    COUNT(*) AS orders_7d,
    COUNT(DISTINCT user_id) AS buyers_7d,
    ROUND(SUM(order_value), 2) AS revenue_7d
  FROM o7
  GROUP BY channel_group
),
c30 AS (
  SELECT * FROM base WHERE first_visit_date <= DATE '2021-01-01'
),
o30 AS (
  SELECT c.channel_group, o.user_id, COUNT(*) AS n_orders
  FROM c30 c
  JOIN `ga4-funnel-project-515805.ga4_project.orders` o
    ON o.user_id = c.user_id
   AND o.order_ts >= c.first_visit_ts
   AND o.order_ts <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 30 DAY)
  GROUP BY c.channel_group, o.user_id
),
rep30 AS (
  SELECT
    channel_group,
    COUNT(*) AS buyers_30d,
    COUNTIF(n_orders > 1) AS repeat_buyers_30d
  FROM o30
  GROUP BY channel_group
)
SELECT
  s.channel_group,
  s.users_7d,
  r.orders_7d,
  r.buyers_7d,
  r.revenue_7d,
  ROUND(SAFE_DIVIDE(r.revenue_7d, r.orders_7d), 2) AS aov_7d,
  ROUND(SAFE_DIVIDE(r.revenue_7d, s.users_7d), 3) AS revenue_per_user_7d,
  p.buyers_30d,
  p.repeat_buyers_30d,
  ROUND(100 * SAFE_DIVIDE(p.repeat_buyers_30d, p.buyers_30d), 2) AS repeat_rate_30d_pct
FROM size7 s
LEFT JOIN rev7 r USING (channel_group)
LEFT JOIN rep30 p USING (channel_group)
ORDER BY s.users_7d DESC
