## Why

Agent Office can complete one seeded content workday, but the owner still
cannot employ Nia for an arbitrary real research outcome. The next usable slice
must replace “watch the demo” with “give one employee useful work and receive a
grounded deliverable” without introducing a general workflow platform.

## What Changes

- Let the owner create one bounded free-form research assignment from the
  organization home, including an outcome and optional context.
- Have Mira turn that owner request into an attributable assignment for Nia,
  while keeping responsibility, delegation, and current state visible.
- Run Nia through a small durable research lifecycle: ready, blocked for
  permission, researching, delivered, or failed.
- Require the existing read-only `web-research` grant before Local Codex may
  search; never silently downgrade externally requested research into invented
  evidence.
- Produce an inspectable Markdown research brief with source references,
  findings, uncertainty, and recommended next actions, followed by a grounded
  Mira delivery note.
- Preserve the assignment, artifacts, activity, and next action across quit and
  reopen.
- Keep Demo mode as an explicitly synthetic rehearsal and retain the existing
  fixed content workday unchanged.

## Capabilities

### New Capabilities

- `owner-directed-research`: Covers owner-created research assignments,
  assistant delegation, permission-aware execution, evidence-bearing delivery,
  bounded review, and durable resume behavior.

### Modified Capabilities

None. There are no canonical repository specs yet, and the seeded content
workday remains behaviorally unchanged.

## Impact

- Extends `AgentOfficeCore` with a small backward-compatible research
  assignment record and deterministic lifecycle helpers.
- Extends `EmployeeRunner` with a research-brief request that uses the existing
  Local Codex and read-only web-search boundary.
- Extends local persistence with inspectable assignment and research-delivery
  projections inside the selected organization folder.
- Adds a preserve-lane SwiftUI assignment and delivery surface to the existing
  organization home; the SpriteKit character system is not changed.
- Adds focused tests for delegation, permission gating, evidence honesty,
  failure, persistence, and reopen behavior.
- Adds no dependency, credential, publishing action, background scheduler, or
  external write.
