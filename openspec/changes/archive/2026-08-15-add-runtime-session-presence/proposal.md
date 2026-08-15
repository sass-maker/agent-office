## Why

Office OS now employs runtimes through a driver contract and enforces what they
may do, but it has no idea whether a runtime is *alive*. A session that dies
mid-commitment leaves the employee looking busy forever, and a restart cannot
tell the difference between work in progress and work that stopped existing.

This is slice 5 of #23: runtime presence as durable, honest organization state.

## What Changes

- Represent an active runtime session separately from the employee, package,
  model, and working contract: a session has its own identity, binding,
  commitment, state, start, and heartbeat.
- Support the honest lifecycle — starting, working, idle, waiting, unreachable,
  stopped — with local registration, heartbeats, and graceful end.
- Reconcile presence deterministically: a session whose heartbeat has gone stale
  becomes unreachable, and on reopening, sessions that never ended become
  stopped with a reason.
- Make runtime loss block or pause work without ever retiring the employee,
  erasing a commitment, or fabricating a completion.

## Capabilities

### New Capabilities

- `runtime-session-presence`: Whether an employee's runtime is actually alive
  right now, and what happens to its work when it is not.

## Non-goals

- Machine provisioning, remote machines, or infrastructure topology.
- Automatic restart or retry of lost work. Losing a runtime surfaces a decision;
  it does not silently redo anything.

## Impact

- Adds a presence collection to organization knowledge, decoded permissively.
- Reconciliation runs on load beside the existing interrupted-work resets.
