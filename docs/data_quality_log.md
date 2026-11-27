# Data Quality Log

## 25 Nov 2026: baseline counts
Query run on bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*

- Event count: 4,295,584
- Distinct users (user_pseudo_id): 270,154
- Distinct event dates: 92 (covers 1 Nov 2020 to 31 Jan 2021)

Note: user_pseudo_id is a browser/device identifier, not a verified person.


## 25 Nov 2026: event names (query 01_event_names.sql)

- 17 event types found. All four funnel stages exist: first_visit, view_item, add_to_cart, begin_checkout, purchase.
- first_visit: 257,462 events but 257,314 users, so some users have more than one first_visit. To investigate.
- Users without a first_visit: about 12,840 (270,154 - 257,314). Likely first seen before 1 Nov 2020. Exclude from new-user cohorts.
- purchase: 5,692 events but 4,419 users. Cause not yet known.
- user_engagement and scroll are auto-generated tracking events. Not counted as a return.
- view_item_list has only 71 events, so it looks barely tracked. Not used in the funnel.

## 25 Nov 2026: purchase field check (query 02_purchase_field_check.sql)

| Check | Value |
|---|---|
| purchase_events | 5,692 |
| distinct_transaction_ids | 4,452 (includes "(not set)" as one value) |
| null_transaction_id | 23 |
| notset_transaction_id | 883 |
| null_revenue | 0 |
| zero_or_negative_revenue | 450 |
| purchasing_users | 4,419 |

Notes:
1. About 906 purchase events (23 + 883) have no usable order ID.
2. At most 4,451 real order IDs exist (4,452 minus "(not set)").
3. 4,786 events have a real ID (5,692 - 23 - 883) and share 4,451 IDs, so about 335 events repeat an order ID. Cause unknown. Not deleted yet.
4. 450 events have zero or negative revenue. Overlap with missing IDs not yet checked.
5. The true order count is lower than 5,692, so purchase events cannot be used as orders directly.

## 25 Nov 2026: purchase overlap (query 03_purchase_overlap_check.sql)

| id_status | revenue_status | events | distinct_ids | revenue |
|---|---|---|---|---|
| has_id | positive | 4,786 | 4,451 | 330,348 |
| not_set_id | positive | 433 | 1 | 30,489 |
| not_set_id | zero_or_negative | 450 | 1 | 0 |
| null_id | positive | 23 | 0 | 1,328 |

- All 450 zero-revenue events have "(not set)" as ID.
- Proposed valid order: real ID, revenue above 0, one row per ID.
- 906 events excluded (450 zero revenue + 456 with no ID but positive revenue worth 31,817).
- About 335 events repeat a real order ID. Not yet checked.
- Sensitivity check planned: report revenue with and without the 456 positive-revenue events.

## 25 Nov 2026: repeated order IDs (query 04_duplicate_order_check.sql)

- 326 order IDs appear more than once (335 extra events).
- 15 IDs show multiple users, 15 show different revenue, 15 span multiple dates (columns read from truncated headers; overlap between these groups not yet confirmed).
- At least 281 repeated IDs are consistent (same user, revenue, date). Likely one order recorded twice. Hypothesis, not confirmed.
- Up to 15 IDs may be one ID reused for different orders. To inspect.
- Proposed rule: one row per order ID when repeats are identical. Flagged IDs decided after inspection.

## 25 Nov 2026: odd order IDs (query 05_odd_order_ids.sql)

- 15 order IDs, 33 rows (18 extra events). The same 15 IDs show multiple users, revenue and dates.
- Pattern A (3 IDs: 140428, 333223, 43463): same user, same revenue, 24-33 ms apart (8 minutes for 43463). Likely one order recorded twice. Hypothesis.
- Pattern B (all 15 IDs): same ID used by different users on different dates with different revenue. Treated as separate orders.
- Decision: order key = transaction_id + user_pseudo_id; keep earliest event per key.
- Expected orders after this rule: about 4,466 (4,451 + 15). To confirm when building the orders table.
- Assumption: the 8-minute repeat for 43463 is a duplicate. Limitation: not provable from this data.

