-- ============================================================================
-- 007_remove_post_writeoff_snapshots.sql
-- ============================================================================
-- Purpose : One-time data repair for audit finding C2 (P1).
--           Charged-off accounts must EXIT the book after their write-off
--           month-end. The generator previously kept re-snapshotting them as
--           '90+' with residual principal every following month, polluting:
--             - 90+ delinquency stock trends
--             - v_dpd_migration_matrix denominators
--             - portfolio balance/arrears aggregates
--
-- Semantics: the snapshot row ON the write-off date is KEPT (it is the
--            account's final in-book state, consistent with
--            fact_writeoffs.balance_before). Every snapshot STRICTLY AFTER
--            the write-off date is removed.
--
-- Idempotent: yes — second run deletes 0 rows.
-- Generator : fixed in parallel (data_generator_v7.py §3H skips WrittenOff
--             accounts), so this repair only matters for already-loaded data.
-- ============================================================================

BEGIN;

WITH written_off AS (
    SELECT DISTINCT account_id, writeoff_date
    FROM fact_writeoffs
)
DELETE FROM fact_eom_snapshot e
USING written_off w
WHERE e.account_id = w.account_id
  AND e.snapshot_date > w.writeoff_date;

COMMIT;
