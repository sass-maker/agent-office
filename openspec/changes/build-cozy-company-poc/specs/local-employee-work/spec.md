## Purpose

Defines durable employee identity, attributed work, local artifact ownership,
and the safe optional boundary for locally authenticated model execution.

## ADDED Requirements

### Requirement: Employees are durable organizational identities
Each employee SHALL have a stable identifier, human name, employee type, role,
manager relationship, current presence, working state, and local workspace
independent of the model used for a work cycle.

#### Scenario: Employee model changes
- **WHEN** the execution model or runner used by an employee changes
- **THEN** the employee retains the same identity, role, task history, and
  workspace

### Requirement: Consequential work is attributable
Every task transition, artifact, review, blocker, and activity entry SHALL
identify the employee or owner responsible for it.

#### Scenario: Manager requests a revision
- **WHEN** the editorial manager returns a draft for revision
- **THEN** the feedback, task transition, revision count, and activity entry are
  attributed to that manager

### Requirement: Employee artifacts remain local and inspectable
The application SHALL store generated research, drafts, reviews, and reports as
ordinary files beneath the selected organization's local directory.

#### Scenario: Owner opens an artifact
- **WHEN** the owner selects an artifact from a task or report
- **THEN** the application reveals the corresponding local file using a native
  macOS action

### Requirement: Optional model execution is bounded to employee work
When the owner enables the local Codex runner, the application SHALL invoke the
installed authenticated CLI without reading or storing an API key and SHALL
request output without granting the subprocess external write authority.

#### Scenario: Codex is unavailable
- **WHEN** the local Codex executable cannot run or returns an error
- **THEN** the employee records a concise blocker or uses the explicitly
  selected deterministic demonstration runner without losing organization
  state

