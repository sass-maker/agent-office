## Why

Office OS can run two things: its built-in demo employee and a local Codex
employee. Both are reached through `EmployeeRunner`, a single-method protocol
with no notion of driver identity, version, health, configuration, session, or
resumption. Choosing a runner today is a hard-coded `if provider == .localCodex`
at the call site.

The product promise is broader: a company should be able to hire agent software
from different creators without that software becoming the employee's identity.
That needs a real seam — one an unknown driver can be plugged into, and one that
keeps a missing or broken driver from taking an employee's identity or history
down with it.

This change adds that seam and moves the two existing runners behind it. It
deliberately adds no new provider, and grants no new authority: enforcement of
what a runtime may actually do is #26's permission broker, which builds on this.

## What Changes

- Add a versioned `RuntimeDriver` contract: stable kind and version, declared
  capabilities, configuration validation over secret *references* rather than
  secret values, availability and health, session creation, turn execution,
  and interrupt/stop/dispose lifecycle.
- Add `RuntimeBinding` as a durable record separate from employee identity,
  package, working contract, and model choice. Rebinding or upgrading a runtime
  changes the binding, never the employee or its history.
- Add a canonical `RuntimeEvent` envelope for session, turn, tool, assistant
  output, runtime request, usage, and error events, carrying stable employee,
  binding, session, commitment, and correlation identifiers.
- Keep three evidence layers technically distinct: raw provider-native
  diagnostics, normalized runtime events, and authoritative organization events
  from #23. Runtime events may propose organization commands; they may never
  mutate organization state directly.
- Add a driver registry that resolves a binding to a driver and produces a
  visible, inspectable *unavailable shadow* when the driver is missing, newer
  than the host, misconfigured, or unhealthy — without deleting the employee and
  without disabling other employees.
- Store opaque resume cursors per binding and session, separate from employee
  memory and organization knowledge, failing recoverably when stale.
- Move the demo and local Codex paths behind the contract, and add a
  deterministic fake driver so the contract itself is testable.

## Capabilities

### New Capabilities

- `provider-neutral-runtime`: A versioned driver contract, durable runtime
  bindings, normalized runtime events, and driver-failure isolation that let
  Office OS employ agent software it did not write.

### Modified Capabilities

None. Employee identity, contracts, commitments, and history keep their current
behaviour and remain authoritative.

## Non-goals

- Any new provider, connector, credential, network call, or external
  integration. The only drivers registered are the two that already exist plus
  a test fake.
- Runtime permission enforcement, approval flows, and capability injection —
  #26 owns those and depends on this seam.
- Employee-to-employee delegation through runtimes (#27).
- Runtime presence, heartbeats, and crash recovery as organization state (#23
  slice 5).
- Replacing `EmployeeRunner`. The existing runners keep working; they become
  the implementation detail of two drivers.

## Impact

- Adds a runtime layer to `AgentOfficeCore` and a `runtimeBindings` collection
  to organization knowledge, decoded permissively so existing organizations load
  unchanged and gain a default binding derived from their current execution
  provider.
- `AppModel`'s hard-coded runner choice becomes a registry lookup.
- No new production dependency, no deploy, nothing published.
