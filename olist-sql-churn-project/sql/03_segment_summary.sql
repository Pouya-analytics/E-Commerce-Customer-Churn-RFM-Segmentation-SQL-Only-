-- =====================================================================
-- 03_segment_summary.sql
-- Aggregates the RFM segmentation (02) into a business-readable summary:
-- how many customers per segment, and what % of total revenue each
-- segment represents. This is the table a freelance client or manager
-- actually wants to see -- not the raw per-customer RFM table.
-- =====================================================================

WITH order_value AS (
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
    SELECT
        customer_id,
        CAST(julianday((SELECT MAX(order_date) FROM order_value)) -
             julianday(MAX(order_date)) AS INTEGER) AS recency_days,
        COUNT(order_id) AS frequency,
        SUM(order_total) AS monetary
    FROM order_value
    GROUP BY customer_id
),
customer_rfm_scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm_raw
),
segmented AS (
    SELECT
        customer_id,
        monetary,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Promising'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (high value)'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
            ELSE 'Regular'
        END AS rfm_segment
    FROM customer_rfm_scored
)
SELECT
    rfm_segment,
    COUNT(*) AS num_customers,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM segmented), 1) AS pct_of_customers,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(100.0 * SUM(monetary) / (SELECT SUM(monetary) FROM segmented), 1) AS pct_of_revenue,
    ROUND(AVG(monetary), 2) AS avg_revenue_per_customer
FROM segmented
GROUP BY rfm_segment
ORDER BY total_revenue DESC;
