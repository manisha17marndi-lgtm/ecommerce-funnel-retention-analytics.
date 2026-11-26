-- Check the channel grouping
SELECT
  channel_group,
  COUNT(*) AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_users
FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
GROUP BY channel_group
ORDER BY users DESC
