-- How many first_visit events does each user have?
WITH f AS (
  SELECT
    user_pseudo_id,
    COUNT(*) AS n_first_visits,
    COUNT(DISTINCT event_date) AS n_dates
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'first_visit'
  GROUP BY user_pseudo_id
)
SELECT
  n_first_visits,
  COUNT(*) AS users,
  COUNTIF(n_dates > 1) AS users_on_multiple_dates
FROM f
GROUP BY n_first_visits
ORDER BY n_first_visits
