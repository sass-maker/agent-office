# Employee-Owned Work Specification

## Purpose

Defines one canonical work model in which hired employees own scoped outcomes, plan and delegate bounded tickets, operate through independent queues, and deliver durable results.

## Requirements

### Requirement: Outcome is the canonical unit of employee work
Every one-off assignment and scheduled responsibility SHALL create an employee-owned outcome with a requester, accountable employee, desired result, context, acceptance criteria, priority, status, plan, tickets, help requests, artifacts, and delivery history.

#### Scenario: Owner gives an employee an outcome
- **WHEN** the owner assigns a desired result to a hired employee
- **THEN** the system queues one outcome for that employee
- **AND** preserves the employee's other active and queued outcomes

#### Scenario: Recurring responsibility becomes due
- **WHEN** a recurring responsibility reaches its next due date
- **THEN** the system creates one canonical queued outcome linked to that responsibility
- **AND** does not execute it while the app is closed

### Requirement: Employees propose bounded plans
A hired employee SHALL propose one to four tickets using only assigned skills, declared tools, granted capabilities, and hired collaborators before first execution.

#### Scenario: Employee proposes a valid plan
- **WHEN** a queued outcome begins planning
- **THEN** the employee records selected skills, proposed tickets, intended delegates, and missing access
- **AND** the outcome waits for owner review when the contract or owner policy requires review

#### Scenario: Plan exceeds employee authority
- **WHEN** a proposed ticket requires an unassigned skill, undeclared tool, ungranted capability, external write, or unavailable collaborator
- **THEN** the plan is not executed
- **AND** the employee creates a precise help request describing the missing requirement

### Requirement: Delegation preserves accountability
The accountable employee SHALL be able to delegate a ticket to another hired, unpaused employee whose working contract covers the ticket while retaining ownership of the overall outcome.

#### Scenario: Employee delegates a covered ticket
- **WHEN** a proposed ticket names an eligible collaborator
- **THEN** the ticket records the delegate, accountable employee, reason, dependencies, and expected artifact
- **AND** both employees' commitments show the work

#### Scenario: Delegate is not eligible
- **WHEN** the proposed delegate is paused, retired, missing a required skill, or lacks required authority
- **THEN** the delegation is rejected before execution and becomes an owner-visible plan issue

### Requirement: Employees have independent queues and bounded concurrency
The system SHALL maintain a durable ordered queue per hired employee, execute at most one ticket per employee at a time, and allow different eligible employees to execute concurrently within a configurable local organization limit.

#### Scenario: Two employees have approved independent work
- **WHEN** capacity is available and the owner starts or resumes organization work
- **THEN** both employees may execute concurrently in their own local homes
- **AND** stopping one employee does not cancel the other employee's run

#### Scenario: One employee has several outcomes
- **WHEN** an employee owns multiple approved outcomes
- **THEN** the employee executes them according to explicit priority and queue order
- **AND** the owner can reorder queued outcomes without changing completed work

### Requirement: Outcome delivery requires reviewable evidence
An employee SHALL deliver an outcome with a summary, produced artifacts, evidence basis, unresolved limitations, and recommended next action. Delivery MUST remain distinct from owner acceptance.

#### Scenario: Employee completes all planned tickets
- **WHEN** every required ticket is complete
- **THEN** the outcome enters delivered status and appears in the owner's review queue
- **AND** the employee does not mark the outcome accepted on the owner's behalf

### Requirement: Work survives interruption without duplication
The system SHALL persist queue, plan, ticket, delegation, artifact, and run state after every consequential transition and SHALL recover interrupted work without duplicating completed tickets or artifacts.

#### Scenario: Application reopens after concurrent work was interrupted
- **WHEN** multiple employees had active tickets at shutdown
- **THEN** each active ticket becomes independently resumable
- **AND** completed tickets, artifacts, and unaffected queues remain unchanged

