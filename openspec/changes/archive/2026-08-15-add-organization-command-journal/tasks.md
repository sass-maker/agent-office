## 1. Event and command model

- [x] 1.1 Add `OrganizationEvent` with stable id, sequence, actor, type, occurrence timestamp, schema version, correlation/causation identifiers, and entity references.
- [x] 1.2 Add `OrganizationActor` distinguishing the owner from an employee runtime, and `OrganizationCommand` with payload, actor, correlation/causation, and idempotency key.
- [x] 1.3 Add `OrganizationCommandError` covering unauthorized actors, unsupported commands, and domain rejection, with owner-readable descriptions.

## 2. Append-only journal

- [x] 2.1 Add `OrganizationJournal` writing one JSON event per line to `journal.jsonl` with a versioned header, appending through a file handle.
- [x] 2.2 Create the journal on first accepted command without rewriting the snapshot or any existing employee home, artifact, or projection.
- [x] 2.3 Read entries with explicit detection of truncated, malformed, duplicated, out-of-order, and unsupported-version input, reporting the offending sequence position.
- [x] 2.4 Expose event lookup by entity reference for owner inspection without destructive repair.

## 3. Command processing and idempotency

- [x] 3.1 Add `OrganizationCommandProcessor` that resolves idempotency keys against the journal before applying anything.
- [x] 3.2 Apply accepted commands through the existing domain mutating functions so validation stays single-sourced.
- [x] 3.3 Append exactly one event per accepted command and nothing on rejection.
- [x] 3.4 Return the recorded result for a repeated idempotency key without a second effect.

## 4. Deterministic replay

- [x] 4.1 Add replay that rebuilds state from a snapshot plus subsequent events using the same handlers as command application.
- [x] 4.2 Record the journal sequence a snapshot corresponds to so replay knows where to resume.
- [x] 4.3 Prove snapshot-plus-replay equivalence and repeatability with a deterministic fixture.

## 5. Prove the boundary on real transitions

- [x] 5.1 Route the owner's assign-an-outcome action through the command path.
- [x] 5.2 Route the runtime's record-a-delivery result through the same command path.
- [x] 5.3 Keep existing UI behaviour, activity entries, and projections unchanged for both transitions.

## 6. Verification

- [x] 6.1 Add focused tests for command validation, unauthorized actors, idempotent retry, journal integrity failures, ordering under a backwards clock, and replay equivalence.
- [x] 6.2 Run `node scripts/check-code-health.mjs all` and `openspec validate --strict`, and keep every ratchet at or below its checked-in baseline.
- [x] 6.3 Confirm an organization created before this change loads, saves, and gains a journal without data loss.
