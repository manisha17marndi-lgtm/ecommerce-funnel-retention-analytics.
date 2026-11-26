-- Time from first_visit to first valid order.
-- Cohort: new users who first visited on or before 31 Dec 2020, so every user
-- has at least 31 days of follow-up (data ends 31 Jan 2021).
-- Uses hours between timestamps, not calendar days.
WITH cohort AS (
  SELECT user_id, first_visit_ts
  FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
  WHERE NOT had_earlier_activity
    AND first_visit_date <= DATE '2020-12-31'
),
first_order AS (
  SELECT c.user_id, c.first_visit_ts, MIN(o.order_ts) AS first_order_ts
  FROM cohort c
  JOIN `ga4-funnel-project-515805.ga4_project.orders` o
    ON o.user_id = c.user_id
  GROUP BY c.user_id, c.first_visit_ts
),
b AS (
  SELECT
    CASE
      WHEN first_order_ts < first_visit_ts THEN '0_before_first_visit'
      WHEN TIMESTAMP_DIFF(first_order_ts, first_visit_ts, HOUR) < 24 THEN '1_under_24h'
      WHEN TIMESTAMP_DIFF(first_order_ts, first_visit_ts, HOUR) < 48 THEN '2_24h_to_48h'
      WHEN TIMESTAMP_DIFF(first_order_ts, first_visit_ts, HOUR) < 168 THEN '3_2_to_7_days'
      WHEN TIMESTAMP_DIFF(first_order_ts, first_visit_ts, HOUR) < 336 THEN '4_7_to_14_days'
      WHEN TIMESTAMP_DIFF(first_order_ts, first_visit_ts, HOUR) < 720 THEN '5_14_to_30_days'
      ELSE '6_over_30_days'
    END AS time_to_first_order
  FROM first_order
)
SELECT
  time_to_first_order,
  COUNT(*) AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_buyers,
  ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY time_to_first_order) / SUM(COUNT(*)) OVER (), 2) AS cumulative_pct
FROM b
GROUP BY time_to_first_order
ORDER BY time_to_first_order
