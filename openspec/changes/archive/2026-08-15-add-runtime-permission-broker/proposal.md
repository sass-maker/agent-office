## Why

Office OS can now employ agent software it did not write (#25). A written
working contract is not enough to make that safe: nothing technically prevents a
runtime from using a tool, connection, or organizational power beyond the
employee's actual authority, and nothing forces a consequential question to be
answered by a person before work continues.

This change adds the enforcement layer. Every runtime request for a capability,
and every question a runtime cannot safely answer itself, goes through one
broker that computes effective authority, contains the runtime until a valid
resolution is recorded, and fails closed when anything is missing.

## What Changes

- Add normalized runtime request types: permission to invoke a tool or external
  capability, and a question whose answer is required to continue safely.
- Route every request through one broker carrying a stable request id, the
  employee, binding, session, commitment and occurrence it belongs to, the
  capability and proposed action, a sanitized input summary, risk context, and
  the requested scope.
- Compute effective authority as the intersection of what the runtime supports,
  what the employee package declares, what the working contract scopes, what the
  organization grants, what the current commitment covers, and the review policy
  in force.
- Support explicit outcomes: deny, answer the question, allow once, allow for
  the current occurrence, allow for the current commitment, or request a
  working-contract revision through the existing owner flow.
- Never let a provider's suggested "always allow" create or widen a grant,
  contract, or durable policy.
- Fail closed when the broker cannot record a resolution, a request expires, a
  request is malformed, or a capability is unrecognized. Consequential questions
  are never answered with "use your best judgment".
- Inject only the capabilities currently authorized for that employee and
  commitment into a runtime session, and make revocation take effect for new
  sessions and interrupt affected work in active ones.
- Keep credential values out of requests, events, and receipts: connection
  handles and references only, with sanitization of anything secret-shaped.
- Record request and resolution provenance through the #23 command boundary with
  sanitized details, keeping provider-native diagnostics separate.
- Make resolution idempotent: a duplicate request id cannot produce a duplicate
  effect, and a late answer cannot resume a different session or occurrence.

## Capabilities

### New Capabilities

- `runtime-authority-broker`: One enforcement point that decides what a running
  employee may actually do, contains the runtime until a person or policy has
  decided, and fails closed.

### Modified Capabilities

None. Working contracts, grants, review policy, the management inbox, and
commitment approvals remain the only durable authority model; the broker reads
them and never writes a new one.

## Non-goals

- Adding credentials, connectors, external integrations, or computer control.
- Any connector vendor dependency.
- A second contract, permission, approval, task, or audit system.
- Delegation between employees (#27).

## Impact

- Adds a broker and request model to `AgentOfficeCore`, plus scoped approvals
  held for the life of a session, occurrence, or commitment.
- No model that already exists changes shape; no new production dependency.
