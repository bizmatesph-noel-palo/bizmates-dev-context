# 13 — Tenant Code Duplication

> **TL;DR:** Bizmates and Zipan share the same accounting logic but had separate code copies. Bugs fixed in one tenant were missed in the other. Fix: tenant differences should be configuration (product IDs, DB connection), not duplicated classes.

---

## Problem Pattern

Multi-tenant system implements tenant-specific logic by duplicating classes — one copy per tenant. Fixes applied to one tenant are missed on the other, creating silent divergence.

---

## How We Encountered It

The ASC system supports Bizmates and Zipan. When bugs were discovered in the monthly CTE, fixes were applied to Bizmates first (more users = bugs found first). The Zipan path required the same fix but was easy to overlook.

Every fix during ASC needed verification against both tenants.

**Status:** Acknowledged as tech debt. Target: `TenantConfig` interface with `BizmatesTenantConfig` / `ZipanTenantConfig` implementations. No active refactoring planned — mitigated by review process (PRs touching Bizmates logic are checked against Zipan by convention).

---

## Industry Standard / Best Practice

### How Shopify Handles Multi-Tenancy

Single Rails monolith for millions of stores. Store-specific behavior = configuration row in a `shops` table. A tax calculation fix deploys once and applies to all stores simultaneously. Tenant isolation is at the data layer (row-level), not the code layer (file-level).

### How Laravel Handles Multi-Tenancy (Stancl/Tenancy)

Popular multi-tenant Laravel packages use a `Tenant` model with a config array. Tenant-specific values (DB connection, product IDs, feature flags) live in that config. The application code reads `tenant()->config('key')` — one code path, N tenants.

### How Stripe Handles Country-Specific Logic

Stripe supports 40+ countries with different tax rules, payment methods, and regulations. Country-specific behavior is driven by a rules engine with per-country config, not per-country code branches. Adding a country = adding rules data, not duplicating classes.

### The Litmus Test

> If you fix a bug in one tenant's code path, do you need to remember to fix it in another? If yes, your multi-tenancy design is wrong.

---

## Prevention Checklist

- [ ] Tenant-specific *data* separated from tenant-agnostic *logic*
- [ ] One implementation of each business rule — tenants differ only in configuration
- [ ] CI runs tests against *all* tenant configurations
- [ ] New tenant onboarding = adding a config block, not duplicating classes
- [ ] Code review asks: "Does this change apply to other tenants?" (ideally unnecessary)