## 25 Nov 2026: repeated first_visit (query 06_first_visit_duplicates.sql)

| first_visit events per user | users | users on multiple dates |
|---|---|---|
| 1 | 257,167 | 0 |
| 2 | 146 | 65 |
| 3 | 1 | 0 |

- Totals reconcile: 257,314 users and 148 extra events.
- 147 users (about 0.06%) have more than one first_visit. 65 of them on different dates.
- Possible cause: identifier reset. Hypothesis, not confirmed.
- Decision: use the earliest first_visit timestamp as the cohort start. All users kept.
- Limitation: a small number of users may sit in the wrong signup week.

## 25 Nov 2026: events before first_visit (query 07_events_before_first_visit.sql)

- 257,314 users have a first_visit.
- 15 users have events on an earlier day than their first_visit. 257,299 start on the same day.
- Possible cause: earlier use before the first_visit was recorded. Hypothesis, not confirmed.
- Decision: exclude these 15 users from new-user cohorts.
- Users with no first_visit: about 12,840 (270,154 - 257,314). Also excluded from new-user cohorts.

## 25 Nov 2026: daily volume (query 08_daily_volume_check.sql)

- Average daily volume: about 46,691 events.
- Lowest day: 25 Dec 2020 with 21,355 events (about 46% of average). No day is empty.
- Eight of the 10 lowest days fall between 24 Dec 2020 and 3 Jan 2021 (holiday period). Likely lower traffic. Hypothesis, not confirmed.
- Tracking looks active on all low days (first visits and purchases still recorded).
- Limitation: holiday seasonality may affect cohort retention for late-December starters.

## 25 Nov 2026: users table built (queries 10 and 11)

- Table: ga4_project.users. Grain: one row per user_pseudo_id with a first_visit.
- Rows: 257,314 = distinct users 257,314. Matches the first_visit user count from step 3.
- 15 users flagged had_earlier_activity (matches step 9). Kept, not deleted.
- Device and source come from each user's earliest non-null value.
- null_device 0, null_source 0. Source values may still contain placeholders such as "(direct)". To inspect before grouping channels.

## 26 Nov 2026: events table built (queries 12 and 13)

- Table: ga4_project.events. Grain: one row per event, for users in the users table only.
- Event types kept: first_visit, session_start, view_item, add_to_cart, begin_checkout, add_shipping_info, add_payment_info, purchase.
- Rows: view_item 333,399; session_start 332,219; first_visit 257,462; add_to_cart 50,322; begin_checkout 32,805; add_shipping_info 16,293; add_payment_info 10,651; purchase 4,409.
- Rows equal distinct event keys for every event. Limitation: the key includes the exact timestamp, so near-duplicate events (milliseconds apart) are not detected by this check.
- null session_id: 0 for all events.
- Purchasing users: 3,511 here vs 4,419 in raw data (step 4). 908 purchasing users (about 20.5%) have no first_visit in the window, and their 1,283 purchase events are excluded. Likely returning customers. Hypothesis.
- Limitation: funnel and revenue results describe new users in the window, not all store customers.
- add_shipping_info users (8,309) almost equal begin_checkout users (8,310). Cause unknown.

## 26 Nov 2026: orders table built (queries 14 and 15)

- Table: ga4_project.orders. Grain: one row per valid order (order_id + user_id), new users only.
- Valid order: real transaction_id, revenue above 0, earliest event kept per order_id + user_id.
- Rows: 3,542 = distinct order keys 3,542. Purchasing users: 3,007. Revenue: 243,430.0 (USD).
- 4,409 purchase events in events table; 867 did not become orders. Breakdown by reason pending (step 15).
- 504 users (3,511 - 3,007) have purchase events but no valid order.
- Open question: should the funnel purchase stage use valid orders or purchase events? Decide at the funnel step and report the other as a sensitivity check.
- Limitation: revenue covers new users in the window, not all store customers.

## 26 Nov 2026: orders reconciliation (query 16_orders_reconciliation.sql)

