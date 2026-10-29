# Coaching E-BOOK Delivery — Implementation Plan

**Ticket:** Redmine #12006
**Date:** 2026-08-11
**Depends on:** `technical-notes/investigation/20260811-coaching-payment-emails/01-observed-purchase-email.md`

---

## 1. Request

From the Coaching team:

1. **New students** — attach the E-BOOK link to the email automatically sent on coaching payment
2. **Existing students** — show the E-BOOK in MyBizmates only to students currently subscribed to coaching
3. Any other good delivery ideas

Both are feasible. Neither needs new infrastructure.

---

## 2. Locked decisions

| Decision | Choice | Why |
|---|---|---|
| Hosting | `bizmates.jp/public/assets/coaching/ebook.pdf` → `https://www.bizmates.jp/assets/coaching/ebook.pdf` | Same pattern as the existing 初心者パッケージ Rulebook. `public/` is CDN-fronted. |
| Access control | Public URL, no auth | Matches existing precedent. See §7 if the team wants it restricted. |
| Delivery in email | Link only, never an attachment | The PDF is 13.8 MB. |
| URL source in code | Config value, not hardcoded per template | The link appears in 8 templates + 1 GraphQL field. One place to change. |
| Portal delivery | Extend the existing `coaching_page_info` query with an E-BOOK field | The coaching portal already fetches this query. A dedicated query would add a resolver, DTO, frontend service method, and store wiring for static content. |

### Housekeeping

`public/assets/coaching/` currently also contains `ebook.pdfZone.Identifier`, a Windows artifact from
the file copy. Delete before committing.

---

## 3. Part 1 — E-BOOK link in the coaching payment email

### 3.1 Which system is live

Coaching payment emails exist in **both** repos:

- **MBTI_backend** — `BCOService::sendPaymentNotification($plan_id)`. Called from the student-portal
  payment mutations (`Paypal.php:1945`, `CreditCard.php:2793`). **This is the live path.**
- **bizmates.jp** — `BizmatesCoachingService::sendPaymentNotification()`. Legacy. Called from
  `controller/coaching/payment.php` and `controller/api/payments/creditcard/coaching.php`.

**Task 0 (do first):** confirm whether the bizmates.jp coaching payment controllers are still
reachable. There is no explicit route entry in `fuel/app/config/routes.php`, so they resolve only by
FuelPHP convention (`/coaching/payment`). If unreachable, skip §3.3 entirely and save ~0.5 day.

### 3.2 When each template fires

All 3 student-facing templates are sent by `BCOService::sendPaymentNotification($plan_id)` at
`src/app/Services/BCO/BCOService.php:68`. The selection logic (line 84–101):

| Template | Path | Fires when |
|---|---|---|
| `S_payment_notification_beginner_package_S` | `src/resources/views/emails/bizmates/bco/S_payment_notification_beginner_package_S/body.blade.php` | `$plan_id` is `MstPlan::ONLINE_LESSON_25_FVP_BEGINNER_COACHING_PLAN` or `MstPlan::ONLINE_LESSON_25_FVP_BEGINNER_COACHING_30_PLAN` |
| `S_payment_notification_campaign_S` | `src/resources/views/emails/bizmates/bco/S_payment_notification_campaign_S/body.blade.php` | Current datetime falls within `bco.campaign_start_datetime` – `bco.campaign_end_datetime` (config: `src/config/bco.php`) AND plan is not beginner-package |
| `S_payment_notification_S` | `src/resources/views/emails/bizmates/bco/S_payment_notification_S/body.blade.php` | Default — none of the above conditions match |

Callers that trigger `sendPaymentNotification()`:

| Payment method | Caller | File | Line |
|---|---|---|---|
| Credit card | `capture_order_coaching()` | `src/app/GraphQL/Mutations/Student/Payment/CreditCard.php` | ~2793 |
| PayPal | coaching capture completion | `src/app/GraphQL/Mutations/Student/Payment/Paypal.php` | ~1945 |

Both callers are gated by `if (isset($bcoParams))` — the email only fires when a coaching product
was detected in the cart (see §3.4 for the associated risk).

### 3.3 MBTI_backend code changes

**Config** — `src/config/bco.php`:

```php
// Coaching E-BOOK (Coaching Guide & Workbook)
'ebook_url' => env('COACHING_EBOOK_URL', 'https://www.bizmates.jp/assets/coaching/ebook.pdf'),
```

