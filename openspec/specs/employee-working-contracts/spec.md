# Employee Working Contracts Specification

## Purpose

Defines the inspectable contract that keeps an AI employee's person-like organizational identity separate from its software execution components and authority.

## Requirements

### Requirement: Working contracts separate employee concerns
Every hired AI employee SHALL have a working contract that separately records identity and role, responsibilities, relationships, assigned skills, tools and required connections, capability grants, execution provider, model configuration, execution environment, workspace, and autonomy boundaries.

#### Scenario: Owner inspects a hired employee
- **WHEN** the owner opens Employee Details
- **THEN** the system presents each working-contract concern as a distinct labelled section
- **AND** identifies which values came from the employee package and which were changed by the organization

### Requirement: Identity survives execution changes
Changing an employee's execution provider, model configuration, or environment MUST NOT replace the employee identity or detach prior work.

#### Scenario: Owner changes an employee model
- **WHEN** the owner selects another available model configuration for a paused or idle employee
- **THEN** the employee keeps the same identifier, name, role, relationships, memory, tasks, artifacts, and activity
- **AND** future runs record the selected execution configuration

### Requirement: Declared capability and granted authority remain distinct
The working contract SHALL distinguish what an employee package can use from what the current organization has granted. Hiring or updating a package MUST NOT automatically grant a connection, permission, or external-write authority.

#### Scenario: Employee requires a connection that is not granted
- **WHEN** the owner hires an employee whose package declares a required connection
- **THEN** the contract shows the employee in a reduced or waiting mode
- **AND** the missing grant appears as an owner decision rather than being granted automatically

### Requirement: Contract changes are attributable and recoverable
The system SHALL record who changed an employee's role, responsibility, relationship, skill assignment, execution configuration, or autonomy boundary and SHALL preserve the previous value for inspection.

#### Scenario: Owner changes a responsibility
- **WHEN** the owner saves a new responsibility for an employee
- **THEN** future work receives the new responsibility
- **AND** the employee history records the previous value, new value, actor, and time

### Requirement: Working contracts remain local and secret-free
The system SHALL persist a human-readable projection of each working contract inside the employee's local home without writing credential values.

#### Scenario: Owner reveals the employee home
- **WHEN** the owner opens the employee's local home
- **THEN** the working contract identifies required and granted connections by stable identifier and availability
- **AND** contains no tokens, passwords, session values, or credential contents

