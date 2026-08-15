## 1. Retrieval

- [x] 1.1 Search memory, skills, contracts, commitments, artifacts, decisions, and organization context.
- [x] 1.2 Filter by the employee's contract, grants, and current commitment scope.
- [x] 1.3 Return provenance with every result and an empty result when nothing matches.

## 2. History

- [x] 2.1 Return retained events for an entity in sequence order with actor and type.
- [x] 2.2 Return an empty history rather than a reconstruction when nothing was recorded.

## 3. Flow evidence

- [x] 3.1 Derive waiting, working, blocked, review, delivery, and owner-decision timing from retained records.
- [x] 3.2 State the basis of each figure and report unknown where nothing supports it.
- [x] 3.3 Do not rank employees or treat volume as value.

## 4. Verification

- [x] 4.1 Tests that another employee's memory and out-of-scope commitments are excluded.
- [x] 4.2 Tests that provenance is present and that no match yields an empty result.
- [x] 4.3 Tests for history ordering and the empty case.
- [x] 4.4 Tests that an absent phase is unknown rather than zero.
- [x] 4.5 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