Add `COACHING_EBOOK_URL=` to `src/.env.bizmates.example` (and `.env.zipan.example` if coaching is ever
enabled there — currently it is not).

**Service** — `src/app/Services/BCO/BCOService.php`, in `sendPaymentNotification()`:

```php
$mail_params = [
    // ... existing keys ...
    'ebook_url' => config('bco.ebook_url'),
];
```

**Templates** — `src/resources/views/emails/bizmates/bco/`:

| Template | Format | Insert |
|---|---|---|
| `S_payment_notification_S/body.blade.php` | HTML | `<a href>` block, after the `【ご対応のお願い】` section |
| `S_payment_notification_beginner_package_S/body.blade.php` | HTML | `<a href>` block, alongside the existing `◆初心者パッケージ専用教材のご確認◆` block |
| `S_payment_notification_campaign_S/body.blade.php` | **plain text** | bare URL on its own line — an `<a>` tag would render literally |
| `S_payment_notification_A/*` | text | **no change** (admin notification) |

HTML variant:

```html
<b>◆コーチングガイド＆ワークブックのご確認◆</b><br>
コーチング開始前に、以下のE-BOOKをダウンロードしてご確認ください。<br>
<a href="{{ $ebook_url }}">コーチングガイド＆ワークブック</a><br>
<br>
```

Text variant:

```text
◆コーチングガイド＆ワークブックのご確認◆
コーチング開始前に、以下のE-BOOKをダウンロードしてご確認ください。
{{ $ebook_url }}
```

### 3.4 bizmates.jp changes (only if §3.1 says the legacy path is live)

**Config** — `fuel/app/config/bizmatescoaching.php`: add `'ebook_url' => getenv('COACHING_EBOOK_URL') ?: 'https://www.bizmates.jp/assets/coaching/ebook.pdf'`, plus `.env.sample`.

**Service** — `fuel/app/classes/libs/service/bizmatescoachingservice.php`: add `'ebook_url'` to `$mail_params`.

**Templates** — `fuel/app/emails/coaching/` (all plain-text twig, so bare URL):
`payment_notification.twig`, `payment_notification_campaign.twig`,
`payment_notification_end_of_year_1.twig`, `_2.twig`, `_3.twig`.

### 3.5 Required bug fix — wrong plan id reaches the email selector

`CreditCard.php::capture_order_coaching()` reassigns `$planId` on every cart-item iteration
(line 2467), so after the loop it holds the **last** product's plan id — for bundle purchases
(coaching + Online Lesson FVP) that is usually the Online Lesson plan, not the coaching plan.
That value is passed to `sendPaymentNotification($planId)`, which uses it to decide between the
beginner-package template and the default template.

This is in scope for this ticket because template selection determines which E-BOOK block a student
sees. Fix by capturing the coaching plan id where the coaching product is detected:

```php
// inside the loop, alongside the existing $bcoParams assignment (~line 2515)
if (CoachingService::isCoachingProduct((int)$productId)) {
    $coachingPlanId = $planId;
    $bcoParams = [ /* unchanged */ ];
}
```

```php
// after DB::commit() (~line 2788)
if (isset($bcoParams) === true) {
    $bcoService = new BCOService($student);
    $bcoService->sendStudentRequest($bcoService::TICKET_SAVE_ENDPOINT, 'POST', $bcoParams);
    $bcoService->sendPaymentNotification($coachingPlanId);
}
```

Apply the same change in `Paypal.php:1945`, which reads `$operation['items'][0]['plan_id']`
(first item rather than last — also not guaranteed to be the coaching product).

### 3.6 Deliberately out of scope (log as separate tickets)

- **Coaching email silently skipped when `$bcoParams` is unset.** The whole email send is inside
  `if (isset($bcoParams))`. If no cart item passes `CoachingService::isCoachingProduct()`, the student
  gets no coaching email and nothing is logged. This is a delivery risk for the E-BOOK, but fixing it
  properly means deciding what "a coaching purchase without a coaching product" means. Add
  a `Log::warning` in this ticket; fix the root cause separately.
- **Date format on the coaching path.** `capture_order_coaching()` passes raw `Y-m-d` into
  `S_buy_new_plan_S`, which the plan path feeds `Y年m月d日`. Cosmetic, unrelated to E-BOOK.
