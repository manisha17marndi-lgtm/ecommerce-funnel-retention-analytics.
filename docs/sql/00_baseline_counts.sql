-- Purpose: baseline counts for the GA4 sample dataset (Nov 2020 - Jan 2021)
-- Used to check that later queries and tables reconcile with the raw data.
SELECT COUNT(*) AS event_count,
       COUNT(DISTINCT user_pseudo_id) AS user_count,
       COUNT(DISTINCT event_date) AS day_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;
