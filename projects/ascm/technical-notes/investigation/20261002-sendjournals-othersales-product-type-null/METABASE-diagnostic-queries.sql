-- ============================================================================
-- Metabase (READ-ONLY) diagnostic queries
-- Incident: SendJournals FINAL 2026-10-02 — "product_type on null" in
--           getOtherSalesJournals() (missing mst_rule_for_journals row).
--
-- Purpose: CONFIRM the root cause without changing anything. These are all
--          SELECTs — safe to run in Metabase (which cannot run INSERT/UPDATE).
--
-- Context (from code): getOtherSalesJournals() resolves, per OtherSales charge,
--   product_id -> product_type (mst_product)
--             -> freee product type (mst_code_change, master_data_type = 1)
--             -> segment2 / freee contract type (CommonUtil::getContractTypeInfo)
--             -> mst_rule_for_journals (segment2_id, product_type, status = 1)
-- When the final lookup finds no row, the code dereferences null and aborts.
--
-- Special case (DEVOPS-6287): when contract = B2B AND freee product type =
--   Bizmates App (236270504), the segment2 tag is resolved from mst_code_change
--   master_data_type = 2, code = 4 ('B2B_App', expected freee_code = 1622735),
--   and mst_rule_for_journals.id = 102 must carry segment2_id = 1622735.
--   Wu-san's fix inserts that code-change row and updates id=102 — i.e. the
--   production DB is suspected to be MISSING this DEVOPS-6287 master data.
--
-- Run on the Bizmates DB (bizmates_new).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- CHECK 1 — Is the DEVOPS-6287 "B2B_App" code-change row present?
-- Expected (healthy): exactly one row, freee_code = 1622735.
-- If EMPTY  -> this is the missing master data; getChangeCodeToFreeeCode(2,4)
--             returns null -> downstream rule lookup fails -> the crash.
-- ----------------------------------------------------------------------------
SELECT *
FROM mst_code_change
WHERE master_data_type = 2
  AND code = 4;


-- ----------------------------------------------------------------------------
-- CHECK 1b — Full master_data_type = 2 (segment2 / contract-type) set, for context.
-- Wu-san's note expected 4 rows before the fix and 5 after. Fewer than 5 (no
-- B2B_App / 1622735 row) indicates the fix is not applied in this environment.
-- ----------------------------------------------------------------------------
SELECT *
FROM mst_code_change
WHERE master_data_type = 2
ORDER BY code;


-- ----------------------------------------------------------------------------
-- CHECK 2 — Does the journal rule id=102 point at the B2B_App segment2 tag?
-- Expected (healthy, post-fix): segment2_id = 1622735.
-- If segment2_id = 261928 (the old B2B tag) or anything else, the B2B_App rule
-- lookup (segment2_id = 1622735) finds no row -> null -> crash.
-- ----------------------------------------------------------------------------
SELECT id, segment2_id, product_type, status, department_id, segment1_id
FROM mst_rule_for_journals
WHERE id = 102;


-- ----------------------------------------------------------------------------
-- CHECK 3 — Is there ANY active rule for (segment2 = B2B_App 1622735,
--           product_type = Bizmates App freee type 236270504)?
-- This is the exact lookup getOtherSalesJournals() does for a B2B App charge.
-- Expected (healthy): >= 1 row. EMPTY -> confirms the crash path.
-- ----------------------------------------------------------------------------
SELECT *
FROM mst_rule_for_journals
WHERE segment2_id = 1622735
  AND product_type = 236270504
  AND status = 1;


-- ----------------------------------------------------------------------------
-- CHECK 4 — September OtherSales charges, with the FULL resolution chain, and a
--           flag for which ones have NO matching active journal rule.
--
-- This reproduces getOtherSalesJournals()'s grouping
--   (getTrnOtherSalesChargeSumForDeliveryDate: status=1, delivery_date in month,
--    grouped by order_no, product_id, department_id)
-- and the segment2 resolution, INCLUDING the DEVOPS-6287 B2B-App special case.
--
-- *** ADJUST THE DATE RANGE to the target month of the failed run. ***
-- The FINAL run on 2026-10-02 processes the PREVIOUS month = 2026-09.
--   -> delivery_date in ['2026-09-01', '2026-09-30'].
--
-- Any row with rule_found = 0 is a charge that would crash the run.
-- Expectation given the hypothesis: the B2B + Bizmates-App row(s) show
-- rule_found = 0 until the DEVOPS-6287 master data is in place.
-- ----------------------------------------------------------------------------
SELECT
    os.order_no,
    os.product_id,
    os.department_id,
    SUM(os.paid_price)                              AS paid_price,
    mp.product_type                                 AS mst_product_type,
    cc_prod.freee_code                              AS freee_product_type,
    -- segment2 the code resolves to:
    --  * B2B + Bizmates App (236270504) -> B2B_App tag via mst_code_change(2, code=4)
    --  * everything else                -> normal segment2 for the contract type
    CASE
        WHEN cc_prod.freee_code = 236270504
             THEN cc_bapp.freee_code            -- B2B_App segment2 (expected 1622735)
        ELSE NULL                                -- (non-B2B-App paths resolve via getSegment2Id;
                                                 --  shown as NULL here — focus is the B2B-App case)
    END                                             AS resolved_segment2_id_for_b2b_app,
    r.id                                            AS matched_rule_id,
    CASE WHEN r.id IS NULL THEN 0 ELSE 1 END        AS rule_found