- **`S_buy_new_plan_S/body.blade.php` and `jp/body.blade.php` are byte-identical duplicates.**
- **No `契約開始のご案内` email on the PayPal path.** Confirm with the business whether intentional.

---

## 4. Part 2 — E-BOOK in MyBizmates for active coaching students

### 4.1 Where it goes

`/MyBizmates/student/coaching/portal` — the coaching portal. Already protected by
`middleware/coachingPageAccessCheck.js`, and both `index.vue` and `index_sp.vue` render the same
`CoachingPortal.vue`, so one component covers PC and SP.

### 4.2 Backend — MBTI_backend

**Schema** — `src/graphql/Types/Pages/Student/coaching_page.graphql`:

```graphql
"コーチングE-BOOK"
type CoachingEbook {
    "表示タイトル"
    title: String!
    "ダウンロードURL"
    url: String!
    "補足説明"
    description: String
}
```

and inside `type CoachingPageInfo`:

```graphql
    "コーチング利用中の受講生に表示するE-BOOK（対象外の場合は空配列）"
    coaching_ebooks: [CoachingEbook!]!
```

**Config** — `src/config/bco.php`, replacing the single `ebook_url` from §3.2 with a list so a second
document can be added without a code change:

```php
'ebooks' => [
    [
        'title'       => 'コーチングガイド＆ワークブック',
        'url'         => env('COACHING_EBOOK_URL', 'https://www.bizmates.jp/assets/coaching/ebook.pdf'),
        'description' => 'コーチング開始前にご確認ください。',
    ],
],
```

`BCOService` then uses `config('bco.ebooks.0.url')` or iterates the list in the templates.

**Service** — new `src/app/Services/Coaching/CoachingEbookService.php`:

```php
public function getEbooksForStudent(int $studentId): array
{
    if (TrnStudentProduct::hasCurrentCoaching($studentId) === false) {
        return [];
    }

    return array_map(
        fn (array $ebook) => new CoachingEbookData($ebook['title'], $ebook['url'], $ebook['description'] ?? null),
        config('bco.ebooks', [])
    );
}
```

`TrnStudentProduct::hasCurrentCoaching()` is the canonical check already used by
`Libs_Paypal_Coaching::hasCurrentCoaching()` and the `has_coaching` query. It requires an active
`trn_student_product` joined to a paid, active `trn_charge` whose `start_date`/`end_date` bracket
today. No new query logic needed.

**DTO** — `src/app/GraphQL/Data/Pages/Student/CoachingEbookData.php` with public `title`, `url`,
`description`.

**Resolver** — `src/app/GraphQL/Queries/Pages/Student/CoachingPage.php::getCoachingPageInfo()`:

```php
$result->coaching_ebooks = $this->coachingEbookService->getEbooksForStudent($student->student_id);
```

Inject `CoachingEbookService` via the constructor. The resolver already returns a safe response on
failure, so an empty list is the natural degraded state.

### 4.3 Frontend — MBTI_frontend

1. `src/services/coaching/subscription/coachingPageInfoWebAPI.js` —
   add `coaching_ebooks { title url description }` to the `coaching_page_info` selection inside
   `fetchCoachingPortalPageInfo()`.
2. `src/store/pages/student/coaching/coachingPortalPageInfo.js` —
   add a `getCoachingEbooks` getter reading `state.coaching_page_info_portal.coaching_ebooks`.
3. New `src/components/pages/student/coaching/portal/CoachingPortalEbook.vue` —
   card matching the existing portal panels (`#ebeef1` page background, white card, 24px gap in
   `left_panel`). Renders nothing when the list is empty. Link opens in a new tab with
   `rel="noopener"`, includes accessible link text plus a "PDF / 13.8MB" hint so the file size is not
   a surprise on mobile.
4. `CoachingPortal.vue` — insert `<CoachingPortalEbook :is-loading="isLoading" />` in `left_panel`.
   Placement: after `CoachingPortalNextSession`, before `CoachingPortalContractInfoPlanChange` — new
   students look at the portal for their first session, so the E-BOOK should sit near the top.
   Confirm with the Coaching team.
5. Skeleton loader following `skeleton/CoachingPortalNextSessionSkeleton.vue` if the card is shown
   during load.

### 4.4 Why not a dedicated query

