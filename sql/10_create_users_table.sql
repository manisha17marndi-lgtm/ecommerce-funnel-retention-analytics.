-- USERS table. Grain: one row per user_pseudo_id that has a first_visit event.
-- Cohort start = earliest first_visit (decision from step 8).
-- Users with no first_visit are excluded (decision from step 3).
-- Users with activity before their first_visit day are flagged, not deleted (step 9).
CREATE OR REPLACE TABLE `ga4-funnel-project-515805.ga4_project.users` AS
WITH raw AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_timestamp,
    TIMESTAMP_MICROS(event_timestamp) AS ts,
    device.category AS device_category,
    traffic_source.source AS source,
    traffic_source.medium AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
fv AS (
  SELECT user_pseudo_id, MIN(ts) AS first_visit_ts
  FROM raw
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),
fe AS (
  SELECT user_pseudo_id, MIN(ts) AS first_event_ts
  FROM raw
  GROUP BY user_pseudo_id
),
attrs AS (
  -- device and source taken from each user's earliest event that has a value
  SELECT
    user_pseudo_id,
    ARRAY_AGG(device_category IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS device_category,
    ARRAY_AGG(source IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS acquisition_source,
    ARRAY_AGG(medium IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS acquisition_medium
  FROM raw
  GROUP BY user_pseudo_id
)
SELECT
  fv.user_pseudo_id AS user_id,
  fv.first_visit_ts,
  DATE(fv.first_visit_ts) AS first_visit_date,
  a.device_category,
  a.acquisition_source,
  a.acquisition_medium,
  DATE(fe.first_event_ts) < DATE(fv.first_visit_ts) AS had_earlier_activity
FROM fv
JOIN fe USING (user_pseudo_id)
JOIN attrs a USING (user_pseudo_id);
