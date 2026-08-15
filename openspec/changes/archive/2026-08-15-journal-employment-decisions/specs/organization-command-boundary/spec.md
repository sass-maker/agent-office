## ADDED Requirements

### Requirement: Employment decisions are journalled
The system SHALL route hiring, pausing, resuming, and retiring through the
organization command boundary, recording the actor and the employee each
concerns, and SHALL restrict them to the owner.

#### Scenario: Owner pauses an employee
- **WHEN** the owner pauses an employee
- **THEN** an event records the decision, its actor, and the employee it concerns

#### Scenario: A runtime tries to retire a coworker
- **WHEN** an employee runtime submits a retirement
- **THEN** the command is rejected, no event is appended, and employment is unchanged

#### Scenario: A rejected employment decision leaves no history
- **WHEN** an employment decision is refused by the existing rules
- **THEN** no event is appended and the state is unchanged

### Requirement: Employment records are reproducible
Records written by an employment decision SHALL derive their identifiers from
the employee, the decision, and its timestamp, so replaying reproduces them.

#### Scenario: Employment decisions are replayed
- **WHEN** journalled employment decisions are replayed onto the snapshot they followed
- **THEN** the resulting state equals the state produced by applying them directly

#### Scenario: An employment decision is repeated
- **WHEN** the same decision is submitted twice under one idempotency key
- **THEN** it applies once and appends one event
