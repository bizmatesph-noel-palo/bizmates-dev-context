-- =============================================================================
-- ASCA-8 — Metabase allocation-breakdown query  ***[VERSION 1 — SUPERSEDED]***
-- =============================================================================
-- VERSION HISTORY: see version-history.md in this folder.
-- v1 (this file) was drafted from the Spec 01 Req 11 / technical-design / steering
-- references BEFORE the actual ASCA-8 ticket was read. After reading the ticket
-- (summary "New Metabase table – CAP allocation breakdown", updated 2026-10-15),
-- v1 was found NOT to meet the required column list — see asca8-allocation-
-- breakdown-v2.sql for the ticket-aligned version. v1 is kept for history only.
-- Do NOT ship v1.
-- =============================================================================
-- ASCA-8 — Metabase allocation-breakdown query (CAP)
-- =============================================================================
-- Shows Accounting HOW each CAP bundle's revenue was split: reference List Price
-- (L), ratio, original amount (N), allocated amount (P), plus the run status and
-- the context columns (service / target month / student / department / order /
-- product / contract type).
--
-- Style follows the house precedent ASC-271 (flat SELECT mirroring a CSV's
-- columns, `コンテンツ` label column, keyed on target_ym).
--
-- Connection: Bizmates DB (`bizmates_mysql`). CAP-only — `bundle_type = 1`.
--
-- Source of the engine side: `v_alloc_prorations_active`, which already resolves
-- the ACTIVE FINAL run per (bundle_type, target_ym) — status IN (2,4),
-- run_type = 2 (Final), superseded_by_run_id IS NULL, MAX(id) wins. So this query
-- does NOT re-implement run selection; it just reads the view and decorates it.
--
-- Reconciliation column 参照価格(listing) — the single reason ASCA-8 exists:
-- it reads List Price L straight from `mst_new_price_listing`, so Accounting can
-- see the engine's seeded L (`v.reference_price`) next to the live listing L and
-- confirm they agree (no ¥1 divergence — Spec 01 Req 4.3/4.4).
--
-- NOTE on resolution: `mst_new_price_listing` is NOT effective-dated (no
-- start/end date columns — keyed by country_id/product_id/price_flag/tier with a
-- status flag). The "last calendar day of target_ym" resolution date (REF-CAP-10)
-- applies to `mst_alloc_reference_prices` (which IS effective-dated), not to the
-- listing table. The listing L is matched on the standalone-list-price row:
-- country_id = 86 (Japan, CAP is JP-only), price_flag = 2 (pre-VPP standalone
-- list price — the same flag the ReferencePriceSeeder reads), tier = 1 (full
-- price), status = 1 (active).
--
-- Metabase parameter: {{target_ym}} as a 6-char text 'YYYYMM' (e.g. 202612).
-- Leave the filter optional so the query also runs across all months.
-- =============================================================================

SELECT
    v.id                                   AS id,                 -- proration row id (log_alloc_prorations.id)
    'bizmates'                             AS `コンテンツ`,        -- service / content (CAP is Bizmates-only)
    CASE v.bundle_type
        WHEN 1 THEN 'cap'
        WHEN 2 THEN 'cip'
        ELSE CAST(v.bundle_type AS CHAR)
    END                                    AS `プロジェクト`,       -- bundle family label (BundleType::label())
    v.target_ym                            AS `対象年月`,          -- YYYYMM
    v.run_id                               AS run_id,             -- active Final run id
    plan.student_id                        AS `生徒ID`,
    v.department_id                        AS `部署ID`,
    v.order_no                             AS `発注番号`,
    plan.plan_id                           AS `プランID`,          -- joined back from trn_charge (dropped before the daily log)
    v.product_id                           AS `プロダクトID`,
    CASE v.product_type
        WHEN 9   THEN 'coaching'
        WHEN 100 THEN 'app'
        ELSE CAST(v.product_type AS CHAR)
    END                                    AS `プロダクトタイプ`,
    CASE v.contract_type
        WHEN 0 THEN 'B2C'
        WHEN 1 THEN 'B2B'
        WHEN 2 THEN 'B2B2C'
        WHEN 3 THEN 'Partner'
        ELSE CAST(v.contract_type AS CHAR)
    END                                    AS `契約種類`,
    v.reference_price                      AS `参照価格(L_engine)`,   -- L the engine used (seeded mst_alloc_reference_prices)
    listing.price                          AS `参照価格(L_listing)`,  -- L live from mst_new_price_listing (standalone list price)
    (v.reference_price - COALESCE(listing.price, v.reference_price))
                                           AS `参照価格差分`,          -- 0 ⇒ engine L and listing L agree (reconciliation check)
    v.ratio                                AS `配分比率`,            -- product share of the bundle (0..1)
    v.original_amount                      AS `元金額(N)`,           -- original paid_price for this product
    v.allocated_amount                     AS `配分後金額(P)`,        -- allocated amount written back
    v.charge_id                            AS charge_id,
    CASE r.status
        WHEN 1 THEN 'Creating'
        WHEN 2 THEN 'Completed'
        WHEN 3 THEN 'Failed'
        WHEN 4 THEN 'Completed with errors'
        ELSE CAST(r.status AS CHAR)
    END                                    AS `ステータス`,          -- run status label
    v.asc_source_table                     AS asc_source_table,   -- log_daily_rate_calculation (Final) or _pre (Preview)
    v.asc_source_id                        AS asc_source_id,
    v.paid_at                              AS paid_at,
    v.created_at                           AS created_at,
    v.updated_at                           AS updated_at
FROM
    v_alloc_prorations_active AS v
    -- status label: the view already filtered to the active Final run, so this
    -- re-join to the runs table is only to surface the human-readable status.
    JOIN log_alloc_calculation_runs AS r
        ON r.id = v.run_id
    -- student_id + plan_id: the proration carries charge_id, but plan_id lives on
    -- trn_charge (plan_id is dropped before the daily log — Q5 of the G1 code
    -- investigation). student_id is on both; sourced here so it is populated for
    -- both Final (log_daily_rate_calculation) and Preview (_pre) source rows.
    LEFT JOIN trn_charge AS plan
        ON plan.id = v.charge_id
    -- Live listing L (standalone list price). mst_new_price_listing is not
    -- effective-dated; match the standalone-list-price row: Japan, price_flag = 2
    -- (same flag the ReferencePriceSeeder reads), full-price tier, active.
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
    v.order_no,
    v.charge_id,
    v.product_id;
