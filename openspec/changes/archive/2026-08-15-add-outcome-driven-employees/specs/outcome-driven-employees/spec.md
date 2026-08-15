## Purpose

Let the owner employ any AI employee for a bounded local outcome and supervise
the employee through self-created tickets, communication, help requests, and an
inspectable delivery.

## ADDED Requirements

### Requirement: Owner can assign an outcome to any AI employee
The system SHALL let the owner select an AI employee and assign a required
outcome with optional context. The assignment SHALL identify the owner and
assignee and SHALL allow at most one non-terminal generic employee outcome at a
time in the POC.

#### Scenario: Owner assigns a valid outcome
- **WHEN** the owner submits a non-empty outcome for an AI employee while no generic outcome is active
- **THEN** the system stores the assignment, attributes it to the owner, and shows the employee planning it

#### Scenario: Outcome is empty or assignee is human
- **WHEN** the owner submits only whitespace or selects a human member
- **THEN** the system refuses the assignment and explains the missing or invalid input

#### Scenario: Another generic outcome is active
- **WHEN** the owner tries to assign a second generic outcome before the first is terminal
- **THEN** the active outcome is preserved and the owner is directed back to it

### Requirement: Employee creates a bounded skill-aware ticket plan
The assigned employee SHALL receive its responsibility, organization context,
durable memory, assigned skills, and existing capability grants. It SHALL create
between one and four local tickets and SHALL record which assigned skills it
selected. It MUST NOT invent or self-assign a missing skill or capability.

#### Scenario: Planning succeeds
- **WHEN** the employee returns a valid plan using assigned skills
- **THEN** the system creates the proposed tickets on the canonical task board with bounded dependencies and begins the first ticket

#### Scenario: Plan is invalid or unsupported
- **WHEN** the plan has no usable tickets, exceeds the limit, or requires unavailable capability
- **THEN** the outcome stops with a precise blocker or help request and does not create unbounded work

### Requirement: Employee executes or asks for help
The system SHALL execute planned tickets sequentially through the existing
local employee runner, SHALL store successful outputs as ordinary artifacts,
and SHALL stop honestly when context, skill, runtime, or permission is missing.

#### Scenario: All tickets complete
- **WHEN** each planned ticket returns a usable local artifact
- **THEN** every ticket is marked done, the outcome is delivered, and the employee returns to rest

#### Scenario: Employee needs owner help
- **WHEN** a ticket cannot proceed without missing context, skill, or permission
- **THEN** the outcome enters waiting, the ticket is blocked, and the employee leaves one precise attributable request for the owner

#### Scenario: Runtime fails
- **WHEN** the local runner fails or returns no usable work
- **THEN** the outcome records a recoverable failure, preserves completed tickets, and does not claim delivery

#### Scenario: Owner stops the outcome
- **WHEN** the owner stops a non-terminal generic outcome
- **THEN** active execution is invalidated, unfinished tickets stop, and the employee returns to rest without accepting stale work

### Requirement: Communication is foundational for every AI employee
The system SHALL include a built-in Communication skill assigned to every AI
employee. Every generic outcome SHALL produce attributable communication for
acceptance, plan creation, meaningful progress, blocker/help state when
applicable, and final delivery.

#### Scenario: Existing organization is migrated
- **WHEN** an organization created before Communication is opened
- **THEN** Communication is added once and assigned once to every AI employee without changing human members

#### Scenario: Outcome is delivered
- **WHEN** an employee completes its planned tickets
- **THEN** the owner can see what was done, which skills were used, which artifacts were created, and the recommended next action without reading a raw model transcript

### Requirement: Outcome state is durable and inspectable
The system SHALL persist outcome state, tickets, artifacts, blockers, and
activity inside the selected organization folder. Interrupted planning or work
SHALL become resumable rather than falsely completed.

#### Scenario: App closes during planning or execution
- **WHEN** the organization is reopened after an in-flight generic outcome was saved
- **THEN** the outcome becomes queued with completed work preserved and a truthful resume next action

#### Scenario: Delivered outcome is reopened
- **WHEN** a delivered outcome is reopened
- **THEN** its task and artifact identifiers remain unchanged and no duplicate delivery is created
