## Context

The broker exists and is tested; nothing calls it. `EmployeeOutcomeEngine`
builds each work request with `employee.capabilityGrants` — the employee's whole
organization-level grant list, regardless of what the current commitment needs
or what the owner has approved for it.

## Decisions

### The engine takes a set, not a broker

`EmployeeOutcomeEngine.execute` accepts an optional authorized capability set.
It does not know about the broker, does not await it, and behaves exactly as
before when none is supplied. Keeping the engine ignorant of the broker is what
lets this land without touching the engine's tests or its execution semantics.

### Receipts travel the existing command path

A runtime decision is journalled as an ordinary organization command, so it
inherits attribution, correlation, idempotency, and replay for free rather than
growing a second audit store.

### Fail-closed is preserved end to end

The broker already denies when its recorder throws. Connecting that recorder to
the journal means a journal write failure denies the request — the same
behaviour, now with a real failure mode behind it.
