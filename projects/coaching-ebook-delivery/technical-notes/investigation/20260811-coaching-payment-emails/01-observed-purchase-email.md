# Observed Purchase Email — Student Portal BCO Purchase (2026-08-11)

Companion context for `MBTI_backend/.kiro/specs/coaching-ebook-delivery/investigation.md`.

**Source:** email received by a developer after purchasing a coaching (BCO) product through the
student portal, paid by credit card. Captured verbatim below.

---

## 1. Captured email

**Subject:** `【Bizmates】契約開始のご案内`
**Format:** plain text

```text
test様

いつもお世話になっております。
Bizmates運営事務局です。

この度は、ご契約をいただきありがとうございました。
下記内容で、受付が完了致しました。

＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝
契約開始日：2026年08月11日
ご契約内容：毎日1レッスンプラン

ご契約期間：2026年08月11日 〜 2026年09月10日
お支払方法：クレジットカード

取引ID：1KX275937W797821M
＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝

引き続きレッスンのご受講をお楽しみください。

※Online Lesson、Bizmates Program Video Lesson、Bizmates Coachingについては、
休会または利用停止申請をいただくまで 自動更新となります。

＝＝＝＝＝＝＝＝＝＝＝＝＝
【Bizmates公式アプリのご案内】
＝＝＝＝＝＝＝＝＝＝＝＝＝
Bizmatesでは、レッスンと連携して学習できる
Bizmates Appをご利用いただけます。

オンライン英会話レッスンで保存した
My単語帳とアプリを連携することで、復習・予習もスムーズに行えます。

さらに、
プレミアムプラン（有料版）を7日間無料でお試しいただけます。

スキマ時間のインプットと、レッスンでの実践を組み合わせて
ビジネス英語学習をより効率的に進めてください。

▼アプリダウンロードはこちら

App Storeからダウンロード
https://apps.apple.com/jp/app/bizmates-app/id6738068535

Google Playで手に入れよう
https://play.google.com/store/apps/details?id=jp.bizmates.app

[common/footer_b2c — inquiry links + company footer]
```

---

## 2. Which template produced it

`MBTI_backend/src/resources/views/emails/bizmates/payment/S_buy_new_plan_S/`

- `subject.blade.php` → `【Bizmates】契約開始のご案内`
- `body.blade.php` and `jp/body.blade.php` are **byte-identical duplicates**; `tw/` is a separate variant
- Resolved by `EmailTemplateResolver::resolve('payment', 'S_buy_new_plan_S', $student->country_id)`.
  For `country_id = 86` this returns `payment.S_buy_new_plan_S.jp`
- Sent as text via `MailUtil::sendToStudent()` → `sendTextMail()`
- Footer: `@include('emails.bizmates.common.footer_b2c')`

The `【Bizmates公式アプリのご案内】` block exists **only** in the MBTI_backend blade. The legacy
bizmates.jp equivalent (`fuel/app/emails/payment/credit_card/buy_new_plan.twig`) does not have it —
the two templates have drifted.

---

## 3. Which code path produced it

Two credit-card paths in `MBTI_backend/src/app/GraphQL/Mutations/Student/Payment/CreditCard.php`
send `S_buy_new_plan_S`:

| Path | Method | Line | `start_date` value passed |
|---|---|---|---|
| Plan purchase | `paymentCaptureOrder()` → `capture_order()` | ~506 | `(new Carbon(...))->format("Y年m月d日")` |
| Coaching purchase | `paymentCaptureOrderCoaching()` → `capture_order_coaching()` | ~2805 | raw `$item['start_date']` (`Y-m-d`) |

The captured email shows `2026年08月11日`, so it was rendered by the **plan purchase path**, not the
coaching path. The coaching path would have produced `契約開始日：2026-08-11`.

The `ご契約内容` value (`毎日1レッスンプラン`) is also consistent with the plan path, which resolves the
name via `MstPlan::getPlanNameByCountry($plan_id, $student->country_id)` for the plan actually
submitted by the frontend.

> **Unresolved:** the purchase was described as a BCO/coaching purchase but the email came from the
> plan path. Either the portal submitted an Online Lesson plan id, or a coaching bundle purchase
> routes its main product through the plan mutation. Needs confirmation from
> `[PaymentCreditPlan]` / `[PaymentCreditCoaching]` log lines for that student and the
> `trn_charge` rows created.

---

## 4. Full map of coaching purchase emails

### MBTI_backend (current stack)

`BCOService::sendPaymentNotification($plan_id)` — `src/app/Services/BCO/BCOService.php:68`