FROM trn_other_sales_charge os
LEFT JOIN mst_product   mp
       ON mp.product_id = os.product_id
LEFT JOIN mst_code_change cc_prod
       ON cc_prod.master_data_type = 1          -- productType
      AND cc_prod.product_id       = os.product_id
-- the B2B_App segment2 tag row (DEVOPS-6287): master_data_type = 2, code = 4
LEFT JOIN mst_code_change cc_bapp
       ON cc_bapp.master_data_type = 2
      AND cc_bapp.code             = 4
-- the active rule the code would look up for a B2B Bizmates-App charge
LEFT JOIN mst_rule_for_journals r
       ON r.segment2_id   = cc_bapp.freee_code
      AND r.product_type  = cc_prod.freee_code
      AND r.status        = 1
WHERE os.status = 1
  AND os.delivery_date BETWEEN '2026-09-01' AND '2026-09-30'   -- *** adjust month ***
  AND cc_prod.freee_code = 236270504                            -- Bizmates App only (the suspected path)
GROUP BY os.order_no, os.product_id, os.department_id,
         mp.product_type, cc_prod.freee_code, cc_bapp.freee_code, r.id
ORDER BY rule_found ASC, os.order_no;


-- ----------------------------------------------------------------------------
-- CHECK 4b — Broader net (optional): ALL September OtherSales charges with their
-- product_type and freee product type, no rule-join, so Accounting can eyeball
-- which products appeared this month (useful if the culprit is NOT the B2B-App
-- case but some other product/contract combo with a missing rule).
-- ----------------------------------------------------------------------------
SELECT
    os.order_no,
    os.product_id,
    os.department_id,
    SUM(os.paid_price)      AS paid_price,
    mp.product_type         AS mst_product_type,
    cc_prod.freee_code      AS freee_product_type
FROM trn_other_sales_charge os
LEFT JOIN mst_product mp
       ON mp.product_id = os.product_id
LEFT JOIN mst_code_change cc_prod
       ON cc_prod.master_data_type = 1
      AND cc_prod.product_id       = os.product_id
WHERE os.status = 1
  AND os.delivery_date BETWEEN '2026-09-01' AND '2026-09-30'   -- *** adjust month ***
GROUP BY os.order_no, os.product_id, os.department_id, mp.product_type, cc_prod.freee_code
ORDER BY os.product_id, os.order_no;


-- ============================================================================
-- INTERPRETATION
--  * CHECK 1 empty OR CHECK 2 segment2_id != 1622735 OR CHECK 3 empty
--      => the DEVOPS-6287 B2B_App master data is NOT fully applied in this
--         environment. That is the root cause. The fix is Wu-san's write script
--         (INSERT the mst_code_change row + UPDATE mst_rule_for_journals id=102),
--         run in a WRITE-capable MySQL client (NOT Metabase), inside a
--         transaction, after Accounting confirms the mapping values.
--  * CHECK 4 lists the exact September charge(s) (order_no / product_id /
--         department_id) that hit the crash path (rule_found = 0).
--  * If CHECK 1-3 all look healthy but CHECK 4/4b still shows a rule_found = 0
--         or an unexpected product, the missing mapping is for a DIFFERENT
--         product/contract combo — share CHECK 4b output with Accounting to
--         decide the correct journal rule.
-- ============================================================================


