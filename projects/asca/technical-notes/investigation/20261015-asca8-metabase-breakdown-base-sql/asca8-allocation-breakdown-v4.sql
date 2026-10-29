-- =============================================================================
-- ASCA-8 — Metabase allocation-breakdown query  ***[VERSION 4 — CURRENT]***
-- =============================================================================
-- Ticket: ASCA-8 "New Metabase table – CAP allocation breakdown".
-- Reconciled against the REAL current attachment, downloaded directly via the
-- Jira REST API (attachment id 129138, asca_metabase_allocation_sample_CAP_
-- 2026-10-15.xlsx, 47 data rows across 9 scenario patterns P1–P9 incl. refunds).
-- VERSION HISTORY: see version-history.md in this folder.
--
-- v4 fixes a correctness bug in v3's daily-rate-log join that the refund scenarios
-- in the real sample exposed (see "WHY asc_source_id, not a compound key" below).
-- Columns, formula, and bundle-aware Product Name are unchanged from v3 and are
-- now CONFIRMED against real sample numbers (see "Verified against the sample").
--
-- Connection: Bizmates DB (bizmates_mysql). Scope: CAP only (bundle_type = 1).
--
-- =============================================================================
-- Columns (sample row-1 labels, in order) and sourcing
-- =============================================================================
--  対象年月        Target Month        v.target_ym (YYYYMM)
--  生徒ID          Student ID          dr.student_id (daily-rate log row)
--  発注番号        Order No            v.order_no (B2B only; empty for B2C/B2E)
--  プロダクト名     Product Name        bundle-aware (coaching direct; App borrows
--                                       the paired coaching's minute suffix)
--  チャージID      Charge ID           v.charge_id (trn_charge.id)
--  契約開始日       Contract Start Date dr.start_date
--  契約終了日       Contract End Date   dr.target_ymend
--  契約日数        Contract Days       dr.contract_day
--  日数            Days                dr.total_day
--  定価            List Price          mst_new_price_listing.price (tax-excl weight)
--  支払金額        Paid Amount (N)     v.original_amount (pre-allocation; App = 0)
--  売上計上額       Recognized Rev (P)  v.allocated_amount (post-allocation; = CSV 支払金額)
--
-- =============================================================================
-- WHY asc_source_id, not a compound key (the v3 → v4 fix)
-- =============================================================================
-- v3 joined log_daily_rate_calculation on (charge_id, target_ym, product_id). The
-- real sample's refund scenarios (P4a same-month, P4b next-month, P8 consumption
-- tax, P9 shareholder cashback) prove this key is NOT unique:
--
--   Sample rows 13 & 17 (student 900004, pattern P4a):
--     row 13: target_ym=202701, charge_id=7000008, 支払金額=0        (regular App row)
--     row 17: target_ym=202701, charge_id=7000008, 支払金額=0, 売上計上額=-3397
--             ("Refund (90%) - new App row")
--
-- Per the Spec 02b design (confirmed): the refund engine does NOT create a new App
-- CHARGE — it INSERTS A SECOND log_daily_rate_calculation ROW that reuses the
-- original App charge's identity/columns, in the same execution month, to carry
-- the negative P_app (RefundAppRowWriter). So (charge_id, target_ym, product_id)
-- legitimately maps to TWO daily-rate-log rows for a refund month: the original
-- ¥0 proration row and the new refund row. A compound-key join either fans out
-- (duplicate output rows) or silently joins to the wrong row.
--
-- The fix: `log_alloc_prorations.asc_source_id` is the actual primary key of the
-- log_daily_rate_calculation(_pre) row the proration was derived from (see column
-- comment in the ls-database-migrations schema: "Source row ID in
-- asc_source_table"). It is unambiguous by construction — join on it directly.
--
-- =============================================================================
-- Verified against the real sample (not assumed)
-- =============================================================================
-- * Formula: row 2 (coaching N=22,550, L_coaching=18,000, L_app=3,618) →
--   App = floor(22550 × 3618 / 21618) = floor(3773.9) = 3,773 (sample: 3,773 ✓);
--   Coaching = 22550 − 3773 = 18,777 (sample: 18,777 ✓). Only App is floored.
-- * Negative floor direction confirmed on refund rows (pattern P4a):
--   N = -20,295 → App = floor(-20295 × 3618/21618) = floor(-3396.4) = -3,397
--   (sample: -3,397 ✓); Coaching = -20295 − (-3397) = -16,898 (sample: -16,898 ✓).
-- * Bundle-aware Product Name confirmed by the plan-change scenario (P5, rows
--   24–31): the same student's App row shows "(15分)" while paired with Coaching
--   15min, then "(30分)" after the plan change pairs it with Coaching 30min — same
--   App product_id (10022) throughout. A flat product_id→name map cannot produce
--   this; the group_id-based lookup (unchanged from v3) is required and correct.
-- * Refund rows are recognized in FULL in the execution month, not day-prorated:
--   契約日数 = 日数 (e.g. row 16: H=31, I=31) even though the regular rows for the
--   same contract show 契約日数 < 日数 (e.g. row 12: H=17, I=31). This is read
--   directly off dr.contract_day / dr.total_day — no special-casing needed in this
--   query, PROVIDED the asc_source_id join resolves to the correct (refund) row.
-- * The 2027-01~04 sample dates and dummy student/charge ids are explicitly
--   confirmed as placeholders by the ticket's own notes (sheet2, row 20) — not a
--   real-data verification source, only a formula/shape verification source.
--
-- =============================================================================
-- CAP-only scope (confirmed by ticket + sample)
-- =============================================================================
-- Sheet2 row 2: "CAP (plan 1016–1027) only. CIP stopped allocating after the
-- 2026-09-17 policy change (books separate already-priced Coaching ¥71,920 / App
-- ¥3,980 charges with existing day-proration only); CIP is out of scope for this
-- table." Matches bundle_type = 1 filter below.
--
-- List Price (定価): mst_new_price_listing is NOT effective-dated (no start/end
-- date columns); match the standalone list-price row: country_id = 86 (JP; CAP is
-- JP-only), price_flag = 2, tier = 1, status = 1. Confirmed amounts: Coaching
-- 15min 18,000 / 30min 36,000; App 3,618.
--
-- Metabase parameter: {{target_ym}} as 6-char text 'YYYYMM' (e.g. 202612), optional.
-- =============================================================================

SELECT
    v.target_ym                               AS `対象年月`,
    dr.student_id                             AS `生徒ID`,
    v.order_no                                AS `発注番号`,
    CASE
        -- Coaching rows name themselves directly.
        WHEN v.product_id = 10005 THEN 'CAPコーチング(15分)'
        WHEN v.product_id = 10015 THEN 'CAPコーチング(30分)'
        -- App row inherits the minute suffix from the coaching product in its bundle.
        WHEN v.product_id = 10022 THEN
            CASE cg.coaching_product_id
                WHEN 10005 THEN 'CAPアプリ(15分)'
                WHEN 10015 THEN 'CAPアプリ(30分)'
                ELSE 'CAPアプリ'
            END
        ELSE CONCAT('product_id ', CAST(v.product_id AS CHAR))
    END                                       AS `プロダクト名`,
    v.charge_id                               AS `チャージID`,
    dr.start_date                             AS `契約開始日`,
    dr.target_ymend                           AS `契約終了日`,
    dr.contract_day                           AS `契約日数`,
    dr.total_day                              AS `日数`,
    listing.price                             AS `定価`,
    v.original_amount                         AS `支払金額`,       -- N (before allocation); App = 0
    v.allocated_amount                        AS `売上計上額`      -- P (after allocation); matches CSV 支払金額
FROM
    v_alloc_prorations_active AS v
    -- Day fields + student_id, joined on the EXACT source row id (not a compound
    -- business key — see "WHY asc_source_id" above). Restricted to the Final
    -- source table; a Preview-run breakdown would join log_daily_rate_calculation_pre
    -- instead (see note below if this query is ever parameterised for Preview).
    LEFT JOIN log_daily_rate_calculation AS dr
        ON dr.id = v.asc_source_id
       AND v.asc_source_table = 'log_daily_rate_calculation'
    -- List Price (allocation weight) — standalone list-price row.
    LEFT JOIN mst_new_price_listing AS listing
        ON listing.product_id = v.product_id
       AND listing.country_id = 86
       AND listing.price_flag = 2
       AND listing.tier = 1
       AND listing.status = 1
    -- Bundle-aware Product Name: the coaching product sharing this row's group_id.
    -- A CAP bundle has exactly one coaching product (10005 or 10015) per group, so
    -- this resolves to a single row. Used only to pick the App row's minute suffix.
    LEFT JOIN (
        SELECT
            p.group_id,
            MAX(p.product_id) AS coaching_product_id
        FROM v_alloc_prorations_active AS p
        WHERE p.bundle_type = 1
          AND p.product_id IN (10005, 10015)   -- coaching products only
        GROUP BY p.group_id
    ) AS cg
        ON cg.group_id = v.group_id
WHERE
    v.bundle_type = 1                                   -- CAP only
    [[ AND v.target_ym = {{target_ym}} ]]               -- Metabase optional filter
ORDER BY
    v.target_ym,
    dr.student_id,
    v.order_no,
    v.group_id,
    -- Coaching before App within a bundle.
    CASE WHEN v.product_id = 10022 THEN 1 ELSE 0 END,
    v.product_id;

-- =============================================================================
-- OPEN ITEMS before this is published as the Metabase card (see version-history.md)
-- =============================================================================
-- 1. `v_alloc_prorations_active` surfaces the active FINAL run only (per the view
--    definition). This query is Final-only by construction — if a Preview-run
--    breakdown is ever needed, it would need to read log_alloc_prorations directly
--    (not the view) filtered to the latest Preview run, and join
--    log_daily_rate_calculation_pre instead of the Final table above.
-- 2. Confirm the App-row Product Name suffix is wanted exactly as the sample shows
--    it (coaching-derived minute label) — this was the one ambiguous reading in
--    the ticket text and the sample now settles it, but worth a one-line confirm
--    with Kuroda-san before shipping.
-- 3. Spec 02b (new App refund row via RefundAppRowWriter) must be deployed and
--    writing those rows, and 02a's injector must be live, before this query
--    returns anything for CAP at all — see item 4 below.
-- 4. BLOCKED in dev per the ticket's own comment thread (CAP product ids / plans
--    1016–1027 / trn_charge rows not seeded) — the query returns an empty set
--    until that data exists AND the Spec 01/02a/02b code is deployed and has run.
--    Expected, not a bug.
-- 5. The sample's student/charge ids and 2027-01~04 dates are explicit dummy
--    placeholders (sheet2 note) — do not use them as literal expected output when
--    testing; use them only to verify the FORMULA (confirmed above).
