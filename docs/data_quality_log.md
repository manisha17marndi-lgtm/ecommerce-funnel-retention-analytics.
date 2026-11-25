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
