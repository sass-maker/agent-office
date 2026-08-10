## Purpose

Make an employee a portable, inspectable organizational member whose identity, duties, memory, grants, and work survive individual runs and app restarts.

## ADDED Requirements

### Requirement: AI employees have local homes
The system SHALL materialize a stable local home for every AI employee inside the selected organization folder, using ordinary human-readable files for identity, responsibilities, memory, capability grants, and artifacts.

#### Scenario: First organization load
- **WHEN** an organization with AI employees is created or opened
- **THEN** each AI employee has a uniquely named home that reflects the current persisted employee record

#### Scenario: Organization folder changes
- **WHEN** the owner switches to a different organization folder
- **THEN** the application loads or creates employee homes only within that selected folder and does not mix memory or artifacts across organizations

### Requirement: Memory is attributable and append-only
The system SHALL preserve concise memory entries with an author, timestamp, source workday, and source artifact or event, and MUST NOT silently rewrite prior entries.

#### Scenario: Employee completes useful work
- **WHEN** an employee creates an accepted artifact or encounters a durable blocker
- **THEN** the employee home receives one attributable memory entry describing the reusable fact and its source

#### Scenario: App reopens
- **WHEN** the app closes and later reopens the same organization
- **THEN** previous employee memory and artifacts remain available to the next bounded work cycle

### Requirement: Homes remain inspectable without the app
The owner SHALL be able to reveal employee homes and read their identity, responsibility, memory, grant, and artifact files with standard macOS tools.

#### Scenario: Owner opens local files
- **WHEN** the owner chooses to reveal an employee's home
- **THEN** Finder opens the corresponding directory and the files do not require a proprietary database viewer

