## Purpose

Lets employees on different runtimes ask each other for bounded help through the
organization's existing operations, without letting a runtime rewrite
accountability or start an invisible loop.

## ADDED Requirements

### Requirement: Coworker discovery is permission-filtered
The system SHALL expose to a runtime only the coworkers visible to its employee
and relevant to the current commitment, projecting stable identity, role,
skills, working status, availability, and the collaboration operations each
supports. Dismissed, paused, unauthorized, and unavailable coworkers SHALL be
excluded, with a human-readable reason where one is safe to give.

#### Scenario: Directory excludes a paused coworker
- **WHEN** a runtime lists coworkers while one employee is paused
- **THEN** the paused employee is absent and the reason names availability rather than internal state

#### Scenario: Directory never includes the requester
- **WHEN** a runtime lists coworkers
- **THEN** its own employee is not offered as a collaboration target

### Requirement: Collaboration operations stay semantically distinct
The system SHALL keep consultation, messaging, delegation proposal, and
accountability reassignment separate operations. A foreign runtime MAY propose a
change; only validated Office OS commands and existing review rules SHALL change
assignment, ownership, deadlines, or accountability.

#### Scenario: Runtime proposes a delegation
- **WHEN** a runtime proposes delegating existing work to a coworker
- **THEN** the proposal is recorded for review and no assignment, ownership, or accountability changes

#### Scenario: Consultation does not move work
- **WHEN** a consultation completes
- **THEN** the answer is recorded against the commitment and the commitment's assignee is unchanged

### Requirement: Targets execute under their own authority
The system SHALL run a collaboration target under its own runtime binding,
working contract, grants, commitment context, and attribution. A source employee
SHALL NOT lend tools, credentials, data access, or runtime permissions to a
target.

#### Scenario: Two employees on different runtimes collaborate
- **WHEN** a source employee on one driver consults a target employee on another driver
- **THEN** the target's work runs on the target's own binding and the result is attributed to the target

#### Scenario: Request offers to lend capabilities
- **WHEN** a collaboration request offers the source employee's capabilities to the target
- **THEN** the request is rejected and no work runs

### Requirement: Collaboration is hard-contained
The system SHALL reject self-calls, repeated correlation identifiers, cycles,
and requests beyond one hop, and SHALL enforce turn and time budgets. An
unavailable or busy target SHALL be rejected or queued by existing commitment
rules rather than forced.

#### Scenario: Employee calls itself
- **WHEN** a runtime targets its own employee
- **THEN** the request is rejected before any work runs

#### Scenario: Chain would exceed one hop
- **WHEN** a target that was itself consulted tries to consult a third employee
- **THEN** the request is rejected for exceeding the permitted depth

#### Scenario: Correlation identifier is reused
- **WHEN** the same correlation identifier is submitted twice
- **THEN** the second request returns the first result and produces no second effect

#### Scenario: Deadline has passed
- **WHEN** a collaboration request arrives after its deadline
- **THEN** it is rejected rather than run late

### Requirement: Shared context is minimal and reference-based
The system SHALL share only the question and references to commitments and
artifacts the target is permitted to see. It SHALL NOT copy hidden prompts,
transcripts, organization-wide history, or unrelated memory into a collaboration.

#### Scenario: Target receives references, not transcripts
- **WHEN** a consultation is prepared
- **THEN** the target receives the question and permitted references only

### Requirement: Collaboration is visible in existing records
The system SHALL record collaboration results through the organization's
existing communication and supervision records, attributed to both the
initiating employee and the responding employee, and SHALL NOT create work the
organization cannot inspect.

#### Scenario: Consultation answer is recorded
- **WHEN** a consultation completes
- **THEN** the answer appears on the commitment's management messages attributed to the responding employee, and a supervision event records the exchange

#### Scenario: Failure is recorded honestly
- **WHEN** a collaboration fails or is rejected
- **THEN** the reason is inspectable and no partial result is presented as an answer
