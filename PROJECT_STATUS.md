# Agent Office — PROJECT STATUS

Last updated: 2026-08-31

## Why / What

This is a standalone proof of concept for a native Mac workplace where an
owner hires basic AI employees, assigns an organizational outcome, and watches
employees coordinate through goals, blockers, tasks, reviews, and local
artifacts. `Agent Office` is a descriptive development name, not the product
brand.

The first slice is a small content team. It is not HR software, a coding-agent
product, a generic automation platform, or an autonomous company with money,
legal identity, and governance. Its focus is employing and managing agents as
durable people-like collaborators whose execution remains bounded software.

## Dependencies

- macOS, SwiftUI, SpriteKit, and Foundation from the Apple SDK.
- The locally installed and authenticated Codex CLI for optional employee work
  cycles. The app must remain inspectable when Codex is unavailable.
- A user-selected local organization folder for state and artifacts.

## Timeline

- 2026-08-12 — Adopted the Fleet native code-health standard with hosted macOS
  tests, core coverage, build, formatting, unused-code, complexity, duplication,
  dependency, suppression, hygiene, and static-site gates. Existing measured
  debt is ratcheted and owned by GitHub issue #21.
- 2026-08-08 — Standalone POC project initialized.
- 2026-08-09 — First local workday slice implemented and verified.
- 2026-08-09 — First usable organization slice added with a paired executive
  assistant, durable employee homes, grounded product context, and permissioned
  research.
- 2026-08-09 — First responsive product landing page implemented locally.
- 2026-08-09 — Company Library added with explicit employee skill coverage,
  recognized connections, and owner-taught organizational guidance.
- 2026-08-09 — Repeatable local `.app` packaging added with embedded SwiftPM
  resources and ad-hoc signature verification.
- 2026-08-09 — Owner-directed research added as the first reusable employee
  assignment: Mira delegates, Nia researches, and the owner receives a durable
  evidence-labelled brief and delivery note.
- 2026-08-09 — The first live Local Codex employee assignment delivered a cited
  product recommendation in one attempt; its evidence became Iris, a Customer
  Voice Analyst with one bounded weekly local duty.
- 2026-08-10 — The owner-approved Editorial Office experience replaced the
  earlier playground shell across onboarding, Office, Mission, Company,
  employee folios, and full employee details.
- 2026-08-10 — Any AI employee can now own a free-form outcome, choose from
  existing skills, create Mission tickets, communicate progress, deliver local
  artifacts, and ask the owner for help inside explicit autonomy boundaries.
- 2026-08-11 — Employment became explicit: versioned employee packages,
  candidate-first onboarding, durable hired/paused/retired identities,
  revisioned working contracts, independent employee queues, bounded concurrent
  execution, plan review, delivery acceptance, delegation, reassignment, and a
  state-derived management inbox now form one canonical work system.
- 2026-08-11 — Native workplace polish added authored light and dark
  appearances, labelled compact navigation, a vertical compact Company
  directory, progressively disclosed candidate contracts, clearer hiring
  commitment, adaptive sheet geometry, and consistent removal of retired
  employees from the live office scene.
- 2026-08-11 — The repository-owned Office OS informational site shipped to
  `office-os.pages.dev` from verified `main`, with privacy and system details,
  release-state metadata, and a fail-closed direct-download gate.
- 2026-08-11 — The informational site adopted
  `office-os.sassmaker.com` as its product-owned canonical hostname while
  retaining `office-os.pages.dev` as the Cloudflare provider origin.
- 2026-08-15 — Consequential organization change moved onto one journalled
  command boundary: typed commands with actor, correlation and idempotency,
  an append-only local event journal beside the existing snapshot, deterministic
  replay, and visible failure on corrupt history.
- 2026-08-15 — Agent runtimes became employable through a provider-neutral
  driver contract with durable bindings, normalized runtime events, resume
  cursors, and named unavailable states. The demo and local Codex paths moved
  behind it, and a missing Codex now reports itself instead of silently
  producing demo work.
- 2026-08-15 — Employee authority became enforceable at runtime: one broker
  intersects runtime support, package boundaries, working contract, organization
  grant, commitment scope, and review policy, contains the runtime until a
  decision is recorded, and fails closed.
- 2026-08-15 — Employees on different runtimes can complete one bounded,
  permission-filtered consultation, and a runtime can propose a delegation
  without moving accountability.
- 2026-08-15 — Scheduled work gained durable occurrences, planned-versus-actual
  timestamps, honest terminal states, and structured run receipts that keep a
  quiet successful run distinct from a failure and from a run that never
  started.
- 2026-08-15 — The runtime permission broker became live: employee work receives
  only the capabilities authorized for its commitment, every allow and deny is
  organization history, and Mission surfaces what a paused runtime is waiting on.
- 2026-08-15 — Runtime presence became durable state, so a session that dies
  blocks its commitment with a reason instead of leaving an employee looking
  busy forever, and reopening stops what could not have survived.
