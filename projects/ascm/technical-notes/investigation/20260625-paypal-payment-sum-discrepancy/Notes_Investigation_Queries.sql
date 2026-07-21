
-- Q1: Find B2C/B2B2C PayPal monthly-plan charges for May 2026
-- This gives us charges that SHOULD appear in PaypalPaymentSum but were showing uriage=0:
SELECT 
    c.id AS charge_id,
    c.student_id,
    c.product_id,
    c.contract_type,
    c.paid_at,
    c.paid_price AS charge_paid_price,
    c.order_no
FROM trn_charge c
WHERE c.paid = 1
    AND c.status = 1
    AND c.charge_type <> 1
    AND c.contract_type IN (0, 2)
    AND c.product_id IN (16,17,18,19,20,21,22,23,27,28,29)
    AND c.paid_at BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
ORDER BY c.paid_at
LIMIT 20;



-- Q2: Check if those charges have data in log_monthly_rate_calculation
-- Take a few charge_ids from Q1 and verify they have monthly log rows:
SELECT 
    l.charge_id,
    l.target_ym,
    l.number_of_lessons_taken,
    l.number_of_expired_lessons,
    l.number_of_remaining_lessons,
    l.paid_price
FROM log_monthly_rate_calculation l
WHERE l.charge_id IN (
3060894,
3060885,
3060935,
3060943,
3061086,
3061282,
3061324,
3061867,
3061985,
3062093,
3062323,
3062715,
3062722,
3062728,
3062732,
3062784,
3062798,
3062866,
3062887,
3062891
)
ORDER BY l.charge_id, l.target_ym;

-- Q3: Verify these charges are NOT in log_daily_rate_calculation
-- Confirms the gap — monthly plan charges excluded from daily log:
SELECT 
    l.charge_id,
    l.target_ym,
    l.paid_price
FROM log_daily_rate_calculation l
WHERE l.charge_id IN (
3060894,
3060885,
3060935,
3060943,
3061086,
3061282,
3061324,
3061867,
3061985,
3062093,
3062323,
3062715,
3062722,
3062728,
3062732,
3062784,
3062798,
3062866,
3062887,
3062891
)
ORDER BY l.charge_id, l.target_ym;
