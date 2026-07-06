# Honki Set Eligibility Checker

**Author:** Keith Morrissey Manuntag
**Type:** Reference — HCR project frontend eligibility flow
**Source:** Confluence

---

## Overview

Describes the **Campaign Purchasing Flow** — enables students arriving via the Honki Set campaign to be redirected to the coaching payment page upon login, with the correct plan, pricing, and UI elements displayed.

---

## Goals & Scope

### 1. Preserve `registration_source` in `localStorage` on Login Page Load

* **Current Behavior:** The Login page clears `localStorage` on load, destroying the `registration_source` key set by the campaign landing page.
* **Change:** The Login page must **not** clear the `registration_source` key from `localStorage` on load. It should only be cleared after the post-login redirect decision has been made.

### 2. Check `mst_first_month_enrollment_discount_schedule` for Honki Set

* **Eligibility Check:** Hardcoded check for conditions: `REST`, `TRIAL/FirstMonthEnrollment`, `ACTIVESTUDENT`, or `B2B2C CP`.

```javascript
isEligibleCampaign = state.campaign_type === 'Rest'
    || state.campaign_type === 'FirstMonthEnrollment'
    || state.campaign_type === 'ActiveStudent'
```

---

## ASCH Relevance

The frontend eligibility check confirms the same 3 cohorts (REST, FirstMonthEnrollment, ActiveStudent/ActiveCoaching) that ASCH needs to identify Honki Set participants in the batch context. The `campaign_type` values here map directly to the cohort names used in `HonkiSetService`.
