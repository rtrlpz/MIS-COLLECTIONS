-- ============================================================================
-- 003_dim_delinquency_bucket.sql — seed the ordered delinquency-bucket dimension
-- ============================================================================
-- I2 (Kimball): buckets carry an explicit severity order so roll-rate logic
-- joins on sort_order instead of re-deriving CASE maps per consumer.
-- Idempotent via ON CONFLICT DO NOTHING (matches house seed convention).
-- ============================================================================

INSERT INTO dim_delinquency_bucket (bucket_key, bucket_label, sort_order, days_from, days_to) VALUES
    (0, 'Current', 0, NULL,   0),
    (1, '1-30',    1,    1,  30),
    (2, '31-60',   2,   31,  60),
    (3, '61-90',   3,   61,  90),
    (4, '90+',     4,   91, NULL)
ON CONFLICT (bucket_key) DO NOTHING;
