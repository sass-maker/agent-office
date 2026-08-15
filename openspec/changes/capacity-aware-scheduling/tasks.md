## 1. Capacity

- [x] 1.1 Defer on unavailable runtime, busy employee, concurrency limit, unreviewed plan, and missing connection.
- [x] 1.2 Record the reason and keep the occurrence eligible for a later pass.
- [x] 1.3 Pass runtime availability from the app, which is the only fact the organization cannot see.

## 2. Recurring responsibilities

- [x] 2.1 Start a scheduled responsibility through its own occurrence and canonical commitment.
- [x] 2.2 Skip with a stated reason when it cannot begin.

## 3. Verification

- [x] 3.1 Tests for each capacity condition.
- [x] 3.2 Test that a deferred occurrence starts once the condition clears.
- [x] 3.3 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict`.
