-- =============================================================================
-- ASCA-8 — Metabase allocation-breakdown query  ***[VERSION 3 — SUPERSEDED]***
-- =============================================================================
-- SUPERSEDED by asca8-allocation-breakdown-v4.sql after downloading and decoding
-- the REAL current ticket attachment (previous versions used the OLD Sep-3 sample;
-- the pasted 2026-10-15 attachment had arrived corrupted and was never actually
-- read). The real sample's refund rows (pattern P4a/P4b/P8/P9) proved this file's
-- daily-rate-log join is ambiguous: a refund's new App row reuses the ORIGINAL App
-- charge_id in the SAME target_ym as the regular proration row, so the compound key
-- (charge_id, target_ym, product_id) is not unique. v4 joins on the row id
-- (asc_source_id) instead. Do NOT ship v3.
-- =============================================================================
-- Ticket: ASCA-8 "New Metabase table – CAP allocation breakdown" (updated 2026-10-15).
-- VERSION HISTORY: see version-history.md in this folder.
--
-- v3 reconciles v2 against the sample Excel
-- (sample_csv/asca_metabase_allocation_sample.xlsx). Two changes vs v2:
--   (1) Headers are Japanese, matching the sample's row-1 labels exactly.
--   (2) Product Name (プロダクト名) is BUNDLE-AWARE: the App row inherits the paired
--       coaching's minute suffix, so App shows CAPアプリ(15分) when bundled with
--       Coaching 15min and CAPアプリ(30分) with 30min. A flat product_id→name map
--       (v2) could not do this because App is always product_id 10022.
-- Everything else (sources, N/P, day fields, List Price, CAP-only, 12 columns) is
-- unchanged from v2.
--
-- Connection: Bizmates DB (bizmates_mysql). Scope: CAP only (bundle_type = 1).
--
-- =============================================================================
-- Columns (sample row-1 labels, in order) and sourcing
-- =============================================================================
--  対象年月        Target Month        v.target_ym (YYYYMM)
--  生徒ID          Student ID          trn_charge/daily-rate student_id
--  発注番号        Order No            v.order_no (B2B only; empty for B2C/B2E)
--  プロダクト名     Product Name        bundle-aware (see below)
--  チャージID      Charge ID           v.charge_id (trn_charge.id)
--  契約開始日       Contract Start Date log_daily_rate_calculation.start_date
--  契約終了日       Contract End Date   log_daily_rate_calculation.target_ymend
--  契約日数        Contract Days       log_daily_rate_calculation.contract_day
--  日数            Days                log_daily_rate_calculation.total_day
--  定価            List Price          mst_new_price_listing.price (tax-excl weight)
--  支払金額        Paid Amount (N)     v.original_amount (pre-allocation; App = 0)
--  売上計上額       Recognized Rev (P)  v.allocated_amount (post-allocation; = CSV 支払金額)
--
-- NOTE — the sample's 13th column 按分基準額 (Allocation Base Amount) is INTENTIONALLY
-- dropped: the ticket's "changes" list removes it. The sample also contained CIP
-- rows; those are excluded here by bundle_type = 1 (CAP only), per the ticket.
--
-- Paid Amount = log_alloc_prorations.original_amount (NOT the daily-rate log, whose
-- paid_price the injector overwrites N→P on a Final run). Day fields are untouched by
-- allocation, so they are read from log_daily_rate_calculation and match the CSV.
--
-- Product Name (プロダクト名), bundle-aware:
--   * Coaching rows: directly from product_id (10005→15分, 10015→30分).
--   * App row (10022): the suffix comes from the COACHING product in the SAME bundle
--     (same group_id). The App row borrows "(15分)"/"(30分)" from its coaching sibling,
--     matching the sample (CAPアプリ(15分) / CAPアプリ(30分)). Resolved via the
--     `coaching_in_group` subquery below.
--
-- List Price (定価): mst_new_price_listing is not effective-dated; match the
-- standalone list-price row country_id=86, price_flag=2, tier=1, status=1. Confirmed
-- amounts: Coaching 15min 18,000 / 30min 36,000; App 3,618.
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
    -- Day fields + student_id from the daily-rate log row this proration derived from.
    LEFT JOIN log_daily_rate_calculation AS dr
        ON dr.charge_id = v.charge_id
       AND dr.target_ym = v.target_ym
       AND dr.product_id = v.product_id
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
-- 1. The reconciled sample (sample_csv/asca_metabase_allocation_sample.xlsx) is the
--    Sep-3 version (13 cols, incl. CIP + 按分基準額). The 2026-10-15 ticket sample has
--    NOT been read (arrived as corrupted binary). v3 applies the ticket's documented
--    "changes" to the Sep-3 labels; confirm against the real 2026-10-15 file.
-- 2. Product Name suffix on the App row: v3 derives it from the coaching sibling via
--    group_id. Confirm Accounting wants the suffix on App (sample shows CAPアプリ(15分)/
--    (30分)); if plain CAPアプリ is acceptable this subquery can be dropped.
-- 3. Confirm the daily-rate join (charge_id, target_ym, product_id) is 1:1 for a CAP
--    charge-month (no split rows) so N/P do not fan out.
-- 4. Refund rows depend on Spec 02b (negative App row). Verify Spec 02b is deployed
--    and writing those rows before relying on refund output.
-- 5. BLOCKED in dev (CAP ids / plans 1016–1027 / trn_charge rows not seeded) — the
--    query returns empty until that data exists. Expected, not a bug.
