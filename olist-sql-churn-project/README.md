# E-Commerce Customer Churn & RFM Segmentation (SQL-Only)

A pure-SQL analysis of customer retention and value segmentation in a
Brazilian e-commerce marketplace, using window functions and nested CTEs
in SQLite. No pandas, no notebooks for the analysis logic — every result
below was produced by running the `.sql` files in this repo directly
against the database.

## Why this project

Most "data analyst portfolio" projects on GitHub are a Jupyter notebook
running `df.groupby()`. This one is deliberately SQL-only, because SQL —
not pandas — is what most companies actually run analytics on in
production (warehouses, BI tools, dbt models). It demonstrates:

- Window functions (`NTILE`, `FIRST_VALUE`, `PARTITION BY`)
- Multi-level nested CTEs
- A non-trivial business reframing: **why "churn" as commonly defined
  doesn't apply to a marketplace business**, and how to redefine it
  correctly (see *Key Finding* below)

## Dataset

This project uses a **synthetically generated dataset**, not a raw
download. The generator (`scripts/generate_data.py`) is parametrized to
match the publicly documented statistics of the real
[Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(Kaggle, ~100k orders, Sep 2016–Oct 2018):

| Statistic | Real Olist (published) | This synthetic dataset |
|---|---|---|
| One-time buyers | ~97% | ~97% (built into generator) |
| Avg delivery time | ~12 days | ~12 days (gamma-distributed) |
| Review score distribution | 5★:58%, 1★:11% (bimodal) | Same weights, delivered orders |
| Top category share | bed_bath_table ~10% | Same weight table |
| Payment mix | credit card ~74% | Same weight table |

**Why synthetic, disclosed honestly:** this repo needs to run end-to-end
for anyone who clones it, without requiring Kaggle API credentials. The
schema is identical to the real dataset, so if you do have Kaggle access,
you can drop the real CSVs into `data/` (matching table/column names) and
every query in `sql/` runs unchanged. Data provenance should always be
explicit — a client or reviewer should never have to guess whether
numbers are real or simulated.

Scale: 9,600 customers / 10,091 orders / 12,601 line items (10% scale of
the real dataset, for fast local runs — change `N_CUSTOMERS` in the
generator to scale up).

## Repo structure

```
.
├── data/
│   └── ecommerce.db          # SQLite DB (generated, not committed if large)
├── scripts/
│   ├── generate_data.py      # builds the synthetic dataset
│   └── run_query.py          # executes a .sql file, prints formatted output
├── sql/
│   ├── 01_cohort_retention.sql
│   ├── 02_rfm_segmentation.sql
│   └── 03_segment_summary.sql
└── README.md
```

## How to run it

```bash
pip install -r requirements.txt   # only stdlib used, but kept for completeness
python scripts/generate_data.py   # builds data/ecommerce.db
python scripts/run_query.py sql/01_cohort_retention.sql
python scripts/run_query.py sql/02_rfm_segmentation.sql
python scripts/run_query.py sql/03_segment_summary.sql
```

Or open `data/ecommerce.db` in any SQLite client (DB Browser for SQLite,
DBeaver, VS Code SQLite extension) and run the `.sql` files directly.

---

## Key Finding #1: "Churn" needs to be redefined for a marketplace

`sql/01_cohort_retention.sql` builds a monthly cohort retention table
using `FIRST_VALUE() OVER (PARTITION BY ...)` to compute % of each
cohort still active in months 1 through 6.

**Result (real output from this dataset):**

| cohort_month | period_number | num_active_customers | cohort_size | retention_pct |
|---|---|---|---|---|
| 2016-09 | 0 | 360 | 360 | 100.0 |
| 2016-09 | 1 | 2 | 360 | 0.56 |
| 2016-09 | 2 | 4 | 360 | 1.11 |
| 2016-10 | 0 | 383 | 383 | 100.0 |
| 2016-10 | 1 | 3 | 383 | 0.78 |
| 2016-11 | 0 | 381 | 381 | 100.0 |
| 2016-11 | 2 | 7 | 381 | 1.84 |

**Interpretation:** month-1 retention is under 1% for every cohort. A
SaaS analyst would call this a churn crisis. It isn't — it's structurally
normal for a multi-category marketplace where most people buy once for a
specific need (furniture, a phone case, a gift) and don't return on a
monthly cadence. **The correct question isn't "did they come back next
month" — it's "what % return within 90/180/365 days, and which segment
predicts that."** This is exactly what the RFM analysis below answers.

This distinction — *retention metrics must match the business model, not
be copy-pasted from a different one* — is the single most useful thing
to point out to a freelance client who's about to misinterpret their own
dashboard.

## Key Finding #2: RFM segmentation reveals revenue concentration

`sql/02_rfm_segmentation.sql` scores every customer 1–5 on Recency,
Frequency, and Monetary value using `NTILE(5)` window functions, then
labels them into five segments. `sql/03_segment_summary.sql` rolls that
up into a business-readable table.

**Result (real output from this dataset):**

| rfm_segment | num_customers | % of customers | total_revenue | % of revenue | avg revenue/customer |
|---|---|---|---|---|---|
| Regular | 3,369 | 36.2% | R$467,679 | 33.4% | R$138.82 |
| Champion | 1,468 | 15.8% | R$394,454 | 28.2% | R$268.70 |
| At Risk (high value) | 1,454 | 15.6% | R$369,506 | 26.4% | R$254.13 |
| Lost | 1,511 | 16.3% | R$85,823 | 6.1% | R$56.80 |
| New / Promising | 1,493 | 16.1% | R$83,452 | 6.0% | R$55.90 |

**Interpretation:** Champions + At Risk together are **31.4% of
customers but 54.6% of total revenue.** The "At Risk (high value)"
segment — customers who used to spend well but haven't ordered
recently — is the single highest-leverage group for a retention
campaign: same historical value as Champions, but losable. This is the
list a marketing team should email first, not the full customer base.

---

## What I'd add with more time / real data access

- Statistical significance testing on retention differences between
  cohorts (chi-square), not just descriptive %
- Survival analysis (Kaplan-Meier) instead of fixed-period cohort buckets
- Swap in the real Kaggle CSVs once API access is available — zero SQL
  changes required, same schema

## Tech stack

SQLite 3 · Python 3 (stdlib `sqlite3` only, no pandas in the analysis
layer — that's a deliberate constraint of this project) · Window
functions: `NTILE`, `FIRST_VALUE`, `PARTITION BY`/`ORDER BY`
