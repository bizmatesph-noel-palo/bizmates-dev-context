# Account Types (Contract Types)

**Last updated:** 2026-11-24 (B2B / B2B2C plan ranges + B2B CAP/CIP allocation status; OLD ASCH section marked history)

---

## Contract Type Constants

| Business Term | Code Constant | `contract_type` value | Payment Route | Notes |
|--------------|---------------|----------------------|---------------|-------|
| **B2C** | `CONTRACT_TYPE_PRIVATE` | `0` | Individual → Bizmates | Standard individual student |
| **B2B** | `CONTRACT_TYPE_B2B` | `1` | Company → Bizmates | Corporate-sponsored, company pays |
| **B2E** | `CONTRACT_TYPE_B2B2C` | `2` | Individual → Bizmates | Linked to company/dept like B2B, but individual pays like B2C |
| **B2E Partner** | `CONTRACT_TYPE_B2B2C` | `2` | Individual → Partner Company → Bizmates | Same `contract_type` as B2E, distinguished by `mst_partner_department` |

**Source:** `TrnStudent.php` lines 136–138:
```php
public const CONTRACT_TYPE_PRIVATE = 0;
public const CONTRACT_TYPE_B2B = 1;
public const CONTRACT_TYPE_B2B2C = 2;
```

---

## B2E vs B2E Partner — How to Distinguish

B2E and B2E Partner share the same `contract_type = 2`. The distinction is whether the student's `department_id` exists in `mst_partner_department`.

**Detection method:**
```php
// TrnStudent.php
public function isPartner(): bool
{
    return $this->isB2B2C() && $this->mst_partner_department()->get()->isNotEmpty();
}
```

**Logic:**
- `contract_type = 2` AND `department_id` IS in `mst_partner_department` → **B2E Partner**
- `contract_type = 2` AND `department_id` NOT in `mst_partner_department` → **B2E (standard)**

---

## Partner Companies (from seeder)

| `mst_partner_department.id` | `department_id` | Company Name | Status |
|----|------|------|--------|
| 4 | 1 | 東京インターカレッジコープ | Active |
| 5 | 21 | ベネフィット・ワン | Active |
| 6 | 22 | えらべる倶楽部 | Active |
| 7 | 23 | 株式会社イーウェル | Active |

**Source:** `[MBTI] src/database/seeders/MstPartnerDepartmentTableSeeder.php`

> **Note:** Seeder data may not reflect current production state. As of 2024/07/26, active partners were reported as department_id 21 and 23.

---

## `mst_partner_department` Table Schema

```sql
CREATE TABLE `mst_partner_department` (
    `id` BIGINT PRIMARY KEY,
    `department_id` BIGINT,
    `name` VARCHAR(99) COMMENT '会社名',
    `attention_path` VARCHAR(128) NULL COMMENT '特定部署用の利用規約パス',
    `status` INT DEFAULT 1 COMMENT '0=無効（契約解除）/1=有効（契約中）',
    `created_at` DATETIME,
    `updated_at` DATETIME
);
```

**Source:** `[Migrations] database/migrations/2025_07_03_055626_create_mst_partner_department_table.php`

---

## Related Helper Methods (TrnStudent)

```php
public function isPrivate(): bool    // B2C
public function isB2B2C(): bool      // B2E (includes Partners)
public function isB2B(): bool        // B2B
public function isPartner(): bool    // B2E Partner specifically
```

**Static variants for array context:**
```php
public static function isB2C(?array $student = null): bool
public static function getStudentContractType(?array $student = null): ?int
```


---

## Contract Type Transitions

### Allowed Transitions Matrix

| From → To | B2C (0) | B2B (1) | B2E (2) | B2E Partner (2) |
|-----------|:-------:|:-------:|:-------:|:---------------:|
| **B2C (0)** | — | ❌ Never | ✅ Admin | ❌ Never |
| **B2B (1)** | ✅ Admin | — | ✅ Student + Admin | ❌ Never |
| **B2E (2)** | ✅ Student + Admin | ❌ Never | ✅ Admin (dept change) | ❌ Never |
| **B2E Partner (2)** | ✅ Student + Admin | ❌ Never | ✅ Admin | ❌ Never |

**Key rule:** Nobody can transition TO B2B or TO B2E Partner via any system interface. B2B is only assigned at corporate student registration time. Partner status is determined by the `department_id` being in `mst_partner_department`.

