## Purpose

Defines how locally available AI employee packages become durable organizational members through an explicit, inspectable employment lifecycle.

## ADDED Requirements

### Requirement: Employee packages declare employable capability without secrets
The system SHALL accept local employee packages that declare a stable package identifier, version, identity, role, responsibilities, included skills, required connections, execution requirements, default boundaries, and creator information. A package MUST NOT contain credentials or silently grant access.

#### Scenario: Owner imports a valid local package
- **WHEN** the owner selects a valid employee package from the local filesystem
- **THEN** the system adds it to the available employee catalogue without adding the employee to the organization
- **AND** shows every declared requirement before hire

#### Scenario: Package contains invalid or unsafe data
- **WHEN** a package is malformed, duplicates an installed package version, references an invalid skill, or contains a credential-shaped secret value
- **THEN** the system refuses the import with a specific recoverable explanation
- **AND** does not change the organization roster or grants

### Requirement: Hiring is explicit
The system SHALL require an explicit owner action before an available AI employee becomes a member of the organization.

#### Scenario: Owner hires an available employee
- **WHEN** the owner reviews the candidate folio and chooses Hire
- **THEN** the system creates one durable employee identity linked to the selected package version
- **AND** materializes the employee's local home and working contract
- **AND** records an attributable hiring activity

#### Scenario: Owner reviews the prepared starter team
- **WHEN** a new organization reaches the team step in onboarding
- **THEN** the system presents the prepared employees as candidates with declared contracts
- **AND** does not describe them as hired until the owner accepts the starter team

### Requirement: Employment state is distinct from work state
Each AI employee SHALL have an employment state of candidate, hired, paused, or retired that remains separate from resting, planning, working, waiting, reviewing, or blocked work status.

#### Scenario: Hired employee finishes an outcome
- **WHEN** a hired employee delivers or stops work
- **THEN** their work status changes without changing their hired employment state

#### Scenario: Owner pauses an employee
- **WHEN** the owner pauses a hired employee
- **THEN** active work stops recoverably, queued work remains inspectable, and no new work begins for that employee

### Requirement: Retirement preserves organizational history
The owner SHALL be able to retire an AI employee without deleting the employee's identity, outcomes, tasks, artifacts, memory, activity, or local home.

#### Scenario: Owner retires an idle employee
- **WHEN** the owner confirms retirement for an employee with no active run
- **THEN** the employee leaves the active Office and hireable roster
- **AND** remains available in organization history and attributable records

#### Scenario: Owner attempts to retire an active employee
- **WHEN** an employee has active work
- **THEN** the system requires the owner to stop or transfer that work before retirement

### Requirement: Package upgrades do not replace employee identity
The system SHALL allow an owner to review and apply a newer compatible package version while preserving the hired employee's stable identity and organization history.

#### Scenario: Compatible package update is applied
- **WHEN** the owner accepts a newer package version
- **THEN** the working contract records the new package version and declared defaults
- **AND** preserves organization-specific grants, memory, outcomes, and artifacts unless the owner explicitly changes them

