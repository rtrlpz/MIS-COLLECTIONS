-- ============================================================================
-- 001_dim_products.sql — Seed Data for Dim_Products
-- ============================================================================
-- Purpose: Insert 3 product rows matching PRODUCT_CFG in config.py
--
-- Note: Using user-specified values for Mortgage (6.75%, 15 grace days)
-- instead of config.py values (5.85%, 0 grace days)
-- ============================================================================

INSERT INTO dim_products (product_id, product_name, product_type, annual_rate_pct, grace_days, min_payment_rule)
VALUES
    ('PRD_001', 'Credit Card Standard', 'Tarjeta', 25.99, 25, '2% of Balance'),
    ('PRD_002', 'Personal Loan 5yr', 'Prestamo', 12.50, 0, 'Fixed Monthly Installment'),
    ('PRD_003', 'Mortgage 30yr', 'Hipoteca', 6.75, 15, 'Fixed Monthly Installment');