---

### Transition 1: B2B → B2E (Student-Initiated)

**Trigger:** A B2B student makes a personal payment (PayPal or Credit Card) for Online Lessons.

**Business meaning:** The corporate student adds a self-funded lesson plan alongside their company-sponsored plan. The system treats this as a transition to B2E (company-linked but self-paying).

**Flow:**
1. Student visits plan purchase page and selects PayPal/Credit Card payment
2. System creates a "pre-application" charge (事前申し込み) with `contract_type = 2`
3. Charge is linked to existing product via `refresh_charge_id`
4. On start date, `Order::doDeliver()` updates `trn_student.contract_type` to B2E
5. Transition logged in `log_b2b_to_b2b2c`

**What changes:**
- `trn_student.contract_type`: 1 → 2
- `trn_charge.contract_type`: new charge set to 2
- `trn_student_product.contract_type`: new product set to 2
- `company_id`, `department_id`: **unchanged** (still linked to company)
- `source_contract_type`: **unchanged** (preserves original signup type)

**Cancellation:** Student can cancel the pre-application before it takes effect via `B2b2cPreApply::cancelOnlineLesson()` / `cancelVideoLesson()`

**Log table:** `log_b2b_to_b2b2c`
- `apply_status`: 1 = Applied (事前申し込み済み), 2 = Canceled (取消済み), 3 = Complete (移行完了)

**Related files:**
- `[MBTI] src/app/GraphQL/Mutations/Student/B2b2cPreApply.php` — pre-apply cancellation
- `[MBTI] src/app/Services/Student/Payment/PaypalService.php` — `toB2B2cBuy()` (PayPal flow)
- `[MBTI] src/app/GraphQL/Mutations/Student/Payment/CreditCard.php` — credit card flow
- `[MBTI] src/app/Libs/Order.php` — `doDeliver()` completes the transition
- `[MBTI] src/app/Models/LogB2bToB2b2c.php` — log model

---

### Transition 2: B2E → B2C (Student-Initiated)

**Trigger:** A B2E student requests to switch to individual (private) contract.

**Business meaning:** The student disconnects from the corporate department and becomes a fully independent B2C student. They lose all corporate affiliations.

**Flow:**
1. Student initiates individual contract switch (from MyStage UI)
2. System creates pre-application charge with `contract_type = 0`
3. On start date, `Order::doDeliver()` updates student record
4. Transition logged in `log_b2b2c_to_b2c`

**What changes:**
- `trn_student.contract_type`: 2 → 0
- `trn_student.company_id`: → 0
- `trn_student.department_id`: → 0
- `trn_student.employee_code`: → '' (cleared)
- `trn_charge.contract_type`: → 0, `order_no` → null, `department_id` → 0, `rep_id` → 0
- `trn_student_product.contract_type`: → 0, `order_no` → null

**Cancellation:** Student can cancel via `B2cPreApply::cancelLesson()`

**Log table:** `log_b2b2c_to_b2c`
- `apply_status`: 1 = Applied, 2 = Canceled, 3 = Complete

**Related files:**
- `[MBTI] src/app/GraphQL/Mutations/Student/B2cPreApply.php` — pre-apply cancellation
- `[MBTI] src/app/Services/Student/Payment/PaypalService.php` — `changeB2B2CPartnerToB2c()`
- `[MBTI] src/app/Models/LogB2b2cToB2c.php` — log model

---

### Transition 3: B2E Partner (REST) → B2C (Automatic)

**Trigger:** A B2E Partner student who is in REST (inactive) status makes a new personal purchase.

**Business meaning:** Partner company students who have gone inactive and then re-purchase on their own are automatically converted to B2C. The rationale is that the partner relationship is considered broken by the inactivity period.

**Flow:**
1. REST Partner student purchases via PayPal or Credit Card
2. Payment processing detects: `isPartner() && before_contract_status == REST`
3. System immediately sets contract_type to B2C (no pre-application period)
4. All corporate fields cleared

**What changes:**
- Same as B2E → B2C (Transition 2), but happens **immediately** at purchase time — no pre-application period.

**Related code (both paths are identical in behavior):**
- `[MBTI] src/app/Services/Student/Payment/PaypalService.php` ~line 189
- `[MBTI] src/app/GraphQL/Mutations/Student/Payment/CreditCard.php` ~line 2087