- 2026-08-15 — Scheduled work became real work: open windows start through the
  existing employee pipeline, defer with a stated reason when capacity is short,
  and close with what the run actually amounted to.
- 2026-08-15 — Employees can claim the commitments, artifacts, records and
  connections they are working on through expiring leases that refuse conflicts
  rather than preempting them.
- 2026-08-15 — Company knowledge became searchable within each employee's own
  authority, with mandatory provenance, retained-event history, and flow timing
  that reports unknown rather than zero.
- 2026-08-15 — Owner decisions — plan review, help answers, delivery acceptance,
  revisions, hiring, pausing, resuming, retiring — travel the journalled command
  boundary and replay to the same state.
- 2026-08-22 — Rowan joined the Company Library as a hireable Reddit Growth
  Strategist package with four reusable skills, a declared but ungranted
  read-only research dependency, and a folio that states the normal mode, the
  reduced mode, and the external actions that stay with the owner.
- 2026-08-22 — Working-contract revisions travel the same boundary: role,
  responsibility, manager, skills, connections, grants, provider, model,
  boundaries and review policy move as one attributable event that replays to
  the same contract, and resubmitting the same edit changes nothing twice.
- 2026-08-31 — Runtime selection became fully per-employee: live preflight and
  execution use working contracts and commitment pins, installed CLIs report
  model choices with explicit provenance, and the legacy organization-wide mode
  remains only for persistence and one-time migration compatibility.

## Products

- Native macOS POC runnable locally through Swift Package Manager.
- Locally packaged `dist/AgentOffice.app` produced by
  `scripts/package-app.sh`; direct distribution remains gated on Developer ID
  signing, notarization, Gatekeeper verification, checksum publication, and a
  support contact.
- Dependency-free static product landing page live at
  `https://office-os.sassmaker.com` and maintained from `site/`; the
  `office-os.pages.dev` provider origin remains available as a fallback.

## Features (shipped)

- One journalled command boundary for consequential change, shared by the owner
  UI and employee runtimes, with idempotent retries, an append-only
  `journal.jsonl` history beside the existing snapshot, and deterministic replay
  that fails visibly on truncated, duplicated, out-of-order, or unsupported
  history.
- A provider-neutral runtime driver contract: versioned kinds, declared
  capabilities, secret-reference-only configuration, durable bindings separate
  from employee identity, normalized runtime events with validated origins, and
  isolated unavailable states that never substitute one runtime for another.
- A runtime permission broker that enforces effective authority as the
  intersection of every existing limit, supports once/occurrence/commitment
  approvals with genuinely different lifetimes, refuses to let a provider
  suggestion become policy, and fails closed on expiry, malformed requests,
  unknown capabilities, and unrecordable decisions.
- One-hop employee collaboration: a permission-filtered coworker directory,
  bounded consultation run on the target's own runtime and contract, and
  delegation proposals that are recorded for review without moving
  accountability.
- Employee schedule policies with duplicate-proof occurrences, planned-versus-
  actual execution, and run receipts that record what ran, for how long, on
  which runtime, with what evidence, and whether usage was observed, unknown,
  or not applicable.
- A Calendar destination with day and week views over scheduled work, showing
  expected and actual work distinctly, stating status in text rather than colour
  alone, and offering skip without rewriting completed history.
- Capacity-aware dispatch that defers work with a stated reason when the runtime
  is unreachable, the employee is already working, the organization is at its
  concurrency limit, a plan awaits review, or a required connection is missing.
- Durable runtime presence with heartbeats, stale-session reconciliation, and
  crash recovery that blocks affected work without touching employment or
  fabricating a delivery.
- Expiring leases over commitments, artifacts, records, connections and shared
  workspaces, allowing shared reads, refusing conflicting writes by naming their
  holder, and never preempting a live claim.
- Permission-aware knowledge retrieval with mandatory provenance, entity history
  read from retained events, and derived flow timing that reports unknown where
  nothing supports a figure.
- Per-employee runtime resolution across execution and owner-facing preflight,
  with commitment-time pins, explicit refusal instead of silent substitution,
  bounded local CLI model discovery, and fail-closed Auto behavior when a
  working contract is unexpectedly absent.

- A native SwiftUI and SpriteKit organization home with a cosy, authored
  monochrome editorial office, a human owner, a paired executive assistant,
  and four named specialist AI employees.
- Authored light and dark appearance roles across the native workplace, with a
  dark tonal treatment for the illustrated Office and contrast-safe structural
  controls.
- Labelled compact navigation, a no-horizontal-scroll Company member directory,
  compact-friendly sheet sizing, and candidate hiring summaries that reveal one
  complete working contract at a time while keeping the final employment
  commitment visible.
