# Proposal: BatchContext + TenantConfig Introduction

## Status: Future (Phase 2 — after Query Builder refactor)

## Problem
- Date calculation scattered across CommonUtil::setSystemDate/getTargetYm/getTargetFromTo
- Global mutable state via static methods
- Bizmates/Zipan branching duplicated everywhere (if/else per tenant)

## Proposed Solution
- BatchContext: immutable value object holding targetYm, startDate, endDate, isPre
- TenantConfig: interface defining connection(), serviceName(), monthlyPlanIds(), tableName()
- BizmatesTenantConfig / ZipanTenantConfig: concrete implementations

## Size
~90 lines total across 4 new files. Zero impact on existing code until wired in.

## Reusability
Designed for ALL commands (monthly, daily, send journals, data correction, cleanup).
Only wired into monthly first. Other commands adopt gradually.

## Dependencies
- Query Builder refactor should be done first (so TenantConfig can be passed to the builder)
- Or can be introduced standalone as infrastructure (new files, nothing wired)
