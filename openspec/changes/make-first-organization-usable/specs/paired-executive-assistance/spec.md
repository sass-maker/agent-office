## Purpose

Give every human organization member a dedicated, bounded assistant that turns shared work state into timely briefs, decisions, and handoffs.

## ADDED Requirements

### Requirement: Every human has one paired assistant
The system SHALL maintain exactly one active AI executive-assistant relationship for each human organization member, including the owner created during first-run setup.

#### Scenario: Owner completes setup
- **WHEN** a new owner finishes organization setup
- **THEN** the workplace contains the owner and one named executive assistant whose relationship points to that owner

#### Scenario: Existing organization is upgraded
- **WHEN** an organization created by an older compatible version is opened without an owner-assistant relationship
- **THEN** the system adds the missing human owner and paired assistant without removing existing employees, tasks, or artifacts

### Requirement: Assistant brief is grounded in organization state
The assistant SHALL produce briefs only from persisted goals, tasks, blockers, decisions, activity, and artifacts, and SHALL distinguish completed work from pending or unavailable work.

#### Scenario: Morning brief
- **WHEN** the owner opens a resting organization with unfinished work
- **THEN** the assistant presents the current outcome, next owned action, unresolved blockers or decisions, and the most recent relevant artifact without claiming that unfinished work is complete

#### Scenario: End-of-day handoff
- **WHEN** a workday completes or the owner ends it
- **THEN** the assistant records a concise handoff containing completed work, artifacts, unresolved items, and the recommended next action

### Requirement: Assistant work is bounded
The assistant MUST NOT create an unbounded self-review loop and SHALL produce at most one morning brief and one end-of-day handoff for a given workday unless the underlying organization state materially changes.

#### Scenario: Reopening without new state
- **WHEN** the owner reopens the same organization without a new event, task change, artifact, or decision
- **THEN** the existing brief remains current and no duplicate assistant artifact is created

