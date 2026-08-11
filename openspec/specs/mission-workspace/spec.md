## Purpose

Defines a shared mission workspace that connects the organization objective to concrete outcomes, assigned work, reviews, blockers, and delivered evidence.

## Requirements

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

### Requirement: Mission groups work by employee-owned outcomes
The Mission destination SHALL display active, queued, delivered, and accepted outcomes across all hired employees and nest each outcome's tickets without creating a second task source of truth.

#### Scenario: Several employees own outcomes
- **WHEN** multiple outcomes exist across employees
- **THEN** Mission can group by outcome, employee, or status
- **AND** every ticket preserves its accountable employee, current assignee, reviewer, dependencies, artifact, and blocker

### Requirement: Mission exposes management actions in context
The Mission inspector SHALL expose only the valid management actions for the selected outcome or ticket, including plan review, reply, redirect, reassign, reorder, stop, request changes, and accept delivery.

#### Scenario: Owner selects a delivered outcome
- **WHEN** an outcome is delivered but not accepted
- **THEN** the inspector shows delivery evidence and offers Accept or Request changes
- **AND** does not show the outcome as organizationally complete before an owner decision

### Requirement: Mission shows queue and concurrency truth
The Mission destination SHALL show which employee work is active, queued, paused, waiting for capacity, or blocked and SHALL allow the owner to reorder queued outcomes for one employee.

#### Scenario: Organization concurrency limit is reached
- **WHEN** another eligible employee outcome is queued while all run capacity is occupied
- **THEN** Mission labels it Waiting for capacity rather than Blocked
- **AND** preserves its explicit priority and queue position
