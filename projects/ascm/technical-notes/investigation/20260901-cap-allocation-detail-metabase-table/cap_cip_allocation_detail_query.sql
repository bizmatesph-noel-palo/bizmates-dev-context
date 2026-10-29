-- =====================================================================
-- CAP/CIP Allocation Detail — Metabase reports (TWO QUERIES)
-- =====================================================================
-- Investigation: 20260901-cap-allocation-detail-metabase-table
--
-- Two views of the same CAP/CIP charges, matching the "Overwrite" flow:
--
--   QUERY A — BEFORE allocation (N state)
--       log_daily_rate_calculation as the existing ASC produced it:
--       Coaching row carries the full amount N, App row = 0.
--       This is what feeds the CSV before the allocation overwrite.
--
--   QUERY B — AFTER allocation (P state)  ← reproduces the sample xlsx
--       The split: Coaching reduced to P_coaching, App raised to P_app.
--       Adds List Price / Allocation Base / Recognized Revenue columns.
--       This is the "ASCA按分明細サンプル" detail the accounting team wants.
--
-- ---------------------------------------------------------------------
-- REFERENCE PRICES ("定価" / List Price) — from the sample xlsx (ex-tax).
--   These values (App 3,618 / CIP App 3,980 / CIP coaching 84,020) are NOT
--   present in the mst_new_price_listing rows pulled on 2026-09-01. Source of
--   truth is still unconfirmed (likely asc_alloc_reference_prices or a config
--   constant). Hardcoded here to reproduce the sample; replace with the
--   authoritative master once located. See report [DECISION-1].
--
--     product 10005 (CAP Coaching 15分) : 18,000
--     product 10015 (CAP Coaching 30分) : 36,000
--     product 10022 (CIP Coaching)      : 84,020
--     product 10021 (App, CAP context)  :  3,618
--     product 10021 (App, CIP context)  :  3,980   ← differs by project
--
--   NOTE: App list price differs between CAP (3,618) and CIP (3,980), so it is
--   resolved from the *bundle's* coaching product, not from product 10021 alone.
--
-- ROUNDING RULE (from sample notes / REF-CAP-04 D-8):
--   App side  = floor(N_bundle × L_app / (L_coaching + L_app))
--   Coaching  = N_bundle − App side        (absorbs the +1 remainder)
--   => Coaching Recognized can be 1 higher than its Allocation Base.
--
-- DYNAMIC: filters plan_id 1016-1032. Returns 0 rows until CAP/CIP charges
--   exist, then self-activates with no edits.
-- =====================================================================


-- #####################################################################
-- QUERY A — BEFORE ALLOCATION (N state, straight from the daily log)
-- #####################################################################

WITH params AS (
    SELECT {{target_ym}} AS target_ym   -- e.g. 202608
)
SELECT
    d.target_ym                                   AS `対象年月`,
    c.student_id                                  AS `生徒ID`,
    c.order_no                                    AS `発注番号`,
    pr.name                                       AS `プロダクト名`,
    c.id                                          AS `チャージID`,
    c.start_date                                  AS `契約開始日`,
    c.end_date                                    AS `契約終了日`,
    (DATEDIFF(c.end_date, c.start_date) + 1)      AS `契約日数`,
    d.days                                        AS `日数`,
    d.paid_price                                  AS `支払金額`   -- N (App row = 0)
FROM params p
JOIN log_daily_rate_calculation d ON d.target_ym = p.target_ym
JOIN trn_charge  c  ON c.id = d.charge_id
JOIN mst_product pr ON pr.product_id = c.product_id
WHERE c.plan_id BETWEEN 1016 AND 1032
  AND c.product_id IN (10005, 10015, 10022, 10021)
ORDER BY c.student_id, c.order_no, (c.product_id = 10021);   -- coaching first, app last


-- #####################################################################
-- QUERY B — AFTER ALLOCATION (P state) — reproduces the sample xlsx
-- #####################################################################

WITH params AS (
    SELECT {{target_ym}} AS target_ym   -- e.g. 202608
),

