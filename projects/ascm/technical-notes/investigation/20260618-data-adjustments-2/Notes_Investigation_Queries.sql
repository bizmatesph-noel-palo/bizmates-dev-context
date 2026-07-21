-- Q1: Check monthly log data for the affected Bizmates charges
SELECT
    charge_id,
    target_ym,
    total,
    number_of_carried_over_lessons,
    number_of_lessons_taken,
    number_of_expired_lessons,
    number_of_remaining_lessons,
    paid_price
FROM log_monthly_rate_calculation
WHERE charge_id IN (3001753, 3033180, 3026886, 2998736, 3028080, 3026990, 3026093)
ORDER BY charge_id, target_ym;

-- Q2: Check monthly log data for the affected Zipan charges
SELECT
    charge_id,
    target_ym,
    total,
    number_of_carried_over_lessons,
    number_of_lessons_taken,
    number_of_expired_lessons,
    number_of_remaining_lessons,
    paid_price
FROM log_monthly_rate_calculation
WHERE charge_id IN (12480, 12501)
ORDER BY charge_id, target_ym;


-- Q3: Bizmates charge info
SELECT id, student_id, product_id, order_no, start_date, end_date, paid_price, status
FROM trn_charge
WHERE id IN (3001753, 3033180, 3026886, 2998736, 3028080, 3026990, 3026093);

-- Q4: Zipan charge info
SELECT id, student_id, product_id, order_no, start_date, end_date, paid_price, status
FROM trn_charge
WHERE id IN (12480, 12501);



-- Q5: Tickets for charge 3033180's student_product
SELECT
    t.id AS ticket_id,
    t.student_product_id,
    t.start_datetime,
    t.end_datetime,
    t.status
FROM trn_ticket t
JOIN trn_student_product sp ON sp.id = t.student_product_id
WHERE sp.charge_id = 3033180;


-- Q6: Lessons (evaluations) attributed to this charge's tickets in April and May
SELECT
    e.ticket_id,
    e.student_id,
    e.lesson_date,
    e.lesson_datetime,
    t.start_datetime AS ticket_start,
    t.end_datetime AS ticket_end
FROM trn_evaluation e
JOIN trn_ticket t ON t.id = e.ticket_id
JOIN trn_student_product sp ON sp.id = t.student_product_id
WHERE sp.charge_id = 3033180
ORDER BY e.lesson_date;


-- Q6 (optimized): Count lessons per ticket for charge 3033180
SELECT
    e.ticket_id,
    COUNT(*) AS lesson_count,
    MIN(e.lesson_date) AS first_lesson,
    MAX(e.lesson_date) AS last_lesson
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
GROUP BY e.ticket_id
HAVING COUNT(*) > 1
ORDER BY e.ticket_id;


-- Q7: Check if student 210462 has adjacent charges (predecessor/successor)
SELECT
    id AS charge_id,
    student_id,
    product_id,
    order_no,
    start_date,
    end_date,
    paid_price,
    status
FROM trn_charge
WHERE student_id = 210462
    AND product_id = 29
ORDER BY start_date;


-- Q8: Total lesson count for this student in April and May
-- (across ALL tickets, not just this charge)
SELECT
    DATE_FORMAT(e.lesson_date, '%Y-%m') AS lesson_month,
    COUNT(*) AS total_lessons
FROM trn_evaluation e
WHERE e.student_id = 210462
    AND e.lesson_date >= '2026-04-01'
    AND e.lesson_date < '2026-06-01'
GROUP BY DATE_FORMAT(e.lesson_date, '%Y-%m');


-- Q9: All evaluations for charge 3033180's tickets WITH lesson dates
-- (so we can verify which month they fall into)
SELECT
    e.ticket_id,
    e.lesson_date,
    e.lesson_datetime
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
ORDER BY e.lesson_date, e.ticket_id;


-- Q10: Count evaluations per month for ONLY this charge's tickets
-- (should match the log: April=14, May=2)
SELECT
    CASE
        WHEN e.lesson_date >= '2026-04-01' AND e.lesson_date < '2026-05-01' THEN '202604'
        WHEN e.lesson_date >= '2026-05-01' AND e.lesson_date < '2026-06-01' THEN '202605'
        ELSE 'other'
    END AS month,
    COUNT(*) AS evaluation_count
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
GROUP BY 1;


-- Q11: Check if the batch that generated this log data was the May batch
-- (startDate=2026-05-01) or the April batch (startDate=2026-04-01)
-- This matters because the lesson counting boundary differs based on target month
SELECT
    charge_id,
    target_ym,
    created_at
FROM log_monthly_rate_calculation
WHERE charge_id = 3033180
ORDER BY target_ym;


-- Q12: Check created_at of evaluations for charge 3033180's tickets
-- to see if any were added AFTER the batch ran on 2026-06-18
SELECT
    e.ticket_id,
    e.lesson_date,
    e.lesson_datetime,
    e.created_at
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
ORDER BY e.created_at;


-- Q12: tell me if evaluations were added after the batch ran on June 18th 17:37–19:26
SELECT
    e.ticket_id,
    e.lesson_date,
    e.lesson_datetime,
    e.created_at
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
ORDER BY e.created_at;

-- Q13: Check if charge 3001753 has is_available_refund = 1 
-- (which could trigger has_new_contract_after_refund)
SELECT
    sp.charge_id AS true_charge_id,
    sp.student_id,
    sp.order_no,
    sp.start_date,
    sp.end_date,
    prc.refund_charge_id,
    prc.result,
    prc.refund_price
FROM trn_student_product sp
LEFT JOIN trn_prorated_refund_charge prc ON prc.refund_charge_id = sp.charge_id
WHERE sp.charge_id = 3001753;

-- Q14: Check if this charge matches the orphaned charge query
-- (which would produce its own row with different logic)
SELECT
    sp.charge_id,
    sp.student_id,
    sp.product_id,
    sp.start_date,
    sp.end_date,
    (SELECT COUNT(*) FROM trn_ticket t WHERE t.student_product_id = sp.id) AS ticket_count
FROM trn_student_product sp
WHERE sp.charge_id = 3001753;


-- Q15: What flags does the CTE compute for charge 3001753 in the April batch?
-- Run this against Bizmates DB
SELECT
    l.charge_id,
    l.target_ym,
    l.total,
    l.number_of_carried_over_lessons,
    l.number_of_lessons_taken,
    l.number_of_expired_lessons,
    l.number_of_remaining_lessons,
    l.paid_price,
    c.start_date,
    c.end_date,
    c.paid_price AS charge_paid_price
FROM log_monthly_rate_calculation l
JOIN trn_charge c ON c.id = l.charge_id
WHERE l.charge_id = 3001753
ORDER BY l.target_ym;

-- Q16: Charge chain for student 121073, product 29
SELECT
    id AS charge_id,
    student_id,
    product_id,
    order_no,
    start_date,
    end_date,
    paid_price,
    status
FROM trn_charge
WHERE student_id = 121073
    AND product_id = 29
ORDER BY start_date;