| status | events | users | revenue |
|---|---|---|---|
| no transaction ID | 13 | 12 | 735 |
| "(not set)" ID, zero revenue | 380 | 333 | 0 |
| "(not set)" ID, positive revenue | 229 | 206 | 14,000 |
| repeat of a valid order | 245 | 221 | 16,702 |
| kept as order | 3,542 | 3,007 | 243,430 |

- Events reconcile to 4,409 purchase events in the events table.
- Repeats removed carry 16,702 revenue (about 6% of total). Assumed to be duplicates. If some are real separate purchases, revenue is understated.
- 242 events with positive revenue but no usable ID (14,735 revenue). Cannot be deduplicated. Sensitivity: revenue 258,165 if included (about +6%).
- 380 zero-revenue events probably not sales. Hypothesis.
- Decision: funnel purchase stage = user with a purchase event with revenue above 0. Revenue metrics use the orders table. Strict and loose definitions reported as sensitivity checks.


## 26 Nov 2026: acquisition source/medium (query 17_source_medium_values.sql)

- 10 distinct source/medium combinations across 257,314 users.
- Largest: google/organic 35.07%, (direct)/(none) 23.84%, <Other>/<Other> 18.03%, <Other>/referral 9.29%, google/cpc 5.48%.
- 78,786 users (30.6%) have source <Other>. Likely obfuscation in the sample data. Hypothesis.
- 46,399 users (18%) have both source and medium <Other>. Cannot be assigned to a channel.
- shop.googlemerchandisestore... as referral: 12,775 users (about 5%). Looks like the store's own domain, so probably not true acquisition. Hypothesis.
- 88 users have "(data deleted)" values.
- Channel grouping: Organic Search, Direct, Paid Search, Referral, Store referral (own domain), Unclassified (obfuscated), Data deleted/other.
- Limitation: channel comparisons are weaker because 18% of users are unclassified.

## 26 Nov 2026: channel grouping (queries 18 and 19)

- Table: ga4_project.users_with_channel (users plus channel_group). Original users table untouched.
- Groups: Organic Search 98,720 (38.37%), Direct 61,335 (23.84%), Unclassified (obfuscated) 46,399 (18.03%), Referral 23,902 (9.29%), Paid Search 14,094 (5.48%), Store referral (own domain) 12,775 (4.96%), Data deleted / other 89 (0.03%).
- Total 257,314 = users table. No user lost or duplicated.
- Limitation: 18% of users are unclassified, so channel comparisons are weaker. Report Unclassified separately.
  
## 26 Nov 2026: overall funnel (query 20_funnel_overall.sql)

Cohort: new users, no earlier activity, first_visit on or before 24 Jan 2021 (7 full days of data). Stages in order within 7 days of first_visit.

| stage | users | stage conversion | drop-off |
|---|---|---|---|
| first_visit | [fill in s1] | N/A | N/A |
| view_item | 50,110 | 21.00% | 79.00% |
| add_to_cart | 9,641 | 19.24% | 80.76% |
| begin_checkout | 3,512 | 36.43% | 63.57% |
| purchase (loose and strict) | 1,703 | 48.49% | 51.51% |

- Overall conversion (loose): 0.71%.
- Largest percentage loss: view_item to add_to_cart (80.76%).
- Strict and loose purchase counts are identical. Hypothesis: purchases with placeholder IDs come from users who skip earlier tracked stages. To test.
- 8,310 new users have a begin_checkout event at any time, but only 3,512 reach it in sequence within 7 days. Possible causes: 7-day window, skipped stages, tracking gaps. To test.
- Limitation: conversion applies to new users in the window, not all store visitors.


## 26 Nov 2026: skipped stages (query 21_funnel_skipped_stages.sql)

Cohort: 238,636 new users (7-day window). Reach counts, any order: view_item 50,110; add_to_cart 9,644; begin_checkout 7,231; purchase (valid order) 2,424.

