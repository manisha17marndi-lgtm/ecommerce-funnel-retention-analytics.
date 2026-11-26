-- WEEKLY COHORT RETENTION (wide format, one row per signup week).
-- Cohort week = week of first_visit (BigQuery WEEK starts on Sunday; 1 Nov 2020 is a Sunday).
-- A cohort is eligible for Day N only if its LAST day + N is on or before 2021-01-31,
-- so every user in an included cohort has had the full N days. Ineligible cells are NULL.
WITH cohort AS (
  SELECT user_id, first_visit_date,
         DATE_TRUNC(first_visit_date, WEEK) AS cohort_week
  FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
  WHERE NOT had_earlier_activity
),
activity AS (
  SELECT
    user_id,
    DATE(event_timestamp) AS d,
    MAX(event_name = 'session_start') AS had_session,
    MAX(event_name IN ('view_item', 'add_to_cart', 'begin_checkout', 'purchase')) AS had_shopping
  FROM `ga4-funnel-project-515805.ga4_project.events`
  WHERE event_name IN ('session_start', 'view_item', 'add_to_cart', 'begin_checkout', 'purchase')
  GROUP BY user_id, d
),
sizes AS (
  SELECT cohort_week, COUNT(*) AS cohort_users
  FROM cohort
  GROUP BY cohort_week
),
ret AS (
  SELECT
    c.cohort_week,
    n,
    COUNT(*) AS users_n,
    COUNTIF(a.had_session) AS ret_session,
    COUNTIF(a.had_shopping) AS ret_shopping
  FROM cohort c
  CROSS JOIN UNNEST([1, 7, 30]) AS n
  LEFT JOIN activity a
    ON a.user_id = c.user_id
   AND a.d = DATE_ADD(c.first_visit_date, INTERVAL n DAY)
  WHERE DATE_ADD(c.cohort_week, INTERVAL 6 + n DAY) <= DATE '2021-01-31'
  GROUP BY c.cohort_week, n
)
SELECT
  s.cohort_week,
  s.cohort_users,
  MAX(IF(r.n = 1,  ROUND(100 * r.ret_session / r.users_n, 2), NULL)) AS d1_session_pct,
  MAX(IF(r.n = 7,  ROUND(100 * r.ret_session / r.users_n, 2), NULL)) AS d7_session_pct,
  MAX(IF(r.n = 30, ROUND(100 * r.ret_session / r.users_n, 2), NULL)) AS d30_session_pct,
  MAX(IF(r.n = 30, r.ret_session, NULL)) AS d30_session_users,
  MAX(IF(r.n = 1,  ROUND(100 * r.ret_shopping / r.users_n, 2), NULL)) AS d1_shopping_pct,
  MAX(IF(r.n = 7,  ROUND(100 * r.ret_shopping / r.users_n, 2), NULL)) AS d7_shopping_pct
FROM sizes s
LEFT JOIN ret r USING (cohort_week)
GROUP BY s.cohort_week, s.cohort_users
ORDER BY s.cohort_week
