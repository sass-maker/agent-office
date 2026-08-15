## Why

Office OS already has durable employees, revisioned working contracts,
employee-owned outcomes, supervision, and local JSON state. What it does not
have is one path through which a consequential change reaches that state.
Today the SwiftUI app mutates `OrganizationState` directly and saves a
snapshot; `activity` entries are written by hand beside each mutation. Nothing
records who authorised a change, what caused it, or in what order transitions
happened, and a retried runtime result can apply twice.

That gap blocks every later runtime issue. A provider-neutral driver (#25), a
permission broker (#26), and bounded delegation (#27) all need a boundary that
agent software can be routed through and a history the owner can trust.

This change delivers the first three slices of the delivery order in #23:
a canonical command boundary, an append-only event journal, and deterministic
replay with idempotent retries. Later slices — runtime presence, leases,
retrieval, historical inspection — build on this substrate and stay out of
scope here.

## What Changes

- Add typed organization commands carrying actor, authorization context,
  correlation and causation identifiers, and a stable idempotency key. Owner
  UI actions and runtime-originated results use the same commands.
- Add a versioned, append-only local journal (`journal.jsonl`) written beside
  the existing `organization.json` snapshot. The snapshot and human-readable
  projections keep working exactly as they do now; the journal is authoritative
  history, not a replacement UI.
- Record an attributable, schema-versioned event for every accepted command,
  including entity references for the employee, commitment, and artifacts it
  touched.
- Rebuild organization state deterministically from a snapshot plus subsequent
  events, and prove snapshot-plus-replay equivalence with a fixture.
- Make retried commands duplicate-safe: replaying a command whose idempotency
  key is already journalled returns the recorded result instead of applying a
  second time.
- Fail visibly on truncated, malformed, out-of-order, or unsupported journal
  input rather than silently claiming a valid organization.
- Route one owner action (assigning an employee outcome) and one runtime action
  (recording an outcome delivery) through the shared path to prove the boundary.

## Capabilities

### New Capabilities

- `organization-command-boundary`: One typed, validated, attributable path for
  consequential organization changes, shared by the owner UI and agent runtimes,
  with idempotent retries.
- `organization-event-journal`: An append-only, schema-versioned local history
  of accepted organization transitions, with deterministic replay and visible
  integrity failure.

### Modified Capabilities

None. Existing employment, outcome, supervision, and memory capabilities keep
their current behaviour; commands wrap the transitions they already define.

## Non-goals

- Runtime session presence, heartbeats, and crash recovery (#23 slice 5).
- Generic expiring resource leases (#23 slice 6).
- Permission-aware knowledge retrieval, historical inspection UI, and derived
  flow metrics (#23 slices 7 and 8).
- Routing *every* consequential mutation through commands. This change proves
  the boundary on two transitions and leaves the rest to follow-up slices, so
  each slice stays independently reviewable.
- Any new production dependency, external write capability, or parallel task,
  message, or memory store.

## Impact

- Extends `AgentOfficeCore` with a command, event, and journal layer plus
  replay. No existing model type changes shape, so current organizations load
  unchanged and a journal is created on first accepted command.
- `AppModel` gains one command-dispatch path; the two proven transitions move
  onto it.
- Adds a local `journal.jsonl` file inside the organization folder. Nothing is
  deployed, published, or sent anywhere.