- cart without view: 3. checkout without cart: 3,175 (43.9% of checkout users). purchase without checkout: 0. purchase without cart: 709 (29.2% of buyers).
- add_to_cart appears under-recorded. Possible causes: buy-now path, add from list or promotion, tracking gap. Hypotheses, not confirmed.
- Overall conversion: strict sequence 0.71% (1,703), reach-based about 1.02% (2,424).
- Checkout to purchase: 48.49% strict, 33.52% by reach. Reach-based is more defensible because every buyer has a checkout event.
- Cart to checkout reported as a range: 36.4% (strict) to 42.1% (reach-based among cart users).
- Decision: report strict and reach-based funnels; use reach-based for channel and device comparisons.
- Open: strict and loose purchase counts in the sequential funnel are identical (1,703). Cause not yet tested.

## 26 Nov 2026: funnel by channel (query 22_funnel_by_channel.sql)

Reach-based funnel, 7-day window, cohort 238,636 users (channel users sum to this total).

| channel | users | viewed item | view to cart | checkout to purchase | purchased of users |
|---|---|---|---|---|---|
| Organic Search | 91,545 | 21.06% | 18.78% | 34.04% | 1.03% |
| Direct | 56,880 | 21.00% | 20.06% | 33.45% | 1.01% |
| Unclassified | 43,040 | 20.83% | 19.71% | 33.23% | 1.02% |
| Referral | 22,219 | 20.87% | 19.41% | 33.43% | 0.99% |
| Paid Search | 13,049 | 20.73% | 17.63% | 35.85% | 1.02% |
| Store referral | 11,824 | 21.60% | 18.79% | 28.35% | 0.91% |
| Data deleted / other | 79 | 30.38% | 16.67% | 80.00% | 5.06% |

- Conversion is about 1% in all large channels. Largest drops (visit to view, view to cart) appear in every channel, so they look site-wide.
- Store referral checkout-to-purchase (28.35%) vs Organic (34.04%): rough z about 2.3. Lead only, multiple comparisons. Formal test in Python.
- Paid Search view-to-cart (17.63%) vs Organic (18.78%): rough z about 1.5. Within chance.
- "Data deleted / other" has 79 users. Ignore its percentages.
- Hypothesis: obfuscation in the sample may flatten channel differences. Limitation.

## 26 Nov 2026: funnel by device (query 23_funnel_by_device.sql)

Reach-based funnel, 7-day window, cohort 238,636 users (device users sum to this total).

| device | users | viewed item | view to cart | checkout to purchase | purchased of users |
|---|---|---|---|---|---|
| desktop | 138,616 | 21.13% | 19.23% | 33.25% | 1.01% |
| mobile | 94,670 | 20.81% | 19.33% | 34.07% | 1.04% |
| tablet | 5,350 | 20.90% | 18.16% | 30.52% | 0.88% |

- Desktop vs mobile overall conversion: rough z about 0.7. No meaningful difference.
- Tablet is lower but small (154 checkout users). Rough z about 0.9 vs desktop. Within chance.
- With channel results, conversion is about 1% in every segment. Largest drops look site-wide.
- Limitation: device is each user's earliest recorded value. Cross-device behaviour not captured.
- Formal tests (confidence intervals, two-proportion tests) planned in Python.

## 26 Nov 2026: time to first order (query 24_time_to_first_order.sql)

Cohort: new users with first_visit on or before 31 Dec 2020 (at least 31 days of follow-up). 2,417 buyers.

| time to first valid order | users | % of buyers | cumulative % |
|---|---|---|---|
| under 24h | 1,520 | 62.89% | 62.89% |
| 24h to 48h | 134 | 5.54% | 68.43% |
| 2 to 7 days | 252 | 10.43% | 78.86% |
| 7 to 14 days | 176 | 7.28% | 86.14% |
| 14 to 30 days | 243 | 10.05% | 96.19% |
| over 30 days | 92 | 3.81% | 100.00% |

