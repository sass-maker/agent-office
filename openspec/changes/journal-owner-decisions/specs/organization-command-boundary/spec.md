## ADDED Requirements

### Requirement: Owner decisions about commitments are journalled
The system SHALL route the owner's plan approval, plan return, help answer,
delivery acceptance, and revision request through the organization command
boundary, recording actor, correlation, and the entities each concerns. Only the
owner SHALL be able to make them.

#### Scenario: Owner answers a help request
- **WHEN** the owner answers an employee's help request
- **THEN** an event records the decision, its actor, and the commitment and employee it concerns

#### Scenario: A runtime tries to accept its own delivery
- **WHEN** an employee runtime submits a delivery acceptance for its own commitment
- **THEN** the command is rejected and no event is appended

#### Scenario: A rejected decision leaves no history
- **WHEN** a decision is refused by the organization's existing rules
- **THEN** no event is appended and the state is unchanged

### Requirement: Owner-authored records are reproducible
Records written by an owner decision SHALL derive their identifiers from what
the record is about, so replaying a journalled decision reproduces the same
records rather than writing new ones.

#### Scenario: A decision is replayed
- **WHEN** a journalled decision is replayed onto the snapshot it followed
- **THEN** the resulting state equals the state produced by applying it directly

#### Scenario: A decision is repeated
- **WHEN** the same decision is submitted twice under one idempotency key
- **THEN** it applies once and appends one event
