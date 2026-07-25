-- =====================================================================
-- 02_rfm_segmentation.sql
-- RFM (Recency, Frequency, Monetary) customer segmentation using
-- nested CTEs and NTILE() window function for quintile scoring.
--
-- Business question: Which customers are "at risk" (high past value,
-- but long time since last order) vs "champions" (recent, frequent,
-- high spend) vs "lost"? This is the standard pre-step before any
-- targeted retention campaign or freelance client deliverable.
-- =====================================================================

WITH order_value AS (
    -- total spend per order = sum of item prices + freight, joined once
    SELECT
        o.order_id,
        o.customer_id,
        DATE(o.order_purchase_timestamp) AS order_date,
        SUM(oi.price + oi.freight_value) AS order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.customer_id, o.order_purchase_timestamp
),

customer_rfm_raw AS (
    -- Recency = days between the customer's LAST order and the dataset's
    -- most recent date (a fixed "analysis date" anchor, standard in RFM)
    SELECT
        customer_id,
        CAST(julianday((SELECT MAX(order_date) FROM order_value)) -
             julianday(MAX(order_date)) AS INTEGER) AS recency_days,
        COUNT(order_id) AS frequency,
        SUM(order_total) AS monetary
    FROM order_value
    GROUP BY customer_id
),

-- ---------------------------------------------------------------------
-- Score each dimension 1-5 using NTILE (quintiles). Recency is INVERTED
-- (lower days-since-last-order = better = score 5) versus Frequency and
-- Monetary (higher = better = score 5).
-- ---------------------------------------------------------------------
customer_rfm_scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        -- NTILE(5) splits ordered rows into 5 equal-ish buckets (1=lowest)
        6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm_raw
)

-- ---------------------------------------------------------------------
-- Final segment label from the combined RFM score. Thresholds below
-- follow the standard RFM segmentation scheme used in CRM analytics
-- (Hughes, 1994 framework, simplified to 5 buckets for readability).
-- ---------------------------------------------------------------------
SELECT
    customer_id,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    r_score, f_score, m_score,
    (r_score + f_score + m_score) AS rfm_total,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (high value)'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Regular'
    END AS rfm_segment
FROM customer_rfm_scored
ORDER BY rfm_total DESC;
