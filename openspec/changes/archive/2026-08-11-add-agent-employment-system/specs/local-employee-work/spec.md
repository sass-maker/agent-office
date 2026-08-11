## ADDED Requirements

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

