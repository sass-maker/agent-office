## 1. Command

- [x] 1.1 Add an employment decision payload for hire, pause, resume, and retire.
- [x] 1.2 Restrict it to the owner.
- [x] 1.3 Reference the employees it concerns and return a created identifier.

## 2. Reproducibility

- [x] 2.1 Derive employment supervision and activity identifiers from the record they describe.
- [x] 2.2 Derive contract-change identifiers the same way.

## 3. App

- [x] 3.1 Route hire, pause, resume, and retire through the boundary.

## 4. Verification

- [x] 4.1 Test that a decision journals against its employee.
- [x] 4.2 Test that a runtime cannot change employment.
- [x] 4.3 Test replay equivalence and idempotent repetition.
- [x] 4.4 Test that a rejected decision leaves no history.
- [x] 4.5 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict`.
