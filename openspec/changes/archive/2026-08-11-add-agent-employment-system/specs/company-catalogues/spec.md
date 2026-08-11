## ADDED Requirements

### Requirement: Employee catalogue separates available and employed agents
The Employee catalogue SHALL distinguish locally available employee packages, current hired employees, paused employees, and retired organization members without presenting a package as an employed person.

#### Scenario: Owner opens the employee catalogue
- **WHEN** local packages and organization employees both exist
- **THEN** the catalogue provides clear Available, Employed, and History groupings
- **AND** preserves one stable employee identity per hired package instance

### Requirement: Candidate folios expose the complete hiring contract
The Employee catalogue SHALL show a candidate's package version, creator, role, responsibilities, included skills, required connections, execution requirements, boundaries, and reduced-mode behavior before the owner can hire them.

#### Scenario: Owner inspects a candidate
- **WHEN** the owner selects an available employee package
- **THEN** the catalogue shows what the employee brings, what the organization must provide, and what remains unavailable
- **AND** offers an explicit Hire action rather than an install action that silently changes the roster

### Requirement: Local package management remains separate from employment
Importing, updating, or removing an unused local package SHALL NOT hire, pause, retire, or delete an organization employee.

#### Scenario: Owner removes an unused package
- **WHEN** no current or historical employee references the selected package version
- **THEN** the package leaves the Available catalogue without changing organization state

