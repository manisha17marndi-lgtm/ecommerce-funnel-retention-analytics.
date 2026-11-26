-- Check the users table against what we found earlier
SELECT
  COUNT(*) AS rows_in_table,
  COUNT(DISTINCT user_id) AS distinct_users,
  COUNTIF(had_earlier_activity) AS flagged_users,
  COUNTIF(device_category IS NULL) AS null_device,
  COUNTIF(acquisition_source IS NULL) AS null_source
FROM `ga4-funnel-project-515805.ga4_project.users`
