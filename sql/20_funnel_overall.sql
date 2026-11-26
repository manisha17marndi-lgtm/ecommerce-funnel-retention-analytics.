-- OVERALL USER-BASED FUNNEL
-- Cohort: new users (had a first_visit, no earlier activity) whose first visit leaves
--         a full 7 days of data (first_visit_date <= 2021-01-24).
-- Each stage must happen AFTER the previous stage and within 7 days of first_visit.
-- Purchase stage, two versions (decision from step 15):
--   loose = purchase event with revenue above 0
--   strict = a valid order in the orders table
WITH cohort AS (
  SELECT user_id, first_visit_ts
  FROM `ga4-funnel-project-515805.ga4_project.users_with_channel`
  WHERE NOT had_earlier_activity
    AND first_visit_date <= DATE '2021-01-24'
),
vi AS (
  SELECT c.user_id, MIN(e.event_timestamp) AS ts
  FROM cohort c
  JOIN `ga4-funnel-project-515805.ga4_project.events` e
    ON e.user_id = c.user_id AND e.event_name = 'view_item'
   AND e.event_timestamp >= c.first_visit_ts
   AND e.event_timestamp <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY c.user_id
),
atc AS (
  SELECT c.user_id, MIN(e.event_timestamp) AS ts
  FROM cohort c
  JOIN vi ON vi.user_id = c.user_id
  JOIN `ga4-funnel-project-515805.ga4_project.events` e
    ON e.user_id = c.user_id AND e.event_name = 'add_to_cart'
   AND e.event_timestamp >= vi.ts
   AND e.event_timestamp <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY c.user_id
),
bc AS (
  SELECT c.user_id, MIN(e.event_timestamp) AS ts
  FROM cohort c
  JOIN atc ON atc.user_id = c.user_id
  JOIN `ga4-funnel-project-515805.ga4_project.events` e
    ON e.user_id = c.user_id AND e.event_name = 'begin_checkout'
   AND e.event_timestamp >= atc.ts
   AND e.event_timestamp <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY c.user_id
),
pu_loose AS (
  SELECT c.user_id, MIN(TIMESTAMP_MICROS(r.event_timestamp)) AS ts
  FROM cohort c
  JOIN bc ON bc.user_id = c.user_id
  JOIN `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` r
    ON r.user_pseudo_id = c.user_id
   AND r._TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
   AND r.event_name = 'purchase'
   AND r.ecommerce.purchase_revenue_in_usd > 0
   AND TIMESTAMP_MICROS(r.event_timestamp) >= bc.ts
   AND TIMESTAMP_MICROS(r.event_timestamp) <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY c.user_id
),
pu_strict AS (
  SELECT c.user_id, MIN(o.order_ts) AS ts
  FROM cohort c
  JOIN bc ON bc.user_id = c.user_id
  JOIN `ga4-funnel-project-515805.ga4_project.orders` o
    ON o.user_id = c.user_id
   AND o.order_ts >= bc.ts
   AND o.order_ts <= TIMESTAMP_ADD(c.first_visit_ts, INTERVAL 7 DAY)
  GROUP BY c.user_id
),
counts AS (
  SELECT
    COUNT(*) AS s1_first_visit,
    COUNTIF(vi.ts IS NOT NULL) AS s2_view_item,
    COUNTIF(atc.ts IS NOT NULL) AS s3_add_to_cart,
    COUNTIF(bc.ts IS NOT NULL) AS s4_begin_checkout,
    COUNTIF(pl.ts IS NOT NULL) AS s5_purchase_loose,
    COUNTIF(ps.ts IS NOT NULL) AS s5_purchase_strict
  FROM cohort c
  LEFT JOIN vi ON vi.user_id = c.user_id
  LEFT JOIN atc ON atc.user_id = c.user_id
  LEFT JOIN bc ON bc.user_id = c.user_id
  LEFT JOIN pu_loose pl ON pl.user_id = c.user_id
  LEFT JOIN pu_strict ps ON ps.user_id = c.user_id
)
SELECT
  *,
  ROUND(100 * s2_view_item / s1_first_visit, 2) AS pct_visit_to_view,
  ROUND(100 * s3_add_to_cart / s2_view_item, 2) AS pct_view_to_cart,
  ROUND(100 * s4_begin_checkout / s3_add_to_cart, 2) AS pct_cart_to_checkout,
  ROUND(100 * s5_purchase_loose / s4_begin_checkout, 2) AS pct_checkout_to_purchase_loose,
  ROUND(100 * s5_purchase_strict / s4_begin_checkout, 2) AS pct_checkout_to_purchase_strict,
  ROUND(100 * s5_purchase_loose / s1_first_visit, 2) AS overall_conversion_loose
FROM counts
