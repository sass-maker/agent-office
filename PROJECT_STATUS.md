# Agent Office — PROJECT STATUS

Last updated: 2026-08-10

## Why / What

This is a standalone proof of concept for a native Mac workplace where an
owner hires basic AI employees, assigns an organizational outcome, and watches
employees coordinate through goals, blockers, tasks, reviews, and local
artifacts. `Agent Office` is a descriptive development name, not the product
brand.

The first slice is a small content team. It is not HR software, a coding-agent
product, or a generic automation platform.

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

## Products

- Native macOS POC runnable locally through Swift Package Manager.
- Locally packaged `dist/AgentOffice.app` produced by
  `scripts/package-app.sh`; production distribution remains out of scope.
- Dependency-free static product landing page runnable from `site/`.

## Features (shipped)

- A native SwiftUI and SpriteKit organization home with a cosy, authored
  monochrome editorial office, a human owner, a paired executive assistant,
  and four named specialist AI employees.
- One persistent full-height sidebar with Office, Mission, and Company;
  a live selectable SpriteKit workplace; floating employee folios; a grouped,
  persistent native team and work summary with keyboard-selectable employee
  folios and Needs/Moving/Done queues; a grouped, filterable Mission task list;
  editable organization memory; a unified member relationship wall; and full
  employee details for work, skills, artifacts, activity, and blockers.
- A bounded content-team workday: research, drafting, manager review, one
  revision, approval, and an end-of-day report.
- A general employee outcome loop entered from each Office folio: structured
  one-to-four-ticket planning, assigned-skill selection, sequential execution,
  local Markdown delivery, stop/retry/reopen recovery, and precise help
  requests without self-granted tools or external writes.
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

## Work queue

[GitHub Issues](https://github.com/sass-maker/agent-office/issues)
