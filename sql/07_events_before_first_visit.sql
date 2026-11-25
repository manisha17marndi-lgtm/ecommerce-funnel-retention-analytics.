-- Do any users have events on a day before their first_visit date?
WITH fv AS (
  SELECT
    user_pseudo_id,
    MIN(TIMESTAMP_MICROS(event_timestamp)) AS first_visit_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'first_visit'
  GROUP BY user_pseudo_id
),
ev AS (
  SELECT
    user_pseudo_id,
    MIN(TIMESTAMP_MICROS(event_timestamp)) AS first_event_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY user_pseudo_id
)
SELECT
  COUNT(*) AS users_with_first_visit,
  COUNTIF(DATE(ev.first_event_ts) < DATE(fv.first_visit_ts)) AS users_with_events_on_earlier_day,
  COUNTIF(DATE(ev.first_event_ts) = DATE(fv.first_visit_ts)) AS users_same_day
FROM fv
JOIN ev USING (user_pseudo_id)
