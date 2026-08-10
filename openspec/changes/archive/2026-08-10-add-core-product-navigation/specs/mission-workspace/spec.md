## Purpose

Defines a shared mission workspace that connects the organization objective to concrete outcomes, assigned work, reviews, blockers, and delivered evidence.

## ADDED Requirements

### Requirement: Current mission has a bounded definition
The Mission destination SHALL display the current organization mission, its owner, current progress, and the observable condition that represents success.

#### Scenario: Owner opens Mission
- **WHEN** an organization has a current outcome and goals
- **THEN** the mission header shows the outcome, responsible owner, aggregate progress, and success evidence available from completed work

### Requirement: Work is organized in a list-first execution view
The Mission destination SHALL group every current task into In progress, Review, Next, or Delivered in a dense native list without changing the persisted task status merely to fit the presentation.

#### Scenario: Waiting and ready work is displayed
- **WHEN** tasks are waiting or ready
- **THEN** those tasks appear in Next with their task key, assignee, reviewer when present, due context, and dependency or blocker context

#### Scenario: Active and revision work is displayed
- **WHEN** tasks are doing or revision
- **THEN** those tasks appear in In motion with their current employee and latest state

#### Scenario: Review and completed work is displayed
- **WHEN** tasks are in review or done
- **THEN** they appear in Review or Delivered respectively with attributable artifact evidence when available

### Requirement: Mission supports focused daily operation
The Mission destination SHALL provide compact local filters and grouping controls, keyboard-accessible task selection, and a contextual task inspector while keeping the grand mission visible.

#### Scenario: Owner selects a task
- **WHEN** the owner selects a task row
- **THEN** Mission highlights the row and shows the task outcome, state, owner, reviewer, artifact, blocker, and attributable activity in a right-side inspector
- **AND** the owner can reveal an available artifact through the existing local artifact action

### Requirement: Blockers and owner decisions are visible
The Mission destination SHALL show unresolved blockers and pending owner attention next to the work they affect.

#### Scenario: Work cannot continue
- **WHEN** an unresolved blocker or permission request exists
- **THEN** Mission identifies the affected employee or task and exposes the existing resolution path

### Requirement: Mission and office share one source of truth
The Mission board and Office scene SHALL derive from the same persisted organization, employee, task, blocker, and artifact state.

#### Scenario: Employee advances a task
- **WHEN** employee execution changes a task status or creates an artifact
- **THEN** the Mission board and Office activity reflect the new state without manual synchronization
