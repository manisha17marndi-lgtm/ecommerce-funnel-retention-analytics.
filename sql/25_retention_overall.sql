-- OVERALL RETENTION. Day N = calendar date of first_visit + N days (UTC dates throughout).
-- Cohort: new users (no earlier activity). Eligible for Day N only if
--   first_visit_date + N <= 2021-01-31 (last day of data).
-- Two definitions of a return on day N:
--   returned_session  = at least one session_start on that day
--   returned_shopping = at least one view_item / add_to_cart / begin_checkout / purchase that day
WITH cohort AS (
  SELECT user_id, first_visit_date
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
)
SELECT
  n AS day_n,
  COUNT(*) AS eligible_users,
  COUNTIF(a.had_session) AS returned_session,
  COUNTIF(a.had_shopping) AS returned_shopping,
  ROUND(100 * COUNTIF(a.had_session) / COUNT(*), 2) AS retention_session_pct,
  ROUND(100 * COUNTIF(a.had_shopping) / COUNT(*), 2) AS retention_shopping_pct
FROM cohort c
CROSS JOIN UNNEST([1, 7, 30]) AS n
LEFT JOIN activity a
  ON a.user_id = c.user_id
 AND a.d = DATE_ADD(c.first_visit_date, INTERVAL n DAY)
WHERE c.first_visit_date <= DATE_SUB(DATE '2021-01-31', INTERVAL n DAY)
GROUP BY n
ORDER BY n