| Template | When | Format |
|---|---|---|
| `bco.S_payment_notification_beginner_package_S` | plan is `ONLINE_LESSON_25_FVP_BEGINNER_COACHING_PLAN` / `..._30_PLAN` | HTML |
| `bco.S_payment_notification_campaign_S` | inside `bco.campaign_start/end_datetime` | **plain text** |
| `bco.S_payment_notification_S` | default | HTML |
| `bco.S_payment_notification_A` | always, to coaching admin mailbox + CC | text |

Callers:

- `Paypal.php:1945` — coaching PayPal capture
- `CreditCard.php:2793` — coaching card capture, **gated on `isset($bcoParams)`**

### bizmates.jp (legacy stack)

`BizmatesCoachingService::sendPaymentNotification()` —
`fuel/app/classes/libs/service/bizmatescoachingservice.php:32`

Templates in `fuel/app/emails/coaching/`: `payment_notification.twig` (default),
`_campaign`, `_end_of_year_1`, `_end_of_year_2`, `_end_of_year_3`, plus `payment_notification_A.twig`
for admin. Callers: `controller/coaching/payment.php:218` (PayPal),
`controller/api/payments/creditcard/coaching.php:453` (card).

### Card vs PayPal

Template selection never depends on payment method. The difference is in **how many** emails are sent:

| Payment method | Coaching welcome email | `契約開始のご案内` (`S_buy_new_plan_S`) |
|---|---|---|
| Credit card | yes | yes |
| PayPal | yes | **no** |

`Paypal.php` contains no `S_buy_new_plan_S` / `buy_new_plan` send at all, and bizmates.jp only has a
`payment/credit_card/` folder for that template. `お支払方法：クレジットカード` is hardcoded in the body,
consistent with it being card-only.

Note the `取引ID` is a PayPal capture id (`1KX275937W797821M`) even on the card path, because card
capture goes through PayPal's card API.

---

## 5. Findings worth acting on

1. **Date format inconsistency (visible defect).** The coaching card path passes raw `Y-m-d` into a
   template whose other caller passes `Y年m月d日`. A real coaching card purchase renders
   `契約開始日：2026-08-11`. `CreditCard.php:2489` vs `:511`.

2. **`$planId` and `$mail_params` are overwritten per cart item.** In `capture_order_coaching()` the
   loop reassigns both on every product (`CreditCard.php:2467`, `:2488`). After the loop, `$planId`
   holds the **last** product's plan id, and that value feeds both
   `sendPaymentNotification($planId)` (which drives the beginner-package template branch and the
   `plan_name` mail param) and the `S_buy_new_plan_S` `plan_name`. For bundle purchases
   (coaching product + Online Lesson FVP) this is order-dependent and can select the wrong template.

3. **Coaching welcome email is gated on `isset($bcoParams)`.** `$bcoParams` is only set when a cart
   item passes `CoachingService::isCoachingProduct()` (`CreditCard.php:2515`). If no cart item
   matches, the student receives the generic contract email and **no coaching onboarding email** —
   and no error is logged. Consistent with only one email being observed here.

4. **`body.blade.php` and `jp/body.blade.php` are duplicates.** Any edit must be applied twice or the
   two country paths silently diverge.

5. **Campaign coaching template is plain text while the others are HTML.**
   `bco.S_payment_notification_campaign_S` goes out via `sendToStudent` (text) while the default and
   beginner-package variants use `sendHtmlToStudent`.

---

## 6. Implications for the E-BOOK delivery ticket

- E-BOOK links belong in the `payment_notification*` / `S_payment_notification_*` templates, not in
  `S_buy_new_plan_S`. That one is a generic contract receipt shared with plain plan purchases.
- No card-specific or PayPal-specific variant is needed — payment method does not branch template
  selection.
- `bco.S_payment_notification_campaign_S` is plain text, so it needs a bare URL, not an `<a href>`.
- Finding 3 is a delivery risk for the ticket: if `$bcoParams` is not set, no coaching email is sent
  at all, so the E-BOOK link never reaches the student. Worth confirming before relying on the
  payment email as the only delivery channel for new students.

---

## 7. Open questions

1. Which mutation did this purchase actually hit — `paymentCaptureOrder` or
   `paymentCaptureOrderCoaching`? Confirm via logs and `trn_charge`.
2. Did `bco.S_payment_notification_S` also arrive for this purchase? If not, was `$bcoParams` unset?
3. Is the missing `契約開始のご案内` on the PayPal path intentional, or an unnoticed gap?
4. Is the raw `Y-m-d` date on the coaching card path a known issue or unreported?
