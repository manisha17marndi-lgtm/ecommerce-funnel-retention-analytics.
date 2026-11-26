-- EVENTS table. Grain: one row per recorded event (meaningful event types only).
-- Restricted to users in the users table (those with a first_visit).
-- No deduplication yet: duplicates are checked in the next step before any removal.
CREATE OR REPLACE TABLE `ga4-funnel-project-515805.ga4_project.events` AS
SELECT
  TO_HEX(MD5(CONCAT(
    e.user_pseudo_id, '|',
    CAST(e.event_timestamp AS STRING), '|',
    e.event_name, '|',
    IFNULL(CAST((SELECT value.int_value FROM UNNEST(e.event_params)
                 WHERE key = 'ga_session_id') AS STRING), '')
  ))) AS event_key,
  e.user_pseudo_id AS user_id,
  TIMESTAMP_MICROS(e.event_timestamp) AS event_timestamp,
  PARSE_DATE('%Y%m%d', e.event_date) AS event_date,
  e.event_name,
  (SELECT value.int_value FROM UNNEST(e.event_params)
   WHERE key = 'ga_session_id') AS session_id
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` e
JOIN `ga4-funnel-project-515805.ga4_project.users` u
  ON e.user_pseudo_id = u.user_id
WHERE e._TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND e.event_name IN ('first_visit', 'session_start', 'view_item', 'add_to_cart',
                       'begin_checkout', 'add_shipping_info', 'add_payment_info',
                       'purchase');
