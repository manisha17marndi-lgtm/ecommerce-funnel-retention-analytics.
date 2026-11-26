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
