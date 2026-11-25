-- Events, users, first visits and purchases per day. Lowest 10 days by event volume.
SELECT
  event_date,
  COUNT(*) AS events,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNTIF(event_name = 'first_visit') AS first_visits,
  COUNTIF(event_name = 'purchase') AS purchases,
  ROUND(AVG(COUNT(*)) OVER (), 0) AS avg_daily_events
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_date
ORDER BY events ASC
LIMIT 10
