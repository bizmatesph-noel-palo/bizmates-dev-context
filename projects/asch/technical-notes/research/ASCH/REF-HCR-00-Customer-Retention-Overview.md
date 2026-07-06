# HCR — Honki Set Customer Retention: Project Overview

**Project Code:** HCR (Honki Set Customer Retention)
**Type:** Reference — existing MBTI_backend project that ASCH depends on
**Source:** Confluence

---

## Project Summary

* **Objective:** Reduce the withdraw rate (離脱率 / churn rate) among Honki Set users by displaying a cancellation warning modal when they attempt to cancel their Online Lesson or Bizmates Coaching subscription within 6 months of their Honki Set purchase.
* **Business Impact:** Students who see the warning are informed they will forfeit their 1-month cashback benefit if they proceed, encouraging them to maintain their subscription.

---

## Resources

| Role | Name |
|------|------|
| Project Manager (PM) | Soli Sahukar |
| Software Delivery Manager (SDM) | Jaysser Balido |
| SCM / Lead Developer | Francis Nikko Perez |
| Developer | Francis Nikko Perez |
| Developer | Terry Balahadia |
| QA | Jaymariz Liwanag |

---

## Repositories

| Repository | Purpose |
|-----------|---------|
| `MBTI_backend` | Laravel 12 GraphQL API — Eligibility endpoint, behavior tracking |
| `MBTI_frontend` | Nuxt.js 2.15 Student Portal — Warning modal, redirect logic |

---

## Technical Architecture

### Backend (MBTI_backend)

* **Framework:** Laravel 12 + Lighthouse GraphQL
* **Endpoint:** `honki_set_eligibility` query (authenticated via `@guard`)
* **Pattern:** Thin Resolver → Service Class → 5-CTE SQL Query
* **Response:** `is_honki_user`, `months_completed`, `cashback_date`, `days_remaining`
* **Error Strategy:** Graceful degradation (always returns `is_honki_user: false` on failure)

### Frontend (MBTI_frontend)

* **Framework:** Nuxt.js 2.15 + Vue.js 2.6
* **Feature:** Warning modal on rest/cancellation pages
* **Target Pages:**
  * `MyBizmates/student/rest/request/coaching/`
  * `MyBizmates/student/rest/request/online/`

---

## Key Business Rules

* **Honki Set Definition:** Online Lesson + Bizmates Coaching 30分 + Bizmates App purchased during a campaign period
* **Eligibility Window:** 6 months from trigger purchase date
* **Cashback Condition:** Maintain continuous subscription (both Online Lesson AND Coaching) for 6 months
* **Continuous:** No gap > 1 day between consecutive charge periods
* **Forfeiture:** Cancelling either Online Lesson or Coaching before 6 months forfeits the cashback
* **Exclusions:** B2B students (`contract_type=1`) and non-Japan students (`country_id≠86`) are excluded
* **Renewal Detection:** Charges where a prior charge's `end_date = start_date - 1 day` are renewals (not new purchases)

---

## Implementation Status

| Component | Status |
|-----------|--------|
| Backend: Eligibility Service | ✅ Complete — 5-CTE SQL with campaign fallback |
| Backend: GraphQL Resolver | ✅ Complete — with full logging |
| Backend: DTO Pattern | ✅ Complete — `HonkiSetEligibilityData` class |
| Backend: Unit Tests | ✅ Complete — including property-based tests |
| Backend: Feature Tests | ✅ Complete — end-to-end GraphQL tests |
| Frontend: Warning Modal | 🔲 Not Started |
| Frontend: Behavior Tracking | 🔲 Not Started |

---

## ASCH Relevance

The HCR project built the eligibility detection infrastructure that ASCH depends on:
- `mst_honki_set` table — campaign config (dates, plan IDs, cohort flags)
- `HonkiSetService` — eligibility checking waterfall (first_month → rest → active_coaching)
- 5-CTE SQL query — runtime identification of Honki Set members

ASCH will need to build on or replicate this identification logic to determine which charges to process.
