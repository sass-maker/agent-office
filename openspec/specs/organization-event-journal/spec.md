# organization-event-journal Specification

## Purpose
Keeps an append-only, schema-versioned local record of accepted organization
transitions so the owner can reconstruct how the organization reached its
current state instead of trusting prose.
## Requirements
### Requirement: Accepted transitions append attributable events
The system SHALL append one event per accepted command to a local append-only
journal. Each event SHALL carry a stable identifier, a monotonically increasing
sequence number, the actor, the event type, an occurrence timestamp, the journal
schema version, correlation and causation identifiers, and references to the
entities it concerns.

#### Scenario: Command is accepted
- **WHEN** a command is accepted
- **THEN** exactly one event is appended with the next sequence number and the acting identity

#### Scenario: Existing snapshot keeps working
- **WHEN** an organization that has never had a journal accepts its first command
- **THEN** the journal is created alongside the existing snapshot and no existing state, employee home, artifact, or projection is lost

### Requirement: Journal ordering is independent of wall-clock time
The journal SHALL order events by sequence number. A timestamp that moves
backwards SHALL NOT reorder history or cause an event to be rejected.

#### Scenario: Clock moves backwards between events
- **WHEN** an event is appended with an occurrence timestamp earlier than the previous event
- **THEN** it receives the next sequence number and replay applies it after the previous event

### Requirement: Replay reconstructs state deterministically
The system SHALL rebuild organization state from a snapshot plus the events
recorded after that snapshot, producing the same state as applying the same
commands directly. Replaying the same journal twice SHALL produce identical
state.

#### Scenario: Snapshot plus replay equals direct application
- **WHEN** a sequence of commands is applied to an organization and the resulting journal is replayed against the starting snapshot
- **THEN** the replayed state equals the directly applied state

#### Scenario: Replay is repeatable
- **WHEN** the same journal is replayed twice from the same snapshot
- **THEN** both runs produce identical state

### Requirement: Corrupt or unsupported history fails visibly
The system SHALL detect truncated, malformed, duplicated, out-of-order, and
unsupported-version journal entries and SHALL report the failure with the
offending sequence position. It SHALL NOT silently skip an entry, repair the
file automatically, or present the result as a valid organization.

#### Scenario: Journal is truncated by a crash
- **WHEN** the final line of the journal is incomplete
- **THEN** replay fails with an error naming the truncated position and no state is returned

#### Scenario: Journal contains a future schema version
- **WHEN** an event declares a schema version the running app does not support
- **THEN** replay fails visibly rather than ignoring the event

#### Scenario: Journal repeats a sequence number
- **WHEN** two entries claim the same sequence number
- **THEN** replay fails and identifies the duplicated position

### Requirement: History is inspectable without destructive repair
The system SHALL let the owner read recorded events, including the actor,
type, and entity references, and SHALL NOT rewrite or delete journal entries as
part of ordinary operation.

#### Scenario: Owner inspects how a commitment reached its state
- **WHEN** the events for a commitment are requested
- **THEN** they are returned in sequence order with actor and type for each

#### Scenario: Integrity failure is reported rather than repaired
- **WHEN** replay detects an integrity failure
- **THEN** the journal file is left unchanged