- No order earlier than first_visit.
- 7-day window captures about 79% of first orders. 30-day captures about 96%.
- Decision: keep 7 days as primary conversion window; report 30-day conversion as a sensitivity check (cohorts through 1 Jan 2021).
- Limitation: the funnel's 7-day conversion is a lower bound. Over-30-day group is truncated by the end of data.
- Open question 1 (BRD): resolved.

## 26 Nov 2026: overall retention (query 25_retention_overall.sql)

Cohort: new users (no earlier activity). Day N = first_visit date + N days (UTC dates). Exact-day returns only. Eligible if first_visit date + N is on or before 31 Jan 2021.

| day | eligible users | session return | shopping return |
|---|---|---|---|
| Day 1 | 255,174 | 10,754 (4.21%) | 2,457 (0.96%) |
| Day 7 | 238,636 | 1,586 (0.66%) | 482 (0.20%) |
| Day 30 | 170,403 | 223 (0.13%) | 85 (0.05%) |

- Retention is low and falls steeply. No benchmark verified, so no good/bad claim.
- Exact-day definition is strict. A "returned within N days" sensitivity check is planned.
- Shopping return at Day 30 is only 85 users. Splits by cohort or channel will be noisy.
- Possible causes of low retention (hypotheses): device/cookie-based IDs, one-off merchandise visits, obfuscation.
- Decision: primary retention = session return; secondary = shopping return. BRD retention definition updated (v0.2).
- Limitation: day boundary uses UTC dates.

## 26 Nov 2026: weekly cohort retention (query 26_retention_weekly_cohorts.sql)

Cohort week starts Sunday (first_visit week). A cohort is shown for Day N only if its last day + N is on or before 31 Jan 2021. Session return = session_start on exactly Day N (UTC dates).

| cohort week | users | D1 session % | D7 session % | D30 session % (users) | D1 shopping % | D7 shopping % |
|---|---|---|---|---|---|---|
| 2020-11-01 | 16,925 | 4.73 | 0.83 | 0.21 (36) | 0.97 | 0.15 |
| 2020-11-08 | 14,543 | 5.27 | 1.27 | 0.24 (35) | 1.05 | 0.41 |
| 2020-11-15 | 16,584 | 5.83 | 0.87 | 0.20 (33) | 1.39 | 0.26 |
| 2020-11-22 | 18,300 | 4.83 | 0.89 | 0.03 (5) | 1.07 | 0.28 |
| 2020-11-29 | 21,109 | 5.19 | 0.85 | 0.07 (15) | 1.32 | 0.27 |
| 2020-12-06 | 27,093 | 4.35 | 0.66 | 0.15 (41) | 1.09 | 0.24 |
| 2020-12-13 | 24,524 | 3.80 | 0.39 | 0.13 (31) | 1.19 | 0.13 |
| 2020-12-20 | 17,397 | 3.12 | 0.33 | 0.09 (15) | 0.48 | 0.14 |
| 2020-12-27 | 16,224 | 2.81 | 0.37 | n/a | 0.47 | 0.06 |
| 2021-01-03 | 22,319 | 3.54 | 0.47 | n/a | 0.70 | 0.13 |
| 2021-01-10 | 21,025 | 3.58 | 0.61 | n/a | 0.64 | 0.16 |
| 2021-01-17 | 20,318 | 4.22 | 0.65 | n/a | 1.06 | 0.24 |
| 2021-01-24 | 18,813 | 3.89 | n/a | n/a | 0.97 | n/a |
| 2021-01-31 | 2,125 | n/a | n/a | n/a | n/a | n/a |

- Cohort users sum to 257,299 (257,314 minus 15 flagged). First 13 cohorts sum to 255,174 = Day 1 eligible users in the overall query. Size-weighted Day 1 average about 4.21%, matching overall.
- Early-season cohorts retain better at Day 1 and Day 7. Dip in the weeks of 13 Dec to 27 Dec.
- December cohorts are the largest but retain worse. Possible reason: more one-off holiday visitors. Hypothesis.
- Day 30 cells hold 5 to 41 users. Not reliable for comparison.
- Cannot separate seasonality from product or tracking changes. Rough standard-error check suggests the Day 1 gap exceeds sampling noise. Formal tests in Python.
- Weekly eligibility is stricter than the overall query, so Day 7 and Day 30 figures differ by construction.

