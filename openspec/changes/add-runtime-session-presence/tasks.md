## 1. Presence model

- [x] 1.1 Add a runtime session presence record with identity, binding, commitment, state, start, and heartbeat.
- [x] 1.2 Support starting, working, idle, waiting, unreachable, and stopped.
- [x] 1.3 Persist presence in organization knowledge with permissive decoding.

## 2. Lifecycle

- [x] 2.1 Register a session, record heartbeats, and end one gracefully.
- [x] 2.2 Mark stale heartbeats unreachable deterministically and idempotently.
- [x] 2.3 Stop sessions that never ended when an organization is reopened.

## 3. Consequences for work

- [x] 3.1 Block the affected commitment with a readable reason when a runtime is lost.
- [x] 3.2 Leave employment state, commitment history, and deliveries untouched.

## 4. Verification

- [x] 4.1 Tests for registration, heartbeat, graceful end, and separate sessions per employee.
- [x] 4.2 Tests for stale-heartbeat reconciliation and its idempotency.
- [x] 4.3 Tests that a lost runtime blocks work without retiring the employee or fabricating delivery.
- [x] 4.4 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict` with every ratchet held or tightened.
