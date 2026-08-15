## Purpose

Records when an employee's work is expected, whether it actually happened, and
what it left behind, without letting a calendar become the organization's source
of truth.

## ADDED Requirements

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
