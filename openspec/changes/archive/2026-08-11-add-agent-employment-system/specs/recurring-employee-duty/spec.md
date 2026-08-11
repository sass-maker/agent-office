## MODIFIED Requirements

### Requirement: The duty runs only by an explicit in-app action
The system SHALL show whether the recurring responsibility is upcoming, due, queued, running, delivered, accepted, or blocked and SHALL create a canonical employee-owned outcome for each occurrence. The first version MUST NOT wake the app or run while the app is closed.

#### Scenario: Weekly occurrence becomes due
- **WHEN** the stored next-due date has arrived
- **THEN** the workplace shows Iris and the responsibility as due without starting work automatically
- **AND** creates at most one queued outcome for that occurrence

#### Scenario: Owner starts a due or upcoming occurrence
- **WHEN** the owner chooses Run now
- **THEN** the occurrence's canonical outcome enters Iris's employee queue
- **AND** may run alongside eligible work owned by other employees within the organization concurrency limit

### Requirement: A completed occurrence advances without duplicating work
The system SHALL advance the next-due date by one week only after the occurrence's canonical outcome is delivered and successfully persisted. Re-running a delivered or accepted occurrence MUST NOT create duplicate outcomes or artifacts, while stopping, failure, persistence failure, or reopening an interrupted run MUST leave the same occurrence and outcome resumable.

#### Scenario: Delivery persists
- **WHEN** the brief, handoff, delivered outcome, and terminal organization state save successfully
- **THEN** the next-due date advances by seven days and the completed outcome remains available for owner acceptance and history

#### Scenario: Run is interrupted
- **WHEN** the owner stops, the model fails, persistence fails, or the app reopens during a run
- **THEN** the current occurrence's outcome remains resumable and the next-due date does not advance

## ADDED Requirements

### Requirement: Recurring responsibilities use the shared employee contract
Every recurring responsibility SHALL identify its accountable hired employee, schedule, outcome template, required inputs, acceptance criteria, and required working-contract capabilities without defining a separate employee execution path.

#### Scenario: Recurring responsibility lacks required input
- **WHEN** a due occurrence cannot satisfy its declared local input boundary
- **THEN** the resulting outcome creates a precise help request through the shared supervision inbox
- **AND** no special-purpose blocker store is created

