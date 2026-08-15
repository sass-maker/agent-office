## MODIFIED Requirements

### Requirement: Only currently authorized capabilities reach a session
The system SHALL inject into a runtime session only the capabilities currently
authorized for that employee and commitment. Revoking access SHALL remove it
from subsequent sessions and SHALL cause affected work in an active session to
be interrupted or rejected. Employee work SHALL receive that authorized set
rather than the employee's full organization grant list.

#### Scenario: Session receives its capability set
- **WHEN** a session is opened for an employee and commitment
- **THEN** it receives only the capabilities authorized at that moment, not a full catalogue

#### Scenario: Access is revoked mid-flight
- **WHEN** a capability is revoked while a session holds an approval for it
- **THEN** subsequent use is rejected and the affected work is interrupted rather than completed

#### Scenario: Grant is outside the current commitment
- **WHEN** an employee holds an organization grant that its current commitment does not authorize
- **THEN** the work request does not carry that capability

## ADDED Requirements

### Requirement: Runtime decisions become organization history
The system SHALL record every runtime allow and deny through the organization
command boundary, carrying the acting identity, the request it settles, the
employee and commitment it concerns, and sanitized detail. A decision that
cannot be recorded SHALL fail closed.

#### Scenario: Owner allows a capability
- **WHEN** the owner allows a runtime request
- **THEN** an organization event records the decision, its actor, and the employee and commitment it concerns

#### Scenario: Recorded decision carries no secret
- **WHEN** a decision is journalled
- **THEN** the recorded detail contains the sanitized summary and no credential value

#### Scenario: History cannot be written
- **WHEN** the journal cannot record a decision
- **THEN** the request is denied and no approval is retained
