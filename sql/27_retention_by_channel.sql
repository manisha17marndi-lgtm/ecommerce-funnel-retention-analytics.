-- RETENTION BY CHANNEL (wide format, one row per channel).
-- Day N = first_visit date + N days (UTC). A user is eligible for Day N if
-- first_visit_date + N <= 2021-01-31. (User-level eligibility, so channel groups
-- get larger samples than the weekly cohort table, which requires whole weeks.)
WITH cohort AS (
  SELECT user_id, first_visit_date, channel_group
  FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
  WHERE NOT had_earlier_activity
),
activity AS (
  SELECT
    user_id,
    DATE(event_timestamp) AS d,
    MAX(event_name = 'session_start') AS had_session
  FROM `ga4-funnel-project-515805.ga4_project.events`
  WHERE event_name = 'session_start'
  GROUP BY user_id, d
),
ret AS (
  SELECT
    c.channel_group,
    n,
    COUNT(*) AS eligible,
    COUNTIF(a.had_session) AS ret_session
  FROM cohort c
  CROSS JOIN UNNEST([1, 7, 30]) AS n
  LEFT JOIN activity a
    ON a.user_id = c.user_id
   AND a.d = DATE_ADD(c.first_visit_date, INTERVAL n DAY)
  WHERE c.first_visit_date <= DATE_SUB(DATE '2021-01-31', INTERVAL n DAY)
  GROUP BY c.channel_group, n
)
SELECT
  channel_group,
  MAX(IF(n = 1,  eligible, NULL)) AS d1_users,
  MAX(IF(n = 1,  ROUND(100 * ret_session / eligible, 2), NULL)) AS d1_session_pct,
  MAX(IF(n = 7,  eligible, NULL)) AS d7_users,
  MAX(IF(n = 7,  ROUND(100 * ret_session / eligible, 2), NULL)) AS d7_session_pct,
  MAX(IF(n = 30, eligible, NULL)) AS d30_users,
  MAX(IF(n = 30, ret_session, NULL)) AS d30_returned,
  MAX(IF(n = 30, ROUND(100 * ret_session / eligible, 2), NULL)) AS d30_session_pct
FROM ret
GROUP BY channel_group
ORDER BY d1_users DESC
