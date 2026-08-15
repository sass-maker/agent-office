# organization-command-boundary Specification

## Purpose
Gives the owner UI and agent runtimes one typed, validated, attributable path
for consequential organization change, so authority and history cannot diverge
between clients.
## Requirements
### Requirement: Consequential change is expressed as a typed command
The system SHALL express consequential organization change as typed commands
carrying the acting identity, the command payload, a correlation identifier, an
optional causation identifier, and a stable idempotency key. Adapters such as
the SwiftUI app and future runtime drivers SHALL submit commands rather than
mutate organization state directly.

#### Scenario: Owner assigns an outcome
- **WHEN** the owner assigns an outcome to an employee
- **THEN** the change is submitted as a command identifying the owner as actor and returns the created commitment identifier

#### Scenario: Runtime records a delivery
- **WHEN** an employee runtime finishes work and records a delivery
- **THEN** the change is submitted through the same command path identifying the employee as actor

### Requirement: Commands preserve existing domain validation
A command SHALL apply the organization's existing validation rules and SHALL
fail without changing state or appending history when those rules reject it.
Command handling SHALL NOT introduce a second set of rules for a transition the
domain already defines.

#### Scenario: Command violates a domain rule
- **WHEN** a command would create a second non-terminal outcome for an employee that already has one
- **THEN** the command fails with the existing domain error and the organization state is unchanged

#### Scenario: Rejected command leaves no history
- **WHEN** a command is rejected
- **THEN** no event is appended for it and a later retry with the same idempotency key is still eligible to run

### Requirement: Retried commands are duplicate-safe
The system SHALL treat a command whose idempotency key has already been accepted
as already applied, returning the recorded result without producing a second
effect or a second event.

#### Scenario: Runtime retries after a lost response
- **WHEN** a runtime resubmits a delivery command with the same idempotency key
- **THEN** the system returns the originally recorded result and appends no additional event

#### Scenario: Distinct work is not collapsed
- **WHEN** two different commands are submitted with different idempotency keys
- **THEN** both apply and both append their own events

### Requirement: Commands carry authorization context
Every command SHALL record the authorization context under which it was
accepted, including the acting identity and, where the command concerns an
employee's work, the employee and commitment it acts on. A runtime-originated
command SHALL NOT be able to widen its own authority through the command
payload.

#### Scenario: Runtime command names its employee and commitment
- **WHEN** a runtime submits a command about an outcome
- **THEN** the recorded event references the acting employee and that commitment

#### Scenario: Runtime cannot act as the owner
- **WHEN** a command submitted by an employee runtime claims owner authority
- **THEN** the command is rejected and the organization state is unchanged

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

