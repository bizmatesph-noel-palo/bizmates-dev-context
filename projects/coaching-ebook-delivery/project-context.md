# coaching-ebook-delivery — Project Context

> Load this at the start of each session for this project.

---

## What This Is

The Coaching team produced a Coaching Guide (textbook) and Workbook as E-BOOKs and needs them
delivered to students:

1. **New students** — attach E-BOOK links to the automatic email sent on coaching payment
2. **Existing students** — surface the E-BOOK in MyBizmates only for students with an active
   coaching subscription

The primary spec lives in the code repo: `MBTI_backend/.kiro/specs/coaching-ebook-delivery/`.
This directory holds supporting investigation artifacts that don't belong in the code repo.

---

## Workspace Overview

| Directory | What it is |
|---|---|
| `MBTI_backend` | **Main codebase.** BCO service, coaching payment emails, GraphQL resolvers. Spec lives in `.kiro/specs/coaching-ebook-delivery/`. |
| `MBTI_frontend` | Student portal (Nuxt). Where the E-BOOK would be displayed for existing students. |
| `bizmates.jp` | Legacy monolith. Duplicate coaching payment email templates; static file hosting under `public/`. |
| `bizmates-dev-context/projects/coaching-ebook-delivery` | **This directory.** Investigation notes and observed artifacts. |

---

## Key Code Locations

| Concern | Location |
|---|---|
| Coaching payment email dispatch (current) | `MBTI_backend/src/app/Services/BCO/BCOService.php::sendPaymentNotification()` |
| Coaching email templates (current) | `MBTI_backend/src/resources/views/emails/bizmates/bco/` |
| Coaching payment email dispatch (legacy) | `bizmates.jp/fuel/app/classes/libs/service/bizmatescoachingservice.php` |
| Coaching email templates (legacy) | `bizmates.jp/fuel/app/emails/coaching/` |
| Card capture (coaching) | `MBTI_backend/src/app/GraphQL/Mutations/Student/Payment/CreditCard.php::capture_order_coaching()` |
| PayPal capture (coaching) | `MBTI_backend/src/app/GraphQL/Mutations/Student/Payment/Paypal.php` |
| Country-aware template resolution | `MBTI_backend/src/app/Utils/EmailTemplateResolver.php` |

---

## Artifacts

| Date | Artifact |
|---|---|
| 2026-08-11 | `technical-notes/investigation/20260811-coaching-payment-emails/01-observed-purchase-email.md` — captured the email received after a portal purchase, identified its template and code path, mapped the full set of coaching purchase emails, and recorded 5 defects/risks. |
| 2026-08-11 | `technical-notes/jira/proposals/01-ebook-delivery-implementation-plan.md` — implementation plan for Redmine #12006 (email link + portal display), 11 tasks, ~5.5–6d. |
| 2026-08-19 | `technical-notes/investigation/20260819-portal-ebook-tabs/01-investigation-ticket.md` — investigation for portal E-BOOK tab UI: two tabs (テキストブック/ワークブック) displayed in an iframe modal using meclib viewer. Supersedes §4 of the original implementation plan. |

## E-BOOK Assets

### PDF (original)
`bizmates.jp/public/assets/coaching/ebook.pdf` (13.8 MB) →
`https://www.bizmates.jp/assets/coaching/ebook.pdf`

### meclib E-BOOK viewer (new — portal tabs)
| Name | URL |
|---|---|
| テキストブック | `https://bizmatescoaching.meclib.jp/library/books/bizmatescoachingworkbook/book/index.html` |
| ワークブック | `https://bizmatescoaching.meclib.jp/library/books/bizmatescoachingworkbook/book/index.html` |

> ⚠️ Both URLs are currently identical — pending confirmation of the correct textbook URL.
