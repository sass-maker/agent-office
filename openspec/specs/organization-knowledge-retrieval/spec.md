# organization-knowledge-retrieval Specification

## Purpose
Lets an employee find what it is allowed to know, and lets the owner see how
something reached its current state, without either becoming a new source of
truth.
## Requirements
### Requirement: Retrieval is filtered by the employee's actual authority
The system SHALL search across company memory, policies, skills, decisions,
commitments, contracts, and artifacts, and SHALL exclude anything outside the
employee's working contract, grants, and current commitment scope.

#### Scenario: Another employee's memory is excluded
- **WHEN** an employee searches for a term that appears in a coworker's private memory
- **THEN** that entry is not returned

#### Scenario: Own commitment and its artifacts are included
- **WHEN** an employee searches for a term in its own commitment
- **THEN** the commitment and its linked artifacts are returned

#### Scenario: Organization-level context is shared
- **WHEN** an employee searches for a term in the product brief
- **THEN** it is returned, because organization context is not private to one employee

### Requirement: Every result carries provenance
The system SHALL return, with each result, what it came from and why it was
visible, so a retrieved passage cannot silently become new company truth.

#### Scenario: Result names its source
- **WHEN** any result is returned
- **THEN** it names the record it came from and the reason it was in scope

#### Scenario: Nothing matches
- **WHEN** no allowed record matches
- **THEN** an empty result is returned rather than an unsourced answer

### Requirement: History explains how something reached its state
The system SHALL return the retained events concerning an employee, commitment,
or artifact in sequence order, with actor and type, and SHALL NOT invent an
event that was never recorded.

#### Scenario: Owner inspects a commitment
- **WHEN** the history of a commitment is requested
- **THEN** its events are returned in sequence order with actor and type

#### Scenario: Nothing was recorded
- **WHEN** an entity has no retained events
- **THEN** an empty history is returned rather than a reconstruction

### Requirement: Timing is evidence, not a score
The system SHALL derive waiting, working, blocked, review, delivery, and
owner-decision timing from retained records, and SHALL state what each figure
was derived from. It SHALL NOT rank employees, treat volume as value, or report
a figure it cannot support.

#### Scenario: Timing is derived from records
- **WHEN** flow evidence is requested for a commitment
- **THEN** each figure names the records it came from

#### Scenario: A phase never happened
- **WHEN** a commitment was never blocked
- **THEN** blocked time is reported as unknown rather than zero

