## Why

#34 built the runtime permission broker and proved it in tests, but nothing in
the product calls it. Employee work still receives the employee's full
organization-level capability grants directly, and the broker's decisions are
recorded through an injected recorder that no one has connected to anything.

An enforcement point that is never asked enforces nothing. This change makes it
live: work receives the capabilities the broker currently authorizes, and every
decision becomes authoritative organization history.

## What Changes

- Inject the broker's currently authorized capability set into employee work
  instead of the employee's full grant list, so a capability that is granted but
  outside the current commitment's authority never reaches a runtime.
- Add a runtime-decision receipt to the organization command boundary, so every
  allow and deny is journalled with actor, correlation, and sanitized detail —
  and so a decision that cannot be recorded still fails closed.
- Surface pending runtime requests and their resolution on the app model, so the
  owner can allow once, allow for the commitment, deny, or answer.
- Expire pending requests on a bounded schedule rather than leaving them open.

## Capabilities

### Modified Capabilities

- `runtime-authority-broker`: decisions now become organization history, and the
  authorized capability set is what actually reaches a runtime.

## Non-goals

- The approval surface itself. This change exposes the state and the commands;
  the owner-facing view lands separately.
- Persisting approvals across restart. Deliberately still in-memory.
- Any new external capability, credential, or connector.

## Impact

- Adds one command payload and one receipt type to `AgentOfficeCore`.
- `EmployeeOutcomeEngine` accepts an authorized capability set; when none is
  supplied its behaviour is unchanged, so existing callers and tests are safe.
