-- =============================================================================
-- ASCA-8 — Metabase allocation-breakdown query  ***[VERSION 2 — SUPERSEDED]***
-- =============================================================================
-- Ticket: ASCA-8 "New Metabase table – CAP allocation breakdown" (updated 2026-10-15).
-- VERSION HISTORY: see version-history.md in this folder.
--
-- SUPERSEDED by asca8-allocation-breakdown-v3.sql after reading the sample Excel
-- (sample_csv/asca_metabase_allocation_sample.xlsx). v2's headers were English and
-- its Product Name was a flat product_id map; the sample shows Japanese headers and
-- an App Product Name that inherits the paired coaching's minute suffix (CAPアプリ(15分)
-- vs (30分)) — which a flat map cannot produce. v3 fixes both. Do NOT ship v2.
--
-- v2 rewrite against the ACTUAL ticket column list (v1 was built from secondary
-- docs and missed the required columns). This version produces exactly the 12
-- columns the ticket specifies, in order:
--
--   Target Month | Student ID | Order No | Product Name | Charge ID |
--   Contract Start Date | Contract End Date | Contract Days | Days |
--   List Price | Paid Amount | Recognized Revenue Amount
--
-- Connection: Bizmates DB (bizmates_mysql). Scope: CAP only (bundle_type = 1).
--
-- =============================================================================
-- Column sourcing (per the ticket's definitions)
-- =============================================================================
--  Target Month              v.target_ym (YYYYMM)
--  Student ID                trn_charge.student_id (via charge_id)
--  Order No                  v.order_no (B2B only; NULL/empty for B2C/B2E)
--  Product Name              mapped from product_id → "CAP Coaching (15min)" etc.
--  Charge ID                 v.charge_id (trn_charge.id)
--  Contract Start Date       log_daily_rate_calculation.start_date
--  Contract End Date         log_daily_rate_calculation.target_ymend
--  Contract Days (契約日数)    log_daily_rate_calculation.contract_day
--  Days (日数)                 log_daily_rate_calculation.total_day
--  List Price                mst_new_price_listing.price (tax-excl allocation weight)
--  Paid Amount (N)           v.original_amount  ← pre-allocation N (NOT the daily-
--                            rate log paid_price, which is overwritten to P after a
--                            Final run). App row = 0. This equals the 支払金額 the
--                            CSV would show WITHOUT allocation.
--  Recognized Revenue Amount v.allocated_amount ← P written into the CSV 支払金額.
--                            App = floor(N × L_app / (L_coaching + L_app));
--                            Coaching = N − App. Must match the CSV row by row.
--
-- WHY Paid Amount comes from log_alloc_prorations.original_amount, not the log:
-- the AllocationInjector OVERWRITES log_daily_rate_calculation.paid_price N→P
-- (Scenario D / Option 1). So after a Final run the daily-rate log no longer holds
-- N. The engine snapshots N into log_alloc_prorations.original_amount, which is the
-- authoritative pre-allocation value for this column.
--
-- Day fields (start_date / target_ymend / contract_day / total_day) are NOT touched
-- by allocation, so reading them from log_daily_rate_calculation is correct and
-- matches DailyRateCalculation.csv exactly (same table, same rows).
--
-- Refunds (ticket "Refunds" section): a refund is recognized in full in its
-- execution month and split with the same floor formula; the engine inserts a new
-- negative App row (Spec 02b Req 9) with Paid Amount 0 and a negative Recognized
-- Revenue Amount. Those rows live in log_alloc_prorations like any other proration,
-- so this query surfaces them with no special-casing — PROVIDED Spec 02b is
-- deployed and has written them. (Spec 02b is a later spec; verify before relying
-- on the refund rows in prod.)
--
-- List Price resolution: mst_new_price_listing is NOT effective-dated (keyed by
-- country_id/product_id/price_flag/tier + status). Match the standalone list-price
-- row: country_id = 86 (JP; CAP is JP-only), price_flag = 2, tier = 1, status = 1.
-- Ticket confirms: Coaching 15min 18,000 / 30min 36,000; App via price_flag = 2
-- (3,618).
--
-- Metabase parameter: {{target_ym}} as 6-char text 'YYYYMM' (e.g. 202612), optional.
-- =============================================================================

SELECT
    v.target_ym                               AS `Target Month`,
    dr.student_id                             AS `Student ID`,
    v.order_no                                AS `Order No`,
    CASE v.product_id
        WHEN 10005 THEN 'CAP Coaching (15min)'
        WHEN 10015 THEN 'CAP Coaching (30min)'
        WHEN 10022 THEN 'CAP App'
        ELSE CONCAT('product_id ', CAST(v.product_id AS CHAR))
    END                                       AS `Product Name`,
    v.charge_id                               AS `Charge ID`,
    dr.start_date                             AS `Contract Start Date`,
    dr.target_ymend                           AS `Contract End Date`,
    dr.contract_day                           AS `Contract Days`,   -- 契約日数
    dr.total_day                              AS `Days`,            -- 日数
    listing.price                             AS `List Price`,      -- allocation weight (tax-excl)
    v.original_amount                         AS `Paid Amount`,                 -- N (before allocation); App = 0
    v.allocated_amount                        AS `Recognized Revenue Amount`    -- P (after allocation); matches CSV 支払金額
FROM
    v_alloc_prorations_active AS v
    -- Day fields + student_id: the daily-rate log row this proration was derived
    -- from. Join on charge_id + target_ym (the daily-rate log's natural key for a
    -- charge-month) rather than asc_source_id, so the day columns resolve for both
    -- Final (log_daily_rate_calculation) and are consistent with the CSV. The
    -- allocation never alters these day fields, only paid_price.
    LEFT JOIN log_daily_rate_calculation AS dr
        ON dr.charge_id = v.charge_id
       AND dr.target_ym = v.target_ym
       AND dr.product_id = v.product_id
    -- List Price (allocation weight) from the standalone list-price row.
    LEFT JOIN mst_new_price_listing AS listing
        ON listing.product_id = v.product_id
       AND listing.country_id = 86
       AND listing.price_flag = 2
       AND listing.tier = 1
       AND listing.status = 1
WHERE
    v.bundle_type = 1                                   -- CAP only
    [[ AND v.target_ym = {{target_ym}} ]]               -- Metabase optional filter
ORDER BY
    v.target_ym,
    dr.student_id,
    v.order_no,
    v.charge_id,
    -- Coaching before App within a bundle (coaching product ids sort below 10022,
    -- but force the intent explicitly):
    CASE WHEN v.product_id = 10022 THEN 1 ELSE 0 END,
    v.product_id;

-- =============================================================================
-- OPEN ITEMS before this is published as the Metabase card (see version-history.md)
-- =============================================================================
-- 1. Sample Excel attached to ASCA-8 (updated 2026-10-15) is the AUTHORITATIVE
--    column spec — confirm column order/labels and the refund example rows against
--    it. Not yet seen by the author of this query.
-- 2. Product Name strings ("CAP Coaching (15min)" / "CAP App") are taken from the
--    ticket text; confirm the exact wording Accounting wants (the ticket also wrote
--    "CAP App (15min)" in one example, which may be a typo).
-- 3. The daily-rate join uses (charge_id, target_ym, product_id). Confirm a CAP
--    charge-month has exactly one daily-rate row per product (no split rows) so the
--    join is 1:1 and does not fan out N/P.
-- 4. Refund rows depend on Spec 02b (negative App row insertion). Verify Spec 02b
--    is deployed and writing those rows before relying on refund output.
-- 5. BLOCKED in dev per the ticket comments (CAP product ids / plans 1016–1027 /
--    trn_charge rows not seeded) — the query returns an empty set until that data
--    exists. Expected, not a bug.