---

### Transition 4: Admin Contract Type Change (Admin-Initiated)

**Trigger:** Admin user changes contract type via Admin Panel (bizmates.jp).

**Business meaning:** Support or corporate management manually reassigns a student's contract type. Common scenarios:
- Company restructuring (B2B → B2E, so student starts paying themselves)
- Student leaving company (B2E → B2C)
- B2C student joining a corporate program (B2C → B2E)

**Admin UI location:** Admin Panel → Student Detail → 契約種別変更 (Contract Type Change)

**Allowed transitions per the admin service:**

| Current Type | Options Shown in Admin UI |
|---|---|
| B2C | B2E only |
| B2B | B2C, B2E |
| B2E (non-partner) | B2C only |
| B2E Partner | B2C, B2E (to different non-partner department) |

**Restrictions (enforced by `isChangeable()`):**
- ❌ Cannot change TO B2B (ever — B2B is registration-only)
- ❌ Cannot change TO B2E Partner (partner status comes from `mst_partner_department`)
- ❌ Cannot change B2B or B2E Partner if student has current/future active charges

**What changes:**
- `trn_student.contract_type`: updated
- `trn_student.company_id`: set to target company or 0
- `trn_student.department_id`: set to target department or 0
- `trn_student.employee_code`: cleared if → B2C
- `trn_student.company_email`: cleared if → B2C
- `trn_student.disclose_agreement`: reset to unchecked
- All current/future `trn_charge`: `contract_type`, `department_id`, `rep_id` updated
- All current/future `trn_student_product`: `contract_type` updated
- `trn_evaluation`: `contract_type` updated for affected tickets
- `trn_student_book`: `contract_type` updated for affected tickets
- `trn_student_profile.company_name`: cleared if → B2C

**Related files:**
- `[Admin] fuel/app/classes/libs/service/changecontracttypeservice.php` — all transition logic
- `[Admin] fuel/app/classes/controller/api/admin/contracttype.php` — API endpoint
- `[Admin] fuel/app/classes/view/admin/contracttype/change.php` — view model

---

### Transition 5: B2B Student Registration (Admin-Only)

**Trigger:** Admin registers a new corporate student via the Corporate Management panel.

**Business meaning:** A company purchases a batch of student accounts. Admin creates the student with `contract_type = 1` (B2B) from the start.

**Flow:**
1. Admin → Company Manager → Department → Register Student
2. `Controller_Api_Admin_Corp` creates student with `contract_type = B2B`
3. Student is assigned `company_id` and `department_id` at creation

**Key point:** This is the ONLY way a student gets `contract_type = 1`. There is no runtime transition that changes an existing student TO B2B.

**Related files:**
- `[Admin] fuel/app/classes/controller/api/admin/corp.php` ~line 1201

---

### Important Fields for Contract History

| Column | Table | Purpose |
|--------|-------|---------|
| `contract_type` | `trn_student` | Current contract type |
| `source_contract_type` | `trn_student` | Original contract type at registration (never changes) |
| `contract_type` | `trn_charge` | Contract type when charge was created/updated |
| `contract_type` | `trn_student_product` | Contract type of the product subscription |

The `source_contract_type` field is critical for analytics — it preserves what the student originally was, even after transitions.

---

### Log Tables for Contract Transitions

| Table | Tracks | Model |
|-------|--------|-------|
| `log_b2b_to_b2b2c` | B2B → B2E transitions (student-initiated) | `LogB2bToB2b2c` |
| `log_b2b2c_to_b2c` | B2E → B2C transitions (student-initiated) | `LogB2b2cToB2c` |

Both log tables share the same structure:
- `student_id` — who
- `apply_at` / `apply_charge_id` — when pre-applied and which charge triggered it
- `complete_at` / `complete_charge_id` — when completed and which charge finalized it
- `apply_status` — 1=Applied, 2=Canceled, 3=Complete
- `status` — active flag

**Note:** Admin-initiated transitions are NOT logged in these tables. They appear only in system logs (Laravel/FuelPHP log files). The admin controller logs: `"Start contract type change. student_id => X, contract_type_to => Y, department_id_to => Z"`

---

### OLD ASCH Impact: Contract Type Changes During Honki Set (cancelled 2026-08-07 — history only)

