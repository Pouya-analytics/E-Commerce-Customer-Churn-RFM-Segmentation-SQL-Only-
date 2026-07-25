-- =====================================================================
-- 01_cohort_retention.sql
-- Monthly cohort retention analysis using window functions.
--
-- Business question: Of customers who made their FIRST purchase in
-- month X, what % returned to buy again in month X+1, X+2, ... X+6?
--
-- Note on "churn" in a marketplace context: Olist-style marketplaces
-- have ~95-97% one-time buyers by nature (unlike SaaS subscriptions).
-- So "churn" here is reframed as "failure to return within N days of
-- first purchase" -- a more honest and more useful definition for a
-- non-subscription business. This query measures exactly that.
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 1: Assign each customer to a cohort = month of their first order
-- ---------------------------------------------------------------------
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(DATE(order_purchase_timestamp)) AS first_order_date,
        strftime('%Y-%m', MIN(order_purchase_timestamp)) AS cohort_month
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),

-- ---------------------------------------------------------------------
-- STEP 2: For every order, compute how many months after the customer's
-- cohort month it occurred (the "period number"). Period 0 = first order.
-- ---------------------------------------------------------------------
order_periods AS (
    SELECT
        o.customer_id,
        fp.cohort_month,
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
        -- month-difference, computed without a date-diff function (SQLite
        -- has none built in) using year*12 + month arithmetic
        (CAST(strftime('%Y', o.order_purchase_timestamp) AS INTEGER) * 12
         + CAST(strftime('%m', o.order_purchase_timestamp) AS INTEGER))
        -
        (CAST(strftime('%Y', fp.first_order_date) AS INTEGER) * 12
         + CAST(strftime('%m', fp.first_order_date) AS INTEGER)) AS period_number
    FROM orders o
    JOIN first_purchase fp ON o.customer_id = fp.customer_id
    WHERE o.order_status = 'delivered'
),

-- ---------------------------------------------------------------------
-- STEP 3: Cohort size = number of distinct customers per cohort month
-- ---------------------------------------------------------------------
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS num_customers
    FROM first_purchase
    GROUP BY cohort_month
),

-- ---------------------------------------------------------------------
-- STEP 4: Count distinct customers active in each (cohort, period) cell
-- ---------------------------------------------------------------------
retention_table AS (
    SELECT
        cohort_month,
        period_number,
        COUNT(DISTINCT customer_id) AS num_active_customers
    FROM order_periods
    GROUP BY cohort_month, period_number
)

-- ---------------------------------------------------------------------
-- STEP 5: Final retention % grid, using a window function (FIRST_VALUE)
-- to pull each cohort's period-0 size as the denominator on every row,
-- avoiding a second join back to cohort_size.
-- ---------------------------------------------------------------------
SELECT
    rt.cohort_month,
    rt.period_number,
    rt.num_active_customers,
    cs.num_customers AS cohort_size,
    ROUND(100.0 * rt.num_active_customers /
        FIRST_VALUE(rt.num_active_customers) OVER (
            PARTITION BY rt.cohort_month ORDER BY rt.period_number
        ), 2) AS retention_pct
FROM retention_table rt
JOIN cohort_size cs ON rt.cohort_month = cs.cohort_month
WHERE rt.period_number BETWEEN 0 AND 6
ORDER BY rt.cohort_month, rt.period_number;
