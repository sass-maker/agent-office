# employee-work-schedule Specification

## Purpose
Records when an employee's work is expected, whether it actually happened, and
what it left behind, without letting a calendar become the organization's source
of truth.
## Requirements
### Requirement: Work can declare a schedule policy
The system SHALL let an employee's commitment or recurring responsibility
declare a schedule policy recording recurrence, intended start or window,
expected duration, flexibility, timezone, and the actor who authored it. A
schedule SHALL point at existing work rather than define new work, and an
employee without a schedule SHALL remain able to receive owner-assigned work.

#### Scenario: Recurring responsibility gains a weekly policy
- **WHEN** a recurring responsibility declares a weekly schedule
- **THEN** the policy records its recurrence, window, timezone and author, and the responsibility itself is unchanged

#### Scenario: Employee has no schedule
- **WHEN** an employee has no schedule policy
- **THEN** owner-assigned work still reaches them normally

### Requirement: Occurrences are durable and never duplicated
The system SHALL create a durable occurrence for each scheduled instant, with an
identifier derived from its policy and instant, so restart, retry, clock change,
or timezone change cannot produce a second occurrence for the same instant.

#### Scenario: Generation runs twice
- **WHEN** occurrences are generated twice over the same period
- **THEN** the same occurrences exist once each, with unchanged identifiers

#### Scenario: Clock moves between generations
- **WHEN** the clock changes and generation runs again
- **THEN** no duplicate occurrence is produced for an instant already scheduled

### Requirement: Planned and actual are recorded separately
The system SHALL keep scheduled start and window separate from actual start,
end, and duration, and SHALL NOT infer that work happened because time was
reserved.

#### Scenario: Window passes with no run
- **WHEN** a scheduled window passes and nothing ran
- **THEN** the occurrence becomes missed rather than delivered, and no actual times are recorded

#### Scenario: Run starts late but completes
- **WHEN** a run starts after its scheduled start and finishes
- **THEN** both the scheduled window and the actual start, end and duration are retained

### Requirement: Terminal states are honest and distinct
The system SHALL distinguish delivered, quiet, blocked, failed, skipped,
cancelled, and missed occurrences. A quiet run — one that executed and found
nothing to change — SHALL remain distinct from failure, empty output, and a run
that never started.

#### Scenario: Run finds nothing actionable
- **WHEN** a run completes having changed nothing
- **THEN** the occurrence is quiet, not failed and not delivered

#### Scenario: Runtime never started
- **WHEN** a runtime could not start for a scheduled occurrence
- **THEN** the occurrence records that nothing ran, distinctly from a quiet run

### Requirement: Every terminal occurrence produces a receipt
The system SHALL produce a structured receipt for each terminal occurrence
recording what was scheduled and why, the owning employee and commitment, what
actually ran and for how long, the runtime that powered it when known, the
resulting evidence, whether anything changed, and whether usage was observed,
unknown, or not applicable.

#### Scenario: Delivered run leaves a receipt
- **WHEN** a scheduled run delivers
- **THEN** its receipt names the employee, commitment, actual duration, evidence, and result

#### Scenario: Usage is unknown
- **WHEN** a runtime reports no usage information
- **THEN** the receipt records usage as explicitly unknown rather than zero

### Requirement: Owners can change the future without rewriting the past
The system SHALL let the owner pause a policy and skip, move, or cancel future
occurrences. Completed occurrences, their receipts, and accepted deliveries
SHALL NOT be rewritten or deleted by a schedule change.

#### Scenario: Policy is edited after a run
- **WHEN** a policy's window changes after an occurrence has completed
- **THEN** the completed occurrence and its receipt keep their original scheduled and actual values

#### Scenario: Future occurrence is skipped
- **WHEN** the owner skips an upcoming occurrence
- **THEN** it becomes skipped with its reason retained, and later occurrences are unaffected

### Requirement: Missed windows reconcile deterministically
On reopening, the system SHALL reconcile windows that passed without execution
to a missed state, deterministically and without executing them late.

#### Scenario: App reopens after several missed windows
- **WHEN** reconciliation runs after two windows passed unexecuted
- **THEN** both become missed, no work runs, and running reconciliation again changes nothing

### Requirement: Scheduled work is visible as a temporal projection
The system SHALL offer day and week views derived from schedule policies,
occurrences, and receipts, showing expected and actual work distinctly. Each
block SHALL expose its employee, subject, status, planned window, actual run
where one exists, and its receipt headline where one exists. The view SHALL be a
projection: it SHALL NOT create work, and SHALL show nothing where no policy
produced an occurrence.

#### Scenario: A week with scheduled and completed work
- **WHEN** the owner opens the week view
- **THEN** each occurrence appears on its scheduled day with its status, and completed ones show what actually ran

#### Scenario: No schedules exist
- **WHEN** no schedule policy exists
- **THEN** the view says so plainly rather than showing invented blocks

#### Scenario: Status is legible without colour
- **WHEN** an occurrence is missed, quiet, or delivered
- **THEN** its state is conveyed in text, not by colour alone

### Requirement: Missed windows follow an owner-authored catch-up policy
Each schedule policy SHALL declare what happens to a window that passes
unexecuted: leave it missed, or reschedule it into the next window.
Reconciliation SHALL apply that decision deterministically and SHALL NOT execute
anything late.

#### Scenario: Policy leaves missed windows missed
- **WHEN** a window passes unexecuted under the leave-missed policy
- **THEN** the occurrence is missed and no replacement is created

#### Scenario: Policy reschedules into the next window
- **WHEN** a window passes unexecuted under the reschedule policy
- **THEN** the occurrence is missed, one replacement occurrence is created for the next window, and nothing runs

#### Scenario: Reconciliation repeats
- **WHEN** reconciliation runs again after rescheduling
- **THEN** no further replacement is created

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

### Requirement: Work waits for a bounded capacity condition
The system SHALL defer an occurrence, rather than starting or skipping it, when
its runtime is unavailable, its employee is already running other work, the
organization is at its concurrency limit, its plan is awaiting review, or a
required connection is missing. The reason SHALL be recorded, and the occurrence
SHALL remain eligible to start once the condition clears.

#### Scenario: Runtime is unavailable
- **WHEN** an occurrence is due and its employee's runtime cannot be reached
- **THEN** it waits with that reason and records no actual start

#### Scenario: Employee is already working
- **WHEN** an occurrence is due and its employee is running other work
- **THEN** it waits and names the employee

#### Scenario: Organization is at its limit
- **WHEN** an occurrence is due and the organization is already running its allowed number
- **THEN** it waits and states the limit

#### Scenario: Plan is awaiting review
- **WHEN** an occurrence is due and its commitment's plan is proposed but not reviewed
- **THEN** it waits for the owner rather than running unreviewed

#### Scenario: Condition clears
- **WHEN** a deferred occurrence is dispatched again after its condition clears
- **THEN** it starts normally

### Requirement: Recurring responsibilities dispatch from their schedule
The system SHALL start a scheduled recurring responsibility by beginning the
occurrence that responsibility already defines and dispatching its canonical
commitment, rather than introducing a second execution path.

#### Scenario: Weekly responsibility is due
- **WHEN** a recurring responsibility's scheduled window opens
- **THEN** its own occurrence begins and the canonical commitment is dispatched

#### Scenario: Responsibility cannot start
- **WHEN** a recurring responsibility cannot begin an occurrence
- **THEN** the scheduled occurrence is skipped with a stated reason and nothing runs

