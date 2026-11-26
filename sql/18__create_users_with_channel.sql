-- USERS_WITH_CHANNEL: users table plus a channel group, using the rules from step 16.
-- A new table is created (the original users table stays untouched).
CREATE OR REPLACE TABLE `ga4-funnel-project-515805.ga4_project.users_with_channel` AS
SELECT
  u.*,
  CASE
    WHEN acquisition_source = '(data deleted)' OR acquisition_medium = '(data deleted)'
      THEN 'Data deleted / other'
    WHEN acquisition_source = '(direct)' AND acquisition_medium = '(none)'
      THEN 'Direct'
    WHEN acquisition_medium = 'organic' THEN 'Organic Search'
    WHEN acquisition_medium = 'cpc' THEN 'Paid Search'
    WHEN acquisition_medium = 'referral'
         AND acquisition_source LIKE 'shop.googlemerchandisestore%'
      THEN 'Store referral (own domain)'
    WHEN acquisition_medium = 'referral' THEN 'Referral'
    WHEN acquisition_source = '<Other>' AND acquisition_medium = '<Other>'
      THEN 'Unclassified (obfuscated)'
    ELSE 'Data deleted / other'
  END AS channel_group
FROM `ga4-funnel-project-515805.ga4_project.users` u;
