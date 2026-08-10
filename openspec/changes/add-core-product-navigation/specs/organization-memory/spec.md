## Purpose

Defines the editable company memory and unified membership catalogue that give human and AI employees grounded organizational context after onboarding.

## ADDED Requirements

### Requirement: Onboarding creates structured company memory
Onboarding SHALL collect and persist the organization name, owner identity, purpose, product, audience, current stage, operating principles, constraints, and first mission before opening the Office.

#### Scenario: New owner completes onboarding
- **WHEN** the required organization, product, and mission fields are valid
- **THEN** the answers are saved locally and displayed in Company without requiring the owner to repeat them

### Requirement: Existing organizations migrate safely
Existing local organizations SHALL receive backward-compatible company-memory defaults without losing employees, work, artifacts, skills, connections, or the existing product brief.

#### Scenario: Earlier organization state is opened
- **WHEN** persisted state predates structured company memory
- **THEN** the application derives safe initial profile values from existing organization and product-brief state and saves the upgraded shape

### Requirement: Company profile remains editable
The Company destination SHALL allow the owner to inspect and edit the structured company memory while employee execution is not actively using it.

#### Scenario: Owner updates company context
- **WHEN** the owner saves valid changes to the profile
- **THEN** the organization state and inspectable local company projection reflect the new context

### Requirement: Members use one directory
The Members section SHALL list the owner, AI employees, and future human employees through the same member representation while visibly distinguishing member kind, role, reporting relationship, assistant relationship, responsibility, and current status.

#### Scenario: Owner inspects current members
- **WHEN** the owner opens Company Members
- **THEN** every persisted human and AI employee appears exactly once with their relationship and responsibility context

### Requirement: Employee details expose durable identity
The Company destination SHALL expose a full details page for every member without introducing a separate employee database or duplicating persisted state.

#### Scenario: Owner opens an employee profile
- **WHEN** the owner opens a member from Company or follows Open profile from the Office folio
- **THEN** the page shows the member's identity, responsibility, reporting relationships, current outcome, active work, assigned skills, recent artifacts, blockers, and attributable activity from existing organization state
- **AND** existing skill teaching and local artifact actions remain available where applicable

### Requirement: Skills and connections remain organization knowledge
The Company destination SHALL expose the existing employee, skill, and connection catalogues without duplicating their persistence or credential handling.

#### Scenario: Owner opens Skills or Connections
- **WHEN** the owner selects those Company sections
- **THEN** the existing locally derived catalogue and teaching or permission paths remain available
