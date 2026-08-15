## 1. Directory

- [x] 1.1 Project a permission-filtered coworker directory for a source employee and commitment.
- [x] 1.2 Exclude the requester, and exclude paused, retired, unhired, and unavailable coworkers with a safe reason.
- [x] 1.3 Report the collaboration operations each coworker supports.

## 2. Protocol

- [x] 2.1 Add consultation, delegation proposal, and handoff message as distinct operations.
- [x] 2.2 Carry source origin, target, chain, correlation and idempotency keys, deadline, and turn budget on the request.
- [x] 2.3 Share only the question and permitted references.

## 3. Containment

- [x] 3.1 Reject self-calls, cycles, and anything past one hop.
- [x] 3.2 Reject reused correlation identifiers by returning the first result.
- [x] 3.3 Reject expired deadlines and exhausted turn budgets.
- [x] 3.4 Reject requests that offer to lend the source employee's capabilities.
- [x] 3.5 Reject unavailable or busy targets with a human-readable reason.

## 4. Execution and recording

- [x] 4.1 Resolve and run the target's own binding, contract, and attribution.
- [x] 4.2 Record consultation answers as management messages attributed to the responder, plus a supervision event.
- [x] 4.3 Record delegation proposals for review without changing assignment, ownership, or accountability.

## 5. Verification

- [x] 5.1 Integration tests with two different fake drivers covering a successful consultation and a valid proposal.
- [x] 5.2 Tests for self-call, cycle/depth, permission borrowing, stale retry, and unavailable target.
- [x] 5.3 Test that shared context carries no transcript or organization-wide data.
- [x] 5.4 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
