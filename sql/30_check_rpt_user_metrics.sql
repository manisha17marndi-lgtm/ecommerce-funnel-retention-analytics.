-- Reconcile the reporting table to earlier results
SELECT
  COUNT(*) AS rows_total,
  COUNT(DISTINCT user_id) AS distinct_users,
  COUNTIF(eligible_d7_and_funnel) AS funnel_cohort_users,
  COUNTIF(eligible_d7_and_funnel AND orders_7d > 0) AS buyers_7d,
  ROUND(SUM(IF(eligible_d7_and_funnel, revenue_7d, 0)), 2) AS revenue_7d,
  COUNTIF(eligible_d1 AND ret_d1_session) AS d1_returned,
  COUNTIF(eligible_d7_and_funnel AND ret_d7_session) AS d7_returned,
  COUNTIF(eligible_d30_and_repeat AND ret_d30_session) AS d30_returned
FROM `ga4-funnel-project-515805.ga4_project.rpt_user_metrics`
