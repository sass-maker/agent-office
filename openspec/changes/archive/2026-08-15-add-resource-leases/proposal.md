## Why

Employees now run concurrently, collaborate, and hold scoped approvals. Nothing
stops two of them from mutating the same commitment, artifact, or connection at
the same time, and nothing records that one is deliberately holding something
while it works.

This is slice 6 of #23: expiring leases over typed organization resources.

## What Changes

- Add leases over typed organization resources — commitment, artifact, record,
  connection, or shared workspace — with no repository, branch, or file
  assumptions.
- Record who holds a lease, over what, in which access mode, for what purpose,
  when it was acquired, renewed, and when it expires or was released.
- Permit shared reads and refuse conflicting exclusive mutations.
- Expire leases by time rather than by trust, and surface stale or conflicting
  leases as ordinary owner and employee decisions rather than errors.

## Capabilities

### New Capabilities

- `organization-resource-leases`: Expiring, inspectable claims over the things
  employees work on, so concurrent work contends explicitly rather than
  silently.

## Non-goals

- Any Git, repository, branch, worktree, or source-file concept.
- Automatic preemption. A conflict is reported, not resolved by force.
- Distributed coordination. This is one local organization.

## Impact

- Adds a lease collection to organization knowledge, decoded permissively.
- No existing model changes shape; nothing acquires a lease automatically yet.
