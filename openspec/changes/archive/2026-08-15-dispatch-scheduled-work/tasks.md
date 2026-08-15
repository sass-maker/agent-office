## 1. Dispatch

- [x] 1.1 Identify occurrences whose window is open.
- [x] 1.2 Start them through the existing employee work path and record the actual start.
- [x] 1.3 Register a runtime session so presence and crash recovery apply.
- [x] 1.4 Skip unstartable occurrences with a stated reason.

## 2. Completion

- [x] 2.1 Close an occurrence with the commitment's actual state.
- [x] 2.2 Record a run that never started as never started.
- [x] 2.3 Leave an already-completed occurrence and its receipt unchanged.

## 3. Verification

- [x] 3.1 Tests for open, future, and passed windows.
- [x] 3.2 Tests for skipping a finished commitment and an unhired employee.
- [x] 3.3 Tests for delivered, quiet, blocked, and never-ran receipts.
- [x] 3.4 Run `node scripts/check-code-health.mjs all` and `openspec validate --all --strict`.
