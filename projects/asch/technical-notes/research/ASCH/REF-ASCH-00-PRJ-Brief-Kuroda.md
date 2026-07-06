# ASCH: Revenue Allocation for Bundled Plans (Honki-set, 本気セット)

**Author:** Hayato Kuroda
**Type:** Project Brief
**Source:** Confluence (shared 2026-07-02)

---

## Purpose

We will build ASCH to calculate monthly revenue allocation for bundled plans (Honki Set) for students. The goal is to support accounting and Freee integration.

> 💡 **Note:** Honki Set is not a plan or product; it is a marketing campaign.

---

## Background

We need this adjustment because Honki Set includes the App as a benefit, and the App is effectively provided at no extra charge for bundle members.

However, from an accounting point of view, we cannot treat the entire bundle as Lesson revenue. We need to allocate the total sales amount across the Lesson, Coaching, and App so that monthly revenue is recognized correctly and the accounting data can be exported properly for CSV and Freee integration.

---

## Scope

* Calculate monthly allocated sales.
* Export CSV files for accounting.
* Prepare summary data for Freee linkage.

---

## Bundle Overview

Honki Set is a bundled plan for Bizmates students. The bundle components consist of:
* **Lesson plans:** Daily 1, Daily 2, and 15-lesson plans.
* **Coaching plans:** 30-minute coaching plans.
* **App:** Included as a benefit in the bundle.

---

## Eligible Students & Rules

* **Eligible Students:** Honki Set is used for students who are treated as Honki Set members under the marketing rules. *(The exact entry conditions are still being confirmed.)*
* **Discount Rules:** The 6th-month benefit is part of the bundle rules.

---

## Simple Example: Pattern 1

Pattern 1 signifies that the Lesson and Coaching components start on the exact same date.

* **Reference Sheet:** [Honki Set Allocation Google Sheet](https://docs.google.com/spreadsheets/d/1NoaaoTNX8a-enGql_qZdGke8MofQX8AHThNF6XB0Sgk/edit?gid=824413910#gid=824413910)

---

## Data Sources & Output

### Data Sources
* Existing ASC data
* MBTI backend data
* New ASCH tables if needed

### Output
* CSV for accounting
* Data summary for Freee
