# E-Commerce Customer Churn & RFM Segmentation (SQL-Only)

I built this project SQL-only on purpose. Most portfolio projects are
a Jupyter notebook calling df.groupby() — that's not what analytics
looks like in production. Real warehouses run SQL. So I wanted to show
I can write window functions and nested CTEs directly, not just wrap
everything in pandas.

The dataset is synthetic but calibrated to real published Olist
statistics (97% one-time buyers, ~12 day delivery times, same category
and payment mix). I built the generator myself rather than downloading
a CSV, because I wanted full control over the schema and the ability
to scale it up or swap in real data without touching the SQL.

---

## What this project demonstrates

- Window functions: `NTILE`, `FIRST_VALUE`, `PARTITION BY`
- Multi-level nested CTEs
- A business reframing that actually matters: "churn" as defined in
  SaaS doesn't apply to a marketplace. Month-1 retention under 1%
  looks like a crisis — it isn't. I show why, and replace it with
  a metric that actually predicts revenue risk.

---

## Key Finding #1: Churn needs to be redefined for a marketplace

Month-1 retention is under 1% for every cohort. A SaaS analyst would
call this a churn crisis. It isn't — it's structurally normal for a
marketplace where most people buy once for a specific need and don't
return monthly. The right question is "what % return within 90/180
days, and which segment predicts that." That's what the RFM analysis
answers.

| cohort_month | period_number | cohort_size | retention_pct |
|---|---|---|---|
| 2016-09 | 0 | 360 | 100.0 |
| 2016-09 | 1 | 360 | 0.56 |
| 2016-10 | 0 | 383 | 100.0 |
| 2016-10 | 1 | 383 | 0.78 |

---

## Key Finding #2: 31% of customers drive 55% of revenue

RFM segmentation using `NTILE(5)` window functions. Champions + At
Risk together are 31.4% of customers but 54.6% of total revenue. The
At Risk group is the highest-leverage target for a retention campaign —
same historical value as Champions, but losable.

| Segment | Customers | % of revenue | Avg revenue |
|---|---|---|---|
| Regular | 3,369 | 33.4% | R$138.82 |
| Champion | 1,468 | 28.2% | R$268.70 |
| At Risk (high value) | 1,454 | 26.4% | R$254.13 |
| Lost | 1,511 | 6.1% | R$56.80 |
| New / Promising | 1,493 | 6.0% | R$55.90 |

---

## How to run it

```bash
python scripts/generate_data.py
python scripts/run_query.py sql/01_cohort_retention.sql
python scripts/run_query.py sql/02_rfm_segmentation.sql
python scripts/run_query.py sql/03_segment_summary.sql
```

Or open `data/ecommerce.db` in DB Browser for SQLite and run the
`.sql` files directly.

---

## Stack

SQLite · Python 3 stdlib only · Window functions: NTILE, FIRST_VALUE,
