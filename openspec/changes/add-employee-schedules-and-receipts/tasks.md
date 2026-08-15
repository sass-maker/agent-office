## 1. Schedule policy

- [x] 1.1 Add a schedule policy with recurrence, window, expected duration, flexibility, timezone, and author.
- [x] 1.2 Point policies at an existing commitment or recurring responsibility rather than defining new work.
- [x] 1.3 Allow pausing a policy without deleting it or its history.

## 2. Occurrences

- [x] 2.1 Generate occurrences with identifiers derived from policy and instant so generation is idempotent.
- [x] 2.2 Bound generation by an explicit horizon.
- [x] 2.3 Keep scheduled window separate from actual start, end, and duration.
- [x] 2.4 Support delivered, quiet, blocked, failed, skipped, cancelled, and missed states.

## 3. Receipts

- [x] 3.1 Add a receipt recording schedule reason, owner, actual run, runtime, evidence, result, and usage.
- [x] 3.2 Record usage as observed, unknown, or not applicable — never a fabricated zero.
- [x] 3.3 Keep a quiet successful run distinct from failure and from a run that never started.

## 4. Owner control and reconciliation

- [x] 4.1 Skip, move, and cancel future occurrences without touching completed ones.
- [x] 4.2 Leave completed occurrences and receipts unchanged when a policy is edited.
- [x] 4.3 Reconcile passed windows to missed deterministically, without executing them late.

## 5. Verification

- [x] 5.1 Tests for idempotent generation across restart, retry, and clock change.
- [x] 5.2 Tests for planned-versus-actual separation and every terminal state.
- [x] 5.3 Tests for receipts including quiet runs, never-started runs, and unknown usage.
- [x] 5.4 Tests that schedule edits and skips leave completed history intact.
- [x] 5.5 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
