# MOM: ASC for Honkiset Discussion — 2026-07-02

**Author:** Patrick Florentino
**Type:** Minutes of Meeting
**Date:** July 2, 2026, 13:30 PST
**Attendees:** Alvin Glenn Flamiano, Hayato Kuroda, Roi Patrick Florentino, Throy Ross Embudo

---

## Discussion Topics

### 1. Honkiset Campaign Overview & Revenue Allocation

* **Introduction:** Hayato Kuroda introduced a new project concerning revenue allocation for the "Honkiset" discount campaign.
* **Campaign Period:** Started July 1st and runs until October 27th/31st.
* **Campaign Benefit:** Students who start lessons and coaching during the campaign period receive a 50% discount on their first and sixth monthly payments.
* **Products Involved:** Online lessons, coaching, and free companion access to the Bizmates App.

### 2. Bizmates App Sales Calculation

* **Accounting Requirement:** Although students receive free access to the Bizmates App as part of the campaign, from an accounting perspective, a sales value must be assigned to it; it cannot be zero.
* **Allocation Method:** The total amount paid by the student (for lessons and coaching) will be divided proportionally among the lesson, coaching, and Bizmates App to allocate a non-zero sales value for the app.

### 3. Revenue Allocation Calculation Logic

* **Baseline Scenario ("Case 1"):** The allocated cost/sales amount for each product is calculated based on the total paid amount by the student and the ratio of the product's sales price.
* **Ratio Discrepancies:** Online lesson calculations use a discounted paid amount (from *other* general campaigns), while coaching and Bizmates App calculations use their standard sales price as part of the ratio.
* **Daily Rate Evaluation:** Follows existing logic where the paid amount is divided by the total number of days in the contract period, then potentially multiplied by lesson/session counts (similar to the existing ASC daily calculation).
* > 💡 **Note:** The calculation is acknowledged as complex. Hayato Kuroda will provide further explanations for other complex cases in a future discussion after attendees understand Case 1.

### 4. Project Scope & CSV Reporting

* **Deliverables:** Calculating monthly allocated sales data and exporting CSV files for the accounting team, similar to the existing daily/monthly rate calculation summary CSVs.
* **Output Isolation:** A new, separate CSV report will be generated specifically for Honkiset campaign data, distinct from the currently existing daily and monthly CSV reports.

### 5. Honkiset Campaign Eligibility & Discount Conditions

* **Eligible Lesson Plans:** Daily 1 Lesson, Daily 2 Lesson, and 15 Lessons per month.
* **Eligible Coaching Plans:** Only the 30-minute coaching plan qualifies (the 15-minute coaching plan is not eligible).
* **Bundle Condition:** Students must purchase *both* an eligible lesson plan *and* the 30-minute coaching plan during the campaign period to receive the benefits.
* **Continuity Constraints:**
  * If a student takes a "rest" at any point between months 1 and 6, they lose eligibility for the 6th-month discount.
  * Re-subscribing after a suspension does NOT reinstate eligibility.
  * Benefits are tied to the initial purchase during the campaign period only.
  * To receive the 6th-month discount, students must continuously maintain eligible lessons and 30-minute coaching for 5 consecutive months from campaign start.

---

## Action Items

| Action Item | Assigned To | Status |
|-------------|-------------|--------|
| Review the sample Google Sheet and formulas for Case 1 | Alvin Glenn Flamiano, Throy Ross Embudo | 🔲 To Do |
| Study the other cases for revenue allocation after understanding Case 1 | Alvin Glenn Flamiano, Throy Ross Embudo | 🔲 To Do |
| Prepare to explain other cases in a follow-up meeting | Hayato Kuroda | 🔲 In Progress |