-- CAP/CIP charges for the target month with their daily-recognized amount (N).
cap_charges AS (
    SELECT
        d.target_ym,
        c.id            AS charge_id,
        c.student_id,
        c.order_no,
        c.plan_id,
        c.product_id,
        pr.name         AS product_name,
        c.start_date    AS contract_start_date,
        c.end_date      AS contract_end_date,
        (DATEDIFF(c.end_date, c.start_date) + 1) AS contract_days,
        d.days          AS days,
        d.paid_price    AS paid_amount,      -- N, matches DailyRateCalculation.csv
        CASE WHEN c.product_id = 10021 THEN 1 ELSE 0 END AS is_app,
        CASE WHEN c.product_id = 10022 THEN 1 ELSE 0 END AS is_cip_coaching
    FROM params p
    JOIN log_daily_rate_calculation d ON d.target_ym = p.target_ym
    JOIN trn_charge  c  ON c.id = d.charge_id
    JOIN mst_product pr ON pr.product_id = c.product_id
    WHERE c.plan_id BETWEEN 1016 AND 1032
      AND c.product_id IN (10005, 10015, 10022, 10021)
),

-- Per-row List Price ("定価", ex-tax). Hardcoded per sample — see header.
priced AS (
    SELECT
        cc.*,
        CASE cc.product_id
            WHEN 10005 THEN 18000      -- CAP Coaching 15分
            WHEN 10015 THEN 36000      -- CAP Coaching 30分
            WHEN 10022 THEN 84020      -- CIP Coaching
            WHEN 10021 THEN            -- App: value depends on CAP vs CIP bundle
                CASE WHEN EXISTS (
                    SELECT 1 FROM cap_charges x
                    WHERE x.student_id = cc.student_id
                      AND (x.order_no <=> cc.order_no)
                      AND x.target_ym = cc.target_ym
                      AND x.product_id = 10022          -- bundle contains CIP coaching
                ) THEN 3980 ELSE 3618 END
        END AS list_price
    FROM cap_charges cc
),

-- Bundle-level figures per (student, order, month): N and both list prices.
bundle AS (
    SELECT
        pc.target_ym,
        pc.student_id,
        pc.order_no,
        MAX(CASE WHEN pc.is_app = 1 THEN pc.list_price END)              AS app_list_price,
        MAX(CASE WHEN pc.is_app = 0 THEN pc.list_price END)              AS coaching_list_price,
        MAX(CASE WHEN pc.is_app = 0 THEN pc.paid_amount END)             AS coaching_paid_amount
    FROM priced pc
    GROUP BY pc.target_ym, pc.student_id, pc.order_no
)

SELECT
    pc.target_ym                                  AS `対象年月`,
    pc.student_id                                 AS `生徒ID`,
    pc.order_no                                   AS `発注番号`,
    pc.product_name                               AS `プロダクト名`,
    pc.charge_id                                  AS `チャージID`,
    pc.contract_start_date                        AS `契約開始日`,
    pc.contract_end_date                          AS `契約終了日`,
    pc.contract_days                              AS `契約日数`,
    pc.days                                       AS `日数`,
    pc.list_price                                 AS `定価`,
    pc.paid_amount                                AS `支払金額`,
    -- 按分基準額 (Allocation Base): floor(N × this row's list price / ΣL)
    FLOOR(b.coaching_paid_amount * pc.list_price
          / (b.coaching_list_price + b.app_list_price))  AS `按分基準額`,
    -- 売上計上額 (Recognized Revenue):
    --   App row      = its Allocation Base
    --   Coaching row = N − App's Allocation Base   (absorbs +1 remainder)
    CASE
        WHEN pc.is_app = 1
            THEN FLOOR(b.coaching_paid_amount * b.app_list_price
                       / (b.coaching_list_price + b.app_list_price))
        ELSE b.coaching_paid_amount
             - FLOOR(b.coaching_paid_amount * b.app_list_price
                     / (b.coaching_list_price + b.app_list_price))
    END                                           AS `売上計上額`
FROM priced pc
JOIN bundle b
    ON  b.target_ym  = pc.target_ym
    AND b.student_id = pc.student_id
    AND (b.order_no <=> pc.order_no)
ORDER BY pc.student_id, pc.order_no, pc.is_app;   -- coaching first, app second
