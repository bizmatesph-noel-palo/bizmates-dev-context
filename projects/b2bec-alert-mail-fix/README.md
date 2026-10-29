# b2bec-alert-mail-fix

Project working directory for the B2BEC alert-mail batch performance fix.

## Problem Summary

The `b2bec_send_alert_mail` batch (scheduled 08:55 JST) degraded from ~2.5h to ~13h between 2026-06-29 and 2026-07-06. Root cause: a broad `plan_charges` guard query in `runB2b2cSendAlertMailFromTarget()` that joins all `trn_corporate_alert_mail_setting` rows against all `trn_charge` rows without binding the current target's `plan_id`/`department_id`. The query executes once per scheduled setting (N times for N settings), making it O(N × full-table-scan).

## Directory Structure

```
b2bec-alert-mail-fix/
├── README.md                   ← This file
├── investigation.md            ← Full investigation report and fix plan
└── implementation-plan.md      ← Step-by-step implementation guide
```

## JIRA Context

- Original incident investigation: 260716-B2BEC
- Related tickets: B2BEC-345, B2BEC-515

## Related Files (bizmates.jp)

| File | Role |
|------|------|
| `fuel/app/tasks/b2bec_send_alert_mail.php` | Batch entry point |
| `fuel/app/classes/model/corporateAlertEmailSettingModel.php` | Model with `getPendingQue()` and `runB2b2cSendAlertMailFromTarget()` |
| `fuel/app/classes/libs/alertmail/alertmailtask.php` | `Alertmailtask` — calls `findSendTargetStudent()` |

## Fix Strategy

**Preferred**: Remove the redundant `plan_charges` guard entirely. The downstream `Alertmailtask::handle()` → `findSendTargetStudent()` already handles the case where no eligible students exist by returning early with no mail sent.

**Alternative**: If the guard is required by business rules, replace it with a target-specific query that binds `$target->plan_id` and `$target->department_id`.