## 26 Nov 2026: retention by channel (query 27_retention_by_channel.sql)

Session return on exact Day N (UTC dates). User-level eligibility: first_visit date + N on or before 31 Jan 2021.

| channel | D1 users | D1 % | D7 % | D30 users | D30 returned | D30 % |
|---|---|---|---|---|---|---|
| Organic Search | 97,894 | 4.15 | 0.70 | 65,394 | 75 | 0.11 |
| Direct | 60,847 | 4.33 | 0.63 | 40,523 | 58 | 0.14 |
| Unclassified | 46,028 | 4.14 | 0.64 | 30,698 | 38 | 0.12 |
| Referral | 23,707 | 4.21 | 0.74 | 15,837 | 25 | 0.16 |
| Paid Search | 13,954 | 4.41 | 0.66 | 9,399 | 11 | 0.12 |
| Store referral | 12,659 | 4.21 | 0.56 | 8,499 | 16 | 0.19 |
| Data deleted / other | 85 | 10.59 | 1.27 | 53 | 0 | 0.00 |

- Totals reconcile: D1 users 255,174; D7 users 238,636; D30 users 170,403; D30 returners 223 (all match the overall retention query).
- Channels retain almost equally. D1 4.14 to 4.41%, D7 0.56 to 0.74% (excluding the 85-user group).
- Largest gaps (Paid vs Organic D1, rough z about 1.4; Store referral vs Organic D7, about 1.7) are within chance. Formal tests in Python.
- Day 30 rests on 11 to 75 returning users per channel. Not reliable for comparison.
- Hypothesis: obfuscation may flatten channel differences. Limitation.

## 26 Nov 2026: revenue and repeat purchase by channel (query 28_revenue_by_channel.sql)

7-day metrics: new users with first_visit on or before 24 Jan 2021. Repeat rate: 30-day window, first_visit on or before 1 Jan 2021. Revenue from valid orders only.

| channel | users | orders | buyers | revenue | AOV | revenue per user | repeat buyers / buyers (30d) | repeat rate |
|---|---|---|---|---|---|---|---|---|
| Organic Search | 91,545 | 1,078 | 947 | 71,308 | 66.15 | 0.779 | 100 / 937 | 10.67% |
| Direct | 56,880 | 663 | 572 | 43,728 | 65.95 | 0.769 | 62 / 536 | 11.57% |
| Unclassified | 43,040 | 487 | 440 | 32,622 | 66.99 | 0.758 | 46 / 412 | 11.17% |
| Referral | 22,219 | 245 | 220 | 17,452 | 71.23 | 0.785 | 26 / 207 | 12.56% |
| Paid Search | 13,049 | 143 | 133 | 10,752 | 75.19 | 0.824 | 14 / 133 | 10.53% |
| Store referral | 11,824 | 119 | 108 | 9,071 | 76.23 | 0.767 | 10 / 103 | 9.71% |
| Data deleted / other | 79 | 4 | 4 | 173 | 43.25 | 2.19 | 0 / 5 | 0.00% |

- Reconciles: users 238,636; buyers 2,424 (match reach-based funnel); orders 2,739; revenue 185,106 (7-day window, below full-window 243,430 as expected).
- Revenue per user 0.76 to 0.82 across large channels. Differences untested.
- Paid Search and Store referral AOV (75.19, 76.23) above Organic (66.15). Based on 143 and 119 orders. Lead only. Bootstrap or t-test in Python.
- Repeat purchase 9.7 to 12.6% on 10 to 100 repeat buyers per channel. Rough z for widest gap about 0.75. Within chance.
- Overall 30-day repeat rate: 258 of 2,333 buyers (11.06%).
- Limitation: no cost data, so no ROI claim. Revenue is observed in a short window, not lifetime value.

## 26 Nov 2026: reporting table (queries 29 and 30)

