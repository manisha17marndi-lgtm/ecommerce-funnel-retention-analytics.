-- Check the events table
SELECT
  event_name,
  COUNT(*) AS rows_in_table,
  COUNT(DISTINCT event_key) AS distinct_event_keys,
  COUNT(DISTINCT user_id) AS distinct_users,
  COUNTIF(session_id IS NULL) AS null_session_id
FROM `ga4-funnel-project-515805.ga4_project.events`
GROUP BY event_name
ORDER BY rows_in_table DESC
