## ADDED Requirements

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