- Table: ga4_project.rpt_user_metrics. Grain: one row per new user (no earlier activity), 257,299 users.
- Columns: channel, device, cohort week, eligibility flags (D1, D7/funnel, D30/repeat), 7-day funnel flags, orders and revenue (7d), orders (30d), retention flags (session D1/D7/D30, shopping D1/D7).
- Reconciliation check matched earlier results: users 257,299; funnel cohort 238,636; buyers (7d) 2,424; revenue (7d) 185,106; D1 returned 10,754; D7 returned 1,586; D30 returned 223.
- Purpose: single source for Power BI measures and the Python recalculation.

## 26 Nov 2026: Python check on rpt_user_metrics (Colab notebook)

- Loaded rpt_user_metrics into Pandas and recomputed funnel counts, buyers, revenue and D1/D7/D30 returns from its flags.
- All values matched the SQL results.
- Limitation: this check reads flags created by SQL, so it does not test the SQL rules themselves. Independent rebuild from raw purchase events is the next check.

## 27 Nov 2026: independent rebuild of orders in Pandas (Colab notebook)

- Rebuilt valid orders from raw purchase events in Pandas: real transaction_id, revenue above 0, earliest event per order_id + user_id.
- Results matched the SQL orders table (valid orders, buyers, revenue) and the 7-day figures (orders, buyers, revenue).
- This tests the SQL rules, not only the SQL flags.

## 27 Nov 2026: significance tests (Colab notebook)

Two-proportion z-tests with Wilson intervals, Holm correction across 9 comparisons. Bootstrap (10,000 resamples, seed 42) for order value.

| test | rate A % | n A | rate B % | n B | diff (pp) | p raw | p Holm |
|---|---|---|---|---|---|---|---|
| Checkout to purchase: Store referral vs Organic | 28.35 | 381 | 34.04 | 2,782 | -5.69 | 0.0271 | 0.1894 |
| View to cart: Paid Search vs Organic | 17.63 | 2,705 | 18.77 | 19,279 | -1.14 | 0.1547 | 0.7009 |
| Purchased in 7 days: Paid Search vs Organic | 1.02 | 13,049 | 1.03 | 91,545 | -0.02 | 0.8721 | 1.0000 |
| Purchased in 7 days: Desktop vs Mobile | 1.01 | 138,616 | 1.04 | 94,670 | -0.03 | 0.4654 | 1.0000 |
| Purchased in 7 days: Tablet vs Desktop | 0.88 | 5,350 | 1.01 | 138,616 | -0.13 | 0.3567 | 1.0000 |
| Day 1 return: Nov cohorts vs mid/late-Dec cohorts | 5.16 | 87,461 | 3.32 | 58,145 | 1.84 | 0.0000 | 0.0000 |
| Day 7 return: Nov cohorts vs mid/late-Dec cohorts | 0.93 | 87,461 | 0.37 | 58,145 | 0.56 | 0.0000 | 0.0000 |
| Day 7 return: Store referral vs Organic | 0.56 | 11,824 | 0.70 | 91,545 | -0.14 | 0.0843 | 0.5059 |
| Day 1 return: Paid Search vs Organic | 4.41 | 13,954 | 4.15 | 97,894 | 0.27 | 0.1402 | 0.7009 |

- Only the two cohort-timing tests are significant after correction. Cause unknown (season, traffic mix, product or tracking changes cannot be separated).
- Store referral checkout-to-purchase gap (raw p 0.027) is not significant after correction. Dropped as a finding.
- No evidence of channel or device effects on conversion or retention. Desktop vs mobile conversion gap: approximate 95% interval -0.11 to +0.05 pp (back-of-envelope).
- AOV: Paid 75.19 (143 orders) vs Organic 66.15 (1,078 orders). Bootstrap 95% CI for difference -4.87 to 24.38, includes zero. Not established.
- Organic view-to-cart prints 18.77% (SQL 18.78%): test counts only users who viewed first; a few users have a cart event without a view.
- Limitations: comparisons chosen after viewing results (post hoc); user_pseudo_id is a device identifier, so independence is approximate.
