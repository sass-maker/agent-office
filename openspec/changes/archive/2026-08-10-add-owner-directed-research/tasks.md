## 1. Durable assignment model

- [x] 1.1 Add Codable research assignment status and record types with attribution, evidence, artifact, blocker, and timestamp fields.
- [x] 1.2 Extend organization knowledge decoding and schema migration with empty defaults and resumable interrupted-research behavior.
- [x] 1.3 Add validation and lookup helpers that allow only one non-terminal assignment and preserve delivered history.
- [x] 1.4 Project assignment history and next actions to an inspectable root `RESEARCH_ASSIGNMENTS.md` file.

## 2. Bounded research execution

- [x] 2.1 Add a focused research assignment engine that updates employee state, invokes Nia once, and returns the office to rest.
- [x] 2.2 Add assignment-specific deterministic rehearsal and Local Codex prompt behavior using the existing runner, permission, skills, and memory boundaries.
- [x] 2.3 Verify permitted external output contains a source URL before researched completion and record missing evidence or runtime failure honestly.
- [x] 2.4 Store one Nia brief, one grounded Mira delivery note, attribution activity, evidence basis, and durable memory without duplicate success artifacts.
- [x] 2.5 Make cancellation and reopen convert in-flight research to a resumable state without false completion.

## 3. Application control

- [x] 3.1 Add owner submission, permission-waiting, runtime-waiting, retry, and resume actions to AppModel while preserving the single cancellable execution boundary.
- [x] 3.2 Resume a waiting assignment after the owner grants web research and keep Demo mode explicitly synthetic.
- [x] 3.3 Keep the fixed content workday behavior unchanged and prevent concurrent fixed-workday and research-assignment execution.
- [x] 3.4 Publish the researching state before execution, invalidate stale results on permission revocation or Stop, and require a successful final state save before showing delivery.

## 4. Native research desk

- [x] 4.1 Create the preserve-lane design receipt and capture the existing organization home before adding the research surface.
- [x] 4.2 Add a focused owner assignment sheet with required outcome, optional context, execution/permission truth, validation, keyboard behavior, and no workflow-builder language.
- [x] 4.3 Add one current/latest research card showing `You → Mira → Nia`, live status, blocker or retry action, evidence basis, and artifact reveal actions.
- [x] 4.4 Verify normal and minimum-width states without changing the SpriteKit character system or established navigation.
- [x] 4.5 Refine the assignment handoff with Mira and Nia portraits, owner-facing practice-run language, initial keyboard focus, and consistent recovery actions.

## 5. Verification and handoff

- [x] 5.1 Add tests for validation, single-active enforcement, delegation, permission and runtime waiting, demo honesty, evidence verification, successful delivery, failure, cancellation, persistence, and reopen idempotency.
- [x] 5.2 Run Swift tests, Swift build, release app packaging, strict OpenSpec validation, design review checks, and `git diff --check`.
- [x] 5.3 Update durable project truth, record completed Fleet skill runs, and leave GitHub issue #6 ready for owner review without committing or deploying.