- One persistent full-height sidebar with Office, Mission, and Company;
  a live selectable SpriteKit workplace; floating employee folios; a grouped,
  persistent native team and work summary with keyboard-selectable employee
  folios and Needs/Moving/Done queues; a grouped, filterable Mission task list;
  editable organization memory; a unified member relationship wall; and full
  employee details for work, skills, artifacts, activity, and blockers.
- A bounded content-team workday: research, drafting, manager review, one
  revision, approval, and an end-of-day report.
- A general employee outcome loop entered from each Office folio: structured
  one-to-four-ticket planning, assigned-skill selection, employee-local serial
  execution within an organization-wide capacity limit, local Markdown
  delivery, stop/retry/reopen recovery, and precise help requests without
  self-granted tools or external writes.
- Six versioned built-in employee packages whose declarative metadata can be
  inspected before hiring, including Rowan, a Reddit Growth Strategist who
  prepares rule-aware community research, bounded daily plans and owner-ready
  drafts and never posts, comments, messages, signs in or controls an account. Package import rejects secret-shaped fields,
  executable paths, invalid identifiers, and duplicate skill declarations.
- Explicit employment lifecycle for AI employees: fresh organizations start
  with candidates; hiring creates a durable identity and working contract;
  pause, resume, and retire preserve attributable work and history.
- Revisioned working contracts that keep identity, role, skills, declared
  connections, granted authority, provider/model, local environment, review
  policy, and autonomy boundaries separate and inspectable. Secret-free
  `WORKING_CONTRACT.md` projections live in employee homes.
- Independent employee outcome queues with a configurable local concurrency
  limit (default two), one active run per employee, isolated cancellation, and
  revision-safe application of typed execution results to fresh persisted
  organization state.
- A state-derived management inbox and Mission commitment ledger for plan
  approval or return, contextual replies, priority and queue changes, redirect,
  skill-validated delegation and reassignment, stop, bounded revision, delivery
  inspection, acceptance, and closure.
- Canonical outcome adapters for the prepared content mission, owner-directed
  research, and Customer Voice duty. Legacy records retain their history and
  link to employee-owned outcomes instead of starting parallel execution paths.
- One owner-directed research assignment at a time, with explicit
  `You → Mira → Nia` delegation, permission and runtime waiting, cited Local
  Codex delivery, synthetic Demo honesty, retry, and reopen-safe resume.
- Iris's `Customer Voice Weekly` responsibility: a bounded scan of the local
  company feedback inbox, deterministic source labels, cited Local Codex or
  synthetic Practice delivery, Mira handoff, stop/retry/reopen recovery, and a
  next-due date that advances only after persisted delivery.
- A grounded product brief that blocks real employee work while it still
  contains starter prompts, then flows through research, drafting, review,
  memory, provenance, and the owner report.
- Mira's state-derived morning brief, owner decision queue, and attributable
  completed or interrupted end-of-day handoff.
- A narrow `web-research` permission for Nia with request, grant, revoke,
  unavailable, failure, start, and success history; no external-write
  capability exists in this slice.
- Start Day and End Day controls with resumable local state, visible goals,
  tasks, blockers, activity, and attributable Markdown artifacts.
- Deterministic demo execution and optional use of the locally authenticated
  Codex CLI without storing an API key in the app.
- Local organization folders containing inspectable JSON state,
  `PRODUCT_BRIEF.md`, `RESEARCH_ASSIGNMENTS.md`, `DUTIES.md`, a bounded
  `feedback-inbox/`, and per-employee identity, responsibility, memory,
  capability, and artifact-index files.
- A native Company Library with employee, skill, and connection catalogues;
  explicit coverage gaps; versioned built-in and owner-taught skills; and
  duplicate-safe assignment of skills to employees.
- Communication is an idempotent built-in skill for every AI employee, making
  attributable progress, delivery, and help requests part of the shared
  employee contract.
- Owner-taught operating guidance is persisted locally, projected to
  `SKILLS.md`, and supplied only to the assigned employee's future Local Codex
  work. This is organizational instruction, not model fine-tuning or
  certification.
- Recognized Demo team, Local Codex, and web-research connections with
  state-derived availability and permission grants; credentials are not stored
  in the catalogue.
- A repeatable debug or release app-bundle build that embeds portrait and scene
  resources, writes native bundle metadata, preserves previous local builds,
  and verifies its ad-hoc signature before publishing it to `dist/`.
- A responsive landing page led by the real Mac application, one concrete
  workday, the first three employees, and the intended commercial model:
  one-time workplace ownership with optional employee subscriptions.
- A verified public informational surface with local-data disclosure, macOS
  requirements, version/build identity, support readiness, repository-owned
  manual Pages deployment, and release metadata that cannot expose an
  untrusted Mac binary.
- A repository-owned native quality gate with 63 passing XCTest tests,
  explicit `AgentOfficeCore` coverage floors, a clean Swift build, zero external
  Swift packages, and non-regression ratchets for existing format, unused-code,
  complexity, and duplication debt.

## Work queue

[GitHub Issues](https://github.com/sass-maker/agent-office/issues)
