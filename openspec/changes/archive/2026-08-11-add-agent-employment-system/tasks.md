## 1. Employment, packages, and working contracts

- [x] 1.1 Add backward-compatible employment state, package provenance, employee package, working contract, contract change, and organization concurrency models.
- [x] 1.2 Add built-in starter packages plus validation for package identity, versions, skills, unsafe secret-shaped values, and executable paths.
- [x] 1.3 Implement package import and removal in the organization-local catalogue without changing the roster or granting capabilities.
- [x] 1.4 Implement explicit hire, pause, resume, retire, and compatible package-update operations with attributable activity and projection updates.
- [x] 1.5 Persist a secret-free `WORKING_CONTRACT.md` in each hired AI employee home and preserve employee identity across execution changes.
- [x] 1.6 Migrate existing human and AI members to hired state, link known starter packages, create contracts, and cover legacy decoding and idempotency with tests.

## 2. Canonical employee-owned work and supervision

- [x] 2.1 Expand employee outcomes with acceptance criteria, priority, queue order, source, plan review, accountable employee, delivery, revision, and acceptance history while preserving legacy decoding.
- [x] 2.2 Add persisted supervision events and derive owner inbox items from candidates, proposed plans, help requests, blocked work, deliveries, and contract changes.
- [x] 2.3 Implement plan proposal and approval, contextual owner replies, priority and queue changes, stop, redirect, eligible reassignment, delivery acceptance, bounded revision, and close actions.
- [x] 2.4 Validate delegation against employment state, pause state, assigned skills, declared tools, capability grants, and accountable ownership.
- [x] 2.5 Add focused state-machine, queue-ordering, delegation, attribution, and delivery-versus-acceptance tests.

## 3. Per-employee execution and recovery

- [x] 3.1 Introduce immutable run requests and typed run results carrying employee, contract, outcome, ticket, execution, workspace, capability, and expected-revision data.
- [x] 3.2 Implement an employee work coordinator with one task per employee and a default organization concurrency limit of two.
- [x] 3.3 Apply run results to fresh main-actor organization state with revision checks, idempotent artifacts, transition persistence, and next-work dispatch.
- [x] 3.4 Make stop and failure employee-specific and recover interrupted tickets independently on reopen.
- [x] 3.5 Add focused tests for simultaneous independent runs, capacity queuing, same-employee serialization, cancellation isolation, stale-result rejection, and recovery.

## 4. Legacy work adapters and migration

- [x] 4.1 Route generic assignments through the canonical outcome queue without a competing organization-wide work task.
- [x] 4.2 Adapt each research assignment to one linked canonical outcome while retaining research history and artifact identifiers.
- [x] 4.3 Adapt recurring responsibility occurrences to linked canonical outcomes, advancing schedules only after persisted delivery.
- [x] 4.4 Replace the fixed first content workday engine with a prepared multi-employee outcome template while preserving existing generated work.
- [x] 4.5 Migrate interrupted legacy engine states to independently resumable outcomes and remove superseded execution entry points after parity tests pass.

## 5. Preserve-lane native interface

- [x] 5.1 Create the design-workflow receipt, capture before evidence, and shape the hiring, contract, management inbox, and canonical Mission changes in the existing Editorial Office language.
- [x] 5.2 Change onboarding Team into an explicit starter-candidate contract review and hiring decision without implying candidates are already employed.
- [x] 5.3 Add Available, Employed, Paused, and History employee catalogue groups, candidate folios, declarative package import, and explicit Hire actions.
- [x] 5.4 Update Office employee folios and the owner tray to show each employee's current commitment, independent run state, and next valid management action.
- [x] 5.5 Add Working Contract sections and employment actions to Employee Details while keeping identity, skills, tooling, grants, environment, and model visibly distinct.
- [x] 5.6 Make Mission the canonical outcome and ticket view with queue, capacity, delegation, plan review, reply, redirect, reassign, revision, acceptance, and evidence actions.
- [x] 5.7 Verify normal and compact layouts, keyboard access, VoiceOver labels, focus order, reduced motion, and honest empty/loading/error states.

## 6. Verification and handoff

- [x] 6.1 Run the smallest relevant test after each implementation group and fix regressions before widening checks.
- [x] 6.2 Run migration field tests against seeded and legacy organization fixtures and inspect generated package, contract, queue, supervision, and artifact files.
- [x] 6.3 Run `swift test`, `swift build`, and strict OpenSpec validation.
- [x] 6.4 Capture native before/after evidence and complete Impeccable critique, polish, and audit with no unresolved P0 or P1 findings.
- [x] 6.5 Update `PRODUCT.md`, `DESIGN.md`, and `PROJECT_STATUS.md` to describe the shipped employment model and remaining honest POC limits.
- [x] 6.6 Mark every verified task complete, sync the accepted specifications, and archive the OpenSpec change without committing, pushing, deploying, or publishing.
