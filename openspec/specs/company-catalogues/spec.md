## Purpose

Give an owner one inspectable library for understanding the employees, reusable skills, coverage, and connections currently available inside an organization.

## Requirements

### Requirement: Company Library exposes three distinct catalogues
The system SHALL provide Employee, Skill, and Connection catalogue views from the native organization workplace without requiring the owner to inspect raw files.

#### Scenario: Owner opens the Company Library
- **WHEN** the owner opens the Company Library
- **THEN** the system displays navigation for Employees, Skills, and Connections
- **AND** each view is populated from the current persisted organization state

### Requirement: Employee catalogue shows actual skill coverage
The Employee catalogue SHALL list every current human and AI employee with their role, reporting relationship, assigned skills, and granted capabilities, without presenting uninstalled marketplace employees as hired.

#### Scenario: Owner inspects an employee
- **WHEN** the owner selects an employee in the catalogue
- **THEN** the system shows that employee's assigned skills and current capability grants
- **AND** the coverage matches the employee's persisted assignments

#### Scenario: Employee has no skills
- **WHEN** an employee has no assigned skills
- **THEN** the catalogue shows an explicit coverage gap instead of inferring skills from the role name

### Requirement: Skill catalogue shows reusable definitions and coverage
The Skill catalogue SHALL show every available skill's purpose, version, source, success criteria, required connections, and assigned employees.

#### Scenario: Owner inspects a skill
- **WHEN** the owner opens a skill entry
- **THEN** the system identifies which employees have the skill and which connections it requires
- **AND** distinguishes built-in skills from organization-taught skills

### Requirement: Connection catalogue reflects access rather than credentials
The Connection catalogue SHALL show the execution and tool connections recognized by the application, their current availability when it can be determined locally, and which employees have corresponding grants. It MUST NOT display or persist secret values.

#### Scenario: Local Codex is unavailable
- **WHEN** the installed Codex runtime cannot be discovered
- **THEN** the Local Codex connection is shown as unavailable with a recoverable explanation
- **AND** the Demo connection remains available

#### Scenario: Employee has web research permission
- **WHEN** Nia has the `web-research` grant
- **THEN** the Web Research connection lists Nia as permitted
- **AND** revoking the grant removes that coverage without deleting the connection definition

### Requirement: Existing organizations receive catalogue truth safely
The system SHALL migrate existing organizations to the catalogue schema without losing employees, tasks, artifacts, activity, memory, permissions, or handoffs.

#### Scenario: Version-three organization reopens
- **WHEN** an existing version-three organization is loaded
- **THEN** built-in skills and connections are added idempotently
- **AND** the existing organization work remains unchanged
