# Requirements Document

**ASCA Spec 02c — AllocationDetail CSV**

> **Staging note:** Dev-context draft pending PM sign-off (Kuroda-san, G1). On approval it is promoted to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02c-allocation-detail-csv/requirements.md` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do not begin design/tasks from this draft.

## Introduction

This spec adds the **AllocationDetail CSV** — the per-product breakdown Accounting asked for (O-6), showing **how** each CAP allocation was calculated (reference price, ratio, original N, allocated P, run status), not just the resulting amounts the existing CSVs already show. It is the **third of four Spec 02 sub-specs** (02a Core Injection → 02b Refund → **02c CSV** → 02d DataCorrection).

Per the O-6 resolution: the existing CSVs (DailyRateCalculation, CalculationSummary) already show the allocated amounts under Option 1 (Overwrite) — Accounting confirmed that is acceptable. This sub-spec adds a dedicated breakdown file so the "why" behind those numbers is auditable. The file is delivered **inside the existing zip and the existing 速報版 / 確定版 email** — no separate email, no new mail type, no `mst_mail_template` row.

Since the ASCM-prep refactor (DEVOPS-6415), zip creation and email dispatch are handled by the extracted `ArchiverService` / `MailerService`. This CSV rides that same path: each generator returns `[$fileName, $displayName]`, the caller appends it to `$fileNameList`, and the existing archive/mail services zip and send it.

### Design decisions (confirmed)

- **Delivery (O-6, resolved 2026-08-17):** added to the **existing zip** and the **existing 速報版 / 確定版 email** — no separate/third email, no separate command, no new `mst_mail_template` row. A Metabase saved query on `log_alloc_prorations` is a separate post-deployment deliverable (not code in this sub-spec).
- **Generation location:** a `RevenueAllocation`-namespace service (`RevenueAllocationCsvService::createAllocationDetailFile($targetYm, $preFlg)`), NOT `CommonUtil` (that file is already oversized).
- **Config-driven:** a new `allocationDetailFile` entry in `config/const.php` (`fileName` / `name` / `headerItem`), read via the existing `CommonUtil::getCsvFileInfo()` and written via the existing `CommonUtil::createCsvFile()` (fputcsv). No new CSV-writing mechanism.
- **Source of truth:** `log_alloc_prorations` (joined for charge/plan context), or `v_alloc_prorations_active` for the active Final run.
- **File conventions:** filename `{YYYYMM}_10_AllocationDetail({execDate}).csv` — `{YYYYMM}` = target month (previous month from exeDate), `{execDate}` = today (Ymd), `10` = sequence number. **UTF-8 with BOM** (`EF BB BF`) for Excel. Stored in `storage_path('app/public/')` (from `config('const.filedirectory')`).
- **Guarded emission:** the file is added only when an allocation run completed for the month (`LogAllocCalculationRun::hasCompletedRun($targetYm)`); a failed/absent allocation simply omits the file — the rest of the zip and the email are unaffected.
- **CAP-only.** ZipanUtil's `addZipanData()` appends Zipan rows to the *existing* Bizmates CSVs, but allocation adds nothing to the Zipan path. CIP is not in the engine (REF-CIP-05); rows are whatever the CAP run produced.

### Dependencies

- **02a (CAP Core Injection) merged** — the CSV reads the `log_alloc_*` rows a completed allocation run produced; without injection there is nothing to report.
- **Spec 01 Foundation merged** — `log_alloc_prorations` / `log_alloc_calculation_runs` (and the `hasCompletedRun` check), plus `LogAllocProration` reads.
- **DEVOPS-6415 present in the ASCA base** — the CSV is hooked into `$fileNameList` on the path now handled by the extracted `ArchiverService` / `MailerService`. Design/tasks need those refactored files checked out (pull from `main` once released). Requirements (this doc) do not.

### Out of scope (explicit)

- **The allocation itself** (injection, detection, overwrite) → 02a; **refund rows' allocation** → 02b (this CSV *displays* whatever rows exist, including refunds, but does not compute them).
- **The Metabase saved query** — a post-deployment analytics deliverable, not code here.
- **Changing the existing CSVs** (DailyRateCalculation, CalculationSummary) — they already show allocated amounts under Option 1; no format change.
- **Any new email / mail template / command.**

**Reference:** technical design §10 (CSV report, O-6); CSV-generation steering (file conventions, zip→email flow); `asc-alloc-db-schema.md` (`log_alloc_prorations`, `v_alloc_prorations_active`).

## Glossary

- **AllocationDetail CSV** — the new per-product breakdown file (`{YYYYMM}_10_AllocationDetail({execDate}).csv`).
- **`$fileNameList`** — the accumulator (`[$fileName => $displayName]`) the batch passes to the archiver (zip) and mailer (email attachment + template file list).
- **速報版 / 確定版** — the preliminary (Pre) and final email variants; the CSV joins whichever one runs.
- **L / ratio / N / P** — reference price / allocation ratio / original amount / allocated amount, the columns that make the calculation reproducible.

---

## Requirements

### Requirement 1: Config entry for the AllocationDetail CSV

**User Story:** As the CSV generator, I need the file's name and headers defined in config so that generation follows the existing config-driven pattern.

#### Acceptance Criteria

1. THE system SHALL add an `allocationDetailFile` entry to `config/const.php` with `fileName`, `name` (display name), and `headerItem` (ordered header list).
2. THE `fileName` SHALL follow the convention `{YYYYMM}_10_AllocationDetail({execDate}).csv`, where `{YYYYMM}` is the target month and `{execDate}` is today (Ymd).
3. THE `headerItem` SHALL define, in order, these 15 columns: コンテンツ (service), 対象年月 (target_ym), プロジェクト (bundle_type label — `cap`/`cip`), 生徒ID (student_id), 部署ID (department_id), 発注番号 (order_no), プランID (plan_id), プロダクトID (product_id), プロダクトタイプ (product_type), 契約種類 (contract_type), 参照価格 (reference_price / L), 配分比率 (ratio), 元金額(N) (original_amount), 配分後金額(P) (allocated_amount), ステータス (run status).
4. THE config entry SHALL be readable via the existing `CommonUtil::getCsvFileInfo('allocationDetailFile')`.

### Requirement 2: Generate the CSV from allocation data

**User Story:** As Accounting, I need a per-product breakdown row for each allocated charge so that I can see the reference price, ratio, and original vs allocated amounts behind each figure.

#### Acceptance Criteria

1. THE system SHALL provide `RevenueAllocationCsvService::createAllocationDetailFile(string $targetYm, bool $preFlg = false): array` returning `[$fileName, $displayName]`, in the `App\Libs\RevenueAllocation` namespace (NOT `CommonUtil`).
2. THE service SHALL read the month's allocation rows from `log_alloc_prorations` (joined for charge/plan context), or from `v_alloc_prorations_active` for the active Final run.
3. THE system SHALL emit one row per product per group (i.e. per `log_alloc_prorations` row), mapping each to the 15 configured columns.
4. THE プロジェクト column SHALL render the `bundle_type` label (`cap` / `cip`), not the raw TINYINT.
5. WHERE `order_no` or `department_id` is present, THE system SHALL populate それ; contract types include B2C / B2B / B2B2C / Partner and SHALL be rendered from `contract_type`.
6. THE system SHALL write the file via the existing `CommonUtil::createCsvFile()` (fputcsv) to `storage_path('app/public/')` (`config('const.filedirectory')`), **UTF-8 with a BOM** (`EF BB BF`) for Excel compatibility.
7. THE system SHALL NOT introduce a new CSV-writing mechanism or a new storage location.

### Requirement 3: Attach to the existing zip and email (guarded)

**User Story:** As Accounting, I need the breakdown in the same monthly zip/email I already receive so that no new delivery channel is introduced.

#### Acceptance Criteria

1. IN `createSendMailAttacheFile()` of both `SendJournalsDataLogic` (Final) and `DailyRateCalculationPreLogic` (Pre), after the existing CSVs, THE system SHALL add the AllocationDetail file to `$fileNameList` as `$fileNameList[$fileName] = $displayName`.
2. THE addition SHALL be guarded by a completed-run check (`LogAllocCalculationRun::hasCompletedRun($targetYm)`): only when an allocation run completed for the month is the file generated and added.
3. IF no completed allocation run exists for the month (allocation absent or failed), THEN THE system SHALL omit the file, AND the rest of the zip and the email SHALL be produced unchanged.
4. THE system SHALL pass `$preFlg` so the Pre logic generates the `_pre`-context file and the Final logic the final-context file.
5. THE file SHALL be zipped and emailed by the existing `ArchiverService` / `MailerService` path with no change to those services beyond receiving one more entry in `$fileNameList`.
6. THE system SHALL NOT add a new email, a new mail type, or a new `mst_mail_template` row; the file rides the existing 速報版 / 確定版 email.
7. THE `$fileNameList` display name SHALL appear in the email template's file list (via `$contents->fileList`) exactly like the existing CSVs.

### Requirement 4: Reproducibility and consistency with existing CSVs

**User Story:** As an auditor, I need the breakdown to reconcile with the existing CSVs so that the "why" matches the "what".

#### Acceptance Criteria

1. THE 配分後金額(P) values in this CSV SHALL equal the allocated amounts the existing DailyRateCalculation / CalculationSummary CSVs show for the same charges (both read post-overwrite data).
2. THE 参照価格 (L), 配分比率 (ratio), and 元金額(N) columns SHALL be sufficient to recompute 配分後金額(P) via the documented floor formula (the ASCA-8 breakdown recomputes an identical floored P — no ¥1 divergence).
3. THE system SHALL NOT modify the existing CSVs' format or content.
4. THE ステータス column SHALL reflect the allocation run's status for the month.

### Requirement 5: Tenant and scope safety

**User Story:** As accounting, I need the new CSV to affect only the CAP/Bizmates flow so that Zipan and non-allocated output are untouched.

#### Acceptance Criteria

1. THE AllocationDetail CSV SHALL contain only rows produced by the allocation engine (CAP; `log_alloc_prorations`), and SHALL NOT add rows to or alter any existing CSV.
2. THE system SHALL NOT change ZipanUtil's `addZipanData()` behaviour; allocation contributes nothing to the Zipan path.
3. WHERE the month produced allocation rows for multiple `bundle_type`s, THE プロジェクト column SHALL distinguish them; in Foundation/CAP scope this is `cap` only.

## Confirmed Decisions (settled — for the approver's reference)

| # | Decision | Source |
|---|---|---|
| O-6 | Existing CSVs already show allocated amounts (OK); add a breakdown CSV | Accounting via Kuroda-san, 2026-08-17 |
| Delivery | Existing zip + existing 速報版/確定版 email; no new email/template | O-6 resolution |
| Generation | `RevenueAllocationCsvService` (RevenueAllocation namespace), not CommonUtil | Technical design §10 |
| Source | `log_alloc_prorations` / `v_alloc_prorations_active` | §10; schema ref |
| Format | `{YYYYMM}_10_AllocationDetail({execDate}).csv`, UTF-8 + BOM, `app/public/` | CSV steering |
| Guard | Emit only if `hasCompletedRun($targetYm)`; else omit, zip/email unaffected | §10 |
| Metabase | Separate post-deployment query — not code here | O-6 resolution |

## Open Items (for the approver)

| # | Item | Status / ask |
|---|---|---|
| O-C1 | **Column set final confirmation** — the 15 columns above match the technical design; confirm Accounting needs no additional column (e.g. paid_at, tax_free) in the breakdown. | Confirm the header list is complete for Accounting's reconciliation. |
| O-C2 | **Sequence number `10`** in the filename — confirm `10` does not collide with an existing CSV sequence in the monthly set. | Verify against the current file list at design time (non-blocking for sign-off). |
| O-C3 | **Pre vs Final content** — whether the Pre (速報) breakdown should read `_pre` proration rows or the same source; assumes `$preFlg` selects the preliminary context. | Confirm the Pre file should reflect preliminary allocation, consistent with the other 速報版 CSVs. |
