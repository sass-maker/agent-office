## Purpose

Records whether an employee's runtime is actually alive, so a dead session
cannot masquerade as work in progress.

## ADDED Requirements

### Requirement: Presence is separate from employment
The system SHALL represent a runtime session with its own identity, binding,
optional commitment, state, start time, and last heartbeat, separately from the
employee, its package, its model, and its working contract.

#### Scenario: Session is registered
- **WHEN** a runtime session starts for an employee
- **THEN** presence records the session, its binding, and its start without altering the employee or its contract

#### Scenario: Two sessions for one employee
- **WHEN** a second session is registered for the same employee
- **THEN** each session is tracked separately and neither replaces the employee's identity

### Requirement: Presence states are honest
The system SHALL support starting, working, idle, waiting, unreachable, and
stopped states, and SHALL NOT infer that work is progressing from the existence
of a session.

#### Scenario: Session reports it is waiting
- **WHEN** a session reports waiting
- **THEN** presence shows waiting rather than working

#### Scenario: Session ends gracefully
- **WHEN** a session ends normally
- **THEN** presence records stopped with an end time and keeps the session's history

### Requirement: Stale heartbeats become unreachable
The system SHALL mark a session unreachable when its heartbeat is older than the
allowed interval, deterministically and without executing anything.

#### Scenario: Heartbeat goes stale
- **WHEN** reconciliation runs after a session's heartbeat has aged past the timeout
- **THEN** that session becomes unreachable and a fresh heartbeat is required to return it to working

#### Scenario: Reconciliation repeats
- **WHEN** reconciliation runs twice
- **THEN** the second run changes nothing

### Requirement: Runtime loss never rewrites employment or work
Losing a runtime SHALL NOT retire, pause, or delete the employee, SHALL NOT
erase or complete its commitment, and SHALL NOT fabricate a delivery. It MAY
make the employee unavailable and block the affected work with a reason.

#### Scenario: Session dies mid-commitment
- **WHEN** a session with an active commitment becomes unreachable
- **THEN** the employee remains hired, the commitment remains open with its history, and the work is blocked with a readable reason

#### Scenario: App reopens after a crash
- **WHEN** an organization loads with sessions that never ended
- **THEN** those sessions become stopped with a reason and no work is marked delivered
