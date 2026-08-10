## 1. Durable employee duty

- [x] 1.1 Add Codable duty, occurrence, status, recurrence, and captured-input records with stable IDs and attribution.
- [x] 1.2 Migrate existing organizations to Iris, her built-in skill, and one weekly duty without duplicating or losing current state.
- [x] 1.3 Persist duty history and project it to an inspectable root `DUTIES.md` file and Iris employee files.

## 2. Bounded local feedback input

- [x] 2.1 Add the organization-owned `feedback-inbox/` directory and reveal action without accepting arbitrary external paths.
- [x] 2.2 Scan only direct regular `.txt`, `.md`, and `.csv` files without following symlinks, using deterministic 25-file and 250-KB limits.
- [x] 2.3 Record included and excluded filenames with stable source labels and block empty snapshots before model execution.

## 3. Customer voice execution

- [x] 3.1 Add one customer-voice runner operation with bounded snapshot context, no web permission, and explicit Local Codex and Demo output contracts.
- [x] 3.2 Implement the duty engine with upcoming, due, running, blocked, delivered, stop, retry, and reopen-safe transitions.
- [x] 3.3 Verify required brief sections and at least one valid source label before real delivery.
- [x] 3.4 Store Iris's brief and Mira's handoff once, advance the next due date only after persisted delivery, and prevent duplicate occurrence artifacts.

## 4. Application control

- [x] 4.1 Add AppModel actions for reveal inbox, Run now, retry, stop, and artifact reveal through the existing single cancellable execution boundary.
- [x] 4.2 Prevent customer-voice execution from overlapping the fixed content workday or owner-directed research and ignore stale completion after stop or state changes.
- [x] 4.3 Surface input, runtime, evidence, and save failures as attributable recoverable blockers without false delivery or due-date advancement.

## 5. Native duty folio

- [x] 5.1 Create a preserve-lane design receipt for the compact weekly duty surface.
- [x] 5.2 Add an Iris duty card with responsibility, due state, input coverage, Add feedback, Run now/Stop/Retry, and latest brief actions.
- [x] 5.3 Keep due and running state accessible and responsive without changing the established SpriteKit character system or navigation.
- [x] 5.4 Run Impeccable critique, polish, native audit, and fresh normal/minimum-width visual checks when the display session is available.

## 6. Verification and handoff

- [x] 6.1 Add tests for migration, safe scanning, bounds, empty input, runner permissions, evidence verification, delivery, due advancement, interruption, persistence, and idempotency.
- [x] 6.2 Run Swift tests, Swift build, app packaging/signature verification, strict OpenSpec validation, design review checks, and `git diff --check`.
- [x] 6.3 Update durable project truth, record completed Fleet skill runs, and leave GitHub issue #7 ready for owner review without committing or deploying.
