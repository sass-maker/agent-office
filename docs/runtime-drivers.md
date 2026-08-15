# Runtime drivers

How Office OS employs agent software it did not write, what it guarantees, and
where the boundary sits between what a runtime says and what the organization
knows.

## The three evidence layers

These are deliberately separate, and only one of them is history.

| Layer | Lives in | Authoritative? | Example |
|---|---|---|---|
| Provider-native diagnostics | `RuntimeTurnResult.rawDiagnostics` | No | A runtime's own log line |
| Normalized runtime events | `RuntimeEvent`, per session | No | `turnStarted`, `assistantOutput` |
| Organization events | `journal.jsonl` | **Yes** | `employee-outcome.assigned` |

A runtime that wants to change the organization returns a
`ProposedOrganizationCommand`. The caller submits it through the command
boundary, where authority and idempotency are decided and an organization event
is appended. A runtime event never mutates organization state, and is rejected
outright if it claims a binding or session other than the one that produced it.

**Runtime events are not persisted.** They are evidence about a session, and a
session does not outlive the app. What survives is the organization event the
work produced and, for scheduled work, its run receipt. If a future need calls
for retaining diagnostics, that is a deliberate retention decision with its own
size and privacy questions — not a side effect of emitting them.

## Driver lifecycle

```
register → resolve(binding) → availability() → openSession() → run(turn)* → stop()
```

1. **Register.** A driver is added to the registry by kind. Nothing is
   auto-discovered; Office OS ships two and the tests add a third.
2. **Resolve.** A binding resolves to either a driver or an *unavailable
   shadow* naming why: not installed, older than the binding requires,
   misconfigured, or unhealthy.
3. **Availability.** Asked, never assumed. A driver that cannot work says so,
   and Office OS reports it instead of substituting a different runtime.
4. **Session.** Created per employee, binding, and session identifier. A session
   belongs to one employee and refuses another employee's turn.
5. **Turns.** Each turn returns output, normalized events, an optional resume
   cursor, and optional raw diagnostics.
6. **Stop.** Ends the session. Presence records it; a session still marked alive
   after a restart is stopped with a reason, because a process cannot outlive
   the app that hosted it.

## Compatibility

A driver declares a contract `version`. A binding records the version it was
created against.

- Driver version **≥** binding version → resolves.
- Driver version **<** binding version → incompatible, reported with both
  numbers. Office OS does not run a binding against an older contract and hope.

Optional facilities are negotiated through `declaredCapabilities` rather than
assumed. A driver that is not chat-based, not process-based, or not resumable is
still a first-class runtime.

## Event ordering

- Events from one session are emitted in the order the session produced them.
- Ordering across sessions is not defined and must not be relied on. Correlate
  with `correlationID` instead.
- Organization events are ordered by journal sequence, never by timestamp, so a
  clock change cannot reorder history.

## Configuration and secrets

`RuntimeConfigurationValue` is either a literal or a reference to a secret held
elsewhere. A driver declares which fields are secret, and validation rejects a
literal in one of those fields.

Nothing in the runtime layer reads a secret. Resolving a reference is a
deliberate owner handoff, and credential values never appear in runtime events,
organization events, or receipts — the permission broker redacts secret-shaped
content when a request is built, before anything is recorded.

## What a driver may not do

- Become the employee's identity. Rebinding changes the runtime, never the
  employee, its history, or its contract.
- Use a capability outside the intersection of runtime support, package
  boundaries, working contract, organization grant, commitment scope, and review
  policy.
- Turn its own suggestion into policy. A provider's "always allow" is recorded
  and ignored; widening authority is an owner action on the contract.
- Answer its own consequential question, accept its own delivery, or record its
  own permission decision.

## Failure isolation

One driver being missing, misconfigured, or unhealthy affects only the employees
bound to it. Employees on other drivers keep working. A lost runtime blocks the
affected commitment with a readable reason; it never retires the employee,
erases the commitment, or fabricates a delivery.
