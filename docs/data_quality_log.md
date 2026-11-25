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
