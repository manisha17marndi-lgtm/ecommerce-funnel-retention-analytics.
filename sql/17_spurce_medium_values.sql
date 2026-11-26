-- Top acquisition source/medium combinations among new users
SELECT
  acquisition_source,
  acquisition_medium,
  COUNT(*) AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_users,
  COUNT(*) OVER () AS total_combinations
FROM `ga4-funnel-project-515805.ga4_project.users`
GROUP BY acquisition_source, acquisition_medium
ORDER BY users DESC
LIMIT 30