`coaching_ebooks` on `CoachingPageInfo` costs one schema field, one service, one resolver line, and
one line in an existing frontend query. A standalone `coaching_ebook_info` query would add a graphql
file, a resolver class, a frontend service method, a store module, and its own tests — for a static
config-driven list. Revisit if the E-BOOK later needs to appear outside the coaching portal (e.g. the
dashboard), since `coaching_page_info` is not fetched there.

---

## 5. Part 3 — Existing students who won't get a payment email (optional)

Students already subscribed will see the portal card immediately after release, but receive no email.
If the Coaching team wants a one-time announcement:

- New artisan command in MBTI_backend, e.g. `php artisan coaching:notify-ebook --dry-run`
- Recipients: students where `TrnStudentProduct::hasCurrentCoaching()` is true
- New template `bco.S_ebook_announcement_S`
- `--dry-run` prints the recipient count and a sample render without sending

Needs marketing sign-off before building. Not included in the estimate below.

---

## 6. Tasks

| # | Task | Repo | Est. |
|---|---|---|---|
| 0 | Confirm whether the legacy bizmates.jp coaching payment path is still reachable | bizmates.jp | 0.25d |
| 1 | Delete `ebook.pdfZone.Identifier`; verify the PDF resolves at the public URL in dev/staging | bizmates.jp | 0.25d |
| 2 | Add `bco.ebooks` config + env sample entries | MBTI_backend | 0.25d |
| 3 | Pass `ebook_url` from `BCOService` + edit 3 blade templates (2 HTML, 1 text) | MBTI_backend | 0.5d |
| 4 | Fix coaching plan id passed to `sendPaymentNotification()` (card + PayPal) | MBTI_backend | 0.5d |
| 5 | Add `Log::warning` when the coaching email is skipped because `$bcoParams` is unset | MBTI_backend | 0.25d |
| 6 | Mirror the email change in the 5 bizmates.jp twig templates — **only if task 0 says it's live** | bizmates.jp | 0.5d |
| 7 | `CoachingEbookService` + `CoachingEbookData` + schema field + resolver wiring | MBTI_backend | 1d |
| 8 | Backend tests: extend `CoachingPageTest`, unit-test the service (active / expired / never-subscribed / rest period) | MBTI_backend | 0.5d |
| 9 | `CoachingPortalEbook.vue` + query field + store getter + portal wiring | MBTI_frontend | 1d |
| 10 | QA across PC/SP, card and PayPal purchase, active and non-active coaching students | all | 1d |
| | **Total (excluding Part 3)** | | **5.5–6d** |

Task 6 drops out if the legacy path is dead, bringing it to ~5–5.5d.

---

## 7. Open questions for the Coaching team

1. **One document or two?** The ticket says ガイド（テキスト）**＆** ワークブック but only a single
   `ebook.pdf` was provided. Is it one combined file, or is a second PDF coming? The config is a list
   either way, so a second file is a config change, not a code change.
2. **Access control.** A public URL means anyone with the link can download it, and it is
   search-engine indexable unless excluded in `robots.txt`. Acceptable (matches the beginner-package
   Rulebook), or should it be behind a signed S3/CloudFront URL? Signed URLs add ~1–1.5d and make the
   link expire, which is awkward in an email students may revisit months later.
3. **Which coaching students count?** Proposal uses "any active paid coaching contract covering
   today", which includes beginner-package and solo-plan students, and students in a rest period
   whose contract still covers today. Should rest-period students see it?
4. **Portal placement.** Top of the left panel, above contract info — confirm.
5. **Existing-student email.** Do you want the one-time blast in §5?
6. **Language.** Japanese only, or will EN/ZH versions be needed? Affects whether the config becomes
   country-keyed (the email layer already supports `jp` / `tw` template variants).
7. **Updates.** How often will the E-BOOK be revised? If frequently, overwriting the same filename
   keeps old email links working but risks CDN cache staleness; versioned filenames avoid staleness
   but break old links.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Coaching email silently not sent (`$bcoParams` unset) means the E-BOOK never reaches a new student | Task 5 adds a warning log so it becomes observable; portal card in Part 2 acts as the fallback channel |
| 13.8 MB download on mobile data | Show file type and size next to the link |
| CDN caching an outdated PDF after replacement | Coordinate a cache invalidation with Infra on every replacement |
| Public URL leaks to non-subscribers | Accepted per existing precedent; escalate to question 2 if the team objects |
| Editing `S_payment_notification_*` templates without noticing the campaign variant is plain text | Task 3 explicitly calls out the format per template |
