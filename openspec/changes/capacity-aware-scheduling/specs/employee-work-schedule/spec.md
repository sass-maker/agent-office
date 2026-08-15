## ADDED Requirements

### Requirement: Work waits for a bounded capacity condition
The system SHALL defer an occurrence, rather than starting or skipping it, when
its runtime is unavailable, its employee is already running other work, the
organization is at its concurrency limit, its plan is awaiting review, or a
required connection is missing. The reason SHALL be recorded, and the occurrence
SHALL remain eligible to start once the condition clears.

#### Scenario: Runtime is unavailable
- **WHEN** an occurrence is due and its employee's runtime cannot be reached
- **THEN** it waits with that reason and records no actual start

#### Scenario: Employee is already working
- **WHEN** an occurrence is due and its employee is running other work
- **THEN** it waits and names the employee

#### Scenario: Organization is at its limit
- **WHEN** an occurrence is due and the organization is already running its allowed number
- **THEN** it waits and states the limit

#### Scenario: Plan is awaiting review
- **WHEN** an occurrence is due and its commitment's plan is proposed but not reviewed
- **THEN** it waits for the owner rather than running unreviewed

#### Scenario: Condition clears
- **WHEN** a deferred occurrence is dispatched again after its condition clears
- **THEN** it starts normally

### Requirement: Recurring responsibilities dispatch from their schedule
The system SHALL start a scheduled recurring responsibility by beginning the
occurrence that responsibility already defines and dispatching its canonical
commitment, rather than introducing a second execution path.

#### Scenario: Weekly responsibility is due
- **WHEN** a recurring responsibility's scheduled window opens
- **THEN** its own occurrence begins and the canonical commitment is dispatched

#### Scenario: Responsibility cannot start
- **WHEN** a recurring responsibility cannot begin an occurrence
- **THEN** the scheduled occurrence is skipped with a stated reason and nothing runs
