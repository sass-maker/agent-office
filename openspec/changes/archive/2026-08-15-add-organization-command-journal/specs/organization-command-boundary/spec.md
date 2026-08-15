## Purpose

Gives the owner UI and agent runtimes one typed, validated, attributable path
for consequential organization change, so authority and history cannot diverge
between clients.

## ADDED Requirements

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
