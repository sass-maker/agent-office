## Purpose

Decides what a running employee may actually do, so a working contract is
enforced by the runtime boundary rather than trusted to the agent software.

## ADDED Requirements

### Requirement: Runtime requests are normalized and contained
The system SHALL express a runtime's need for permission or for a human answer
as a normalized request carrying a stable identifier, the employee, binding,
session, commitment and occurrence it belongs to, the capability and proposed
action, a sanitized input summary, risk context, and the requested scope. The
requesting runtime SHALL remain paused or contained until a valid resolution is
recorded.

#### Scenario: Runtime asks to use a capability
- **WHEN** a runtime requests a tool or external capability
- **THEN** the request is recorded with its origin, capability, sanitized summary, and requested scope, and the runtime does not proceed until it is resolved

#### Scenario: Runtime asks a question it cannot safely answer
- **WHEN** a runtime raises a question required to continue safely
- **THEN** the question stays unresolved until a person answers or cancels it, and is never auto-answered with a best-judgment response

### Requirement: Effective authority is the intersection of every limit
The system SHALL allow a capability only when it is supported by the runtime,
declared by the employee package, within the working contract's scope, granted by
the organization, within the current commitment's scope, and permitted by the
review and safety policy in force. Failing any one of these SHALL deny the
request with an inspectable reason.

#### Scenario: Capability is granted but out of contract
- **WHEN** the organization grants a capability the employee's working contract does not scope
- **THEN** the request is denied with a reason naming the contract limit

#### Scenario: Capability is in contract but not granted
- **WHEN** the working contract scopes a capability the organization has not granted
- **THEN** the request is denied and no work proceeds under it

#### Scenario: Commitment has already ended
- **WHEN** a request arrives for a commitment that is no longer active
- **THEN** the request is denied rather than applied to unrelated work

### Requirement: Approvals have explicit and different lifetimes
The system SHALL support denying a request, answering a question, allowing once,
allowing for the current occurrence, allowing for the current commitment, and
requesting a working-contract revision through the existing owner flow. Each
approval scope SHALL expire on its own terms and SHALL NOT become a durable
grant.

#### Scenario: Allowed once
- **WHEN** a capability is allowed once and used
- **THEN** a second use of that capability requires a new decision

#### Scenario: Allowed for the commitment
- **WHEN** a capability is allowed for the current commitment
- **THEN** it remains usable for that commitment and is unavailable to any other commitment

#### Scenario: Provider suggests always allowing
- **WHEN** a provider marks a request as one the user should always allow
- **THEN** the suggestion changes nothing: no grant, contract, or durable policy is created or widened

### Requirement: The broker fails closed
The system SHALL deny a request when it expires, when it is malformed, when the
capability is unrecognized, or when the resolution cannot be recorded. A denial
SHALL carry an inspectable reason, and no approval SHALL be stored for it.

#### Scenario: Request expires before anyone answers
- **WHEN** a pending request passes its expiry
- **THEN** it resolves as denied with an expiry reason and the runtime does not proceed

#### Scenario: Receipt cannot be written
- **WHEN** the broker cannot record a resolution
- **THEN** the request is denied and no approval is retained

#### Scenario: Unknown capability
- **WHEN** a runtime requests a capability the organization does not recognize
- **THEN** the request is denied rather than treated as harmless

### Requirement: Only currently authorized capabilities reach a session
The system SHALL inject into a runtime session only the capabilities currently
authorized for that employee and commitment. Revoking access SHALL remove it
from subsequent sessions and SHALL cause affected work in an active session to
be interrupted or rejected.

#### Scenario: Session receives its capability set
- **WHEN** a session is opened for an employee and commitment
- **THEN** it receives only the capabilities authorized at that moment, not a full catalogue

#### Scenario: Access is revoked mid-flight
- **WHEN** a capability is revoked while a session holds an approval for it
- **THEN** subsequent use is rejected and the affected work is interrupted rather than completed

### Requirement: Requests and receipts never carry credential values
The system SHALL keep credential values out of runtime requests, resolutions,
and recorded receipts, passing references or connection handles only, and SHALL
redact secret-shaped content from any summary it records.

#### Scenario: Summary contains a secret-shaped token
- **WHEN** a runtime submits an input summary containing an API-key-shaped value
- **THEN** the recorded request stores a redacted summary instead of the value

#### Scenario: Connection is used
- **WHEN** a request concerns a configured connection
- **THEN** it carries the connection handle, never the credential behind it

### Requirement: Resolution is idempotent and cannot be replayed elsewhere
The system SHALL treat a repeated resolution of the same request identifier as
already resolved, returning the recorded outcome without a second effect. A
resolution SHALL NOT apply to a different session, commitment, or occurrence
than the request it belongs to.

#### Scenario: Duplicate provider request
- **WHEN** the same request identifier is submitted twice
- **THEN** the second submission returns the recorded outcome and creates no second approval

#### Scenario: Late answer arrives for a finished session
- **WHEN** a resolution arrives for a request whose session has ended
- **THEN** it is rejected and cannot resume or authorize a different session
