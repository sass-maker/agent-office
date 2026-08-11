## Purpose

Defines durable employee identity, attributed work, local artifact ownership,
and the safe optional boundary for locally authenticated model execution.

## Requirements

### Requirement: Employees are durable organizational identities
Each employee SHALL have a stable identifier, human name, employee type, role,
manager relationship, current presence, working state, and local workspace
independent of the model used for a work cycle.

#### Scenario: Employee model changes
- **WHEN** the execution model or runner used by an employee changes
- **THEN** the employee retains the same identity, role, task history, and workspace

### Requirement: Consequential work is attributable
Every task transition, artifact, review, blocker, and activity entry SHALL
identify the employee or owner responsible for it.

#### Scenario: Manager requests a revision
- **WHEN** the editorial manager returns a draft for revision
- **THEN** the feedback, task transition, revision count, and activity entry are attributed to that manager

### Requirement: Employee artifacts remain local and inspectable
The application SHALL store generated research, drafts, reviews, and reports as
ordinary files beneath the selected organization's local directory.

#### Scenario: Owner opens an artifact
- **WHEN** the owner selects an artifact from a task or report
- **THEN** the application reveals the corresponding local file using a native macOS action

### Requirement: Optional model execution is bounded to employee work
When the owner enables the local Codex runner, the application SHALL invoke the
installed authenticated CLI without reading or storing an API key and SHALL
request output without granting the subprocess external write authority.

#### Scenario: Codex is unavailable
- **WHEN** the local Codex executable cannot run or returns an error
- **THEN** the employee records a concise blocker or uses the explicitly selected deterministic demonstration runner without losing organization state

### Requirement: Execution is selected per employee run
Every employee run SHALL record the hired employee, working-contract revision, execution provider, model configuration when available, workspace, granted capabilities, outcome, and ticket being executed.

#### Scenario: Two employees use different execution configurations
- **WHEN** two eligible employees begin work with different configured providers or models
- **THEN** each run uses and records its own configuration without replacing either employee identity

### Requirement: Concurrent runs remain isolated
The system SHALL execute concurrent employee runs in their respective local employee homes and SHALL prevent one run from reading or writing another employee's private work area except through explicit organization artifacts supplied as task context.

#### Scenario: Two employees run concurrently
- **WHEN** both runs create artifacts
- **THEN** each artifact is written beneath the correct employee home and attributed to the correct ticket and employee
- **AND** cancellation or failure of one run does not mutate the other's run state

### Requirement: Local execution capacity is bounded
The system SHALL enforce a small configurable organization concurrency limit and at most one active execution per employee while keeping excess work durably queued.

#### Scenario: Work exceeds local capacity
- **WHEN** approved employee outcomes exceed the configured run limit
- **THEN** only eligible work within capacity begins
- **AND** remaining work stays ordered and inspectable without polling or duplicate starts

### Requirement: Recovery is run-specific
The system SHALL persist each employee run transition independently and convert only interrupted active tickets to resumable state when the application reopens.

#### Scenario: One of several runs was interrupted
- **WHEN** the application reopens after only one run failed to persist completion
- **THEN** the uncertain run becomes resumable
- **AND** other completed or queued employee work remains unchanged
