# AI-assisted validation example

## Purpose
Show how an AI assistant was used to speed up the analysis, and how every important result was checked independently instead of being trusted.

## Workflow
1. Define each metric in writing first (BRD and metric dictionary).
2. Ask the AI assistant to draft SQL from those definitions.
3. Run the SQL in BigQuery myself and read the results.
4. Recalculate selected metrics in Python (Pandas), using different code.
5. Compare the two results. If they differ, investigate and document the cause.
6. Save the final query and note what was found.

## What the AI assistant drafted
- SQL for the users, events, orders and reporting tables, and for the funnel, retention (overall, weekly, by channel) and revenue queries.
- Candidate data-quality checks, and first drafts of the explanations of results.
- Python code for the validation checks, significance tests and charts.

## What I verified independently

| Check | How | Result |
|---|---|---|
| Day 7 retention | Rebuilt from raw session_start events in Pandas, without using the SQL flags | Matched SQL: 238,636 eligible users, 1,586 returned, 0.66% |
| Valid orders and revenue | Rebuilt from raw purchase events in Pandas with the same rules | Matched SQL: 3,542 orders, 243,430 revenue; 7-day figures also matched |
| Funnel counts, buyers, retention counts | Recomputed from the reporting table | Matched SQL |
| Differences between channels, devices and cohorts | Two-proportion tests with confidence intervals, Holm correction for nine comparisons, bootstrap for order value | Only the cohort-timing differences were significant |

## Discrepancies and corrections found during review
- **Retention definition.** The BRD defined a return as a shopping event only. That mostly measured shopping behaviour, so session returns became the primary measure (BRD v0.2) and shopping returns the secondary one.
- **Funnel.** A strict sequential funnel understated conversion because add_to_cart looks under-recorded: 3,175 users reached checkout with no cart event. I now report a strict and a reach-based funnel side by side.
- **Duplicate detection.** The event key includes the exact timestamp, so purchases recorded milliseconds apart were not caught by it. Duplicates are handled in the orders table with an order_id + user_id key.
- **Rough estimate dropped.** The Store referral checkout-to-purchase gap looked meaningful (raw p = 0.027) but was not significant after correction for multiple tests (p = 0.189), so it is not reported as a finding.
- **Small numeric difference.** Organic view-to-cart printed 18.77% in Python and 18.78% in SQL. The Python test counts only users who viewed an item first, and a few users have a cart event without a view. No error found.

No numerical error was found in the SQL itself for the checks above. The AI's explanations of why patterns occur (for example the December retention dip) are hypotheses, not findings.

## What I did myself
I ran every query in BigQuery and every check in Colab, compared the printed numbers with the SQL results, and stopped to investigate whenever a number looked unexpected, such as the purchase events with placeholder transaction IDs and the checkout users without an add_to_cart event. I can explain the three pieces of logic below.

### 1. Removing duplicate orders in SQL (window function)
```sql
SELECT order_id, user_id, order_ts, order_value
FROM p
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id, user_id ORDER BY order_ts) = 1
```
For each order_id and user_id pair, the rows are numbered from earliest to latest and only row 1 is kept. Some purchase events were recorded twice, milliseconds apart, and counting both would overstate orders and revenue. I used order_id plus user_id, not order_id alone, because 15 order IDs were reused by different users on different dates, so those are separate purchases.

### 2. Rebuilding valid orders in Pandas (filter and drop duplicates)
```python
valid = p[p['order_id'].notna() & (p['order_id'] != '(not set)') & (p['revenue'] > 0)]
orders_py = valid.sort_values('ts').drop_duplicates(['order_id', 'user_id'], keep='first')
```
The first line keeps purchases with a real transaction ID and revenue above 0. The second sorts by time and keeps the earliest row for each order_id and user_id. It applies the same rules as the SQL in different code, starting from raw events, and the result matched the SQL orders table.

### 3. Comparing returning and non-returning users (groupby)
```python
d.groupby('returned_d1').agg(users=('user_id', 'count'), bought=('bought_7d', 'mean'))
```
This splits users into returned and not returned, then counts them and takes the average of the purchase flag. The average of a True/False column is the share of True, so it gives the purchase rate for each group. This is a description, not proof of cause: returners have more days to shop, and people who intend to buy may be more likely to return.

## Limits of this validation
- SQL and Python use the same metric definitions, so they test the logic, not whether the definitions are right.
- Users are device identifiers (user_pseudo_id), not verified people.
- The data covers three months, including the holiday season, and is obfuscated.
- Comparisons were chosen after viewing the tables, so they are exploratory.

## Data safety
Only public, obfuscated sample data was used. No confidential data was sent to an AI service.
