## ADDED Requirements

### Requirement: Office makes the employment action legible
The organization home SHALL expose the next relevant employment action—hire, assign, review, answer, resume, pause, or inspect delivery—without requiring the owner to understand internal work engines.

#### Scenario: Organization has no hired AI employees
- **WHEN** the owner enters the Office with available employee packages but no hired AI employees
- **THEN** the workplace presents a clear Hire an employee action and an honest empty office

#### Scenario: Hired employee is ready
- **WHEN** a hired employee has no active or queued commitment
- **THEN** selecting that employee offers Give an outcome as the primary action

### Requirement: Office represents independent employee commitments
The workplace SHALL derive each hired employee's position, label, status, and contextual action from that employee's own active commitment and run state rather than one organization-wide execution state.

#### Scenario: Several employees work concurrently
- **WHEN** two or more employees have active tickets
- **THEN** the Office truthfully represents each employee at the appropriate persisted station
- **AND** exposes individual stop or inspect actions without implying that all work must stop together

### Requirement: Owner attention is employee-centered
The Office SHALL summarize pending hire decisions, plans, help requests, permissions, and delivered outcomes by employee and consequence.

#### Scenario: Employee awaits an owner reply
- **WHEN** an outcome is blocked on contextual help
- **THEN** the employee moves to the attention state and the folio opens the contextual reply action
- **AND** does not redirect the owner into a separate special-purpose workflow

