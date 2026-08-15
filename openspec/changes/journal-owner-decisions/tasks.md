## 1. Command

- [x] 1.1 Add a supervision decision payload covering approve, return, answer, accept, and revise.
- [x] 1.2 Restrict it to the owner in the command boundary.
- [x] 1.3 Reference the commitment and its assignee on the resulting event.

## 2. Reproducibility

- [x] 2.1 Derive supervision event and activity identifiers from the record they describe.
- [x] 2.2 Derive management message and revision identifiers the same way.

## 3. App

- [x] 3.1 Route the five supervision actions through the boundary.

## 4. Verification

- [x] 4.1 Test that a decision journals with actor and entities.
- [x] 4.2 Test that a runtime cannot supervise its own commitment.
- [x] 4.3 Test replay equivalence and idempotent repetition.
- [x] 4.4 Test that a rejected decision leaves no history.
- [x] 4.5 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict`.