-- ============================================================================
-- FOLLOW-UP (added after first run): CHECK 4 (B2B Bizmates-App path) came back
-- EMPTY, and CHECK 1/2/3 returned rows. So the DEVOPS-6287 B2B-App master data
-- IS present, and NO September OtherSales charge was on the App path. The crash
-- is therefore the GENERAL (non-App) OtherSales path. CHECK 5 covers it.
--
-- General-path resolution, from code (values resolved from config):
--   $contractType = 1                      -- OtherSales hardcodes 'B2B'; const.contractType '1'=>'B2B'
--   segment2Id    = (department_id IN (21,22,23)) ? 3 : 1
--                   -- 21/22/23 = BenefitOne / Eraberu / Ewel partner depts (config code.partnerDepartmentId)
--   masterDataType (for the contract-type code lookup) =
--       3 if freee_product_type IN (261930,261932,261931,261933,191155084)   -- Zipan
--       4 if freee_product_type IN (191155067, 236569626)                    -- Coaching / Versant
--       2 otherwise                                                          -- Bizmates
--   freeeContractType = mst_code_change.freee_code
--                       WHERE master_data_type = masterDataType AND code = segment2Id
--   RULE lookup = mst_rule_for_journals
--                 WHERE segment2_id = freeeContractType
--                   AND product_type = freee_product_type
--                   AND status = 1
--   -> null rule = the crash.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- CHECK 5 — September OtherSales charges on the GENERAL path, full resolution,
-- flagged for a missing active journal rule. Any row with rule_found = 0 is a
-- charge that aborts the run. *** Adjust the month to the failed run's target. ***
-- (FINAL on 2026-10-02 targets 2026-09.)
-- ----------------------------------------------------------------------------
SELECT
    os.order_no,
    os.product_id,
    os.department_id,
    SUM(os.paid_price)                                   AS paid_price,
    mp.product_type                                      AS mst_product_type,
    cc_prod.freee_code                                   AS freee_product_type,
    -- segment2Id = 3 for partner depts, else 1 (B2B)
    CASE WHEN os.department_id IN (21, 22, 23) THEN 3 ELSE 1 END  AS segment2_code,
    -- masterDataType for the contract-type lookup, by product family
    CASE
        WHEN cc_prod.freee_code IN (261930,261932,261931,261933,191155084) THEN 3   -- Zipan
        WHEN cc_prod.freee_code IN (191155067, 236569626)                  THEN 4   -- Coaching / Versant
        ELSE 2                                                                      -- Bizmates
    END                                                   AS master_data_type_used,
    cc_ct.freee_code                                      AS freee_contract_type,   -- segment2 tag resolved
    r.id                                                  AS matched_rule_id,
    CASE WHEN r.id IS NULL THEN 0 ELSE 1 END              AS rule_found
FROM trn_other_sales_charge os
LEFT JOIN mst_product mp
       ON mp.product_id = os.product_id
-- product_id -> freee product type (master_data_type = 1 = productType)
LEFT JOIN mst_code_change cc_prod
       ON cc_prod.master_data_type = 1
      AND cc_prod.product_id       = os.product_id
-- (segment2Id, masterDataType) -> freee contract type (segment2 tag)
LEFT JOIN mst_code_change cc_ct
       ON cc_ct.master_data_type =
            CASE
                WHEN cc_prod.freee_code IN (261930,261932,261931,261933,191155084) THEN 3
                WHEN cc_prod.freee_code IN (191155067, 236569626)                  THEN 4
                ELSE 2
            END
      AND cc_ct.code = CASE WHEN os.department_id IN (21, 22, 23) THEN 3 ELSE 1 END
-- the active journal rule the code looks up
LEFT JOIN mst_rule_for_journals r
       ON r.segment2_id  = cc_ct.freee_code
      AND r.product_type = cc_prod.freee_code
      AND r.status       = 1
WHERE os.status = 1
  AND os.delivery_date BETWEEN '2026-09-01' AND '2026-09-30'   -- *** adjust month ***
GROUP BY os.order_no, os.product_id, os.department_id,
         mp.product_type, cc_prod.freee_code, cc_ct.freee_code, r.id
ORDER BY rule_found ASC, os.product_id, os.order_no;


-- ----------------------------------------------------------------------------
-- INTERPRETATION (CHECK 5)
--  * rule_found = 0 rows are the charge(s) that crash getOtherSalesJournals().
--    Read across the row to see WHY:
--      - freee_product_type (cc_prod.freee_code) NULL -> product has no
--        master_data_type=1 mapping for its product_id (mst_code_change gap);
--      - freee_contract_type (cc_ct.freee_code) NULL -> no segment2 code row
--        for (master_data_type_used, segment2_code) (mst_code_change gap);
--      - both present but matched_rule_id NULL -> no active mst_rule_for_journals
--        for that (segment2, product_type) pair (mst_rule_for_journals gap).
--  * Share the rule_found = 0 row(s) with Accounting to confirm the correct
--    journal mapping, then add the missing master-data row via a WRITE-capable
--    client (not Metabase), mirroring Wu-san's transaction pattern.
--  * NOTE: this query models the OtherSales B2B path (contractType = 1) that the
--    code uses; it does not re-implement getChangeCodeToFreeeCode's secondary
--    fallback (product_id match then code match) for the product-type lookup,
--    which only matters if a product_id has multiple master_data_type=1 rows.
--    If a flagged row looks surprising, verify that product's mst_code_change
--    rows directly.
-- ============================================================================
