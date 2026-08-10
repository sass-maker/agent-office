## Purpose

Defines the observable owner experience for starting, supervising, ending, and
resuming a bounded workday performed by a small team of AI employees.

## ADDED Requirements

### Requirement: First launch creates a usable organization
On first launch, the application SHALL offer a concise, skippable setup journey
that lets the owner name the organization, state its first outcome, meet the
starter employees, and enter the same persistent workplace used thereafter.

#### Scenario: Owner completes setup
- **WHEN** the owner confirms the organization and first outcome
- **THEN** the application persists setup completion, opens the organization
  home, and offers to begin the first real workday

#### Scenario: Returning owner opens the app
- **WHEN** setup was completed previously
- **THEN** the application restores the organization directly without replaying
  onboarding

### Requirement: Owner can operate one persistent organization
The application SHALL present one local organization with a name, outcome,
employees, goals, blockers, tasks, and an activity history that survive closing
and reopening the application.

#### Scenario: Resume an existing organization
- **WHEN** the owner reopens an organization that completed part of a workday
- **THEN** the application restores its employees, task state, artifacts, and
  most recent activity without restarting completed work

### Requirement: Owner can start and end a workday
The application SHALL let the owner start work, observe employees advance
eligible tasks, and end the day without losing completed progress.

#### Scenario: Start the day
- **WHEN** the owner selects Start Day while the organization is resting
- **THEN** eligible employees begin advancing the next unblocked tasks and the
  workplace reflects their active state

#### Scenario: End the day
- **WHEN** the owner selects End Day during active work
- **THEN** no new task step begins, in-flight state is persisted, and employees
  return to a resting state

### Requirement: Content work follows a bounded review cycle
The application SHALL move content work through research, drafting, manager
review, at most two revision requests, approval or a surfaced blocker, and a
daily report.

#### Scenario: Manager approves a revision
- **WHEN** the writer submits a revised draft that satisfies the manager's
  recorded feedback
- **THEN** the draft becomes approved and the report identifies its artifact

#### Scenario: Revision limit is reached
- **WHEN** a manager would request a third revision
- **THEN** the task becomes blocked for the owner instead of entering an
  unbounded employee loop

### Requirement: Owner can understand unfinished work
The application SHALL make current goals, blockers, task ownership, next work,
and the latest employee activity visible without requiring the owner to inspect
raw execution logs.

#### Scenario: Employee needs owner help
- **WHEN** an employee cannot continue within the POC's tools or review limit
- **THEN** the application creates an attributable blocker with a concise owner
  request and leaves unaffected tasks available