> The OLD ASCH proration was never built. For the 2027 Honki campaign (NEW ASCH, testing only), a contract change shows up only through the charges themselves — e.g. pattern P11 (B2C/B2E → B2B in the half-price first month; per Kuroda-san's provisional sheet the overlap is a prorated refund, FLOOR(daily price) × overlap days, e.g. 7,425 / 31 = 239 × 21 = 5,019; the B2B charge is not allocated until the B2B CAP/CIP extension below is released).

Contract type transitions affected the planned OLD ASCH revenue proration:
- **B2E → B2B switch** (Pattern 7): Future-only reversion, past prorated discounts kept. Student excluded from future ASCH runs.
- **Charge-level contract_type**: ASCH reads `trn_charge.contract_type` per charge, not `trn_student.contract_type`, because individual charges retain the contract type they were created under.
- **department_id on refund**: When B2E→B2C happens, existing charges get `department_id = 0`, affecting Freee journal `mst_rule_for_journals` lookup.

**Source:** REF-ASCH-06 §3 (Eligibility-Loss Handling)

---

## B2B / B2B2C Plans and the CAP / CIP Allocation (added 2026-11-24)

**Plan ranges (Bizmates prod, per Cristoff-san's B2B investigation, Confluence v6, 2026-11-20):**

| Range | Who | Notes |
|---|---|---|
| 1016–1027 | CAP (standard plans) | ASCA allocation detects these |
| 1028–1032 | CIP (standard plans) | ASCI conversion / refund split detects these |
| 20000001–20024537 | **B2B** company plans (14,545 plans) | Not detected by ASCA / ASCI today |
| 30000001–30013186 | **B2B2C** department plans | One plan has Coaching Intensive 10025 but no App 10022 (`planModel.php:333-340`) |

**Current behaviour:** CAP / CIP detection gates on plan_id 1016–1032, so a B2B student on a company plan with Coaching + App is **not allocated** (App stays ¥0, Coaching keeps the full amount). Found in the B2C/E UAT mapping (2026-11). **Accounting decision: B2B CAP/CIP is not sold until the B2B allocation is released.**

**Planned B2B CAP/CIP extension (agreed with Kuroda-san; G1 pending):**
- Detection: `plan_id ≥ 20000000` + product combination, **no `contract_type` filter**; App-present check in SQL (about 4,000 B2B coaching-only charges a year).
- Safety-net guards kept (per Sales: B2B App always ¥0, same dates, no CAP + CIP coaching together, discount already in `paid_price`).
- **Scope A:** no B2B refund split, a warning log only (no B2B refunds in prod; after a B2B refund the allocated App revenue is not reversed — manual fix).
- B2B is BANK-paid and not renewed.
- **Business context (Kuroda-san, Slack 2026-11-17 / 11-19):** B2B starts selling CAP/CIP from the **April 2027 plan revision** (at most one early case before that). Same list prices as B2C, plus long-term discounts (6 months 5% off, 12 months 10% off) typed by hand into `paid_price` — no separate discount logic. Rounding follows the existing logic (CIP: App = FLOOR, Coaching = total − App); a test for a multi-month charge with a long-term discount is requested. Student replacement (LMS 受講生の入れ替え) may happen; staging test pending.
- **Release conditions (Kuroda-san, 2026-11-24):** B2B on its own branch, not merged into the shared branch before the 12/14–12/17 release; on DEV04 the UAT data must show zero difference on all B2C/B2E rows between the release code and the B2B code; the November production data must show no change on non-CAP/CIP rows (esp. B2B coaching-only charges); B2B checks skip only the B2B bundle, never fail the whole month; confirm 0 production charges with plan_id ≥ 20000000 and product 10022; if released after the 202701 batch, also compare with its production output.
- ⚠️ **DEV04 data note:** Kuroda-san's example B2B student 515 (CIP) is on plan **30000067** (30000000 + department_id) on DEV04, while 3000xxxx is the B2B2C range in production. DEV04 test data may differ from production — check before the B2B rule is finalized (the ≥ 20000000 rule covers both ranges).
- Open: `≥ 20000000` also covers the B2B2C range; whether CIP needs the App-present rule; whether the new guards apply to B2B only or all plans.
- Release planned the **week of 2027-01-11** (tentative, approved by the business side 2026-11-24; separate from the ASCA / ASCI 12/14–12/17 release). Live status: `docs/asc-projects-task-tracker.md`.
