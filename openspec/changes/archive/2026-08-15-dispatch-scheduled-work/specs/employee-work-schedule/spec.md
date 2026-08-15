## ADDED Requirements

### Requirement: Work whose window is open can be started
The system SHALL identify occurrences whose window has opened and not yet passed
its flexibility, and SHALL start them through the existing employee work path,
recording the actual start separately from the planned window.

#### Scenario: Window is open
- **WHEN** an occurrence's window has opened and its commitment is still open
- **THEN** the work starts and the occurrence records its actual start, session, and runtime

#### Scenario: Window has not opened
- **WHEN** an occurrence's window is still in the future
- **THEN** nothing starts

#### Scenario: Window has passed its flexibility
- **WHEN** an occurrence's window passed unnoticed
- **THEN** nothing runs late; the window is reconciled as missed

### Requirement: Unstartable work is skipped with a reason
The system SHALL skip an occurrence whose commitment has finished or whose
employee is not currently hired, recording why, and SHALL NOT record an actual
start for it.

#### Scenario: Commitment already finished
- **WHEN** an occurrence points at a commitment that is no longer open
- **THEN** it is skipped with a stated reason and no run is recorded

#### Scenario: Employee is paused
- **WHEN** an occurrence's employee is not hired
- **THEN** it is skipped with a stated reason

### Requirement: Completion reflects what the run amounted to
The system SHALL close a dispatched occurrence using the commitment's actual
state — delivered, waiting, failed, cancelled, or unchanged — and SHALL record
that a run which never started never started.

#### Scenario: Commitment delivered
- **WHEN** a dispatched commitment delivered
- **THEN** the receipt records a change with its evidence and the occurrence is delivered

#### Scenario: Commitment changed nothing
- **WHEN** a dispatched commitment finished with nothing to show
- **THEN** the receipt is quiet, which is an honest success, and not a delivery

#### Scenario: Nothing ever started
- **WHEN** an occurrence is completed without ever having started
- **THEN** the receipt says the runtime never started and the occurrence is missed

#### Scenario: Completion is not repeated
- **WHEN** an already-completed occurrence is completed again
- **THEN** the original receipt is unchanged
