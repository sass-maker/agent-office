# Agent Office — PROJECT STATUS

Last updated: 2026-08-11

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

## Products

- Native macOS POC runnable locally through Swift Package Manager.
- Locally packaged `dist/AgentOffice.app` produced by
  `scripts/package-app.sh`; direct distribution remains gated on Developer ID
  signing, notarization, Gatekeeper verification, checksum publication, and a
  support contact.
- Dependency-free static product landing page live at
  `https://office-os.pages.dev` and maintained from `site/`.

## Features (shipped)

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
- Five versioned built-in employee packages whose declarative metadata can be
  inspected before hiring. Package import rejects secret-shaped fields,
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

## Work queue

[GitHub Issues](https://github.com/sass-maker/agent-office/issues)
