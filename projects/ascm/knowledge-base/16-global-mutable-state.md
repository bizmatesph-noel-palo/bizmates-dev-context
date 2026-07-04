# 16 — Global Mutable State

> **TL;DR:** The "current processing month" was stored as a mutable class property. When processing multiple months in sequence, the date from iteration N leaked into iteration N+1. Fix: immutable BatchContext value object passed as a parameter.

---

## Problem Pattern

Batch system uses globally-accessible mutable variables for execution context. Sequential processing leaks state between iterations.

---

## How We Encountered It

The ASC system stored target month as mutable properties on service classes, set once at command start. When running multiple months (catch-up), or when methods set the date differently, values leaked.

**Status:** Proposed fix (BatchContext value object), not yet implemented. Risk contained — current operations process one month at a time.

---

## Proposed Fix

```php
final class BatchContext {
    public function __construct(
        public readonly Carbon $targetMonth,
        public readonly string $serviceId,
        public readonly ExecutionMode $mode,
    ) {}
}
```

---

## Industry Standard / Best Practice

### How Laravel Commands Should Handle Per-Iteration State

Laravel artisan commands that process multiple items in a loop should construct fresh context per iteration. The pattern is explicit parameter passing, not shared properties:

```php
foreach ($months as $month) {
    $context = new BatchContext($month, $serviceId, $mode);
    $this->processMonth($context);  // no shared state between iterations
}
```

### How Symfony Messenger Isolates Message Handling

Each message handler receives an immutable `Envelope` containing all context. No shared state between messages — even within the same worker process. This is the "message = context" pattern.

### How Functional Programming Prevents This

In languages like Elixir/Erlang, each process has its own state — mutation requires explicit message passing. The principle is transferable to PHP: make execution context a value object that's constructed once and passed through, never mutated after creation.

### How Spring Batch Scopes Step Execution

Spring Batch's `StepExecution` is an immutable snapshot of the current step's context (dates, parameters, counters). It's passed to every component in the step — never a shared mutable singleton.

### The Rule

> If two iterations of a loop can observe each other's state, the design is fragile. Each iteration should receive its own immutable context.

---

## Prevention Checklist

- [ ] Execution context = immutable value object, never mutable class properties
- [ ] Service methods declare context needs in parameter lists — no ambient state
- [ ] Context constructed once at entry point, passed through the call chain
- [ ] No `setX()` for execution context — create a new immutable instance if context changes
- [ ] Tests construct their own context per test case — no shared mutable state
